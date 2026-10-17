#import "CVPlayback.h"
#import "CVMediaProxy.h"
#import "CVSettings.h"
#import "CVCommon.h"

@implementation CVVariant

- (NSString *)title
{
    if (self.height > 0) {
        return [NSString stringWithFormat:@"%ldp", (long)self.height];
    }
    return self.name ?: @"Video";
}

- (NSString *)qualityKey
{
    if (self.height > 0) {
        return [NSString stringWithFormat:@"%ld", (long)self.height];
    }
    return @"auto";
}

@end

@implementation CVPlayback

+ (BOOL)is64BitDevice
{
#if defined(__arm64__) || defined(__aarch64__)
    return YES;
#else
    return NO;
#endif
}

+ (BOOL)deviceCanPlay:(CVVariant *)variant
{
    if (!variant) return NO;
    if ([self is64BitDevice]) {
        // Modern devices decode up to 1080p60 easily
        return variant.height <= 1080;
    }
    // iPad 2 / iPhone 4S: H.264 Main@3.1 up to 720p30, bitrate <= ~2.8 Mbps
    if (variant.height > 720) return NO;
    if (variant.bandwidth > 3200000) return NO;
    return YES;
}

+ (CVVariant *)variantFrom:(NSArray<CVVariant *> *)variants forQuality:(NSString *)quality
{
    if (!variants.count || !quality.length || [quality isEqualToString:@"auto"]) return nil;
    NSInteger targetH = [quality integerValue];
    if (targetH <= 0) return nil;

    CVVariant *best = nil;
    NSInteger minDiff = 100000;
    for (CVVariant *v in variants) {
        NSInteger diff = labs(v.height - targetH);
        if (diff < minDiff) {
            minDiff = diff;
            best = v;
        }
    }
    return best;
}

