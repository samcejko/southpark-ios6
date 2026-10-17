#import <Foundation/Foundation.h>

@interface CVSeason : NSObject <NSCoding>
@property (nonatomic) NSInteger seasonNumber;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *urlPath;
@property (nonatomic) NSInteger episodeCount;

+ (instancetype)seasonWithNumber:(NSInteger)number label:(NSString *)label urlPath:(NSString *)urlPath;
@end

@interface CVEpisode : NSObject <NSCoding>
@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, copy) NSString *mgid;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic) NSInteger seasonNumber;
@property (nonatomic) NSInteger episodeNumber;
@property (nonatomic, copy) NSString *seasonEpisodeString; // e.g. "S2 • E1"
@property (nonatomic, copy) NSString *airDate;
@property (nonatomic, copy) NSString *durationString;       // e.g. "22:00"
@property (nonatomic) NSTimeInterval durationSeconds;
@property (nonatomic, copy) NSString *thumbURL;
@property (nonatomic, copy) NSString *urlPath;
@property (nonatomic) BOOL available;
@property (nonatomic, copy) NSString *rating;
@end

@interface CVClip : NSObject <NSCoding>
@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *airDate;
@property (nonatomic, copy) NSString *durationString;
@property (nonatomic) NSTimeInterval durationSeconds;
@property (nonatomic, copy) NSString *thumbURL;
@property (nonatomic, copy) NSString *urlPath;
@end

@interface CVChapter : NSObject <NSCoding>
@property (nonatomic) NSInteger sequence;
@property (nonatomic, copy) NSString *chapterId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSTimeInterval streamOffsetSeconds;
@property (nonatomic) NSTimeInterval durationSeconds;
@end

@interface CVStream : NSObject
@property (nonatomic, strong) NSURL *masterURL;
@property (nonatomic) NSTimeInterval durationSeconds;
@property (nonatomic, strong) NSArray *chapters;            // CVChapter
@property (nonatomic, strong) NSDate *expiresAt;
@property (nonatomic, strong) NSArray *audioTracks;
@property (nonatomic, strong) NSURL *subtitleURL;
@property (nonatomic, copy) NSString *itemUUID;
@end
