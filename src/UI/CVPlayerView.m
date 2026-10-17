#import "CVPlayerView.h"
#import "CVTheme.h"
#import "CVCommon.h"

@interface CVPlayerView ()
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, strong) UIView *centerBar;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *skipBackButton;
@property (nonatomic, strong) UIButton *skipForwardButton;

@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UISlider *scrubber;
@property (nonatomic, strong) UILabel *remainingLabel;
@property (nonatomic, strong) UIButton *ccButton;
@property (nonatomic, strong) UIButton *qualityButton;

@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSTimer *hideTimer;
@property (nonatomic, assign) BOOL controlsVisible;
@property (nonatomic, assign) BOOL isScrubbing;
@property (nonatomic, assign) NSTimeInterval totalDuration;
@property (nonatomic, strong) NSArray<CVChapter *> *chaptersList;
@end

@implementation CVPlayerView

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)playerLayer
{
    return (AVPlayerLayer *)self.layer;
}

- (void)setPlayer:(AVPlayer *)player
{
    _player = player;
    self.playerLayer.player = player;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;

        _controlsVisible = YES;

        // Subtitles view
        _captionView = [[CVCaptionView alloc] initWithFrame:self.bounds];
        _captionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_captionView];

        // Top bar
        _topBar = [[UIView alloc] init];
        _topBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.65];
        [self addSubview:_topBar];

        _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_closeButton setImage:[[CVTheme shared] closeIconWhite] forState:UIControlStateNormal];
        [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [_topBar addSubview:_closeButton];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.backgroundColor = [UIColor clearColor];
        [_topBar addSubview:_titleLabel];

        // Center controls
        _centerBar = [[UIView alloc] init];
        _centerBar.backgroundColor = [UIColor clearColor];
        [self addSubview:_centerBar];

        _skipBackButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_skipBackButton setImage:[[CVTheme shared] skipIconForward:NO] forState:UIControlStateNormal];
        [_skipBackButton addTarget:self action:@selector(skipBackTapped) forControlEvents:UIControlEventTouchUpInside];
        [_centerBar addSubview:_skipBackButton];

        _playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_playPauseButton setImage:[[CVTheme shared] playIcon] forState:UIControlStateNormal];
        [_playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
        [_centerBar addSubview:_playPauseButton];

        _skipForwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_skipForwardButton setImage:[[CVTheme shared] skipIconForward:YES] forState:UIControlStateNormal];
        [_skipForwardButton addTarget:self action:@selector(skipForwardTapped) forControlEvents:UIControlEventTouchUpInside];
        [_centerBar addSubview:_skipForwardButton];

        // Bottom bar
        _bottomBar = [[UIView alloc] init];
        _bottomBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.65];
        [self addSubview:_bottomBar];

        _elapsedLabel = [[UILabel alloc] init];
        _elapsedLabel.font = [UIFont systemFontOfSize:11];
        _elapsedLabel.textColor = [UIColor whiteColor];
        _elapsedLabel.backgroundColor = [UIColor clearColor];
        _elapsedLabel.textAlignment = NSTextAlignmentRight;
        _elapsedLabel.text = @"00:00";
        [_bottomBar addSubview:_elapsedLabel];

        _scrubber = [[UISlider alloc] init];
        _scrubber.minimumValue = 0;
        _scrubber.maximumValue = 1;
        _scrubber.value = 0;
        _scrubber.minimumTrackTintColor = [[CVTheme shared] accentColor];
        [_scrubber addTarget:self action:@selector(scrubberChanged:) forControlEvents:UIControlEventValueChanged];
        [_scrubber addTarget:self action:@selector(scrubberEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [_bottomBar addSubview:_scrubber];

        _remainingLabel = [[UILabel alloc] init];
        _remainingLabel.font = [UIFont systemFontOfSize:11];
        _remainingLabel.textColor = [UIColor whiteColor];
        _remainingLabel.backgroundColor = [UIColor clearColor];
        _remainingLabel.text = @"00:00";
        [_bottomBar addSubview:_remainingLabel];

        _ccButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_ccButton setTitle:@"CC" forState:UIControlStateNormal];
        _ccButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        _ccButton.titleLabel.backgroundColor = [UIColor clearColor];
        [_ccButton setTitleColor:[UIColor colorWithWhite:1 alpha:0.5] forState:UIControlStateNormal];
        [_ccButton addTarget:self action:@selector(ccTapped) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_ccButton];

        _qualityButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_qualityButton setTitle:@"Auto" forState:UIControlStateNormal];
        _qualityButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        _qualityButton.titleLabel.backgroundColor = [UIColor clearColor];
        [_qualityButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_qualityButton addTarget:self action:@selector(qualityTapped) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_qualityButton];

        // Spinner
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _spinner.hidesWhenStopped = YES;
        [self addSubview:_spinner];

        // Tap gesture to toggle controls
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControls)];
        [self addGestureRecognizer:tap];

        [self resetHideTimer];
    }
    return self;
}

- (void)dealloc
{
    [self.hideTimer invalidate];
}

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    if (subtitle.length) {
        self.titleLabel.text = [NSString stringWithFormat:@"%@  •  %@", title, subtitle];
    } else {
        self.titleLabel.text = title ?: @"";
    }
}

- (void)setLoading:(BOOL)loading
{
    if (loading) [self.spinner startAnimating];
    else [self.spinner stopAnimating];
}

