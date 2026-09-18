#import "TBBrightnessState.h"
#include <math.h>

@implementation TBBrightnessState
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _minimum = NAN;
    _brightness = NAN;
    _physicalNits = NAN;
    _driverNits = NAN;
    _hardwareMinimumNits = NAN;
    _hardwareMaximumNits = NAN;
    _dimmingStep = -1;
    _automaticBrightness = -1;
    return self;
}
@end
