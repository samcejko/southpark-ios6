#import "CVRootViewController.h"
#import "CVHomeViewController.h"
#import "CVSeasonViewController.h"
#import "CVClipsViewController.h"
#import "CVSearchViewController.h"
#import "CVLibraryViewController.h"
#import "CVTheme.h"
#import "CVCommon.h"

@interface CVRootViewController () <UITabBarControllerDelegate>
@property (nonatomic, strong) UINavigationController *homeNav;
@property (nonatomic, strong) UINavigationController *seasonsNav;
@property (nonatomic, strong) UINavigationController *clipsNav;
@property (nonatomic, strong) UINavigationController *searchNav;
@property (nonatomic, strong) UINavigationController *libraryNav;
@end

@implementation CVRootViewController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        CVTheme *theme = [CVTheme shared];

        CVHomeViewController *home = [[CVHomeViewController alloc] init];
        home.tabBarItem = [[UITabBarItem alloc] initWithTitle:L(@"Home") image:[theme tabIconBrowse] tag:0];
        _homeNav = [[UINavigationController alloc] initWithRootViewController:home];

        CVSeasonViewController *seasons = [[CVSeasonViewController alloc] init];
        seasons.tabBarItem = [[UITabBarItem alloc] initWithTitle:L(@"Seasons") image:[theme tabIconCategories] tag:1];
        _seasonsNav = [[UINavigationController alloc] initWithRootViewController:seasons];

        CVClipsViewController *clips = [[CVClipsViewController alloc] init];
        clips.tabBarItem = [[UITabBarItem alloc] initWithTitle:L(@"Clips") image:[theme tabIconClips] tag:2];
        _clipsNav = [[UINavigationController alloc] initWithRootViewController:clips];

        CVSearchViewController *search = [[CVSearchViewController alloc] init];
        search.tabBarItem = [[UITabBarItem alloc] initWithTitle:L(@"Search") image:[theme tabIconSearch] tag:3];
        _searchNav = [[UINavigationController alloc] initWithRootViewController:search];

        CVLibraryViewController *library = [[CVLibraryViewController alloc] init];
        library.tabBarItem = [[UITabBarItem alloc] initWithTitle:L(@"Library") image:[theme tabIconFavorites] tag:4];
        _libraryNav = [[UINavigationController alloc] initWithRootViewController:library];

        self.viewControllers = @[ _homeNav, _seasonsNav, _clipsNav, _searchNav, _libraryNav ];

        NSInteger last = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastTab"];
        self.selectedIndex = (NSUInteger)((last >= 0 && last <= 4) ? last : 0);
        self.delegate = self;
        [self applyTheme];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:CVThemeDidChangeNotification object:nil];
}

- (void)applyTheme
{
    CVTheme *theme = [CVTheme shared];
    for (UIViewController *vc in self.viewControllers) {
        if ([vc isKindOfClass:[UINavigationController class]]) {
            [theme applyToNavigationBar:((UINavigationController *)vc).navigationBar];
        }
    }
    [theme applyToTabBar:self.tabBar];
    [[UIApplication sharedApplication] setStatusBarStyle:[theme statusBarStyle] animated:NO];
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)self.selectedIndex forKey:@"lastTab"];
}

- (void)searchFor:(NSString *)query
{
    [self.presentedViewController dismissViewControllerAnimated:NO completion:nil];
    self.selectedViewController = self.searchNav;
    [self.searchNav popToRootViewControllerAnimated:NO];
    CVSearchViewController *search = (CVSearchViewController *)self.searchNav.viewControllers[0];
    [search searchFor:query];
}

#pragma mark - Rotation

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return CVIsPad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