- (void)setIsPlaying:(BOOL)isPlaying
{
    _isPlaying = isPlaying;
    UIImage *img = isPlaying ? [[CVTheme shared] pauseIcon] : [[CVTheme shared] playIcon];
    [self.playPauseButton setImage:img forState:UIControlStateNormal];
}

- (void)setSubtitlesEnabled:(BOOL)subtitlesEnabled
{
    _subtitlesEnabled = subtitlesEnabled;
    UIColor *c = subtitlesEnabled ? [[CVTheme shared] accentColor] : [UIColor colorWithWhite:1 alpha:0.5];
    [self.ccButton setTitleColor:c forState:UIControlStateNormal];
}

- (void)setQualityTitle:(NSString *)qualityTitle
{
    [self.qualityButton setTitle:qualityTitle ?: @"Auto" forState:UIControlStateNormal];
}

- (void)setChapters:(NSArray<CVChapter *> *)chapters
{
    self.chaptersList = chapters;
}

- (void)setTime:(NSTimeInterval)current duration:(NSTimeInterval)duration
{
    self.totalDuration = duration;
    if (!self.isScrubbing) {
        if (duration > 0) {
            self.scrubber.value = (float)(current / duration);
        } else {
            self.scrubber.value = 0;
        }

        NSInteger curM = (NSInteger)(current / 60);
        NSInteger curS = (NSInteger)(current - curM * 60);
        self.elapsedLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)curM, (long)curS];

        NSTimeInterval rem = duration - current;
        if (rem < 0) rem = 0;
        NSInteger remM = (NSInteger)(rem / 60);
        NSInteger remS = (NSInteger)(rem - remM * 60);
        self.remainingLabel.text = [NSString stringWithFormat:@"-%02ld:%02ld", (long)remM, (long)remS];
    }
}

- (void)toggleControls
{
    self.controlsVisible = !self.controlsVisible;
    [UIView animateWithDuration:0.25 animations:^{
        CGFloat alpha = self.controlsVisible ? 1.0 : 0.0;
        self.topBar.alpha = alpha;
        self.centerBar.alpha = alpha;
        self.bottomBar.alpha = alpha;
    }];

    if (self.controlsVisible) {
        [self resetHideTimer];
    } else {
        [self.hideTimer invalidate];
        self.hideTimer = nil;
    }
}

- (void)resetHideTimer
{
    [self.hideTimer invalidate];
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:4.5 target:self selector:@selector(hideControls) userInfo:nil repeats:NO];
}

- (void)hideControls
{
    if (self.controlsVisible && self.isPlaying && !self.isScrubbing) {
        [self toggleControls];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    self.spinner.center = CGPointMake(w / 2.0, h / 2.0);

    // Top bar: height 44
    self.topBar.frame = CGRectMake(0, 0, w, 44);
    self.closeButton.frame = CGRectMake(10, 4, 36, 36);
    self.titleLabel.frame = CGRectMake(54, 10, w - 64, 24);

    // Center bar: 220 x 60 centered
    self.centerBar.frame = CGRectMake((w - 220) / 2.0, (h - 60) / 2.0, 220, 60);
    self.skipBackButton.frame = CGRectMake(10, 8, 44, 44);
    self.playPauseButton.frame = CGRectMake(88, 8, 44, 44);
    self.skipForwardButton.frame = CGRectMake(166, 8, 44, 44);

    // Bottom bar: fixed height 54
    self.bottomBar.frame = CGRectMake(0, h - 54, w, 54);

    // Scrubber row
    self.elapsedLabel.frame = CGRectMake(10, 14, 46, 20);
    self.scrubber.frame = CGRectMake(60, 12, w - 195, 24);
    self.remainingLabel.frame = CGRectMake(w - 130, 14, 46, 20);
    self.ccButton.frame = CGRectMake(w - 80, 8, 32, 32);
    self.qualityButton.frame = CGRectMake(w - 44, 8, 38, 32);
}

#pragma mark - Actions

- (void)closeTapped
{
    [self.delegate playerViewDidTapClose:self];
}

- (void)playPauseTapped
{
    [self.delegate playerViewDidTapPlayPause:self];
    [self resetHideTimer];
}

- (void)skipBackTapped
{
    [self.delegate playerView:self didSkipSeconds:-15];
    [self resetHideTimer];
}

- (void)skipForwardTapped
{
    [self.delegate playerView:self didSkipSeconds:15];
    [self resetHideTimer];
}

- (void)ccTapped
{
    [self.delegate playerViewDidToggleSubtitles:self];
    [self resetHideTimer];
}

- (void)qualityTapped
{
    [self.delegate playerViewDidTapQuality:self];
    [self resetHideTimer];
}


- (void)scrubberChanged:(UISlider *)sender
{
    self.isScrubbing = YES;
    NSTimeInterval seekTime = sender.value * self.totalDuration;
    NSInteger m = (NSInteger)(seekTime / 60);
    NSInteger s = (NSInteger)(seekTime - m * 60);
    self.elapsedLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)m, (long)s];
    [self resetHideTimer];
}

- (void)scrubberEnded:(UISlider *)sender
{
    NSTimeInterval targetTime = sender.value * self.totalDuration;
    self.isScrubbing = NO;
    [self.delegate playerView:self didSeekToTime:targetTime];
    [self resetHideTimer];
}

@end
