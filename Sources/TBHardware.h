#import <Foundation/Foundation.h>
#import "TBBrightnessState.h"

typedef NS_ENUM(NSInteger, TBPowerState) {
    TBPowerStateUnknown = -1,
    TBPowerStateOff = 0,
    TBPowerStateOn = 1
};

// Reads only the Touch Bar's backlight-dfr IORegistry node.
FOUNDATION_EXPORT TBPowerState TBReadPowerState(void);
FOUNDATION_EXPORT NSString *TBPowerStateName(TBPowerState state);

@protocol TBHardware <NSObject>
@property(nonatomic, readonly) BOOL available;
@property(nonatomic, copy, readonly) NSString *unavailabilityReason;
@property(nonatomic, readonly) BOOL normalBrightnessAvailable;
@property(nonatomic, copy, readonly) NSString *brightnessUnavailabilityReason;
- (TBPowerState)readPowerState;
- (TBBrightnessState *)readBrightnessState;
- (BOOL)applyNormalBrightnessAtNits:(double)nits;
- (BOOL)requestImmediateOff;
- (BOOL)requestOn;
@end

@interface TBRealHardware : NSObject <TBHardware>
- (BOOL)restoreOriginalBrightnessPolicy; // Explicit only: original minimum 0, automatic brightness on.
@end
