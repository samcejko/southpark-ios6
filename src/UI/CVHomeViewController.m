#import "CVHomeViewController.h"
#import "CVEpisodeDetailViewController.h"
#import "CVSettingsViewController.h"
#import "CVEpisodeCell.h"
#import "CVAPI.h"
#import "CVHistory.h"
#import "CVTheme.h"
#import "CVCommon.h"

@interface CVHomeViewController ()
@property (nonatomic, strong) NSArray<CVHistoryEntry *> *historyEntries;
@property (nonatomic, strong) NSArray<CVClip *> *featuredClips;
@property (nonatomic, strong) NSArray<CVEpisode *> *latestEpisodes;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) CVHTTPTask *currentTask;
@end

@implementation CVHomeViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = L(@"Home");
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:L(@"Home") image:[[CVTheme shared] tabIconCategories] tag:0];
    }
    return self;
}

- (void)dealloc
{
    [_currentTask cancel];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.rowHeight = [CVEpisodeCell heightForWidth:self.view.bounds.size.width];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[[CVTheme shared] gearIconWhite]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(settingsTapped)];

    self.refresh = [[UIRefreshControl alloc] init];
    [self.refresh addTarget:self action:@selector(loadData) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refresh];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 100);
    [self.view addSubview:self.spinner];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onHistoryChanged) name:@"CVHistoryDidChangeNotification" object:nil];

    [self applyTheme];
    [self loadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self applyTheme];
    self.historyEntries = [[CVHistory shared] recentEntries];
    [self.tableView reloadData];
}

- (void)onHistoryChanged
{
    self.historyEntries = [[CVHistory shared] recentEntries];
    [self.tableView reloadData];
}

- (void)applyTheme
{
    CVTheme *theme = [CVTheme shared];
    [theme applyToTableView:self.tableView];
    self.view.backgroundColor = [theme backgroundColor];
    self.tableView.backgroundColor = [theme backgroundColor];
    self.tableView.separatorColor = [theme separatorColor];
    self.spinner.activityIndicatorViewStyle = theme.isDark ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray;
}

- (void)settingsTapped
{
    CVSettingsViewController *settings = [[CVSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    [self presentViewController:nav animated:YES completion:NULL];
}

- (void)loadData
{
    [self.currentTask cancel];
    self.historyEntries = [[CVHistory shared] recentEntries];

    if (!self.featuredClips.count && !self.latestEpisodes.count) {
        [self.spinner startAnimating];
    }

    __weak typeof(self) weakSelf = self;
    self.currentTask = [[CVAPI shared] fetchHomeWithCompletion:^(NSArray<CVClip *> *clips, NSArray<CVEpisode *> *episodes, NSError *error) {
        [weakSelf.spinner stopAnimating];
        [weakSelf.refresh endRefreshing];

        weakSelf.featuredClips = clips;
        weakSelf.latestEpisodes = episodes;
        [weakSelf.tableView reloadData];
    }];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger count = 0;
    if (self.historyEntries.count) count++;
    if (self.featuredClips.count) count++;
    if (self.latestEpisodes.count) count++;
    return count > 0 ? count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSInteger s = section;
    if (self.historyEntries.count) {
        if (s == 0) return L(@"Continue Watching");
        s--;
    }
    if (self.featuredClips.count) {
        if (s == 0) return L(@"Latest Clips");
        s--;
    }
    if (self.latestEpisodes.count) {
        if (s == 0) return L(@"Featured Episodes");
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger s = section;
    if (self.historyEntries.count) {
        if (s == 0) return MIN(5, (NSInteger)self.historyEntries.count);
        s--;
    }
    if (self.featuredClips.count) {
        if (s == 0) return self.featuredClips.count;
        s--;
    }
    if (self.latestEpisodes.count) {
        if (s == 0) return self.latestEpisodes.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CVEpisodeCell *cell = [tableView dequeueReusableCellWithIdentifier:[CVEpisodeCell reuseIdentifier]];
    if (!cell) {
        cell = [[CVEpisodeCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[CVEpisodeCell reuseIdentifier]];
    }

    NSInteger s = indexPath.section;
    if (self.historyEntries.count) {
        if (s == 0) {
            CVHistoryEntry *e = self.historyEntries[indexPath.row];
            [cell configureWithEpisode:e.episode];
            return cell;
        }
        s--;
    }
    if (self.featuredClips.count) {
        if (s == 0) {
            [cell configureWithClip:self.featuredClips[indexPath.row]];
            return cell;
        }
        s--;
    }
    if (self.latestEpisodes.count) {
        if (s == 0) {
            [cell configureWithEpisode:self.latestEpisodes[indexPath.row]];
            return cell;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSInteger s = indexPath.section;
    if (self.historyEntries.count) {
        if (s == 0) {
            CVHistoryEntry *e = self.historyEntries[indexPath.row];
            CVEpisodeDetailViewController *vc = [[CVEpisodeDetailViewController alloc] initWithEpisode:e.episode];
            [self.navigationController pushViewController:vc animated:YES];
            return;
        }
        s--;
    }
    if (self.featuredClips.count) {
        if (s == 0) {
            CVClip *c = self.featuredClips[indexPath.row];
            CVEpisodeDetailViewController *vc = [[CVEpisodeDetailViewController alloc] initWithClip:c];
            [self.navigationController pushViewController:vc animated:YES];
            return;
        }
        s--;
    }
    if (self.latestEpisodes.count) {
        if (s == 0) {
            CVEpisode *ep = self.latestEpisodes[indexPath.row];
            CVEpisodeDetailViewController *vc = [[CVEpisodeDetailViewController alloc] initWithEpisode:ep];
            [self.navigationController pushViewController:vc animated:YES];
            return;
        }
    }
}

@end
