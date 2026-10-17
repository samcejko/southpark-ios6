#import "CVPageData.h"
#import "CVCommon.h"

@implementation CVPageData

+ (NSDictionary *)extractDataFromHTML:(NSString *)html
{
    if (!html.length) return nil;
    NSRange marker = [html rangeOfString:@"window.__DATA__"];
    if (marker.location == NSNotFound) return nil;

    NSUInteger start = marker.location + marker.length;
    NSUInteger len = html.length;
    while (start < len && [html characterAtIndex:start] != '{') {
        start++;
    }
    if (start >= len) return nil;

    NSInteger depth = 0;
    BOOL inString = NO;
    BOOL escape = NO;
    NSUInteger end = NSNotFound;

    for (NSUInteger i = start; i < len; i++) {
        unichar ch = [html characterAtIndex:i];
        if (escape) {
            escape = NO;
            continue;
        }
        if (ch == '\\') {
            escape = YES;
            continue;
        }
        if (ch == '"') {
            inString = !inString;
            continue;
        }
        if (!inString) {
            if (ch == '{') {
                depth++;
            } else if (ch == '}') {
                depth--;
                if (depth == 0) {
                    end = i + 1;
                    break;
                }
            }
        }
    }

    if (end == NSNotFound || end <= start) return nil;

    NSString *jsonString = [html substringWithRange:NSMakeRange(start, end - start)];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return nil;

    NSError *err = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&err];
    if ([parsed isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)parsed;
    }
    return nil;
}

