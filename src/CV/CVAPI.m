#import "CVAPI.h"
#import "CVPageData.h"
#import "CVCache.h"
#import "CVCommon.h"

static NSString * const CVSiteBase = @"https://www.southparkstudios.com";

@implementation CVAPI

+ (instancetype)shared
{
    static CVAPI *api;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ api = [[CVAPI alloc] init]; });
    return api;
}

- (NSDictionary *)browserHeaders
{
    return @{
        @"User-Agent": @"Mozilla/5.0 (iPad; CPU OS 12_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Mobile/15E148 Safari/604.1",
        @"Accept": @"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        @"Accept-Language": @"en-US,en;q=0.9"
    };
}

- (CVHTTPTask *)fetchSeasonsWithCompletion:(void (^)(NSArray<CVSeason *> *seasons, NSError *error))completion
{
    // Check cache
    NSArray *cached = [[CVCache shared] objectForKey:@"seasons_list"];
    if (cached.count) {
        if (completion) completion(cached, nil);
        return nil;
    }

    NSString *url = [CVSiteBase stringByAppendingString:@"/seasons/south-park/"];
    return [CVHTTP get:url headers:[self browserHeaders] completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        if (error || status >= 400 || !body.length) {
            if (completion) completion(nil, error ?: CVMakeError(status, @"Failed to fetch seasons"));
            return;
        }

        NSString *html = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        NSDictionary *data = [CVPageData extractDataFromHTML:html];
        NSArray<CVSeason *> *seasons = [CVPageData seasonsFromPageData:data];

        if (seasons.count) {
            [[CVCache shared] setObject:seasons forKey:@"seasons_list" ttl:86400]; // 24h
            if (completion) completion(seasons, nil);
        } else {
            if (completion) completion(nil, CVMakeError(CVErrorBadResponse, @"Could not parse seasons"));
        }
    }];
}

- (CVHTTPTask *)fetchEpisodesForSeason:(CVSeason *)season completion:(void (^)(NSArray<CVEpisode *> *episodes, NSError *error))completion
{
    if (!season) {
        if (completion) completion(@[], nil);
        return nil;
    }

    NSString *cacheKey = [NSString stringWithFormat:@"episodes_season_%ld", (long)season.seasonNumber];
    NSArray *cached = [[CVCache shared] objectForKey:cacheKey];
    if (cached.count) {
        if (completion) completion(cached, nil);
        return nil;
    }

    NSArray *bundled = [self bundledEpisodesForSeasonNumber:season.seasonNumber];
    if (bundled.count) {
        season.episodeCount = bundled.count;
        [[CVCache shared] setObject:bundled forKey:cacheKey ttl:21600];
        if (completion) completion(bundled, nil);
        return nil;
    }

    NSString *url = nil;
    if (season.urlPath.length) {
        if ([season.urlPath hasPrefix:@"http"]) url = season.urlPath;
        else url = [CVSiteBase stringByAppendingString:season.urlPath];
    } else {
        url = [CVSiteBase stringByAppendingString:@"/seasons/south-park/"];
    }

    return [CVHTTP get:url headers:[self browserHeaders] completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        if (error || status >= 400 || !body.length) {
            if (completion) completion(nil, error ?: CVMakeError(status, @"Failed to fetch episodes"));
            return;
        }

        NSString *html = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        NSDictionary *data = [CVPageData extractDataFromHTML:html];
        NSArray<CVEpisode *> *episodes = [CVPageData episodesFromPageData:data defaultSeasonNumber:season.seasonNumber];

        if (episodes.count) {
            season.episodeCount = episodes.count;
            [[CVCache shared] setObject:episodes forKey:cacheKey ttl:21600]; // 6h
            if (completion) completion(episodes, nil);
        } else {
            if (completion) completion(nil, CVMakeError(CVErrorBadResponse, @"No episodes found for season"));
        }
    }];
}

- (CVHTTPTask *)fetchHomeWithCompletion:(void (^)(NSArray<CVClip *> *featuredClips, NSArray<CVEpisode *> *latestEpisodes, NSError *error))completion
{
    NSString *url = [CVSiteBase stringByAppendingString:@"/"];
    return [CVHTTP get:url headers:[self browserHeaders] completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        if (error || status >= 400 || !body.length) {
            if (completion) completion(nil, nil, error ?: CVMakeError(status, @"Failed to fetch home"));
            return;
        }

        NSString *html = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        NSDictionary *data = [CVPageData extractDataFromHTML:html];
        NSArray<CVClip *> *clips = [CVPageData clipsFromPageData:data];
        NSArray<CVEpisode *> *eps = [CVPageData episodesFromPageData:data defaultSeasonNumber:1];

        if (completion) completion(clips ?: @[], eps ?: @[], nil);
    }];
}

