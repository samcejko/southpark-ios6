#import "CVSeasonViewController.h"
#import "CVEpisodeListViewController.h"
#import "CVAPI.h"
#import "CVTheme.h"
#import "CVCommon.h"

@interface CVSeasonViewController ()
@property (nonatomic, strong) NSArray<CVSeason *> *seasons;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, strong) CVHTTPTask *currentTask;
@end

@implementation CVSeasonViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = L(@"Seasons");
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:L(@"Seasons") image:[[CVTheme shared] tabIconBrowse] tag:1];
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
    self.tableView.rowHeight = 52.0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

    self.refresh = [[UIRefreshControl alloc] init];
    [self.refresh addTarget:self action:@selector(loadSeasons) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refresh];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 100);
    [self.view addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 50)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.hidden = YES;
    [self.view addSubview:self.statusLabel];

    [self applyTheme];
    [self loadSeasons];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)applyTheme
{
    CVTheme *theme = [CVTheme shared];
    self.view.backgroundColor = [theme backgroundColor];
    self.tableView.backgroundColor = [theme backgroundColor];
    self.tableView.separatorColor = [theme separatorColor];
    self.statusLabel.textColor = [theme secondaryTextColor];
    self.spinner.activityIndicatorViewStyle = theme.isDark ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray;
}

- (void)loadSeasons
{
    [self.currentTask cancel];
    self.statusLabel.hidden = YES;

    if (!self.seasons.count) {
        [self.spinner startAnimating];
    }

    __weak typeof(self) weakSelf = self;
    self.currentTask = [[CVAPI shared] fetchSeasonsWithCompletion:^(NSArray<CVSeason *> *seasons, NSError *error) {
        [weakSelf.spinner stopAnimating];
        [weakSelf.refresh endRefreshing];

        if (seasons.count) {
            weakSelf.seasons = seasons;
            [weakSelf.tableView reloadData];
        } else if (error) {
            weakSelf.statusLabel.text = error.localizedDescription ?: L(@"Could not load seasons.");
            weakSelf.statusLabel.hidden = NO;
        }
    }];
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.seasons.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const CellId = @"CVSeasonCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    }

    CVSeason *season = self.seasons[indexPath.row];
    cell.textLabel.text = season.label;
    cell.textLabel.textColor = [[CVTheme shared] primaryTextColor];
    cell.detailTextLabel.textColor = [[CVTheme shared] secondaryTextColor];

    if (season.episodeCount > 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld %@", (long)season.episodeCount, L(@"episodes")];
    } else {
        cell.detailTextLabel.text = @"";
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CVSeason *season = self.seasons[indexPath.row];
    CVEpisodeListViewController *vc = [[CVEpisodeListViewController alloc] initWithSeason:season];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
