#import <UIKit/UIKit.h>
#import "CVModels.h"

@interface CVEpisodeCell : UITableViewCell

+ (NSString *)reuseIdentifier;
+ (CGFloat)heightForWidth:(CGFloat)width;

- (void)configureWithEpisode:(CVEpisode *)episode;
- (void)configureWithClip:(CVClip *)clip;

@end
