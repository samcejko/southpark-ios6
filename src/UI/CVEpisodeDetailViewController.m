#import "CVEpisodeDetailViewController.h"
#import "CVPlayerViewController.h"
#import "CVTheme.h"
#import "CVImageLoader.h"
#import "CVFavorites.h"
#import "CVHistory.h"
#import "CVExternalOpen.h"
#import "CVCommon.h"

@interface CVEpisodeDetailViewController ()
@property (nonatomic, strong) CVEpisode *episode;
@property (nonatomic, strong) CVClip *clip;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *bannerView;
@property (nonatomic, strong) UIButton *playOverlayButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *restartButton;
@property (nonatomic, strong) UIButton *favoriteButton;
@property (nonatomic, strong) UIButton *webButton;
@property (nonatomic, strong) UITextView *summaryTextView;
@end

@implementation CVEpisodeDetailViewController

- (id)initWithEpisode:(CVEpisode *)episode
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _episode = episode;
        self.title = episode.title ?: L(@"Episode");
    }
    return self;
}

- (id)initWithClip:(CVClip *)clip
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _clip = clip;
        self.title = clip.title ?: L(@"Clip");
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    // Banner / thumbnail at top
    self.bannerView = [[UIImageView alloc] init];
    self.bannerView.contentMode = UIViewContentModeScaleAspectFill;
    self.bannerView.clipsToBounds = YES;
    self.bannerView.userInteractionEnabled = YES;
    [self.scrollView addSubview:self.bannerView];

    // Big play button overlay
    self.playOverlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.playOverlayButton setImage:[[CVTheme shared] playIcon] forState:UIControlStateNormal];
    [self.playOverlayButton setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.45]];
    self.playOverlayButton.layer.cornerRadius = 32.0;
    self.playOverlayButton.clipsToBounds = YES;
    [self.playOverlayButton addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bannerView addSubview:self.playOverlayButton];

    // Title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.titleLabel];

    // Meta (S1 • E1 • 22:00 • Air date)
    self.metaLabel = [[UILabel alloc] init];
    self.metaLabel.font = [UIFont systemFontOfSize:13];
    self.metaLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.metaLabel];

    // Action buttons
    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.playButton addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];
    self.playButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.scrollView addSubview:self.playButton];

    self.restartButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.restartButton setTitle:L(@"Start from Beginning") forState:UIControlStateNormal];
    [self.restartButton addTarget:self action:@selector(restartTapped) forControlEvents:UIControlEventTouchUpInside];
    self.restartButton.titleLabel.font = [UIFont systemFontOfSize:13];
    [self.scrollView addSubview:self.restartButton];

    self.favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.favoriteButton addTarget:self action:@selector(favoriteTapped) forControlEvents:UIControlEventTouchUpInside];
    self.favoriteButton.titleLabel.font = [UIFont systemFontOfSize:13];
    [self.scrollView addSubview:self.favoriteButton];

    self.webButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.webButton setTitle:L(@"Open on Website") forState:UIControlStateNormal];
    [self.webButton addTarget:self action:@selector(webTapped) forControlEvents:UIControlEventTouchUpInside];
    self.webButton.titleLabel.font = [UIFont systemFontOfSize:13];
    [self.scrollView addSubview:self.webButton];

    // Summary
    self.summaryTextView = [[UITextView alloc] init];
    self.summaryTextView.editable = NO;
    self.summaryTextView.scrollEnabled = NO;
    self.summaryTextView.font = [UIFont systemFontOfSize:14];
    self.summaryTextView.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.summaryTextView];

    [self applyTheme];
    [self populateData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self applyTheme];
    [self updateButtons];
}

