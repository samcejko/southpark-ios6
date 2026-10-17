#import <Foundation/Foundation.h>
#import "CVModels.h"

extern NSString * const CVFavoritesDidChangeNotification;

@interface CVFavorites : NSObject

+ (instancetype)shared;

- (BOOL)isFavorite:(NSString *)uuid;
- (void)toggleFavorite:(CVEpisode *)episode;
- (void)addFavorite:(CVEpisode *)episode;
- (void)removeFavorite:(NSString *)uuid;
- (NSArray<CVEpisode *> *)allFavorites;

@end
