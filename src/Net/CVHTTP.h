#import <Foundation/Foundation.h>

typedef void (^CVHTTPCompletion)(NSInteger status, NSData *body, NSDictionary *headers, NSError *error);
typedef void (^CVJSONCompletion)(id json, NSInteger status, NSError *error);

// A running request of CVHTTP. After -cancel the completion block is never called.
@interface CVHTTPTask : NSObject
@property (atomic, readonly) BOOL isCancelled;
@property (atomic, copy) dispatch_block_t cancelBlock;   // for chained requests: called by -cancel (once)
- (void)cancel;
@end

// Convenience layer over CVHTTPRequest for API calls: redirects are followed, GET requests are tried a second
// time after a network error, completion blocks run on the main thread.
@interface CVHTTP : NSObject

+ (CVHTTPTask *)request:(NSString *)method url:(NSString *)url headers:(NSDictionary *)headers body:(NSData *)body
                retries:(NSInteger)retries completion:(CVHTTPCompletion)completion;

+ (CVHTTPTask *)get:(NSString *)url headers:(NSDictionary *)headers completion:(CVHTTPCompletion)completion;

// JSON answers. `error` is set for network errors, for statuses >= 400 (code = the status, message from the body
// when it has one) and for bodies that are not JSON; `json` is passed even with an error when the body parsed.
+ (CVHTTPTask *)getJSON:(NSString *)url headers:(NSDictionary *)headers completion:(CVJSONCompletion)completion;
+ (CVHTTPTask *)postJSON:(NSString *)url headers:(NSDictionary *)headers object:(id)object retries:(NSInteger)retries
              completion:(CVJSONCompletion)completion;
+ (CVHTTPTask *)postForm:(NSString *)url fields:(NSDictionary *)fields completion:(CVJSONCompletion)completion;

@end
