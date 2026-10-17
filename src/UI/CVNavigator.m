#import "CVNavigator.h"
#import "CVPlayerViewController.h"
#import "CVEpisodeDetailViewController.h"
#import "CVHistory.h"
#import "CVCommon.h"

@implementation CVNavigator

+ (UIViewController *)presenterFrom:(UIViewController *)controller
{
    UIViewController *top = controller ?: [UIApplication sharedApplication].keyWindow.rootViewController;
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) {
        top = top.presentedViewController;
    }
    return top;
}

+ (void)presentPlayer:(CVPlayerViewController *)player from:(UIViewController *)controller
{
    UIViewController *presenter = [self presenterFrom:controller];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    player.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:player animated:YES completion:nil];
}

+ (void)playEpisode:(CVEpisode *)episode from:(UIViewController *)controller
{
    if (!episode.canonicalURL.length) return;
    NSTimeInterval resume = [[CVHistory shared] positionForUUID:episode.uuid];
    CVPlayerViewController *player = [[CVPlayerViewController alloc] initWithItemURL:episode.canonicalURL
                                                                            itemUUID:episode.uuid
                                                                               title:episode.title
                                                                            subtitle:episode.seasonEpisodeString
                                                                      resumePosition:resume
                                                                             episode:episode];
    [self presentPlayer:player from:controller];
}

+ (void)playClip:(CVClip *)clip from:(UIViewController *)controller
{
    if (!clip.canonicalURL.length) return;
    CVPlayerViewController *player = [[CVPlayerViewController alloc] initWithItemURL:clip.canonicalURL
                                                                            itemUUID:clip.uuid
                                                                               title:clip.title
                                                                            subtitle:clip.subtitle
                                                                      resumePosition:0
                                                                             episode:nil];
    [self presentPlayer:player from:controller];
}

+ (void)openEpisode:(CVEpisode *)episode from:(UIViewController *)controller
{
    if (!episode) return;
    CVEpisodeDetailViewController *detail = [[CVEpisodeDetailViewController alloc] initWithEpisode:episode];
    UINavigationController *nav = [controller isKindOfClass:[UINavigationController class]] ? (UINavigationController *)controller : controller.navigationController;
    if (nav) {
        [nav pushViewController:detail animated:YES];
    } else {
        UINavigationController *modalNav = [[UINavigationController alloc] initWithRootViewController:detail];
        [[self presenterFrom:controller] presentViewController:modalNav animated:YES completion:nil];
    }
}

+ (void)openClip:(CVClip *)clip from:(UIViewController *)controller
{
    if (!clip) return;
    CVEpisodeDetailViewController *detail = [[CVEpisodeDetailViewController alloc] initWithClip:clip];
    UINavigationController *nav = [controller isKindOfClass:[UINavigationController class]] ? (UINavigationController *)controller : controller.navigationController;
    if (nav) {
        [nav pushViewController:detail animated:YES];
    } else {
        UINavigationController *modalNav = [[UINavigationController alloc] initWithRootViewController:detail];
        [[self presenterFrom:controller] presentViewController:modalNav animated:YES completion:nil];
    }
}

+ (BOOL)openSouthParkURL:(NSURL *)url from:(UIViewController *)controller
{
    NSString *host = url.host.lowercaseString;
    if (![host isEqualToString:@"southparkstudios.com"] && ![host isEqualToString:@"www.southparkstudios.com"]) {
        return NO;
    }

    NSString *path = url.path;
    if ([path hasPrefix:@"/episodes/"]) {
        CVEpisode *ep = [[CVEpisode alloc] init];
        ep.canonicalURL = path;
        ep.title = [path lastPathComponent];
        [self openEpisode:ep from:controller];
        return YES;
    } else if ([path hasPrefix:@"/clips/"]) {
        CVClip *clip = [[CVClip alloc] init];
        clip.canonicalURL = path;
        clip.title = [path lastPathComponent];
        [self openClip:clip from:controller];
        return YES;
    }
    return NO;
}

@end
