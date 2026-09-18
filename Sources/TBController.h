#import "TBHardware.h"

@interface TBController : NSObject
@property(nonatomic, readonly) BOOL requestedOff;
@property(nonatomic, readonly) BOOL holdingOff;
@property(nonatomic, readonly) BOOL idleOff;
@property(nonatomic, readonly) BOOL sleeping;
@property(nonatomic, readonly) BOOL failed;
@property(nonatomic, readonly) BOOL available;
@property(nonatomic, readonly) BOOL normalBrightnessAvailable;
@property(nonatomic, readonly) BOOL guardingBrightness;
@property(nonatomic, readonly) BOOL brightnessVerified;
@property(nonatomic, strong, readonly) TBBrightnessState *brightnessState;
@property(nonatomic, readonly) TBPowerState observedState;
@property(nonatomic, copy, readonly) NSString *message;
@property(nonatomic, readonly) NSUInteger offRequestCount;
@property(nonatomic, readonly) NSUInteger brightnessRequestCount;
@property(nonatomic, readonly) NSInteger selectedBrightnessPercent;
@property(nonatomic, readonly) double targetBrightnessNits;
- (instancetype)initWithHardware:(id<TBHardware>)hardware;
- (void)keepOffAtTime:(NSTimeInterval)now;
- (void)turnOnAtTime:(NSTimeInterval)now;
- (void)resumeOnAtTime:(NSTimeInterval)now; // Adopt On mode without sending any power-on command.
- (void)setBrightnessPercent:(double)percent atTime:(NSTimeInterval)now;
- (void)pollAtTime:(NSTimeInterval)now;
- (void)prepareForSleep;
- (void)resumeAtTime:(NSTimeInterval)now;
- (void)stop; // Stops holding. Never sends an on command.
@end