- (CVHTTPTask *)resolveStreamForItemURL:(NSString *)urlPath itemUUID:(NSString *)uuid completion:(void (^)(CVStream *stream, NSError *error))completion
{
    if (!urlPath.length) {
        if (completion) completion(nil, CVMakeError(CVErrorBadResponse, @"Invalid URL path"));
        return nil;
    }

    NSString *itemFullUrl = [urlPath hasPrefix:@"http"] ? urlPath : [CVSiteBase stringByAppendingString:urlPath];

    CVHTTPTask *outerTask = [[CVHTTPTask alloc] init];

    CVHTTPTask *pageTask = [CVHTTP get:itemFullUrl headers:[self browserHeaders] completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        if (outerTask.isCancelled) return;
        if (error || status >= 400 || !body.length) {
            if (completion) completion(nil, error ?: CVMakeError(status, @"Failed to fetch video page"));
            return;
        }

        NSString *html = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        NSDictionary *data = [CVPageData extractDataFromHTML:html];
        NSString *rawServiceUrl = [CVPageData videoServiceURLFromPageData:data];

        if (!rawServiceUrl.length) {
            if (completion) completion(nil, CVMakeError(CVErrorBadResponse, @"Video service URL not found"));
            return;
        }

        // Clean placeholders
        NSMutableString *cleanUrl = [rawServiceUrl mutableCopy];
        [cleanUrl replaceOccurrencesOfString:@"{clientPlatform}" withString:@"desktop" options:0 range:NSMakeRange(0, cleanUrl.length)];
        // Remove unresolved query parameters like &advertId={advertisingid}
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"&[a-zA-Z]+=\\{[a-zA-Z]+\\}" options:0 error:NULL];
        [regex replaceMatchesInString:cleanUrl options:0 range:NSMakeRange(0, cleanUrl.length) withTemplate:@""];

        CVHTTPTask *micaTask = [CVHTTP getJSON:cleanUrl headers:@{ @"Referer": CVSiteBase } completion:^(id json, NSInteger mStatus, NSError *mError) {
            if (outerTask.isCancelled) return;
            if (mError || mStatus >= 400 || ![json isKindOfClass:[NSDictionary class]]) {
                if (completion) completion(nil, mError ?: CVMakeError(mStatus, @"Failed to fetch stream descriptor"));
                return;
            }

            NSDictionary *dict = (NSDictionary *)json;
            NSDictionary *stitched = CVDict(dict[@"stitchedstream"]);
            NSString *source = CVStr(stitched[@"source"]);
            if (!source.length) {
                if (completion) completion(nil, CVMakeError(CVErrorBadResponse, @"No stream source in mica"));
                return;
            }

            CVStream *stream = [[CVStream alloc] init];
            stream.itemUUID = uuid;
            stream.masterURL = [NSURL URLWithString:source];
            stream.durationSeconds = [CVPageData secondsFromDurationString:CVStr(stitched[@"duration"])];

            double expEpoch = [dict[@"expirydateepoch"] doubleValue];
            if (expEpoch > 0) {
                stream.expiresAt = [NSDate dateWithTimeIntervalSince1970:expEpoch];
            } else {
                stream.expiresAt = [NSDate dateWithTimeIntervalSinceNow:240]; // ~4 mins fallback
            }

            // Chapters (acts)
            NSArray *contents = CVArr(dict[@"content"]);
            if (contents.count) {
                NSDictionary *c0 = contents[0];
                NSArray *chRaw = CVArr(c0[@"chapters"]);
                NSMutableArray *parsedCh = [NSMutableArray array];
                for (NSDictionary *ch in chRaw) {
                    if (![ch isKindOfClass:[NSDictionary class]]) continue;
                    CVChapter *chapter = [[CVChapter alloc] init];
                    chapter.sequence = [ch[@"sequence"] integerValue];
                    chapter.chapterId = CVStr(ch[@"id"]);
                    chapter.title = [NSString stringWithFormat:@"Act %ld", (long)chapter.sequence];
                    chapter.streamOffsetSeconds = [CVPageData secondsFromDurationString:CVStr(ch[@"streamoffset"])];
                    chapter.durationSeconds = [CVPageData secondsFromDurationString:CVStr(ch[@"duration"])];
                    [parsedCh addObject:chapter];
                }
                stream.chapters = parsedCh;
            }

            if (completion) completion(stream, nil);
        }];

        outerTask.cancelBlock = ^{ [micaTask cancel]; };
    }];

    outerTask.cancelBlock = ^{ [pageTask cancel]; };
    return outerTask;
}