- (void)applyTheme
{
    CVTheme *theme = [CVTheme shared];
    self.view.backgroundColor = [theme backgroundColor];
    self.scrollView.backgroundColor = [theme backgroundColor];
    self.titleLabel.textColor = [theme primaryTextColor];
    self.metaLabel.textColor = [theme secondaryTextColor];
    self.summaryTextView.textColor = [theme primaryTextColor];

    [self.playButton setBackgroundImage:[theme accentButtonImageHighlighted:NO disabled:NO] forState:UIControlStateNormal];
    [self.playButton setBackgroundImage:[theme accentButtonImageHighlighted:YES disabled:NO] forState:UIControlStateHighlighted];
    [self.playButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    [self.restartButton setBackgroundImage:[theme buttonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.restartButton setBackgroundImage:[theme buttonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.restartButton setTitleColor:[theme primaryTextColor] forState:UIControlStateNormal];

    [self.favoriteButton setBackgroundImage:[theme buttonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.favoriteButton setBackgroundImage:[theme buttonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.favoriteButton setTitleColor:[theme primaryTextColor] forState:UIControlStateNormal];

    [self.webButton setBackgroundImage:[theme buttonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.webButton setBackgroundImage:[theme buttonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.webButton setTitleColor:[theme primaryTextColor] forState:UIControlStateNormal];
}

- (void)populateData
{
    NSString *thumb = nil;
    if (self.episode) {
        self.titleLabel.text = self.episode.title ?: @"";
        NSString *m = @"";
        if (self.episode.seasonEpisodeString.length) m = self.episode.seasonEpisodeString;
        if (self.episode.durationString.length) m = [m stringByAppendingFormat:@"  •  %@", self.episode.durationString];
        if (self.episode.airDate.length) m = [m stringByAppendingFormat:@"  •  %@", self.episode.airDate];
        self.metaLabel.text = m;
        self.summaryTextView.text = self.episode.summary ?: @"";
        thumb = self.episode.thumbURL;
    } else if (self.clip) {
        self.titleLabel.text = self.clip.title ?: @"";
        NSString *m = self.clip.durationString ?: @"";
        if (self.clip.airDate.length) m = [m stringByAppendingFormat:@"  •  %@", self.clip.airDate];
        self.metaLabel.text = m;
        self.summaryTextView.text = self.clip.summary ?: @"";
        thumb = self.clip.thumbURL;
        self.favoriteButton.hidden = YES;
    }

    self.bannerView.image = [[CVTheme shared] thumbnailPlaceholder];
    if (thumb.length) {
        __weak typeof(self) weakSelf = self;
        [[CVImageLoader shared] loadImageURL:thumb completion:^(UIImage *image, NSError *error) {
            if (image) weakSelf.bannerView.image = image;
        }];
    }
}

- (void)updateButtons
{
    NSString *uuid = self.episode ? self.episode.uuid : self.clip.uuid;
    NSTimeInterval pos = [[CVHistory shared] positionForUUID:uuid];

    if (pos > 15) {
        NSInteger m = (NSInteger)(pos / 60);
        NSInteger s = (NSInteger)(pos - m * 60);
        [self.playButton setTitle:[NSString stringWithFormat:@"%@ (%02ld:%02ld)", L(@"Resume"), (long)m, (long)s] forState:UIControlStateNormal];
        self.restartButton.hidden = NO;
    } else {
        [self.playButton setTitle:L(@"Play Episode") forState:UIControlStateNormal];
        self.restartButton.hidden = YES;
    }

    if (self.episode) {
        BOOL isFav = [[CVFavorites shared] isFavorite:self.episode.uuid];
        [self.favoriteButton setTitle:isFav ? L(@"★ Favorited") : L(@"☆ Add to Favorites") forState:UIControlStateNormal];
    }

    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;

    CGFloat bannerH = floor(w * (9.0 / 16.0));
    self.bannerView.frame = CGRectMake(0, 0, w, bannerH);
    self.playOverlayButton.frame = CGRectMake((w - 64) / 2.0, (bannerH - 64) / 2.0, 64, 64);

    CGFloat y = bannerH + 14;
    self.titleLabel.frame = CGRectMake(14, y, w - 28, 24);
    y += 28;

    self.metaLabel.frame = CGRectMake(14, y, w - 28, 18);
    y += 24;

    self.playButton.frame = CGRectMake(14, y, w - 28, 42);
    y += 50;

    if (!self.restartButton.hidden) {
        self.restartButton.frame = CGRectMake(14, y, w - 28, 36);
        y += 44;
    }

    if (self.episode) {
        CGFloat halfW = (w - 36) / 2.0;
        self.favoriteButton.frame = CGRectMake(14, y, halfW, 36);
        self.webButton.frame = CGRectMake(14 + halfW + 8, y, halfW, 36);
        y += 44;
    } else {
        self.webButton.frame = CGRectMake(14, y, w - 28, 36);
        y += 44;
    }

    CGSize sumSize = [self.summaryTextView sizeThatFits:CGSizeMake(w - 28, CGFLOAT_MAX)];
    self.summaryTextView.frame = CGRectMake(10, y, w - 20, sumSize.height + 20);
    y += sumSize.height + 30;

    self.scrollView.contentSize = CGSizeMake(w, y);
}

- (void)playTapped
{
    NSString *urlPath = self.episode ? self.episode.urlPath : self.clip.urlPath;
    NSString *uuid = self.episode ? self.episode.uuid : self.clip.uuid;
    NSTimeInterval startPos = [[CVHistory shared] positionForUUID:uuid];

    CVPlayerViewController *player = [[CVPlayerViewController alloc] initWithItemURL:urlPath itemUUID:uuid title:self.titleLabel.text subtitle:self.metaLabel.text resumePosition:startPos episode:self.episode];
    [self presentViewController:player animated:YES completion:NULL];
}

- (void)restartTapped
{
    NSString *urlPath = self.episode ? self.episode.urlPath : self.clip.urlPath;
    NSString *uuid = self.episode ? self.episode.uuid : self.clip.uuid;

    CVPlayerViewController *player = [[CVPlayerViewController alloc] initWithItemURL:urlPath itemUUID:uuid title:self.titleLabel.text subtitle:self.metaLabel.text resumePosition:0 episode:self.episode];
    [self presentViewController:player animated:YES completion:NULL];
}

- (void)favoriteTapped
{
    if (self.episode) {
        [[CVFavorites shared] toggleFavorite:self.episode];
        [self updateButtons];
    }
}

- (void)webTapped
{
    NSString *path = self.episode ? self.episode.urlPath : self.clip.urlPath;
    if (path.length) {
        NSString *url = [@"https://www.southparkstudios.com" stringByAppendingString:path];
        [CVExternalOpen openURLString:url fromViewController:self];
    }
}

@end
