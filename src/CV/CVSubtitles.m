#import "CVSubtitles.h"
#import "CVHTTP.h"
#import "CVCommon.h"

@implementation CVCue
@end

@interface CVSubtitles ()
@property (nonatomic, strong) NSMutableArray<CVCue *> *parsedCues;
@end

@implementation CVSubtitles

- (NSArray<CVCue *> *)cues
{
    return [self.parsedCues copy];
}

+ (NSTimeInterval)parseTimestamp:(NSString *)ts
{
    // Format: 00:00:02.711 or 00:02.711
    NSArray *parts = [ts componentsSeparatedByString:@":"];
    if (parts.count == 3) {
        double h = [parts[0] doubleValue];
        double m = [parts[1] doubleValue];
        double s = [parts[2] doubleValue];
        return h * 3600.0 + m * 60.0 + s;
    } else if (parts.count == 2) {
        double m = [parts[0] doubleValue];
        double s = [parts[1] doubleValue];
        return m * 60.0 + s;
    }
    return 0;
}

+ (void)parseVTTContent:(NSString *)content intoCues:(NSMutableArray<CVCue *> *)cues
{
    if (!content.length) return;
    NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSUInteger count = lines.count;

    for (NSUInteger i = 0; i < count; i++) {
        NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([line rangeOfString:@"-->"].location != NSNotFound) {
            NSArray *parts = [line componentsSeparatedByString:@"-->"];
            if (parts.count == 2) {
                NSString *startStr = [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *endStr = [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                // Strip any trailing settings like align:start or position:50%
                NSRange spaceRange = [endStr rangeOfString:@" "];
                if (spaceRange.location != NSNotFound) {
                    endStr = [endStr substringToIndex:spaceRange.location];
                }

                NSTimeInterval startTime = [self parseTimestamp:startStr];
                NSTimeInterval endTime = [self parseTimestamp:endStr];

                // Gather following subtitle text lines until empty line
                NSMutableArray *textLines = [NSMutableArray array];
                NSUInteger j = i + 1;
                while (j < count) {
                    NSString *tl = lines[j];
                    if ([tl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0) {
                        break;
                    }
                    // Strip voice tags like <v Speaker> or <i>
                    NSMutableString *cleaned = [tl mutableCopy];
                    NSRegularExpression *tagRegex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:NULL];
                    [tagRegex replaceMatchesInString:cleaned options:0 range:NSMakeRange(0, cleaned.length) withTemplate:@""];
                    [textLines addObject:cleaned];
                    j++;
                }

                if (textLines.count && endTime > startTime) {
                    CVCue *cue = [[CVCue alloc] init];
                    cue.start = startTime;
                    cue.end = endTime;
                    cue.text = [textLines componentsJoinedByString:@"\n"];
                    [cues addObject:cue];
                }
                i = j;
            }
        }
    }
}

+ (void)loadFromURL:(NSURL *)playlistURL completion:(void (^)(CVSubtitles *subtitles, NSError *error))completion
{
    if (!playlistURL) {
        if (completion) completion(nil, KCMakeError(CVErrorBadResponse, @"No subtitle URL"));
        return;
    }

    [CVHTTP get:playlistURL.absoluteString headers:@{ @"Referer": @"https://www.southparkstudios.com/" } completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        if (error || status >= 400 || !body.length) {
            if (completion) completion(nil, error ?: KCMakeError(status, @"Failed to fetch subtitles"));
            return;
        }

        NSString *m3u8 = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        NSArray *lines = [m3u8 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSMutableArray *segUrls = [NSMutableArray array];

        NSString *basePath = [playlistURL.path stringByDeletingLastPathComponent];
        NSString *baseHost = [NSString stringWithFormat:@"%@://%@", playlistURL.scheme, playlistURL.host];

        for (NSString *line in lines) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmed.length && ![trimmed hasPrefix:@"#"]) {
                if ([trimmed hasPrefix:@"http"]) {
                    [segUrls addObject:trimmed];
                } else if ([trimmed hasPrefix:@"/"]) {
                    [segUrls addObject:[baseHost stringByAppendingString:trimmed]];
                } else {
                    [segUrls addObject:[NSString stringWithFormat:@"%@%@/%@", baseHost, basePath, trimmed]];
                }
            }
        }

        if (!segUrls.count) {
            if (completion) completion(nil, KCMakeError(CVErrorBadResponse, @"No subtitle segments found"));
            return;
        }

        // Fetch segments
        __block NSInteger remaining = segUrls.count;
        NSMutableArray<CVCue *> *allCues = [NSMutableArray array];
        NSLock *lock = [[NSLock alloc] init];

        for (NSString *segUrl in segUrls) {
            [CVHTTP get:segUrl headers:@{ @"Referer": @"https://www.southparkstudios.com/" } completion:^(NSInteger sStatus, NSData *sBody, NSDictionary *sHeaders, NSError *sError) {
                if (sBody.length && sStatus < 400) {
                    NSString *vttText = [[NSString alloc] initWithData:sBody encoding:NSUTF8StringEncoding];
                    NSMutableArray *segCues = [NSMutableArray array];
                    [CVSubtitles parseVTTContent:vttText intoCues:segCues];

                    [lock lock];
                    [allCues addObjectsFromArray:segCues];
                    [lock unlock];
                }

                remaining--;
                if (remaining == 0) {
                    // Sort all cues by start time
                    [allCues sortUsingComparator:^NSComparisonResult(CVCue *a, CVCue *b) {
                        if (a.start < b.start) return NSOrderedAscending;
                        if (a.start > b.start) return NSOrderedDescending;
                        return NSOrderedSame;
                    }];

                    CVSubtitles *sub = [[CVSubtitles alloc] init];
                    sub.parsedCues = allCues;
                    if (completion) completion(sub, nil);
                }
            }];
        }
    }];
}

- (NSString *)textAtTime:(NSTimeInterval)time
{
    // Find matching cue
    for (CVCue *cue in self.parsedCues) {
        if (time >= cue.start && time <= cue.end) {
            return cue.text;
        }
        if (cue.start > time) {
            break;
        }
    }
    return nil;
}

@end
