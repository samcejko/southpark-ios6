#import <UIKit/UIKit.h>
#import "CVModels.h"

@class CVPlayerViewController;

@interface CVNavigator : NSObject

// Present player full screen
+ (void)presentPlayer:(CVPlayerViewController *)player from:(UIViewController *)controller;

// Play an episode directly
+ (void)playEpisode:(CVEpisode *)episode from:(UIViewController *)controller;

// Play a clip directly
+ (void)playClip:(CVClip *)clip from:(UIViewController *)controller;

// Open detail page for an episode
+ (void)openEpisode:(CVEpisode *)episode from:(UIViewController *)controller;

// Open detail page for a clip
+ (void)openClip:(CVClip *)clip from:(UIViewController *)controller;

// Check and open southparkstudios.com URLs inside the app
+ (BOOL)openSouthParkURL:(NSURL *)url from:(UIViewController *)controller;

// Topmost view controller for modal presentation
+ (UIViewController *)presenterFrom:(UIViewController *)controller;

@end
