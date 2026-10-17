// Shared macros and constants. Everything here must be iOS 6.0 safe.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Any API newer than the iOS 6.0 deployment target is a hard error in files that include this header.
#pragma clang diagnostic error "-Wunguarded-availability"

#define L(key) NSLocalizedString((key), nil)
#define CVIsPad() (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define CVLog(fmt, ...) NSLog((@"[CityVOD] " fmt), ##__VA_ARGS__)

// Runs a block on the main thread (immediately if already there).
static inline void CVMain(dispatch_block_t block)
{
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

extern NSString * const CVErrorDomain;
extern NSString * const CVThemeDidChangeNotification;
extern NSString * const CVSettingsDidChangeNotification;
extern NSString * const CVFavoritesDidChangeNotification;

// NSError codes in CVErrorDomain (HTTP errors use the HTTP status as code)
enum {
    CVErrorNetwork        = -1,
    CVErrorTLS            = -2,
    CVErrorCertificate    = -3,
    CVErrorTimeout        = -4,
    CVErrorCancelled      = -5,
    CVErrorBadResponse    = -6,
    CVErrorDNS            = -7,
    CVErrorConnect        = -8,
    CVErrorConnectionLost = -9,
    CVErrorAPI            = -10,   // Kick answered, but with an error
    CVErrorOffline        = -11,   // the channel is not live
    CVErrorRestricted     = -12,   // subscribers only, geoblocked...
};

NSError *CVMakeError(NSInteger code, NSString *message);
#define KCMakeError CVMakeError
#define KCDict CVDict

// JSON values as the type the caller expects, nil/0 for anything else (NSNull, wrong type)
NSString *CVStr(id value);         // numbers become their decimal string
NSDictionary *CVDict(id value);
NSArray *CVArr(id value);
NSInteger CVInt(id value);
double CVDbl(id value);
BOOL CVBool(id value);

// "2026-10-02T17:31:00Z", "2026-10-02T17:31:05.042684Z", "2026-10-02 17:31:00" (all read as UTC)
NSDate *CVDateFromISO(NSString *string);
