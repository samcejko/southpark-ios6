#import "CVConnectionPool.h"
#import "CVTLSSocket.h"
#import "CVCommon.h"

static const NSTimeInterval CVIdleTimeout = 25;     // most servers drop idle connections after 5 to 60 s
static const NSUInteger CVMaxIdlePerKey = 6;
static const NSUInteger CVMaxIdleTotal = 24;

@interface CVPooledConnection : NSObject
@property (nonatomic, strong) CVTLSSocket *socket;
@property (nonatomic) NSTimeInterval lastUsed;
@end

@implementation CVPooledConnection
@end

@implementation CVConnectionPool {
    NSMutableDictionary *_idle;     // key -> NSMutableArray<CVPooledConnection>
    NSUInteger _count;
    NSUInteger _reuses;
}

+ (instancetype)shared
{
    static CVConnectionPool *pool;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ pool = [[CVConnectionPool alloc] init]; });
    return pool;
}

- (instancetype)init
{
    self = [super init];
    if (self) _idle = [NSMutableDictionary dictionary];
    return self;
}

// Must be called with the lock held. Moves expired connections into `dead`.
- (void)pruneLocked:(NSMutableArray *)dead
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSMutableArray *emptyKeys = [NSMutableArray array];
    for (NSString *key in _idle) {
        NSMutableArray *list = _idle[key];
        for (NSInteger i = (NSInteger)list.count - 1; i >= 0; i--) {
            CVPooledConnection *c = list[(NSUInteger)i];
            if (now - c.lastUsed > CVIdleTimeout) {
                [dead addObject:c.socket];
                [list removeObjectAtIndex:(NSUInteger)i];
                _count--;
            }
        }
        if (!list.count) [emptyKeys addObject:key];
    }
    [_idle removeObjectsForKeys:emptyKeys];
}

- (CVTLSSocket *)checkoutSocketForKey:(NSString *)key
{
    if (!key) return nil;
    NSMutableArray *dead = [NSMutableArray array];
    CVTLSSocket *result = nil;
    @synchronized (self) {
        [self pruneLocked:dead];
        NSMutableArray *list = _idle[key];
        while (list.count && !result) {
            CVPooledConnection *c = [list lastObject];
            [list removeLastObject];
            _count--;
            if ([c.socket isLikelyAlive]) result = c.socket;
            else [dead addObject:c.socket];
        }
        if (result) _reuses++;
    }
    for (CVTLSSocket *s in dead) [s close];
    return result;
}

- (void)checkinSocket:(CVTLSSocket *)socket forKey:(NSString *)key
{
    if (!socket || !key) return;
    NSMutableArray *dead = [NSMutableArray array];
    @synchronized (self) {
        [self pruneLocked:dead];
        NSMutableArray *list = _idle[key];
        if (!list) {
            list = [NSMutableArray array];
            _idle[key] = list;
        }
        if (list.count >= CVMaxIdlePerKey || _count >= CVMaxIdleTotal) {
            [dead addObject:socket];
        } else {
            CVPooledConnection *c = [[CVPooledConnection alloc] init];
            c.socket = socket;
            c.lastUsed = [NSDate timeIntervalSinceReferenceDate];
            [list addObject:c];
            _count++;
        }
    }
    for (CVTLSSocket *s in dead) [s close];
}

- (void)drain
{
    NSMutableArray *dead = [NSMutableArray array];
    @synchronized (self) {
        for (NSString *key in _idle) {
            for (CVPooledConnection *c in _idle[key]) [dead addObject:c.socket];
        }
        [_idle removeAllObjects];
        _count = 0;
    }
    for (CVTLSSocket *s in dead) [s close];
    if (dead.count) CVLog(@"Connection pool drained (%lu closed)", (unsigned long)dead.count);
}

- (NSUInteger)idleCount
{
    @synchronized (self) { return _count; }
}

- (NSUInteger)reuseCount
{
    @synchronized (self) { return _reuses; }
}

@end
