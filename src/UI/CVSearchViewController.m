#import "CVSearchViewController.h"
#import "CVEpisodeDetailViewController.h"
#import "CVEpisodeCell.h"
#import "CVAPI.h"
#import "CVCache.h"
#import "CVTheme.h"
#import "CVCommon.h"

@interface CVSearchViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *results;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, copy) NSString *lastQuery;
@property (nonatomic, assign) BOOL isIndexing;
@end

@implementation CVSearchViewController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = L(@"Search");
        _results = @[];
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

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = L(@"Search episodes and clips...");
    self.searchBar.showsCancelButton = NO;
    [self.view addSubview:self.searchBar];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, self.view.bounds.size.width, self.view.bounds.size.height - 44) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = [CVEpisodeCell heightForWidth:self.view.bounds.size.width];
    [self.view addSubview:self.tableView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 120);
    [self.view addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, 60)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.backgroundColor = [UIColor clearColor];
    self.statusLabel.text = L(@"Type a keyword, episode title, or season/episode (e.g. S01E01).");
    [self.view addSubview:self.statusLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:CVThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:@"CVHistoryDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:@"CVFavoritesDidChangeNotification" object:nil];

    [self applyTheme];
    [self checkAndWarmIndex];
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
    [theme applyToSearchBar:self.searchBar];
    [theme applyToNavigationBar:self.navigationController.navigationBar];
}

- (void)checkAndWarmIndex
{
    NSArray *seasons = [[CVCache shared] objectForKey:@"seasons_list"];
    if (!seasons.count) {
        self.isIndexing = YES;
        [[CVAPI shared] fetchSeasonsWithCompletion:^(NSArray<CVSeason *> *loadedSeasons, NSError *error) {
            self.isIndexing = NO;
            if (self.lastQuery.length) {
                [self performSearch:self.lastQuery];
            }
        }];
    }
}

- (void)searchFor:(NSString *)query
{
    self.searchBar.text = query;
    [self performSearch:query];
}

- (void)performSearch:(NSString *)query
{
    NSString *trimmed = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.lastQuery = trimmed;

    if (!trimmed.length) {
        self.results = @[];
        self.statusLabel.text = L(@"Type a keyword, episode title, or season/episode (e.g. S01E01).");
        self.statusLabel.hidden = NO;
        [self.spinner stopAnimating];
        [self.tableView reloadData];
        return;
    }

    [self.spinner startAnimating];
    self.statusLabel.hidden = YES;

    [[CVAPI shared] searchEpisodesAndClips:trimmed completion:^(NSArray *results, NSError *error) {
        [self.spinner stopAnimating];
        self.results = results ?: @[];
        [self.tableView reloadData];

        if (!self.results.count) {
            self.statusLabel.text = [NSString stringWithFormat:L(@"No results found for \"%@\"."), trimmed];
            self.statusLabel.hidden = NO;
        } else {
            self.statusLabel.hidden = YES;
        }
    }];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self performSearch:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    [self performSearch:searchBar.text];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [self performSearch:@""];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if ([self.searchBar isFirstResponder]) {
        [self.searchBar resignFirstResponder];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CVEpisodeCell *cell = [tableView dequeueReusableCellWithIdentifier:[CVEpisodeCell reuseIdentifier]];
    if (!cell) {
        cell = [[CVEpisodeCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[CVEpisodeCell reuseIdentifier]];
    }

    id item = self.results[indexPath.row];
    if ([item isKindOfClass:[CVEpisode class]]) {
        [cell configureWithEpisode:(CVEpisode *)item];
    } else if ([item isKindOfClass:[CVClip class]]) {
        [cell configureWithClip:(CVClip *)item];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.results.count) return;

    id item = self.results[indexPath.row];
    if ([item isKindOfClass:[CVEpisode class]]) {
        CVEpisodeDetailViewController *detail = [[CVEpisodeDetailViewController alloc] initWithEpisode:(CVEpisode *)item];
        [self.navigationController pushViewController:detail animated:YES];
    } else if ([item isKindOfClass:[CVClip class]]) {
        CVEpisodeDetailViewController *detail = [[CVEpisodeDetailViewController alloc] initWithClip:(CVClip *)item];
        [self.navigationController pushViewController:detail animated:YES];
    }
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
