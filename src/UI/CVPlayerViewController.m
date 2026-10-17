#import "CVPlayerViewController.h"
#import "CVPlayerView.h"
#import "CVPlayback.h"
#import "CVAPI.h"
#import "CVSubtitles.h"
#import "CVHistory.h"
#import "CVSettings.h"
#import "CVMediaProxy.h"
#import "CVCommon.h"
#import <MediaPlayer/MediaPlayer.h>

@interface CVPlayerViewController () <CVPlayerViewDelegate, UIActionSheetDelegate>
@property (nonatomic, copy) NSString *urlPath;
@property (nonatomic, copy) NSString *itemUUID;
@property (nonatomic, copy) NSString *itemTitle;
@property (nonatomic, copy) NSString *itemSubtitle;
@property (nonatomic) NSTimeInterval initialResumePosition;
@property (nonatomic, strong) CVEpisode *episode;

@property (nonatomic, strong) CVPlayerView *playerView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) CVStream *currentStream;
@property (nonatomic, strong) CVSubtitles *subtitles;
@property (nonatomic, strong) NSArray<CVVariant *> *variants;
@property (nonatomic, copy) NSString *selectedQuality;
@property (nonatomic, assign) BOOL subtitlesEnabled;
@property (nonatomic, assign) BOOL hasSeekedToResume;
@property (nonatomic, strong) CVHTTPTask *streamTask;
@end

@implementation CVPlayerViewController

- (id)initWithItemURL:(NSString *)urlPath itemUUID:(NSString *)uuid title:(NSString *)title subtitle:(NSString *)subtitle resumePosition:(NSTimeInterval)resumePos episode:(CVEpisode *)episode
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _urlPath = [urlPath copy];
        _itemUUID = [uuid copy];
        _itemTitle = [title copy];
        _itemSubtitle = [subtitle copy];
        _initialResumePosition = resumePos;
        _episode = episode;
        _selectedQuality = [CVSettings preferredQuality] ?: @"auto";
        _subtitlesEnabled = [CVSettings subtitlesEnabled];
    }
    return self;
}

- (void)dealloc
{
    [self cleanupPlayer];
    [_streamTask cancel];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    self.playerView = [[CVPlayerView alloc] initWithFrame:self.view.bounds];
    self.playerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.playerView.delegate = self;
    [self.playerView setTitle:self.itemTitle subtitle:self.itemSubtitle];
    self.playerView.subtitlesEnabled = self.subtitlesEnabled;
    [self.view addSubview:self.playerView];

    // Audio session for background playback
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:NULL];
    [[AVAudioSession sharedInstance] setActive:YES error:NULL];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

    [self resolveAndPlay];
}

- (void)resolveAndPlay
{
    [self.playerView setLoading:YES];
    __weak typeof(self) weakSelf = self;
    self.streamTask = [[CVAPI shared] resolveStreamForItemURL:self.urlPath itemUUID:self.itemUUID completion:^(CVStream *stream, NSError *error) {
        if (error || !stream.masterURL) {
            [weakSelf.playerView setLoading:NO];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:L(@"Playback Error")
                                                           message:error.localizedDescription ?: L(@"Could not resolve video stream.")
                                                          delegate:nil
                                                 cancelButtonTitle:L(@"OK")
                                                 otherButtonTitles:nil];
            [alert show];
            return;
        }

        weakSelf.currentStream = stream;
        [weakSelf.playerView setChapters:stream.chapters];
        [weakSelf setupPlayerWithStream:stream];
    }];
}

- (void)setupPlayerWithStream:(CVStream *)stream
{
    // Fetch master playlist text to parse variants and subtitle URL
    __weak typeof(self) weakSelf = self;
    [CVHTTP get:stream.masterURL.absoluteString headers:@{ @"Referer": @"https://www.southparkstudios.com/" } completion:^(NSInteger status, NSData *body, NSDictionary *headers, NSError *error) {
        if (body.length && status < 400) {
            NSString *m3u8Text = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            NSURL *subURL = nil;
            NSArray *audioRends = nil;
            weakSelf.variants = [CVPlayback variantsFromMaster:m3u8Text baseURL:stream.masterURL audioRenditions:&audioRends subtitleURL:&subURL];
            stream.subtitleURL = subURL;

            // Load subtitles if available
            if (subURL) {
                [CVSubtitles loadFromURL:subURL completion:^(CVSubtitles *subtitles, NSError *subErr) {
                    weakSelf.subtitles = subtitles;
                }];
            }
        }

        // Start playback through proxy
        NSURL *proxyURL = [CVPlayback playerURLForStream:stream quality:weakSelf.selectedQuality chosen:NULL];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf startAVPlayerWithURL:proxyURL];
        });
    }];
}

