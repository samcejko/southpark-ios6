#import <UIKit/UIKit.h>
#import "CVModels.h"

@interface CVPlayerViewController : UIViewController

- (id)initWithItemURL:(NSString *)urlPath itemUUID:(NSString *)uuid title:(NSString *)title subtitle:(NSString *)subtitle resumePosition:(NSTimeInterval)resumePos episode:(CVEpisode *)episode;

@end
