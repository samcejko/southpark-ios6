#import <Foundation/Foundation.h>

@interface CVCache : NSObject

+ (instancetype)shared;

// Cache objects with TTL
- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key ttl:(NSTimeInterval)ttl;
- (id)objectForKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
- (void)clearAll;

@end
