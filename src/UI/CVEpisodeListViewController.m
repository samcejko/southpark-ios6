#import "CVEpisodeListViewController.h"
#import "CVEpisodeDetailViewController.h"
#import "CVEpisodeCell.h"
#import "CVAPI.h"
#import "CVTheme.h"
#import "CVCommon.h"

@interface CVEpisodeListViewController ()
@property (nonatomic, strong) CVSeason *season;
@property (nonatomic, strong) NSArray<CVEpisode *> *episodes;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, strong) CVHTTPTask *currentTask;
@end

@implementation CVEpisodeListViewController

- (id)initWithSeason:(CVSeason *)season
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _season = season;
        self.title = season.label ?: L(@"Episodes");
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
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

    self.refresh = [[UIRefreshControl alloc] init];
    [self.refresh addTarget:self action:@selector(loadEpisodes) forControlEvents:UIControlEventValueChanged];
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

    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:@"CVHistoryDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:@"CVFavoritesDidChangeNotification" object:nil];

    [self applyTheme];
    [self loadEpisodes];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self applyTheme];
    [self.tableView reloadData];
}

- (void)applyTheme
{
    CVTheme *theme = [CVTheme shared];
    [theme applyToTableView:self.tableView];
    self.view.backgroundColor = [theme backgroundColor];
    self.tableView.backgroundColor = [theme backgroundColor];
    self.tableView.separatorColor = [theme separatorColor];
    self.statusLabel.textColor = [theme secondaryTextColor];
    self.spinner.activityIndicatorViewStyle = theme.isDark ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray;
}

- (void)loadEpisodes
{
    [self.currentTask cancel];
    self.statusLabel.hidden = YES;

    if (!self.episodes.count) {
        [self.spinner startAnimating];
    }

    __weak typeof(self) weakSelf = self;
    self.currentTask = [[CVAPI shared] fetchEpisodesForSeason:self.season completion:^(NSArray<CVEpisode *> *episodes, NSError *error) {
        [weakSelf.spinner stopAnimating];
        [weakSelf.refresh endRefreshing];

        if (episodes.count) {
            weakSelf.episodes = episodes;
            [weakSelf.tableView reloadData];
        } else if (error) {
            weakSelf.statusLabel.text = error.localizedDescription ?: L(@"Could not load episodes.");
            weakSelf.statusLabel.hidden = NO;
        }
    }];
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.episodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CVEpisodeCell *cell = [tableView dequeueReusableCellWithIdentifier:[CVEpisodeCell reuseIdentifier]];
    if (!cell) {
        cell = [[CVEpisodeCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[CVEpisodeCell reuseIdentifier]];
    }

    CVEpisode *ep = self.episodes[indexPath.row];
    [cell configureWithEpisode:ep];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CVEpisode *ep = self.episodes[indexPath.row];
    CVEpisodeDetailViewController *vc = [[CVEpisodeDetailViewController alloc] initWithEpisode:ep];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
