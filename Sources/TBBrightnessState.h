#import <Foundation/Foundation.h>

// Software telemetry, not an optical measurement. Missing values are NAN / -1.
@interface TBBrightnessState : NSObject
@property(nonatomic) int displayID;
@property(nonatomic) double minimum;
@property(nonatomic) double brightness;
@property(nonatomic) double physicalNits;
@property(nonatomic) double driverNits;
@property(nonatomic) double hardwareMinimumNits;
@property(nonatomic) double hardwareMaximumNits;
@property(nonatomic) NSInteger dimmingStep;
@property(nonatomic) NSInteger automaticBrightness; // -1 unknown, 0 manual, 1 automatic
@property(nonatomic) BOOL normalConfiguration;
@end
