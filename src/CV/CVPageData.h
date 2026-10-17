#import <Foundation/Foundation.h>
#import "CVModels.h"

@interface CVPageData : NSObject

// Extracts the JSON object stored in `window.__DATA__ = {...}`
+ (NSDictionary *)extractDataFromHTML:(NSString *)html;

// Parses SeasonSelector items into an array of CVSeason
+ (NSArray<CVSeason *> *)seasonsFromPageData:(NSDictionary *)data;

// Parses LineList items containing episodes into an array of CVEpisode
+ (NSArray<CVEpisode *> *)episodesFromPageData:(NSDictionary *)data defaultSeasonNumber:(NSInteger)seasonNumber;

// Parses LineList items containing clips into an array of CVClip
+ (NSArray<CVClip *> *)clipsFromPageData:(NSDictionary *)data;

// Finds the videoServiceUrl template string anywhere in the page tree
+ (NSString *)videoServiceURLFromPageData:(NSDictionary *)data;

// Parses duration "MM:SS" or "HH:MM:SS" into seconds
+ (NSTimeInterval)secondsFromDurationString:(NSString *)durationString;

@end
