#import "CVModels.h"

@implementation CVSeason

+ (instancetype)seasonWithNumber:(NSInteger)number label:(NSString *)label urlPath:(NSString *)urlPath
{
    CVSeason *s = [[CVSeason alloc] init];
    s.seasonNumber = number;
    s.label = label ?: [NSString stringWithFormat:@"Season %ld", (long)number];
    s.urlPath = urlPath;
    return s;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:self.seasonNumber forKey:@"seasonNumber"];
    [coder encodeObject:self.label forKey:@"label"];
    [coder encodeObject:self.urlPath forKey:@"urlPath"];
    [coder encodeInteger:self.episodeCount forKey:@"episodeCount"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _seasonNumber = [coder decodeIntegerForKey:@"seasonNumber"];
        _label = [coder decodeObjectForKey:@"label"];
        _urlPath = [coder decodeObjectForKey:@"urlPath"];
        _episodeCount = [coder decodeIntegerForKey:@"episodeCount"];
    }
    return self;
}

@end

@implementation CVEpisode

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.uuid forKey:@"uuid"];
    [coder encodeObject:self.mgid forKey:@"mgid"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.summary forKey:@"summary"];
    [coder encodeInteger:self.seasonNumber forKey:@"seasonNumber"];
    [coder encodeInteger:self.episodeNumber forKey:@"episodeNumber"];
    [coder encodeObject:self.seasonEpisodeString forKey:@"seasonEpisodeString"];
    [coder encodeObject:self.airDate forKey:@"airDate"];
    [coder encodeObject:self.durationString forKey:@"durationString"];
    [coder encodeDouble:self.durationSeconds forKey:@"durationSeconds"];
    [coder encodeObject:self.thumbURL forKey:@"thumbURL"];
    [coder encodeObject:self.urlPath forKey:@"urlPath"];
    [coder encodeBool:self.available forKey:@"available"];
    [coder encodeObject:self.rating forKey:@"rating"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _uuid = [coder decodeObjectForKey:@"uuid"];
        _mgid = [coder decodeObjectForKey:@"mgid"];
        _title = [coder decodeObjectForKey:@"title"];
        _summary = [coder decodeObjectForKey:@"summary"];
        _seasonNumber = [coder decodeIntegerForKey:@"seasonNumber"];
        _episodeNumber = [coder decodeIntegerForKey:@"episodeNumber"];
        _seasonEpisodeString = [coder decodeObjectForKey:@"seasonEpisodeString"];
        _airDate = [coder decodeObjectForKey:@"airDate"];
        _durationString = [coder decodeObjectForKey:@"durationString"];
        _durationSeconds = [coder decodeDoubleForKey:@"durationSeconds"];
        _thumbURL = [coder decodeObjectForKey:@"thumbURL"];
        _urlPath = [coder decodeObjectForKey:@"urlPath"];
        _available = [coder decodeBoolForKey:@"available"];
        _rating = [coder decodeObjectForKey:@"rating"];
    }
    return self;
}

@end

@implementation CVClip

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.uuid forKey:@"uuid"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.summary forKey:@"summary"];
    [coder encodeObject:self.airDate forKey:@"airDate"];
    [coder encodeObject:self.durationString forKey:@"durationString"];
    [coder encodeDouble:self.durationSeconds forKey:@"durationSeconds"];
    [coder encodeObject:self.thumbURL forKey:@"thumbURL"];
    [coder encodeObject:self.urlPath forKey:@"urlPath"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _uuid = [coder decodeObjectForKey:@"uuid"];
        _title = [coder decodeObjectForKey:@"title"];
        _summary = [coder decodeObjectForKey:@"summary"];
        _airDate = [coder decodeObjectForKey:@"airDate"];
        _durationString = [coder decodeObjectForKey:@"durationString"];
        _durationSeconds = [coder decodeDoubleForKey:@"durationSeconds"];
        _thumbURL = [coder decodeObjectForKey:@"thumbURL"];
        _urlPath = [coder decodeObjectForKey:@"urlPath"];
    }
    return self;
}

@end

@implementation CVChapter

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:self.sequence forKey:@"sequence"];
    [coder encodeObject:self.chapterId forKey:@"chapterId"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeDouble:self.streamOffsetSeconds forKey:@"streamOffsetSeconds"];
    [coder encodeDouble:self.durationSeconds forKey:@"durationSeconds"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _sequence = [coder decodeIntegerForKey:@"sequence"];
        _chapterId = [coder decodeObjectForKey:@"chapterId"];
        _title = [coder decodeObjectForKey:@"title"];
        _streamOffsetSeconds = [coder decodeDoubleForKey:@"streamOffsetSeconds"];
        _durationSeconds = [coder decodeDoubleForKey:@"durationSeconds"];
    }
    return self;
}

@end

@implementation CVStream
@end
