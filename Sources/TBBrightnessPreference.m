#import "TBBrightnessPreference.h"
#include <math.h>

static NSString *const TBPercentKey = @"BrightnessPercent";

NSInteger TBSnapBrightnessPercent(double value) {
    if (!isfinite(value)) return 50;
    return (NSInteger)(round(fmin(100.0, fmax(50.0, value)) / 10.0) * 10.0);
}

double TBTargetNits(NSInteger percent, double hardwareMinimum, double hardwareMaximum) {
    if (!isfinite(hardwareMinimum) || !isfinite(hardwareMaximum) || hardwareMinimum < 0 ||
        hardwareMaximum < 184.5 || hardwareMinimum >= hardwareMaximum) return NAN;
    double normalized = TBSnapBrightnessPercent(percent) / 100.0;
    // Preserve the exact tested lower level despite millinit readback rounding.
    return fmin(hardwareMaximum, fmax(184.5, hardwareMinimum + (hardwareMaximum - hardwareMinimum) * normalized));
}

@implementation TBBrightnessPreference {
    id<TBPreferenceStore> _store;
}
- (instancetype)initWithStore:(id<TBPreferenceStore>)store {
    if (!(self = [super init])) return nil;
    _store = store;
    id saved = [store objectForKey:TBPercentKey];
    _percent = [saved isKindOfClass:NSNumber.class] ? TBSnapBrightnessPercent([saved doubleValue]) : 50;
    return self;
}
- (void)setSelectedPercent:(double)value {
    _percent = TBSnapBrightnessPercent(value);
    [_store setObject:@(_percent) forKey:TBPercentKey];
}
@end
