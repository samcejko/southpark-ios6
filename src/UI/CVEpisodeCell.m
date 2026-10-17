#import "CVEpisodeCell.h"
#import "CVTheme.h"
#import "CVImageLoader.h"
#import "CVHistory.h"
#import "CVFavorites.h"
#import "CVCommon.h"

@interface CVEpisodeCell ()
@property (nonatomic, strong) UIImageView *thumbView;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIView *durationPill;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UIImageView *watchedBadge;
@property (nonatomic, strong) UIImageView *favoriteBadge;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, copy) NSString *currentImageURL;
@end

@implementation CVEpisodeCell

+ (NSString *)reuseIdentifier
{
    return @"CVEpisodeCell";
}

+ (CGFloat)heightForWidth:(CGFloat)width
{
    return 88.0;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleGray;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];

        _thumbView = [[UIImageView alloc] init];
        _thumbView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbView.clipsToBounds = YES;
        _thumbView.layer.cornerRadius = 4.0;
        [self.contentView addSubview:_thumbView];

        _durationPill = [[UIView alloc] init];
        _durationPill.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
        _durationPill.layer.cornerRadius = 3.0;
        _durationPill.clipsToBounds = YES;
        [_thumbView addSubview:_durationPill];

        _durationLabel = [[UILabel alloc] init];
        _durationLabel.font = [UIFont boldSystemFontOfSize:10];
        _durationLabel.textColor = [UIColor whiteColor];
        _durationLabel.backgroundColor = [UIColor clearColor];
        [_durationPill addSubview:_durationLabel];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        _titleLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:11];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_subtitleLabel];

        _summaryLabel = [[UILabel alloc] init];
        _summaryLabel.font = [UIFont systemFontOfSize:11];
        _summaryLabel.numberOfLines = 2;
        _summaryLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_summaryLabel];

        _progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressBar.progressTintColor = [[CVTheme shared] accentColor];
        _progressBar.trackTintColor = [UIColor colorWithWhite:0 alpha:0.5];
        [_thumbView addSubview:_progressBar];

        _watchedBadge = [[UIImageView alloc] init];
        _watchedBadge.image = [[CVTheme shared] pillImageWithColor:[UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1]];
        [_thumbView addSubview:_watchedBadge];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.thumbView.image = nil;
    self.currentImageURL = nil;
    self.progressBar.hidden = YES;
    self.watchedBadge.hidden = YES;
    self.alpha = 1.0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;

    // 16:9 thumbnail on the left
    CGFloat thumbH = h - 16;
    CGFloat thumbW = floor(thumbH * (16.0 / 9.0));
    self.thumbView.frame = CGRectMake(10, 8, thumbW, thumbH);

    // Duration pill at bottom right of thumbnail (with clear spacing above progress bar)
    CGSize durSize = [self.durationLabel.text sizeWithFont:self.durationLabel.font];
    CGFloat pillW = durSize.width + 8;
    CGFloat pillH = durSize.height + 4;
    CGFloat pillY = (self.progressBar.hidden) ? (thumbH - pillH - 4) : (thumbH - pillH - 7);
    CGFloat pillX = thumbW - pillW - 4;
    self.durationPill.frame = CGRectMake(pillX, pillY, pillW, pillH);
    self.durationLabel.frame = CGRectMake(4, 2, durSize.width, durSize.height);

    // Progress bar along the very bottom of the thumbnail
    self.progressBar.frame = CGRectMake(0, thumbH - 3, thumbW, 3);

    // Text on the right
    CGFloat textX = CGRectGetMaxX(self.thumbView.frame) + 10;
    CGFloat textW = w - textX - 10;

    self.titleLabel.frame = CGRectMake(textX, 8, textW, 18);
    self.subtitleLabel.frame = CGRectMake(textX, 28, textW, 14);
    self.summaryLabel.frame = CGRectMake(textX, 44, textW, h - 50);
}

- (void)configureWithEpisode:(CVEpisode *)episode
{
    CVTheme *theme = [CVTheme shared];
    self.titleLabel.textColor = [theme primaryTextColor];
    self.subtitleLabel.textColor = [theme secondaryTextColor];
    self.summaryLabel.textColor = [theme secondaryTextColor];

    self.titleLabel.text = episode.title ?: @"Episode";
    self.summaryLabel.text = episode.summary ?: @"";

    NSString *sub = @"";
    if (episode.seasonEpisodeString.length) sub = episode.seasonEpisodeString;
    else if (episode.seasonNumber > 0) sub = [NSString stringWithFormat:@"S%ld • E%ld", (long)episode.seasonNumber, (long)episode.episodeNumber];
    if (episode.airDate.length) sub = [sub stringByAppendingFormat:@"  •  %@", episode.airDate];
    self.subtitleLabel.text = sub;

    self.durationLabel.text = episode.durationString ?: @"";
    self.durationPill.hidden = (episode.durationString.length == 0 || [episode.durationString isEqualToString:@"00:00"]);

    // Resume / Watched status
    NSTimeInterval pos = [[CVHistory shared] positionForUUID:episode.uuid];
    BOOL isWatched = [[CVHistory shared] isWatched:episode.uuid];
    if (isWatched) {
        self.progressBar.hidden = NO;
        self.progressBar.progress = 1.0;
    } else if (pos > 0 && episode.durationSeconds > 0) {
        self.progressBar.hidden = NO;
        self.progressBar.progress = (float)(pos / episode.durationSeconds);
    } else {
        self.progressBar.hidden = YES;
    }
    [self setNeedsLayout];

    if (!episode.available) {
        self.alpha = 0.5;
        self.subtitleLabel.text = [self.subtitleLabel.text stringByAppendingString:@"  (Not Available)"];
    } else {
        self.alpha = 1.0;
    }

    // Load image
    self.thumbView.image = [theme thumbnailPlaceholder];
    if (episode.thumbURL.length) {
        self.currentImageURL = episode.thumbURL;
        __weak typeof(self) weakSelf = self;
        [[CVImageLoader shared] loadImageURL:episode.thumbURL completion:^(UIImage *image, NSError *error) {
            if ([weakSelf.currentImageURL isEqualToString:episode.thumbURL] && image) {
                weakSelf.thumbView.image = image;
            }
        }];
    }
}

- (void)configureWithClip:(CVClip *)clip
{
    CVTheme *theme = [CVTheme shared];
    self.titleLabel.textColor = [theme primaryTextColor];
    self.subtitleLabel.textColor = [theme secondaryTextColor];
    self.summaryLabel.textColor = [theme secondaryTextColor];

    self.titleLabel.text = clip.title ?: @"Clip";
    self.summaryLabel.text = clip.summary ?: @"";
    self.subtitleLabel.text = clip.airDate ?: @"";
    self.durationLabel.text = clip.durationString ?: @"";
    self.durationPill.hidden = (clip.durationString.length == 0 || [clip.durationString isEqualToString:@"00:00"]);
    self.progressBar.hidden = YES;
    self.alpha = 1.0;
    [self setNeedsLayout];

    self.thumbView.image = [theme thumbnailPlaceholder];
    if (clip.thumbURL.length) {
        self.currentImageURL = clip.thumbURL;
        __weak typeof(self) weakSelf = self;
        [[CVImageLoader shared] loadImageURL:clip.thumbURL completion:^(UIImage *image, NSError *error) {
            if ([weakSelf.currentImageURL isEqualToString:clip.thumbURL] && image) {
                weakSelf.thumbView.image = image;
            }
        }];
    }
}

@end
