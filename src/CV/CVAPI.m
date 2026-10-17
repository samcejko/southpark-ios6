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
            if (completion) completion(nil, error ?: KCMakeError(status, @"Failed to fetch seasons"));
            return;
        }

        NSString *html = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        NSDictionary *data = [CVPageData extractDataFromHTML:html];
        NSArray<CVSeason *> *seasons = [CVPageData seasonsFromPageData:data];

        if (seasons.count) {
            [[CVCache shared] setObject:seasons forKey:@"seasons_list" ttl:86400]; // 24h
            if (completion) completion(seasons, nil);
        } else {
            if (completion) completion(nil, KCMakeError(CVErrorBadResponse, @"Could not parse seasons"));
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

    NSString *url = nil;
    if (season.urlPath.length) {
        if ([season.urlPath hasPrefix:@"http"]) url = season.urlPath;
        else url = [CVSiteBase stringByAppendingString:season.urlPath];
    } else {
        url = [CVSiteBase stringByAppendingString:@"/seasons/south-park/"];
    }

    return [CVHTTP get:url headers:[self browserHeaders] completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        if (error || status >= 400 || !body.length) {
            if (completion) completion(nil, error ?: KCMakeError(status, @"Failed to fetch episodes"));
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
            if (completion) completion(nil, KCMakeError(CVErrorBadResponse, @"No episodes found for season"));
        }
    }];
}

- (CVHTTPTask *)fetchHomeWithCompletion:(void (^)(NSArray<CVClip *> *featuredClips, NSArray<CVEpisode *> *latestEpisodes, NSError *error))completion
{
    NSString *url = [CVSiteBase stringByAppendingString:@"/"];
    return [CVHTTP get:url headers:[self browserHeaders] completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        if (error || status >= 400 || !body.length) {
            if (completion) completion(nil, nil, error ?: KCMakeError(status, @"Failed to fetch home"));
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
        if (completion) completion(nil, KCMakeError(CVErrorBadResponse, @"Invalid URL path"));
        return nil;
    }

    NSString *itemFullUrl = [urlPath hasPrefix:@"http"] ? urlPath : [CVSiteBase stringByAppendingString:urlPath];

    CVHTTPTask *outerTask = [[CVHTTPTask alloc] init];

    CVHTTPTask *pageTask = [CVHTTP get:itemFullUrl headers:[self browserHeaders] completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        if (outerTask.isCancelled) return;
        if (error || status >= 400 || !body.length) {
            if (completion) completion(nil, error ?: KCMakeError(status, @"Failed to fetch video page"));
            return;
        }

        NSString *html = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        NSDictionary *data = [CVPageData extractDataFromHTML:html];
        NSString *rawServiceUrl = [CVPageData videoServiceURLFromPageData:data];

        if (!rawServiceUrl.length) {
            if (completion) completion(nil, KCMakeError(CVErrorBadResponse, @"Video service URL not found"));
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
                if (completion) completion(nil, mError ?: KCMakeError(mStatus, @"Failed to fetch stream descriptor"));
                return;
            }

            NSDictionary *dict = (NSDictionary *)json;
            NSDictionary *stitched = KCDict(dict[@"stitchedstream"]);
            NSString *source = CVStr(stitched[@"source"]);
            if (!source.length) {
                if (completion) completion(nil, KCMakeError(CVErrorBadResponse, @"No stream source in mica"));
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

- (void)searchEpisodesAndClips:(NSString *)query completion:(void (^)(NSArray *results, NSError *error))completion
{
    if (!query.length) {
        if (completion) completion(@[], nil);
        return;
    }

    NSString *q = [query lowercaseString];

    // Search through cached season episodes
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *results = [NSMutableArray array];
        NSArray *seasons = [[CVCache shared] objectForKey:@"seasons_list"];
        for (CVSeason *s in seasons) {
            NSString *key = [NSString stringWithFormat:@"episodes_season_%ld", (long)s.seasonNumber];
            NSArray *eps = [[CVCache shared] objectForKey:key];
            for (CVEpisode *ep in eps) {
                if ([ep.title.lowercaseString rangeOfString:q].location != NSNotFound ||
                    [ep.summary.lowercaseString rangeOfString:q].location != NSNotFound ||
                    [ep.seasonEpisodeString.lowercaseString rangeOfString:q].location != NSNotFound) {
                    [results addObject:ep];
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(results, nil);
        });
    });
}

@end
