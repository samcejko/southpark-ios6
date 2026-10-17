#import <Foundation/Foundation.h>

@interface CVCue : NSObject
@property (nonatomic) NSTimeInterval start;
@property (nonatomic) NSTimeInterval end;
@property (nonatomic, copy) NSString *text;
@end

@interface CVSubtitles : NSObject
@property (nonatomic, strong, readonly) NSArray<CVCue *> *cues;

+ (void)loadFromURL:(NSURL *)playlistURL completion:(void (^)(CVSubtitles *subtitles, NSError *error))completion;
- (NSString *)textAtTime:(NSTimeInterval)time;

@end