- (NSArray<CVEpisode *> *)allCatalogEpisodes
{
    static NSArray<CVEpisode *> *sCatalog = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"catalog" ofType:@"json"];
        if (path) {
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (data) {
                NSArray *raw = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([raw isKindOfClass:[NSArray class]]) {
                    NSMutableArray *list = [NSMutableArray arrayWithCapacity:raw.count];
                    for (NSDictionary *d in raw) {
                        if (![d isKindOfClass:[NSDictionary class]]) continue;
                        CVEpisode *ep = [[CVEpisode alloc] init];
                        ep.uuid = CVStr(d[@"uuid"]);
                        ep.title = CVStr(d[@"title"]);
                        ep.summary = CVStr(d[@"summary"]);
                        ep.seasonNumber = [d[@"seasonNumber"] integerValue];
                        ep.episodeNumber = [d[@"episodeNumber"] integerValue];
                        ep.seasonEpisodeString = CVStr(d[@"seasonEpisodeString"]);
                        ep.airDate = CVStr(d[@"airDate"]);
                        ep.durationString = CVStr(d[@"durationString"]);
                        ep.urlPath = CVStr(d[@"urlPath"]);
                        NSString *rawImg = CVStr(d[@"thumbnailURL"]);
                        if (rawImg.length) {
                            if ([rawImg rangeOfString:@"format="].location == NSNotFound) {
                                ep.thumbURL = [rawImg stringByAppendingString:@"&format=jpg"];
                            } else {
                                ep.thumbURL = rawImg;
                            }
                        }
                        ep.available = YES;
                        [list addObject:ep];
                    }
                    sCatalog = [list copy];
                }
            }
        }
        if (!sCatalog) sCatalog = @[];
    });
    return sCatalog;
}

- (NSArray<CVEpisode *> *)bundledEpisodesForSeasonNumber:(NSInteger)seasonNumber
{
    NSArray<CVEpisode *> *all = [self allCatalogEpisodes];
    NSMutableArray *res = [NSMutableArray array];
    for (CVEpisode *ep in all) {
        if (ep.seasonNumber == seasonNumber) {
            [res addObject:ep];
        }
    }
    return res;
}

