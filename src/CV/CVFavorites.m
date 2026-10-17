#import "CVFavorites.h"

@interface CVFavorites ()
@property (nonatomic, copy) NSString *storagePath;
@property (nonatomic, strong) NSMutableArray<CVEpisode *> *items;
@end

@implementation CVFavorites

+ (instancetype)shared
{
    static CVFavorites *fav;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ fav = [[CVFavorites alloc] init]; });
    return fav;
}

- (id)init
{
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _storagePath = [paths[0] stringByAppendingPathComponent:@"favorites.plist"];

        NSArray *loaded = nil;
        @try {
            loaded = [NSKeyedUnarchiver unarchiveObjectWithFile:_storagePath];
        } @catch (NSException *e) {}

        if ([loaded isKindOfClass:[NSArray class]]) {
            _items = [loaded mutableCopy];
        } else {
            _items = [NSMutableArray array];
        }
    }
    return self;
}

- (void)save
{
    NSArray *snapshot = [self.items copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [NSKeyedArchiver archiveRootObject:snapshot toFile:self.storagePath];
    });
    [[NSNotificationCenter defaultCenter] postNotificationName:CVFavoritesDidChangeNotification object:self];
}

- (BOOL)isFavorite:(NSString *)uuid
{
    if (!uuid.length) return NO;
    for (CVEpisode *ep in self.items) {
        if ([ep.uuid isEqualToString:uuid]) return YES;
    }
    return NO;
}

- (void)toggleFavorite:(CVEpisode *)episode
{
    if (!episode.uuid.length) return;
    if ([self isFavorite:episode.uuid]) {
        [self removeFavorite:episode.uuid];
    } else {
        [self addFavorite:episode];
    }
}

- (void)addFavorite:(CVEpisode *)episode
{
    if (!episode.uuid.length || [self isFavorite:episode.uuid]) return;
    [self.items insertObject:episode atIndex:0];
    [self save];
}

- (void)removeFavorite:(NSString *)uuid
{
    if (!uuid.length) return;
    NSInteger idx = NSNotFound;
    for (NSUInteger i = 0; i < self.items.count; i++) {
        if ([self.items[i].uuid isEqualToString:uuid]) {
            idx = (NSInteger)i;
            break;
        }
    }
    if (idx != NSNotFound) {
        [self.items removeObjectAtIndex:(NSUInteger)idx];
        [self save];
    }
}

- (NSArray<CVEpisode *> *)allFavorites
{
    return [self.items copy];
}

@end
