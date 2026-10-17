#import "CVEpisodeDetailViewController.h"
#import "CVPlayerViewController.h"
#import "CVTheme.h"
#import "CVImageLoader.h"
#import "CVFavorites.h"
#import "CVHistory.h"
#import "CVExternalOpen.h"
#import "CVAPI.h"
#import "CVCache.h"
#import "CVCommon.h"

@interface CVEpisodeDetailViewController ()
@property (nonatomic, strong) CVEpisode *episode;
@property (nonatomic, strong) CVClip *clip;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *bannerView;
@property (nonatomic, strong) UIButton *playOverlayButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIView *badgesView;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *restartButton;
@property (nonatomic, strong) UIButton *favoriteButton;
@property (nonatomic, strong) UIButton *webButton;
@property (nonatomic, strong) UIButton *prevEpisodeButton;
@property (nonatomic, strong) UIButton *nextEpisodeButton;
@property (nonatomic, strong) CVEpisode *prevEpisode;
@property (nonatomic, strong) CVEpisode *nextEpisode;
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

    // Badges row
    self.badgesView = [[UIView alloc] init];
    self.badgesView.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.badgesView];

    // Action buttons
    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.playButton addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];
    self.playButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.playButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [self.playButton setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.6] forState:UIControlStateNormal];
    [self.playButton setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.8] forState:UIControlStateHighlighted];
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

    self.prevEpisodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.prevEpisodeButton addTarget:self action:@selector(prevEpisodeTapped) forControlEvents:UIControlEventTouchUpInside];
    self.prevEpisodeButton.titleLabel.font = [UIFont systemFontOfSize:13];
    self.prevEpisodeButton.hidden = YES;
    [self.scrollView addSubview:self.prevEpisodeButton];

    self.nextEpisodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.nextEpisodeButton addTarget:self action:@selector(nextEpisodeTapped) forControlEvents:UIControlEventTouchUpInside];
    self.nextEpisodeButton.titleLabel.font = [UIFont systemFontOfSize:13];
    self.nextEpisodeButton.hidden = YES;
    [self.scrollView addSubview:self.nextEpisodeButton];

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

    [self.prevEpisodeButton setBackgroundImage:[theme buttonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.prevEpisodeButton setBackgroundImage:[theme buttonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.prevEpisodeButton setTitleColor:[theme primaryTextColor] forState:UIControlStateNormal];

    [self.nextEpisodeButton setBackgroundImage:[theme buttonImageHighlighted:NO] forState:UIControlStateNormal];
    [self.nextEpisodeButton setBackgroundImage:[theme buttonImageHighlighted:YES] forState:UIControlStateHighlighted];
    [self.nextEpisodeButton setTitleColor:[theme primaryTextColor] forState:UIControlStateNormal];
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
        [self findAdjacentEpisodes];
    } else if (self.clip) {
        self.titleLabel.text = self.clip.title ?: @"";
        NSString *m = @"";
        if (self.clip.seasonEpisodeString.length) m = self.clip.seasonEpisodeString;
        if (self.clip.durationString.length) {
            if (m.length) m = [m stringByAppendingFormat:@"  •  %@", self.clip.durationString];
            else m = self.clip.durationString;
        }
        if (self.clip.airDate.length) {
            if (m.length) m = [m stringByAppendingFormat:@"  •  %@", self.clip.airDate];
            else m = self.clip.airDate;
        }
        self.metaLabel.text = m;
        self.summaryTextView.text = self.clip.summary ?: @"";
        thumb = self.clip.thumbURL;
        self.favoriteButton.hidden = YES;
        self.prevEpisodeButton.hidden = YES;
        self.nextEpisodeButton.hidden = YES;
    }

    [self updateBadges];

    self.bannerView.image = [[CVTheme shared] thumbnailPlaceholder];
    if (thumb.length) {
        __weak typeof(self) weakSelf = self;
        [[CVImageLoader shared] loadImageURL:thumb completion:^(UIImage *image, NSError *error) {
            if (image) weakSelf.bannerView.image = image;
        }];
    }
}