- (void)searchEpisodesAndClips:(NSString *)query completion:(void (^)(NSArray *results, NSError *error))completion
{
    if (!query.length) {
        if (completion) completion(@[], nil);
        return;
    }

    NSString *trimmed = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) {
        if (completion) completion(@[], nil);
        return;
    }

    NSString *cleanQuery = [trimmed lowercaseString];
    NSArray *queryWords = [cleanQuery componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray *nonEmptyWords = [NSMutableArray array];
    for (NSString *w in queryWords) {
        if (w.length) [nonEmptyWords addObject:w];
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *results = [NSMutableArray array];
        NSMutableSet *seenResultKeys = [NSMutableSet set];
        NSMutableArray<CVEpisode *> *allCandidates = [NSMutableArray array];
        NSMutableSet *seenCandidateKeys = [NSMutableSet set];

        // 1. Gather cached episodes first (they have the freshest metadata)
        NSArray *seasons = [[CVCache shared] objectForKey:@"seasons_list"];
        for (CVSeason *s in seasons) {
            NSString *key = [NSString stringWithFormat:@"episodes_season_%ld", (long)s.seasonNumber];
            NSArray *eps = [[CVCache shared] objectForKey:key];
            for (CVEpisode *ep in eps) {
                NSString *k = ep.uuid.length ? ep.uuid : [NSString stringWithFormat:@"s%ld_e%ld", (long)ep.seasonNumber, (long)ep.episodeNumber];
                if (k.length && ![seenCandidateKeys containsObject:k]) {
                    [seenCandidateKeys addObject:k];
                    [allCandidates addObject:ep];
                }
            }
        }

        // 2. Add remaining episodes from catalog
        NSArray<CVEpisode *> *catalog = [self allCatalogEpisodes];
        for (CVEpisode *ep in catalog) {
            NSString *k = ep.uuid.length ? ep.uuid : [NSString stringWithFormat:@"s%ld_e%ld", (long)ep.seasonNumber, (long)ep.episodeNumber];
            if (k.length && ![seenCandidateKeys containsObject:k]) {
                [seenCandidateKeys addObject:k];
                [allCandidates addObject:ep];
            }
        }

        // 3. Search episodes
        for (CVEpisode *ep in allCandidates) {
            NSString *t = ep.title.lowercaseString ?: @"";
            NSString *desc = ep.summary.lowercaseString ?: @"";
            NSString *se = ep.seasonEpisodeString.lowercaseString ?: @"";
            NSString *sCode1 = [NSString stringWithFormat:@"s%ld", (long)ep.seasonNumber];
            NSString *sCode2 = [NSString stringWithFormat:@"s%02ld", (long)ep.seasonNumber];
            NSString *seCode1 = [NSString stringWithFormat:@"s%lde%ld", (long)ep.seasonNumber, (long)ep.episodeNumber];
            NSString *seCode2 = [NSString stringWithFormat:@"s%02lde%02ld", (long)ep.seasonNumber, (long)ep.episodeNumber];
            NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@ %@", t, desc, se, sCode1, sCode2, seCode1, seCode2];

            BOOL allMatch = YES;
            for (NSString *w in nonEmptyWords) {
                if ([combined rangeOfString:w].location == NSNotFound) {
                    allMatch = NO;
                    break;
                }
            }
            if (allMatch) {
                NSString *resKey = ep.uuid.length ? ep.uuid : [NSString stringWithFormat:@"s%ld_e%ld", (long)ep.seasonNumber, (long)ep.episodeNumber];
                if (!resKey.length) resKey = ep.title;
                if (resKey.length && ![seenResultKeys containsObject:resKey]) {
                    [seenResultKeys addObject:resKey];
                    [results addObject:ep];
                }
            }
        }

        // 4. Also search any cached clips
        NSArray *cachedClips = [[CVCache shared] objectForKey:@"clips_page_1"];
        for (CVClip *clip in cachedClips) {
            NSString *t = clip.title.lowercaseString ?: @"";
            NSString *desc = clip.summary.lowercaseString ?: @"";
            NSString *se = clip.seasonEpisodeString.lowercaseString ?: @"";
            NSString *combined = [NSString stringWithFormat:@"%@ %@ %@", t, desc, se];

            BOOL allMatch = YES;
            for (NSString *w in nonEmptyWords) {
                if ([combined rangeOfString:w].location == NSNotFound) {
                    allMatch = NO;
                    break;
                }
            }
            if (allMatch) {
                NSString *resKey = clip.uuid.length ? clip.uuid : clip.title;
                if (resKey.length && ![seenResultKeys containsObject:resKey]) {
                    [seenResultKeys addObject:resKey];
                    [results addObject:clip];
                }
            }
        }

        // Rank results: exact title match or title prefix first
        [results sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            if ([obj1 isKindOfClass:[CVEpisode class]] && [obj2 isKindOfClass:[CVEpisode class]]) {
                CVEpisode *ep1 = (CVEpisode *)obj1;
                CVEpisode *ep2 = (CVEpisode *)obj2;
                BOOL ep1TitleMatch = [ep1.title.lowercaseString rangeOfString:cleanQuery].location != NSNotFound;
                BOOL ep2TitleMatch = [ep2.title.lowercaseString rangeOfString:cleanQuery].location != NSNotFound;
                if (ep1TitleMatch && !ep2TitleMatch) return NSOrderedAscending;
                if (!ep1TitleMatch && ep2TitleMatch) return NSOrderedDescending;

                // Sort by season and episode number
                if (ep1.seasonNumber != ep2.seasonNumber) {
                    return ep1.seasonNumber < ep2.seasonNumber ? NSOrderedAscending : NSOrderedDescending;
                }
                return ep1.episodeNumber < ep2.episodeNumber ? NSOrderedAscending : NSOrderedDescending;
            }
            return NSOrderedSame;
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(results, nil);
        });
    });
}

@end
