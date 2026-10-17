#import <Foundation/Foundation.h>
#import "CVModels.h"
#import "CVHTTP.h"

@interface CVVariant : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *codecs;
@property (nonatomic, copy) NSString *url;
@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;
@property (nonatomic) NSInteger bandwidth;
@property (nonatomic) double frameRate;

- (NSString *)title;
- (NSString *)qualityKey;
@end

@interface CVPlayback : NSObject

// Parses all video variants from master playlist text
+ (NSArray<CVVariant *> *)variantsFromMaster:(NSString *)text baseURL:(NSURL *)base audioRenditions:(NSArray **)audioRenditions subtitleURL:(NSURL **)subURL;

// Tests if the device (iPad 2 vs modern arm64) can decode this variant
+ (BOOL)deviceCanPlay:(CVVariant *)variant;

// Selects the variant matching user quality preference (or nil for auto)
+ (CVVariant *)variantFrom:(NSArray<CVVariant *> *)variants forQuality:(NSString *)quality;

// Builds rewritten master playlist text containing only playable variants
+ (NSString *)masterPlaylistForVariants:(NSArray<CVVariant *> *)variants startingWith:(CVVariant *)first audioPlaylistURL:(NSString *)audioURL;

// Generates a local 127.0.0.1 proxy URL for AVPlayer
+ (NSURL *)playerURLForStream:(CVStream *)stream quality:(NSString *)quality chosen:(CVVariant **)chosen;

@end
