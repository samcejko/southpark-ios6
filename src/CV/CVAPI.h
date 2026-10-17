#import <Foundation/Foundation.h>
#import "CVModels.h"
#import "CVHTTP.h"

@interface CVAPI : NSObject

+ (instancetype)shared;

// Fetches the list of all seasons (1 through 29+)
- (CVHTTPTask *)fetchSeasonsWithCompletion:(void (^)(NSArray<CVSeason *> *seasons, NSError *error))completion;

// Fetches the episodes for a specific season
- (CVHTTPTask *)fetchEpisodesForSeason:(CVSeason *)season completion:(void (^)(NSArray<CVEpisode *> *episodes, NSError *error))completion;

// Fetches the home page content (featured clips and recent items)
- (CVHTTPTask *)fetchHomeWithCompletion:(void (^)(NSArray<CVClip *> *featuredClips, NSArray<CVEpisode *> *latestEpisodes, NSError *error))completion;

// Resolves playable stream and chapters for an episode or clip
- (CVHTTPTask *)resolveStreamForItemURL:(NSString *)urlPath itemUUID:(NSString *)uuid completion:(void (^)(CVStream *stream, NSError *error))completion;

// Search across all cached seasons & episodes
- (void)searchEpisodesAndClips:(NSString *)query completion:(void (^)(NSArray *results, NSError *error))completion;

@end