- (void)findAdjacentEpisodes
{
    self.prevEpisode = nil;
    self.nextEpisode = nil;
    if (!self.episode || self.episode.seasonNumber <= 0) {
        self.prevEpisodeButton.hidden = YES;
        self.nextEpisodeButton.hidden = YES;
        return;
    }

    NSString *key = [NSString stringWithFormat:@"episodes_season_%ld", (long)self.episode.seasonNumber];
    NSArray *seasonEps = [[CVCache shared] objectForKey:key];
    if (!seasonEps.count) {
        NSArray *catalog = [[CVAPI shared] allCatalogEpisodes];
        NSMutableArray *filtered = [NSMutableArray array];
        for (CVEpisode *ep in catalog) {
            if (ep.seasonNumber == self.episode.seasonNumber) {
                [filtered addObject:ep];
            }
        }
        seasonEps = filtered;
    }

    if (seasonEps.count) {
        NSInteger currentIndex = NSNotFound;
        for (NSInteger i = 0; i < seasonEps.count; i++) {
            CVEpisode *ep = seasonEps[i];
            if ((self.episode.uuid.length && [ep.uuid isEqualToString:self.episode.uuid]) ||
                (ep.episodeNumber == self.episode.episodeNumber)) {
                currentIndex = i;
                break;
            }
        }

        if (currentIndex != NSNotFound) {
            if (currentIndex > 0) {
                self.prevEpisode = seasonEps[currentIndex - 1];
            }
            if (currentIndex + 1 < seasonEps.count) {
                self.nextEpisode = seasonEps[currentIndex + 1];
            }
        }
    }

    if (self.prevEpisode) {
        NSString *code = self.prevEpisode.seasonEpisodeString.length ? self.prevEpisode.seasonEpisodeString : [NSString stringWithFormat:@"E%ld", (long)self.prevEpisode.episodeNumber];
        [self.prevEpisodeButton setTitle:[NSString stringWithFormat:@"◀ %@", code] forState:UIControlStateNormal];
        self.prevEpisodeButton.hidden = NO;
    } else {
        self.prevEpisodeButton.hidden = YES;
    }

    if (self.nextEpisode) {
        NSString *code = self.nextEpisode.seasonEpisodeString.length ? self.nextEpisode.seasonEpisodeString : [NSString stringWithFormat:@"E%ld", (long)self.nextEpisode.episodeNumber];
        [self.nextEpisodeButton setTitle:[NSString stringWithFormat:@"%@ ▶", code] forState:UIControlStateNormal];
        self.nextEpisodeButton.hidden = NO;
    } else {
        self.nextEpisodeButton.hidden = YES;
    }
}

- (void)updateBadges
{
    for (UIView *v in self.badgesView.subviews) {
        [v removeFromSuperview];
    }

    NSMutableArray *badges = [NSMutableArray array];
    if (self.episode) {
        if (self.episode.seasonEpisodeString.length) {
            [badges addObject:self.episode.seasonEpisodeString];
        } else if (self.episode.seasonNumber > 0) {
            [badges addObject:[NSString stringWithFormat:@"S%ld • E%ld", (long)self.episode.seasonNumber, (long)self.episode.episodeNumber]];
        }
        if (self.episode.durationString.length && ![self.episode.durationString isEqualToString:@"00:00"]) {
            [badges addObject:self.episode.durationString];
        }
        [badges addObject:self.episode.rating.length ? self.episode.rating : @"TV-MA"];
        [badges addObject:@"HD"];
        [badges addObject:@"CC"];
    } else if (self.clip) {
        if (self.clip.seasonEpisodeString.length) {
            [badges addObject:self.clip.seasonEpisodeString];
        }
        if (self.clip.durationString.length && ![self.clip.durationString isEqualToString:@"00:00"]) {
            [badges addObject:self.clip.durationString];
        }
        [badges addObject:@"CLIP"];
        [badges addObject:@"HD"];
    }

    CGFloat x = 0;
    for (NSString *text in badges) {
        CGSize s = [text sizeWithFont:[UIFont boldSystemFontOfSize:11]];
        CGFloat badgeW = s.width + 12;
        CGFloat badgeH = 20;

        UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(x, 0, badgeW, badgeH)];
        badge.font = [UIFont boldSystemFontOfSize:10];
        badge.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        badge.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.45];
        badge.layer.cornerRadius = 3.0;
        badge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        badge.layer.borderWidth = 0.5;
        badge.clipsToBounds = YES;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.text = text;
        [self.badgesView addSubview:badge];

        x += badgeW + 6;
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
    y += 22;

    self.badgesView.frame = CGRectMake(14, y, w - 28, 22);
    y += 28;

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

        if (!self.prevEpisodeButton.hidden || !self.nextEpisodeButton.hidden) {
            self.prevEpisodeButton.frame = CGRectMake(14, y, halfW, 34);
            self.nextEpisodeButton.frame = CGRectMake(14 + halfW + 8, y, halfW, 34);
            y += 42;
        }
    } else {
        self.webButton.frame = CGRectMake(14, y, w - 28, 36);
        y += 44;
    }

    CGSize sumSize = [self.summaryTextView sizeThatFits:CGSizeMake(w - 28, CGFLOAT_MAX)];
    self.summaryTextView.frame = CGRectMake(10, y, w - 20, sumSize.height + 20);
    y += sumSize.height + 30;

    self.scrollView.contentSize = CGSizeMake(w, y);
}

- (void)prevEpisodeTapped
{
    if (self.prevEpisode) {
        self.episode = self.prevEpisode;
        self.title = self.episode.title ?: L(@"Episode");
        [self populateData];
        [self updateButtons];
    }
}

- (void)nextEpisodeTapped
{
    if (self.nextEpisode) {
        self.episode = self.nextEpisode;
        self.title = self.episode.title ?: L(@"Episode");
        [self populateData];
        [self updateButtons];
    }
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
