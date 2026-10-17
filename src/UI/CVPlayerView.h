#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "CVCaptionView.h"
#import "CVModels.h"

@protocol CVPlayerViewDelegate <NSObject>
- (void)playerViewDidTapClose:(id)playerView;
- (void)playerViewDidTapPlayPause:(id)playerView;
- (void)playerView:(id)playerView didSeekToTime:(NSTimeInterval)time;
- (void)playerView:(id)playerView didSkipSeconds:(NSTimeInterval)seconds;
- (void)playerViewDidToggleSubtitles:(id)playerView;
- (void)playerViewDidTapQuality:(id)playerView;
- (void)playerView:(id)playerView didSelectChapter:(CVChapter *)chapter;
@end

@interface CVPlayerView : UIView

@property (nonatomic, weak) id<CVPlayerViewDelegate> delegate;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, readonly) CVCaptionView *captionView;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL subtitlesEnabled;

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle;
- (void)setTime:(NSTimeInterval)current duration:(NSTimeInterval)duration;
- (void)setLoading:(BOOL)loading;
- (void)setChapters:(NSArray<CVChapter *> *)chapters;
- (void)setQualityTitle:(NSString *)qualityTitle;
- (void)toggleControls;

@end