+ (NSArray<CVVariant *> *)variantsFromMaster:(NSString *)text baseURL:(NSURL *)base audioRenditions:(NSArray **)audioRenditions subtitleURL:(NSURL **)subURL
{
    if (!text.length) return @[];

    NSMutableArray<CVVariant *> *variants = [NSMutableArray array];
    NSMutableArray *audios = [NSMutableArray array];
    NSURL *foundSub = nil;

    NSArray *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSUInteger count = lines.count;

    // Pattern for attributes in #EXT-X-STREAM-INF
    NSRegularExpression *resRegex = [NSRegularExpression regularExpressionWithPattern:@"RESOLUTION=(\\d+)x(\\d+)" options:0 error:NULL];
    NSRegularExpression *bwRegex = [NSRegularExpression regularExpressionWithPattern:@"BANDWIDTH=(\\d+)" options:0 error:NULL];
    NSRegularExpression *codecRegex = [NSRegularExpression regularExpressionWithPattern:@"CODECS=\"([^\"]+)\"" options:0 error:NULL];
    NSRegularExpression *uriRegex = [NSRegularExpression regularExpressionWithPattern:@"URI=\"([^\"]+)\"" options:0 error:NULL];

    NSString *basePath = [base.path stringByDeletingLastPathComponent];
    NSString *baseHost = [NSString stringWithFormat:@"%@://%@", base.scheme, base.host];

    for (NSUInteger i = 0; i < count; i++) {
        NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        // Subtitles
        if ([line hasPrefix:@"#EXT-X-MEDIA:TYPE=SUBTITLES"]) {
            NSTextCheckingResult *r = [uriRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            if (r && !foundSub) {
                NSString *uriStr = [line substringWithRange:[r rangeAtIndex:1]];
                if ([uriStr hasPrefix:@"http"]) {
                    foundSub = [NSURL URLWithString:uriStr];
                } else {
                    foundSub = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", baseHost, basePath, uriStr]];
                }
            }
            continue;
        }

        // Audio
        if ([line hasPrefix:@"#EXT-X-MEDIA:TYPE=AUDIO"]) {
            NSTextCheckingResult *r = [uriRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            if (r) {
                NSString *uriStr = [line substringWithRange:[r rangeAtIndex:1]];
                if ([uriStr hasPrefix:@"http"]) {
                    [audios addObject:[NSURL URLWithString:uriStr]];
                } else {
                    [audios addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", baseHost, basePath, uriStr]]];
                }
            }
            continue;
        }

        // Video variant stream
        if ([line hasPrefix:@"#EXT-X-STREAM-INF:"]) {
            CVVariant *v = [[CVVariant alloc] init];

            NSTextCheckingResult *bwMatch = [bwRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            if (bwMatch) v.bandwidth = [[line substringWithRange:[bwMatch rangeAtIndex:1]] integerValue];

            NSTextCheckingResult *resMatch = [resRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            if (resMatch) {
                v.width = [[line substringWithRange:[resMatch rangeAtIndex:1]] integerValue];
                v.height = [[line substringWithRange:[resMatch rangeAtIndex:2]] integerValue];
            }

            NSTextCheckingResult *codecMatch = [codecRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            if (codecMatch) v.codecs = [line substringWithRange:[codecMatch rangeAtIndex:1]];

            // The next non-empty non-# line is the variant URL
            NSUInteger j = i + 1;
            while (j < count) {
                NSString *nextLine = [lines[j] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (nextLine.length && ![nextLine hasPrefix:@"#"]) {
                    if ([nextLine hasPrefix:@"http"]) {
                        v.url = nextLine;
                    } else {
                        v.url = [NSString stringWithFormat:@"%@%@/%@", baseHost, basePath, nextLine];
                    }
                    [variants addObject:v];
                    i = j;
                    break;
                }
                j++;
            }
        }
    }

    // Sort descending by height / bandwidth
    [variants sortUsingComparator:^NSComparisonResult(CVVariant *a, CVVariant *b) {
        if (a.height > b.height) return NSOrderedAscending;
        if (a.height < b.height) return NSOrderedDescending;
        if (a.bandwidth > b.bandwidth) return NSOrderedAscending;
        if (a.bandwidth < b.bandwidth) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    if (audioRenditions) *audioRenditions = audios;
    if (subURL) *subURL = foundSub;

    return variants;
}

+ (NSString *)masterPlaylistForVariants:(NSArray<CVVariant *> *)variants startingWith:(CVVariant *)first audioPlaylistURL:(NSString *)audioURL
{
    NSMutableString *m = [NSMutableString stringWithString:@"#EXTM3U\n#EXT-X-VERSION:3\n"];

    if (audioURL.length) {
        [m appendFormat:@"#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"English\",DEFAULT=YES,AUTOSELECT=YES,URI=\"%@\"\n", audioURL];
    }

    // If a specific starting rendition was requested, place it first
    NSMutableArray *ordered = [variants mutableCopy];
    if (first && [ordered containsObject:first]) {
        [ordered removeObject:first];
        [ordered insertObject:first atIndex:0];
    }

    for (CVVariant *v in ordered) {
        if (![self deviceCanPlay:v]) continue;
        NSString *audioAttr = audioURL.length ? @",AUDIO=\"audio\"" : @"";
        [m appendFormat:@"#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=%ld,RESOLUTION=%ldx%ld%@\n%@\n",
         (long)v.bandwidth, (long)v.width, (long)v.height, audioAttr, v.url];
    }

    return [m copy];
}

+ (NSURL *)playerURLForStream:(CVStream *)stream quality:(NSString *)quality chosen:(CVVariant **)chosen
{
    if (!stream.masterURL) return nil;
    [[CVMediaProxy shared] ensureRunning];

    // Wrap through local media proxy
    NSString *proxyMaster = [[CVMediaProxy shared] proxyURLForURL:stream.masterURL];
    return [NSURL URLWithString:proxyMaster];
}

@end
