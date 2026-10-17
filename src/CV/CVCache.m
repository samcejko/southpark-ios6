#import "CVCache.h"
#import "CVCommon.h"

@interface CVCache ()
@property (nonatomic, copy) NSString *cacheDir;
@property (nonatomic, strong) NSCache *memCache;
@end

@implementation CVCache

+ (instancetype)shared
{
    static CVCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[CVCache alloc] init]; });
    return cache;
}

- (id)init
{
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _cacheDir = [paths[0] stringByAppendingPathComponent:@"CityVOD_Data"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_cacheDir withIntermediateDirectories:YES attributes:nil error:NULL];

        _memCache = [[NSCache alloc] init];
        _memCache.countLimit = 60;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLowMemory) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onLowMemory
{
    [self.memCache removeAllObjects];
}

- (NSString *)pathForKey:(NSString *)key
{
    // Simple sanitized filename
    NSMutableString *safe = [key mutableCopy];
    [safe replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, safe.length)];
    [safe replaceOccurrencesOfString:@":" withString:@"_" options:0 range:NSMakeRange(0, safe.length)];
    [safe replaceOccurrencesOfString:@"?" withString:@"_" options:0 range:NSMakeRange(0, safe.length)];
    [safe replaceOccurrencesOfString:@"&" withString:@"_" options:0 range:NSMakeRange(0, safe.length)];
    return [self.cacheDir stringByAppendingPathComponent:safe];
}

- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key ttl:(NSTimeInterval)ttl
{
    if (!key.length) return;
    if (!object) {
        [self removeObjectForKey:key];
        return;
    }

    [self.memCache setObject:object forKey:key];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSDate *expiry = [NSDate dateWithTimeIntervalSinceNow:ttl];
        NSDictionary *wrapper = @{
            @"expiry": expiry,
            @"payload": object
        };
        NSString *path = [self pathForKey:key];
        [NSKeyedArchiver archiveRootObject:wrapper toFile:path];
    });
}

- (id)objectForKey:(NSString *)key
{
    if (!key.length) return nil;

    id mem = [self.memCache objectForKey:key];
    if (mem) return mem;

    NSString *path = [self pathForKey:key];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;

    @try {
        NSDictionary *wrapper = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if (![wrapper isKindOfClass:[NSDictionary class]]) return nil;

        NSDate *expiry = wrapper[@"expiry"];
        if (expiry && [expiry timeIntervalSinceNow] > 0) {
            id payload = wrapper[@"payload"];
            if (payload) {
                [self.memCache setObject:payload forKey:key];
                return payload;
            }
        } else {
            // Expired
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        }
    } @catch (NSException *e) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
    return nil;
}

- (void)removeObjectForKey:(NSString *)key
{
    if (!key.length) return;
    [self.memCache removeObjectForKey:key];
    NSString *path = [self pathForKey:key];
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

- (void)clearAll
{
    [self.memCache removeAllObjects];
    [[NSFileManager defaultManager] removeItemAtPath:self.cacheDir error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDir withIntermediateDirectories:YES attributes:nil error:NULL];
}

@end
