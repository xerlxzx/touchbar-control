#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

// Owned and used on one run-loop thread. Only the service handle is cached;
// callers still read properties and enumerate children on every observation.
@interface TBServiceCache : NSObject
- (instancetype)initWithName:(const char *)name matchingClass:(BOOL)matchingClass;
- (io_service_t)copyService; // Caller must IOObjectRelease the returned handle.
- (void)invalidate;
@end
