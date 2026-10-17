#import <Foundation/Foundation.h>
#import "CVModels.h"

extern NSString * const CVHistoryDidChangeNotification;

@interface CVHistoryEntry : NSObject <NSCoding>
@property (nonatomic, strong) CVEpisode *episode;
@property (nonatomic) NSTimeInterval position;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, strong) NSDate *lastWatched;
@property (nonatomic, readonly) BOOL isCompleted; // > 92%
@property (nonatomic, readonly) double progressFraction;
@end

@interface CVHistory : NSObject

+ (instancetype)shared;

- (NSTimeInterval)positionForUUID:(NSString *)uuid;
- (BOOL)isWatched:(NSString *)uuid;
- (void)saveProgress:(NSTimeInterval)position duration:(NSTimeInterval)duration forEpisode:(CVEpisode *)episode;
- (NSArray<CVHistoryEntry *> *)recentEntries;
- (void)removeEntryForUUID:(NSString *)uuid;
- (void)clearHistory;

@end
