#import <Foundation/Foundation.h>

// Isolates the private wake selector so its arguments can be tested without hardware.
FOUNDATION_EXPORT BOOL TBSupportsImmediateWake(id client);
FOUNDATION_EXPORT BOOL TBRequestWake(id client);
