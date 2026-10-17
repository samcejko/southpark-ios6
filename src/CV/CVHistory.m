#import "CVHistory.h"

NSString * const CVHistoryDidChangeNotification = @"CVHistoryDidChangeNotification";

@implementation CVHistoryEntry

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.episode forKey:@"episode"];
    [coder encodeDouble:self.position forKey:@"position"];
    [coder encodeDouble:self.duration forKey:@"duration"];
    [coder encodeObject:self.lastWatched forKey:@"lastWatched"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _episode = [coder decodeObjectForKey:@"episode"];
        _position = [coder decodeDoubleForKey:@"position"];
        _duration = [coder decodeDoubleForKey:@"duration"];
        _lastWatched = [coder decodeObjectForKey:@"lastWatched"];
    }
    return self;
}

- (BOOL)isCompleted
{
    if (self.duration <= 0) return NO;
    return (self.position / self.duration) >= 0.92;
}

- (double)progressFraction
{
    if (self.duration <= 0) return 0;
    double f = self.position / self.duration;
    if (f < 0) return 0;
    if (f > 1) return 1;
    return f;
}

@end

@interface CVHistory ()
@property (nonatomic, copy) NSString *storagePath;
@property (nonatomic, strong) NSMutableArray<CVHistoryEntry *> *entries;
@end

@implementation CVHistory

+ (instancetype)shared
{
    static CVHistory *h;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ h = [[CVHistory alloc] init]; });
    return h;
}

- (id)init
{
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _storagePath = [paths[0] stringByAppendingPathComponent:@"history.plist"];

        NSArray *loaded = nil;
        @try {
            loaded = [NSKeyedUnarchiver unarchiveObjectWithFile:_storagePath];
        } @catch (NSException *e) {}

        if ([loaded isKindOfClass:[NSArray class]]) {
            _entries = [loaded mutableCopy];
        } else {
            _entries = [NSMutableArray array];
        }
    }
    return self;
}

- (void)save
{
    NSArray *snapshot = [self.entries copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [NSKeyedArchiver archiveRootObject:snapshot toFile:self.storagePath];
    });
    [[NSNotificationCenter defaultCenter] postNotificationName:CVHistoryDidChangeNotification object:self];
}

- (CVHistoryEntry *)entryForUUID:(NSString *)uuid
{
    if (!uuid.length) return nil;
    for (CVHistoryEntry *e in self.entries) {
        if ([e.episode.uuid isEqualToString:uuid]) return e;
    }
    return nil;
}

- (NSTimeInterval)positionForUUID:(NSString *)uuid
{
    CVHistoryEntry *e = [self entryForUUID:uuid];
    return e ? e.position : 0;
}

- (BOOL)isWatched:(NSString *)uuid
{
    CVHistoryEntry *e = [self entryForUUID:uuid];
    return e ? e.isCompleted : NO;
}

- (void)saveProgress:(NSTimeInterval)position duration:(NSTimeInterval)duration forEpisode:(CVEpisode *)episode
{
    if (!episode.uuid.length) return;

    CVHistoryEntry *existing = [self entryForUUID:episode.uuid];
    if (existing) {
        [self.entries removeObject:existing];
    } else {
        existing = [[CVHistoryEntry alloc] init];
        existing.episode = episode;
    }

    existing.position = position;
    existing.duration = duration > 0 ? duration : episode.durationSeconds;
    existing.lastWatched = [NSDate date];

    [self.entries insertObject:existing atIndex:0];

    // Cap history at 50 items
    while (self.entries.count > 50) {
        [self.entries removeLastObject];
    }

    [self save];
}

- (NSArray<CVHistoryEntry *> *)recentEntries
{
    return [self.entries copy];
}

- (void)removeEntryForUUID:(NSString *)uuid
{
    if (!uuid.length) return;
    CVHistoryEntry *e = [self entryForUUID:uuid];
    if (e) {
        [self.entries removeObject:e];
        [self save];
    }
}

- (void)clearHistory
{
    [self.entries removeAllObjects];
    [self save];
}

@end
