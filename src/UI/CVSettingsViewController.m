#import "CVSettingsViewController.h"
#import "CVChoiceViewController.h"
#import "CVExternalOpen.h"
#import "CVSettings.h"
#import "CVTheme.h"
#import "CVTLSSocket.h"
#import "CVHTTP.h"
#import "CVImageLoader.h"
#import "CVUtils.h"
#import "CVCommon.h"

typedef NS_ENUM(NSInteger, CVSettingsSection) {
    CVSectionPlayback = 0,
    CVSectionAppearance,
    CVSectionAdvanced,
    CVSectionAbout,
    CVSectionCount,
};

@interface CVSettingsViewController ()
@property (nonatomic, copy) NSString *cacheSizeText;
@property (nonatomic, copy) NSString *connectionTestText;
@property (nonatomic, strong) CVHTTPTask *testTask;
@end

@implementation CVSettingsViewController

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) self.title = L(@"Settings");
    return self;
}

- (void)dealloc
{
    [_testTask cancel];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (self.navigationController.viewControllers.count == 1) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                               target:self
                                                                                               action:@selector(doneTapped)];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:CVThemeDidChangeNotification object:nil];
}

- (void)doneTapped
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self applyTheme];
    [self.tableView reloadData];
    __weak CVSettingsViewController *weakSelf = self;
    [[CVImageLoader shared] diskUsage:^(unsigned long long bytes) {
        weakSelf.cacheSizeText = [CVUtils formatFileSize:bytes];
        [weakSelf.tableView reloadData];
    }];
}

- (void)applyTheme
{
    CVTheme *t = [CVTheme shared];
    [t applyToTableView:self.tableView];
    [t applyToNavigationBar:self.navigationController.navigationBar];
    [self.tableView reloadData];
}

#pragma mark - Helpers

- (NSInteger)tagForSection:(NSInteger)section row:(NSInteger)row
{
    return section * 100 + row;
}

- (UISwitch *)switchOn:(BOOL)on tag:(NSInteger)tag
{
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
    sw.on = on;
    sw.tag = tag;
    sw.onTintColor = [[CVTheme shared] switchTintColor];
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    return sw;
}

