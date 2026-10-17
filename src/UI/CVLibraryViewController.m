#import "CVLibraryViewController.h"
#import "CVEpisodeDetailViewController.h"
#import "CVSettingsViewController.h"
#import "CVEpisodeCell.h"
#import "CVFavorites.h"
#import "CVHistory.h"
#import "CVTheme.h"
#import "CVCommon.h"

typedef NS_ENUM(NSInteger, CVLibrarySegment) {
    CVLibrarySegmentFavorites = 0,
    CVLibrarySegmentHistory
};

@interface CVLibraryViewController () <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIBarButtonItem *settingsItem;
@property (nonatomic, strong) UIBarButtonItem *clearItem;
@property (nonatomic, assign) CVLibrarySegment currentSegment;
@end

@implementation CVLibraryViewController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = L(@"Library");
        _items = [NSMutableArray array];
        _currentSegment = CVLibrarySegmentFavorites;
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

    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[ L(@"Favorites"), L(@"History") ]];
    self.segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    self.segmentedControl.selectedSegmentIndex = 0;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.segmentedControl;

    self.settingsItem = [[UIBarButtonItem alloc] initWithImage:[[CVTheme shared] gearIconWhite]
                                                         style:UIBarButtonItemStyleBordered
                                                        target:self
                                                        action:@selector(settingsTapped)];
    self.navigationItem.leftBarButtonItem = self.settingsItem;

    self.clearItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Clear")
                                                      style:UIBarButtonItemStyleBordered
                                                     target:self
                                                     action:@selector(clearHistoryTapped)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = [CVEpisodeCell heightForWidth:self.view.bounds.size.width];
    [self.view addSubview:self.tableView];

    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, 70)];
    self.emptyLabel.numberOfLines = 3;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.backgroundColor = [UIColor clearColor];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:CVThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataChanged) name:CVFavoritesDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataChanged) name:CVHistoryDidChangeNotification object:nil];

    [self updateNavigationButtons];
    [self applyTheme];
    [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self applyTheme];
    [self reloadData];
}

- (void)applyTheme
{
    CVTheme *theme = [CVTheme shared];
    self.view.backgroundColor = [theme backgroundColor];
    self.tableView.backgroundColor = [theme backgroundColor];
    self.tableView.separatorColor = [theme separatorColor];
    self.emptyLabel.textColor = [theme secondaryTextColor];
    [theme applyToNavigationBar:self.navigationController.navigationBar];
}

- (void)updateNavigationButtons
{
    if (self.currentSegment == CVLibrarySegmentFavorites) {
        self.navigationItem.rightBarButtonItem = self.items.count ? self.editButtonItem : nil;
    } else {
        self.navigationItem.rightBarButtonItem = self.items.count ? self.clearItem : nil;
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

- (void)settingsTapped
{
    CVSettingsViewController *settings = [[CVSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    [self presentViewController:nav animated:YES completion:NULL];
}

- (void)clearHistoryTapped
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:L(@"Are you sure you want to clear your watch history?")
                                                       delegate:self
                                              cancelButtonTitle:L(@"Cancel")
                                         destructiveButtonTitle:L(@"Clear Watch History")
                                              otherButtonTitles:nil];
    if (CVIsPad()) {
        [sheet showFromBarButtonItem:self.clearItem animated:YES];
    } else {
        [sheet showFromTabBar:self.tabBarController.tabBar];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.destructiveButtonIndex) {
        [[CVHistory shared] clearHistory];
        [self reloadData];
    }
}

#pragma mark - Data

- (void)segmentChanged:(UISegmentedControl *)sender
{
    self.currentSegment = (CVLibrarySegment)sender.selectedSegmentIndex;
    if (self.isEditing) {
        [self setEditing:NO animated:NO];
    }
    [self reloadData];
}

- (void)dataChanged
{
    [self reloadData];
}

- (void)reloadData
{
    [self.items removeAllObjects];

    if (self.currentSegment == CVLibrarySegmentFavorites) {
        NSArray<CVEpisode *> *favs = [[CVFavorites shared] allFavorites];
        if (favs.count) {
            [self.items addObjectsFromArray:favs];
        }
    } else {
        NSArray<CVHistoryEntry *> *hist = [[CVHistory shared] recentEntries];
        if (hist.count) {
            [self.items addObjectsFromArray:hist];
        }
    }

    [self.tableView reloadData];
    [self updateNavigationButtons];

    if (self.items.count == 0) {
        self.emptyLabel.hidden = NO;
        if (self.currentSegment == CVLibrarySegmentFavorites) {
            self.emptyLabel.text = L(@"You have no favorites yet.\nTap the star icon on any episode to save it here.");
        } else {
            self.emptyLabel.text = L(@"No watch history yet.\nEpisodes you start watching will appear here.");
        }
    } else {
        self.emptyLabel.hidden = YES;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CVEpisodeCell *cell = [tableView dequeueReusableCellWithIdentifier:[CVEpisodeCell reuseIdentifier]];
    if (!cell) {
        cell = [[CVEpisodeCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[CVEpisodeCell reuseIdentifier]];
    }

    id item = self.items[indexPath.row];
    if ([item isKindOfClass:[CVEpisode class]]) {
        [cell configureWithEpisode:(CVEpisode *)item];
    } else if ([item isKindOfClass:[CVHistoryEntry class]]) {
        CVHistoryEntry *entry = (CVHistoryEntry *)item;
        [cell configureWithEpisode:entry.episode];
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        id item = self.items[indexPath.row];
        if ([item isKindOfClass:[CVEpisode class]]) {
            CVEpisode *ep = (CVEpisode *)item;
            [[CVFavorites shared] removeFavorite:ep.uuid];
        } else if ([item isKindOfClass:[CVHistoryEntry class]]) {
            CVHistoryEntry *entry = (CVHistoryEntry *)item;
            [[CVHistory shared] removeEntryForUUID:entry.episode.uuid];
        }

        [self.items removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self updateNavigationButtons];

        if (self.items.count == 0) {
            [self reloadData];
        }
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.items.count) return;

    id item = self.items[indexPath.row];
    CVEpisode *episode = nil;
    if ([item isKindOfClass:[CVEpisode class]]) {
        episode = (CVEpisode *)item;
    } else if ([item isKindOfClass:[CVHistoryEntry class]]) {
        episode = ((CVHistoryEntry *)item).episode;
    }

    if (episode) {
        CVEpisodeDetailViewController *detail = [[CVEpisodeDetailViewController alloc] initWithEpisode:episode];
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
