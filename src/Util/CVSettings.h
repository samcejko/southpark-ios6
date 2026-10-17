#import <Foundation/Foundation.h>

// Quality preference values (also what the quality menu of the player stores)
extern NSString * const CVQualityAuto;      // the player switches between what the device can decode
extern NSString * const CVQualitySource;
extern NSString * const CVQualityAudio;     // audio only
// ...and "1080", "720", "480", "360", "160": the highest rendition that is not above this height

// User preferences, kept in NSUserDefaults. Setters post CVSettingsDidChangeNotification.
@interface CVSettings : NSObject

+ (void)registerDefaults;
+ (void)save;

// Appearance
+ (BOOL)darkTheme;
+ (void)setDarkTheme:(BOOL)value;

// Playback
+ (NSString *)preferredQuality;
+ (void)setPreferredQuality:(NSString *)value;
+ (BOOL)backgroundAudio;            // keep the sound playing when the app goes to the background
+ (void)setBackgroundAudio:(BOOL)value;
+ (BOOL)keepScreenOn;               // no auto-lock while a video plays
+ (void)setKeepScreenOn:(BOOL)value;
+ (BOOL)autoPlayNext;               // automatically play next episode when current ends
+ (void)setAutoPlayNext:(BOOL)value;
+ (BOOL)subtitlesEnabled;           // show subtitles by default
+ (void)setSubtitlesEnabled:(BOOL)value;
+ (NSString *)audioLanguage;        // "en", "es"
+ (void)setAudioLanguage:(NSString *)value;
+ (NSString *)appLanguage;          // "", "en", "cs"
+ (void)setAppLanguage:(NSString *)value;

// Browsing
+ (NSString *)streamLanguage;       // "" = every language, else a lower case ISO 639-1 code ("cs")
+ (void)setStreamLanguage:(NSString *)value;

// Chat
+ (NSInteger)chatFontSize;          // 0 small, 1 medium, 2 large
+ (void)setChatFontSize:(NSInteger)value;
+ (BOOL)chatTimestamps;
+ (void)setChatTimestamps:(BOOL)value;
+ (BOOL)animatedEmotes;
+ (void)setAnimatedEmotes:(BOOL)value;
+ (BOOL)thirdPartyEmotes;           // 7TV (the emotes many Kick channels add on top of Kick's own)
+ (void)setThirdPartyEmotes:(BOOL)value;
+ (BOOL)showDeletedMessages;        // keep the text of messages a moderator removed (greyed out)
+ (void)setShowDeletedMessages:(BOOL)value;
+ (BOOL)chatSeparators;             // a line between messages
+ (void)setChatSeparators:(BOOL)value;

// Network
+ (BOOL)verifyTLS;
+ (void)setVerifyTLS:(BOOL)value;

// Resume positions of videos: seconds by video id (the last 200 are kept)
+ (NSTimeInterval)resumePositionForVideo:(NSString *)videoId;
+ (void)setResumePosition:(NSTimeInterval)seconds forVideo:(NSString *)videoId;

// Search history (most recent first, 12 kept)
+ (NSArray *)recentSearches;
+ (void)addRecentSearch:(NSString *)query;
+ (void)clearRecentSearches;

@end