- (void)startAVPlayerWithURL:(NSURL *)proxyURL
{
    if (self.player) {
        [self cleanupPlayer];
    }

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:proxyURL];
    self.player = [AVPlayer playerWithPlayerItem:item];
    self.playerView.player = self.player;

    // Observe time
    __weak typeof(self) weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        NSTimeInterval cur = CMTimeGetSeconds(time);
        NSTimeInterval dur = weakSelf.currentStream.durationSeconds;
        if (dur <= 0) {
            CMTime itemDur = weakSelf.player.currentItem.duration;
            if (CMTIME_IS_VALID(itemDur)) dur = CMTimeGetSeconds(itemDur);
        }

        [weakSelf.playerView setTime:cur duration:dur];

        // Seek to resume position on first valid time
        if (!weakSelf.hasSeekedToResume && weakSelf.initialResumePosition > 10 && dur > 30) {
            weakSelf.hasSeekedToResume = YES;
            [weakSelf.player seekToTime:CMTimeMakeWithSeconds(weakSelf.initialResumePosition, 1)];
        }

        // Update subtitles
        if (weakSelf.subtitlesEnabled && weakSelf.subtitles) {
            NSString *cueText = [weakSelf.subtitles textAtTime:cur];
            [weakSelf.playerView.captionView setText:cueText];
        } else {
            [weakSelf.playerView.captionView setText:@""];
        }

        // Save progress to history
        if (weakSelf.episode && cur > 5 && dur > 0) {
            [[CVHistory shared] saveProgress:cur duration:dur forEpisode:weakSelf.episode];
        }

        // Check if token needs refresh (< 30s before expiry)
        if (weakSelf.currentStream.expiresAt && [weakSelf.currentStream.expiresAt timeIntervalSinceNow] < 30) {
            [weakSelf refreshToken];
        }
    }];

    [self.playerView setLoading:NO];
    [self.player play];
    self.playerView.isPlaying = YES;
    [self updateNowPlaying];
}

- (void)refreshToken
{
    // Re-resolve stream in background to update media proxy upstream credentials
    [[CVAPI shared] resolveStreamForItemURL:self.urlPath itemUUID:self.itemUUID completion:^(CVStream *freshStream, NSError *error) {
        if (freshStream.expiresAt) {
            self.currentStream = freshStream;
        }
    }];
}

- (void)updateNowPlaying
{
    if (NSClassFromString(@"MPNowPlayingInfoCenter")) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[MPMediaItemPropertyTitle] = self.itemTitle ?: @"South Park";
        info[MPMediaItemPropertyArtist] = @"South Park";
        if (self.currentStream.durationSeconds > 0) {
            info[MPMediaItemPropertyPlaybackDuration] = @(self.currentStream.durationSeconds);
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(CMTimeGetSeconds(self.player.currentTime));
        info[MPNowPlayingInfoPropertyPlaybackRate] = @(self.playerView.isPlaying ? 1.0 : 0.0);
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    }
}

- (void)cleanupPlayer
{
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    [self.player pause];
    self.player = nil;
    self.playerView.player = nil;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark - CVPlayerViewDelegate

- (void)playerViewDidTapClose:(id)playerView
{
    // Save current progress before closing
    if (self.episode && self.player) {
        NSTimeInterval cur = CMTimeGetSeconds(self.player.currentTime);
        NSTimeInterval dur = self.currentStream.durationSeconds;
        [[CVHistory shared] saveProgress:cur duration:dur forEpisode:self.episode];
    }
    [self cleanupPlayer];
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)playerViewDidTapPlayPause:(id)playerView
{
    if (self.playerView.isPlaying) {
        [self.player pause];
        self.playerView.isPlaying = NO;
    } else {
        [self.player play];
        self.playerView.isPlaying = YES;
    }
    [self updateNowPlaying];
}

- (void)playerView:(id)playerView didSeekToTime:(NSTimeInterval)time
{
    if (self.player) {
        [self.player seekToTime:CMTimeMakeWithSeconds(time, 1)];
        [self updateNowPlaying];
    }
}

- (void)playerView:(id)playerView didSkipSeconds:(NSTimeInterval)seconds
{
    if (self.player) {
        NSTimeInterval cur = CMTimeGetSeconds(self.player.currentTime);
        NSTimeInterval target = cur + seconds;
        if (target < 0) target = 0;
        if (self.currentStream.durationSeconds > 0 && target > self.currentStream.durationSeconds) {
            target = self.currentStream.durationSeconds;
        }
        [self.player seekToTime:CMTimeMakeWithSeconds(target, 1)];
        [self updateNowPlaying];
    }
}

- (void)playerViewDidToggleSubtitles:(id)playerView
{
    self.subtitlesEnabled = !self.subtitlesEnabled;
    self.playerView.subtitlesEnabled = self.subtitlesEnabled;
    [CVSettings setBool:self.subtitlesEnabled forKey:@"subtitlesEnabled"];
}

- (void)playerView:(id)playerView didSelectChapter:(CVChapter *)chapter
{
    if (chapter && self.player) {
        [self.player seekToTime:CMTimeMakeWithSeconds(chapter.streamOffsetSeconds, 1)];
        [self updateNowPlaying];
    }
}

- (void)playerViewDidTapQuality:(id)playerView
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:L(@"Video Quality")
                                                       delegate:self
                                              cancelButtonTitle:L(@"Cancel")
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:L(@"Auto"), nil];

    for (CVVariant *v in self.variants) {
        if ([CVPlayback deviceCanPlay:v]) {
            [sheet addButtonWithTitle:v.title];
        }
    }
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) return;

    NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
    if ([title isEqualToString:L(@"Auto")]) {
        self.selectedQuality = @"auto";
        [self.playerView setQualityTitle:@"Auto"];
    } else {
        self.selectedQuality = title;
        [self.playerView setQualityTitle:title];
    }
}

@end