+ (void)findComponentsInNode:(id)node matchingType:(NSString *)targetType results:(NSMutableArray *)results
{
    if (![node isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *dict = (NSDictionary *)node;

    NSString *type = CVStr(dict[@"type"]);
    if ([type isEqualToString:targetType]) {
        [results addObject:dict];
    }

    id children = dict[@"children"];
    if ([children isKindOfClass:[NSArray class]]) {
        for (id child in (NSArray *)children) {
            [self findComponentsInNode:child matchingType:targetType results:results];
        }
    }
}

+ (NSArray<CVSeason *> *)seasonsFromPageData:(NSDictionary *)data
{
    if (!data) return @[];
    NSMutableArray *components = [NSMutableArray array];
    [self findComponentsInNode:data matchingType:@"SeasonSelector" results:components];

    NSMutableArray *seasons = [NSMutableArray array];
    for (NSDictionary *selector in components) {
        NSArray *items = CVArr(selector[@"props"][@"items"]);
        for (NSDictionary *item in items) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            NSInteger num = [item[@"seasonNumber"] integerValue];
            NSString *label = CVStr(item[@"label"]);
            NSString *url = CVStr(item[@"url"]);
            if (num > 0) {
                [seasons addObject:[CVSeason seasonWithNumber:num label:label urlPath:url]];
            }
        }
        if (seasons.count > 0) break;
    }

    // Sort by season number ascending
    [seasons sortUsingComparator:^NSComparisonResult(CVSeason *a, CVSeason *b) {
        if (a.seasonNumber < b.seasonNumber) return NSOrderedAscending;
        if (a.seasonNumber > b.seasonNumber) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return seasons;
}

+ (NSArray<CVEpisode *> *)episodesFromPageData:(NSDictionary *)data defaultSeasonNumber:(NSInteger)seasonNumber
{
    if (!data) return @[];
    NSMutableArray *lineLists = [NSMutableArray array];
    [self findComponentsInNode:data matchingType:@"LineList" results:lineLists];

    NSMutableArray *episodes = [NSMutableArray array];
    for (NSDictionary *list in lineLists) {
        NSArray *items = CVArr(list[@"props"][@"items"]);
        for (NSDictionary *item in items) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;

            NSString *entityType = CVStr(item[@"entityType"]);
            NSString *itemType = CVStr(item[@"itemType"]);
            if (![entityType isEqualToString:@"episode"] && ![itemType isEqualToString:@"episode"]) {
                continue;
            }

            CVEpisode *ep = [[CVEpisode alloc] init];
            ep.uuid = CVStr(item[@"id"]);
            ep.urlPath = CVStr(item[@"url"]);

            NSDictionary *meta = CVDict(item[@"meta"]);
            ep.mgid = CVStr(meta[@"itemMgid"]);
            ep.title = CVStr(meta[@"subHeader"]);
            ep.summary = CVStr(meta[@"description"]);
            ep.airDate = CVStr(meta[@"date"]);

            NSDictionary *header = CVDict(meta[@"header"]);
            NSDictionary *headerTitle = CVDict(header[@"title"]);
            ep.seasonEpisodeString = CVStr(headerTitle[@"text"]); // e.g. "S1 • E1"

            // Parse season/episode number from "S1 • E1"
            NSInteger parsedSeason = seasonNumber;
            NSInteger parsedEp = 0;
            if (ep.seasonEpisodeString.length) {
                NSScanner *scanner = [NSScanner scannerWithString:ep.seasonEpisodeString];
                [scanner scanString:@"S" intoString:NULL];
                [scanner scanInteger:&parsedSeason];
                [scanner scanUpToString:@"E" intoString:NULL];
                [scanner scanString:@"E" intoString:NULL];
                [scanner scanInteger:&parsedEp];
            }
            ep.seasonNumber = parsedSeason > 0 ? parsedSeason : seasonNumber;
            ep.episodeNumber = parsedEp;

            NSDictionary *media = CVDict(item[@"media"]);
            ep.durationString = CVStr(media[@"duration"]);
            ep.durationSeconds = [self secondsFromDurationString:ep.durationString];

            NSDictionary *image = CVDict(media[@"image"]);
            NSString *rawImg = CVStr(image[@"url"]);
            if (rawImg.length) {
                // Ensure jpg format is requested
                if ([rawImg rangeOfString:@"format="].location == NSNotFound) {
                    ep.thumbURL = [rawImg stringByAppendingString:@"&format=jpg"];
                } else {
                    ep.thumbURL = rawImg;
                }
            }

            ep.available = (media[@"lockedLabel"] == nil || [media[@"lockedLabel"] isEqual:[NSNull null]]);
            [episodes addObject:ep];
        }
    }

    return episodes;
}

+ (NSArray<CVClip *> *)clipsFromPageData:(NSDictionary *)data
{
    if (!data) return @[];
    NSMutableArray *lineLists = [NSMutableArray array];
    [self findComponentsInNode:data matchingType:@"LineList" results:lineLists];

    NSMutableArray *clips = [NSMutableArray array];
    for (NSDictionary *list in lineLists) {
        NSArray *items = CVArr(list[@"props"][@"items"]);
        for (NSDictionary *item in items) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;

            NSString *entityType = CVStr(item[@"entityType"]);
            NSString *itemType = CVStr(item[@"itemType"]);
            if (![entityType isEqualToString:@"showvideo"] && ![itemType isEqualToString:@"showvideo"]) {
                continue;
            }

            CVClip *c = [[CVClip alloc] init];
            c.uuid = CVStr(item[@"id"]);
            c.urlPath = CVStr(item[@"url"]);

            NSDictionary *meta = CVDict(item[@"meta"]);
            NSDictionary *header = CVDict(meta[@"header"]);

            NSString *subHeader = CVStr(meta[@"subHeader"]);
            NSString *headerTitle = CVStr(header[@"title"]);
            NSString *itemTitle = CVStr(item[@"title"]);

            if (subHeader.length) {
                c.title = subHeader;
                c.seasonEpisodeString = headerTitle;
            } else if (itemTitle.length) {
                c.title = itemTitle;
                c.seasonEpisodeString = headerTitle;
            } else {
                c.title = headerTitle.length ? headerTitle : L(@"Clip");
                c.seasonEpisodeString = @"";
            }

            c.summary = CVStr(meta[@"description"]);
            c.airDate = CVStr(meta[@"date"]);

            NSDictionary *media = CVDict(item[@"media"]);
            c.durationString = CVStr(media[@"duration"]);
            c.durationSeconds = [self secondsFromDurationString:c.durationString];

            NSDictionary *image = CVDict(media[@"image"]);
            NSString *rawImg = CVStr(image[@"url"]);
            if (rawImg.length) {
                if ([rawImg rangeOfString:@"format="].location == NSNotFound) {
                    c.thumbURL = [rawImg stringByAppendingString:@"&format=jpg"];
                } else {
                    c.thumbURL = rawImg;
                }
            }
            [clips addObject:c];
        }
    }

    return clips;
}

+ (NSString *)findKey:(NSString *)key inObject:(id)obj
{
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)obj;
        if (dict[key]) {
            return CVStr(dict[key]);
        }
        for (id v in dict.allValues) {
            NSString *res = [self findKey:key inObject:v];
            if (res.length) return res;
        }
    } else if ([obj isKindOfClass:[NSArray class]]) {
        for (id v in (NSArray *)obj) {
            NSString *res = [self findKey:key inObject:v];
            if (res.length) return res;
        }
    }
    return nil;
}

+ (NSString *)videoServiceURLFromPageData:(NSDictionary *)data
{
    return [self findKey:@"videoServiceUrl" inObject:data];
}

+ (NSTimeInterval)secondsFromDurationString:(NSString *)durationString
{
    if (!durationString.length) return 0;
    NSArray *parts = [durationString componentsSeparatedByString:@":"];
    if (parts.count == 2) {
        NSInteger m = [parts[0] integerValue];
        NSInteger s = [parts[1] integerValue];
        return m * 60 + s;
    } else if (parts.count == 3) {
        NSInteger h = [parts[0] integerValue];
        NSInteger m = [parts[1] integerValue];
        NSInteger s = [parts[2] integerValue];
        return h * 3600 + m * 60 + s;
    }
    return 0;
}

@end
