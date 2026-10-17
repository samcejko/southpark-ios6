#import "CVClipsViewController.h"
#import "CVEpisodeDetailViewController.h"
#import "CVEpisodeCell.h"
#import "CVAPI.h"
#import "CVTheme.h"
#import "CVCommon.h"

@interface CVClipsViewController ()
@property (nonatomic, strong) NSArray<CVClip *> *clips;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, strong) CVHTTPTask *currentTask;
@end

@implementation CVClipsViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = L(@"Clips");
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:L(@"Clips") image:[[CVTheme shared] tabIconBrowse] tag:2];
    }
    return self;
}

- (void)dealloc
{
    [_currentTask cancel];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.rowHeight = [CVEpisodeCell heightForWidth:self.view.bounds.size.width];

    self.refresh = [[UIRefreshControl alloc] init];
    [self.refresh addTarget:self action:@selector(loadClips) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refresh];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 100);
    [self.view addSubview:self.spinner];

    [self applyTheme];
    [self loadClips];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self applyTheme];
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

- (void)loadClips
{
    [self.currentTask cancel];
    if (!self.clips.count) [self.spinner startAnimating];

    __weak typeof(self) weakSelf = self;
    self.currentTask = [[CVAPI shared] fetchHomeWithCompletion:^(NSArray<CVClip *> *clips, NSArray<CVEpisode *> *episodes, NSError *error) {
        [weakSelf.spinner stopAnimating];
        [weakSelf.refresh endRefreshing];

        if (clips.count) {
            weakSelf.clips = clips;
            [weakSelf.tableView reloadData];
        }
    }];
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.clips.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CVEpisodeCell *cell = [tableView dequeueReusableCellWithIdentifier:[CVEpisodeCell reuseIdentifier]];
    if (!cell) {
        cell = [[CVEpisodeCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[CVEpisodeCell reuseIdentifier]];
    }
    [cell configureWithClip:self.clips[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CVClip *clip = self.clips[indexPath.row];
    CVEpisodeDetailViewController *vc = [[CVEpisodeDetailViewController alloc] initWithClip:clip];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