- (UISegmentedControl *)segmentedWithItems:(NSArray *)items selected:(NSInteger)selected tag:(NSInteger)tag width:(CGFloat)width
{
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
    seg.segmentedControlStyle = UISegmentedControlStyleBar;
    seg.frame = CGRectMake(0, 0, width, 30);
    seg.selectedSegmentIndex = selected;
    seg.tag = tag;
    [seg addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    return seg;
}

+ (NSArray *)qualityKeys
{
    return @[ CVQualityAuto, CVQualitySource, @"1080", @"720", @"480", @"360" ];
}

+ (NSString *)qualityTitle:(NSString *)key
{
    if ([key isEqualToString:CVQualityAuto]) return L(@"Automatic");
    if ([key isEqualToString:CVQualitySource]) return L(@"Source (best)");
    return [NSString stringWithFormat:@"%@p", key];
}

#pragma mark - Table structure

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return CVSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch ((CVSettingsSection)section) {
        case CVSectionPlayback: return 5;
        case CVSectionAppearance: return 2;
        case CVSectionAdvanced: return 3;
        case CVSectionAbout: return 5;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch ((CVSettingsSection)section) {
        case CVSectionPlayback: return L(@"Playback");
        case CVSectionAppearance: return L(@"Appearance & Audio");
        case CVSectionAdvanced: return L(@"Advanced");
        case CVSectionAbout: return L(@"About");
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    switch ((CVSettingsSection)section) {
        case CVSectionPlayback: return L(@"This device decodes H.264 up to 1080p at 30 frames per second; renditions beyond that are left out of \"Automatic\".");
        case CVSectionAdvanced: return L(@"Turn certificate verification off only if the device clock is wrong or the certificate bundle is outdated.");
        case CVSectionAbout: return L(@"City VOD is an unofficial South Park Studios client. It is not affiliated with or endorsed by South Park Digital Studios, Paramount, or Comedy Central.");
        default: return nil;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == CVSectionAdvanced && indexPath.row == 2) return 56;
    return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CVTheme *t = [CVTheme shared];
    NSInteger sec = indexPath.section, row = indexPath.row;
    NSInteger tag = [self tagForSection:sec row:row];
    BOOL subtitle = sec == CVSectionAdvanced && row == 2;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:subtitle ? UITableViewCellStyleSubtitle : UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:subtitle ? 12 : 15];
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;

    switch ((CVSettingsSection)sec) {
        case CVSectionPlayback:
            if (row == 0) {
                cell.textLabel.text = L(@"Quality");
                cell.detailTextLabel.text = [CVSettingsViewController qualityTitle:[CVSettings preferredQuality]];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else if (row == 1) {
                cell.textLabel.text = L(@"Play next automatically");
                cell.accessoryView = [self switchOn:[CVSettings autoPlayNext] tag:tag];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else if (row == 2) {
                cell.textLabel.text = L(@"Subtitles by default");
                cell.accessoryView = [self switchOn:[CVSettings subtitlesEnabled] tag:tag];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else if (row == 3) {
                cell.textLabel.text = L(@"Sound in background");
                cell.accessoryView = [self switchOn:[CVSettings backgroundAudio] tag:tag];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else {
                cell.textLabel.text = L(@"Keep screen on");
                cell.accessoryView = [self switchOn:[CVSettings keepScreenOn] tag:tag];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            break;
        case CVSectionAppearance:
            if (row == 0) {
                cell.textLabel.text = L(@"Theme");
                cell.accessoryView = [self segmentedWithItems:@[ L(@"Light"), L(@"Dark") ] selected:t.isDark ? 1 : 0 tag:tag width:CVIsPad() ? 200 : 150];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else {
                cell.textLabel.text = L(@"Audio Language");
                BOOL isEs = [[CVSettings audioLanguage] isEqualToString:@"es"];
                cell.accessoryView = [self segmentedWithItems:@[ @"English", @"Español" ] selected:isEs ? 1 : 0 tag:tag width:CVIsPad() ? 200 : 160];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            break;
        case CVSectionAdvanced:
            if (row == 0) {
                cell.textLabel.text = L(@"Verify certificates");
                cell.accessoryView = [self switchOn:[CVSettings verifyTLS] tag:tag];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else if (row == 1) {
                cell.textLabel.text = L(@"Clear image cache");
                cell.detailTextLabel.text = self.cacheSizeText ?: @"";
            } else {
                cell.textLabel.text = L(@"Connection test");
                cell.detailTextLabel.text = self.connectionTestText ?: L(@"Tap to test the connection to South Park Studios");
            }
            break;
        case CVSectionAbout:
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (row == 0) {
                cell.textLabel.text = L(@"Version");
                cell.detailTextLabel.text = [CVUtils appVersion];
            } else if (row == 1) {
                cell.textLabel.text = L(@"Author");
                cell.detailTextLabel.text = @"samcejko";
            } else if (row == 2) {
                cell.textLabel.text = L(@"Root certificates");
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)[CVTLSSocket caCertificateCount]];
            } else if (row == 3) {
                cell.textLabel.text = L(@"Device");
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · iOS %@", [CVUtils deviceModel], [UIDevice currentDevice].systemVersion];
            } else {
                cell.textLabel.text = L(@"Support the development");
                cell.detailTextLabel.text = @"ko-fi.com/samcejko";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            }
            break;
        default:
            break;
    }
    [t styleCell:cell];
    return cell;
}

#pragma mark - Controls

- (void)switchChanged:(UISwitch *)sw
{
    NSInteger sec = sw.tag / 100, row = sw.tag % 100;
    if (sec == CVSectionPlayback && row == 1) [CVSettings setAutoPlayNext:sw.on];
    else if (sec == CVSectionPlayback && row == 2) [CVSettings setSubtitlesEnabled:sw.on];
    else if (sec == CVSectionPlayback && row == 3) [CVSettings setBackgroundAudio:sw.on];
    else if (sec == CVSectionPlayback && row == 4) [CVSettings setKeepScreenOn:sw.on];
    else if (sec == CVSectionAdvanced && row == 0) [CVSettings setVerifyTLS:sw.on];
    [CVSettings save];
}

- (void)segmentChanged:(UISegmentedControl *)seg
{
    NSInteger sec = seg.tag / 100, row = seg.tag % 100;
    if (sec == CVSectionAppearance && row == 0) {
        [[CVTheme shared] setDark:seg.selectedSegmentIndex == 1];
    } else if (sec == CVSectionAppearance && row == 1) {
        [CVSettings setAudioLanguage:seg.selectedSegmentIndex == 1 ? @"es" : @"en"];
    }
    [CVSettings save];
}

#pragma mark - Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger sec = indexPath.section, row = indexPath.row;
    if (sec == CVSectionPlayback && row == 0) {
        CVChoiceViewController *vc = [[CVChoiceViewController alloc] init];
        vc.title = L(@"Quality");
        NSArray *keys = [CVSettingsViewController qualityKeys];
        NSMutableArray *titles = [NSMutableArray array];
        for (NSString *k in keys) [titles addObject:[CVSettingsViewController qualityTitle:k]];
        vc.titles = titles;
        vc.subtitles = @[ L(@"The player picks what the connection allows, up to what the device decodes."),
                          L(@"The streamer's own quality, when the device can decode it."),
                          @"", @"", @"", @"" ];
        NSUInteger idx = [keys indexOfObject:[CVSettings preferredQuality]];
        vc.selectedIndex = idx == NSNotFound ? 0 : (NSInteger)idx;
        vc.completion = ^(NSInteger index) {
            [CVSettings setPreferredQuality:keys[(NSUInteger)index]];
            [CVSettings save];
        };
        [self.navigationController pushViewController:vc animated:YES];
    } else if (sec == CVSectionAdvanced && row == 1) {
        self.cacheSizeText = L(@"Clearing…");
        [tableView reloadData];
        __weak CVSettingsViewController *weakSelf = self;
        [[CVImageLoader shared] clearDiskWithCompletion:^{
            weakSelf.cacheSizeText = [CVUtils formatFileSize:0];
            [weakSelf.tableView reloadData];
        }];
    } else if (sec == CVSectionAdvanced && row == 2) {
        [self runConnectionTest];
    } else if (sec == CVSectionAbout && row == 4) {
        [CVExternalOpen presentOpenInForURL:[NSURL URLWithString:@"https://ko-fi.com/samcejko"] from:self anchor:[tableView cellForRowAtIndexPath:indexPath]];
    }
}

- (void)runConnectionTest
{
    if (self.testTask) return;
    self.connectionTestText = L(@"Testing…");
    [self.tableView reloadData];
    NSDate *start = [NSDate date];
    __weak CVSettingsViewController *weakSelf = self;
    self.testTask = [CVHTTP get:@"https://www.southparkstudios.com/" headers:nil completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        CVSettingsViewController *s = weakSelf;
        if (!s) return;
        NSTimeInterval dt = -[start timeIntervalSinceNow];
        if (error) s.connectionTestText = error.localizedDescription;
        else s.connectionTestText = [NSString stringWithFormat:L(@"Server answered (HTTP %ld) in %.1f s"), (long)status, dt];
        s.testTask = nil;
        [s.tableView reloadData];
    }];
}

@end
