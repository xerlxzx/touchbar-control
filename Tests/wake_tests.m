// Test the private API boundary with ordinary objects; no device/framework is loaded.
#import "TBWakeRequest.h"
#include <math.h>

static NSUInteger assertions;
#define CHECK(condition) do { \
    assertions++; \
    if (!(condition)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); exit(1); } \
} while (0)

@interface FakeWakeClient : NSObject
@property(nonatomic) NSUInteger defaultCalls;
@property(nonatomic) NSUInteger timedCalls;
@property(nonatomic) float period;
@property(nonatomic) BOOL rejects;
@property(nonatomic) BOOL throws;
@end
@implementation FakeWakeClient
- (BOOL)turnOn { self.defaultCalls++; return YES; }
- (BOOL)turnOnWithPeriod:(float)period {
    self.timedCalls++;
    self.period = period;
    if (self.throws) [NSException raise:@"TestWakeError" format:@"Unavailable"];
    return !self.rejects;
}
@end

@interface LegacyWakeClient : NSObject
@property(nonatomic) NSUInteger defaultCalls;
@end
@implementation LegacyWakeClient
- (BOOL)turnOn { self.defaultCalls++; return YES; }
@end

// An OS signature change must not be invoked with the old ABI.
@interface ChangedArgumentClient : NSObject
@property(nonatomic) NSUInteger calls;
@end
@implementation ChangedArgumentClient
- (BOOL)turnOnWithPeriod:(double)period { (void)period; self.calls++; return YES; }
@end

@interface ChangedReturnClient : NSObject
@property(nonatomic) NSUInteger calls;
@end
@implementation ChangedReturnClient
- (id)turnOnWithPeriod:(float)period { (void)period; self.calls++; return @YES; }
@end

int main(void) {
    @autoreleasepool {
        FakeWakeClient *client = [FakeWakeClient new];
        client.period = NAN;
        CHECK(TBRequestWake(client));
        CHECK(client.timedCalls == 1 && client.period == 0.0f && client.defaultCalls == 0);
        client.rejects = YES;
        CHECK(!TBRequestWake(client));
        CHECK(client.timedCalls == 2 && client.defaultCalls == 0);
        client.throws = YES;
        CHECK(!TBRequestWake(client));
        CHECK(client.timedCalls == 3 && client.defaultCalls == 0);

        LegacyWakeClient *legacy = [LegacyWakeClient new];
        CHECK(!TBRequestWake(legacy));
        CHECK(legacy.defaultCalls == 0); // Do not silently restore the half-second fade.
        ChangedArgumentClient *argument = [ChangedArgumentClient new];
        CHECK(!TBRequestWake(argument) && argument.calls == 0);
        ChangedReturnClient *result = [ChangedReturnClient new];
        CHECK(!TBRequestWake(result) && result.calls == 0);
        CHECK(!TBRequestWake(nil));
        CHECK(!TBRequestWake([NSObject new]));
        printf("PASS: %lu wake API assertions. No device provider or private framework linked.\n", (unsigned long)assertions);
    }
    return 0;
}
