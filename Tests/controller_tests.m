#import <Foundation/Foundation.h>
#import "TBController.h"
#import "TBBrightnessPreference.h"

static NSUInteger assertions = 0;
#define CHECK(condition) do { \
    assertions++; \
    if (!(condition)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); exit(1); } \
} while (0)

@interface FakeHardware : NSObject <TBHardware>
@property(nonatomic) BOOL available;
@property(nonatomic, copy) NSString *unavailabilityReason;
@property(nonatomic) TBPowerState state;
@property(nonatomic) BOOL acceptOff;
@property(nonatomic) BOOL acceptOn;
@property(nonatomic) NSUInteger offCalls;
@property(nonatomic) NSUInteger onCalls;
@property(nonatomic) NSUInteger reads;
@property(nonatomic) BOOL normalBrightnessAvailable;
@property(nonatomic, copy) NSString *brightnessUnavailabilityReason;
@property(nonatomic, strong) TBBrightnessState *brightnessState;
@property(nonatomic) BOOL acceptBrightness;
@property(nonatomic) BOOL applyBrightnessChanges;
@property(nonatomic) NSUInteger brightnessCalls;
@property(nonatomic) NSUInteger brightnessReads;
@property(nonatomic) double lastRequestedNits;
@property(nonatomic) NSTimeInterval inputIdleSeconds;
@property(nonatomic) BOOL sessionAllowsControl;
@property(nonatomic, weak) TBController *controller;
@end
@implementation FakeHardware
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _available = YES;
    _sessionAllowsControl = YES;
    _unavailabilityReason = @"Unavailable in test";
    _state = TBPowerStateOff;
    _acceptOff = YES;
    _acceptOn = YES;
    _normalBrightnessAvailable = YES;
    _brightnessUnavailabilityReason = @"Brightness unavailable in test";
    _acceptBrightness = YES;
    _applyBrightnessChanges = YES;
    _brightnessState = [TBBrightnessState new];
    _brightnessState.minimum = 0.25;
    _brightnessState.brightness = 0.5;
    _brightnessState.physicalNits = 184.5;
    _brightnessState.driverNits = 184;
    _brightnessState.hardwareMinimumNits = 11.899;
    _brightnessState.hardwareMaximumNits = 357.099;
    _brightnessState.dimmingStep = 0;
    _brightnessState.automaticBrightness = 0;
    _brightnessState.normalConfiguration = YES;
    return self;
}
- (TBPowerState)readPowerState { self.reads++; return self.state; }
- (BOOL)requestImmediateOff { self.offCalls++; return self.acceptOff; }
- (BOOL)requestOn {
    CHECK(!self.controller.holdingOff); // The ordering is a safety invariant.
    self.onCalls++;
    return self.acceptOn;
}
- (TBBrightnessState *)readBrightnessState { self.brightnessReads++; return self.brightnessState; }
- (BOOL)applyNormalBrightnessAtNits:(double)nits {
    CHECK(!self.controller.requestedOff && !self.controller.holdingOff && !self.controller.sleeping);
    self.brightnessCalls++;
    self.lastRequestedNits = nits;
    if (self.acceptBrightness && self.applyBrightnessChanges) {
        self.brightnessState.minimum = 0.25;
        self.brightnessState.automaticBrightness = 0;
        self.brightnessState.normalConfiguration = YES;
        self.brightnessState.physicalNits = nits;
        self.brightnessState.driverNits = round(nits);
    }
    return self.acceptBrightness;
}
@end

@interface FakePreferences : NSObject <TBPreferenceStore>
@property(nonatomic, strong) NSMutableDictionary *values;
@property(nonatomic) NSUInteger writes;
@end
@implementation FakePreferences
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _values = [NSMutableDictionary new];
    return self;
}
- (id)objectForKey:(NSString *)key { return self.values[key]; }
- (void)setObject:(id)value forKey:(NSString *)key { self.writes++; self.values[key] = value; }
@end

static TBController *MakeController(FakeHardware *hardware) {
    TBController *controller = [[TBController alloc] initWithHardware:hardware];
    hardware.controller = controller;
    return controller;
}

int main(void) {
    @autoreleasepool {
        // Locking before 55 seconds must turn off, not bypass idle protection.
        FakeHardware *lockedHardware = [FakeHardware new];
        lockedHardware.state = TBPowerStateOn;
        TBController *lockedController = MakeController(lockedHardware);
        [lockedController resumeOnAtTime:0];
        lockedHardware.sessionAllowsControl = NO;
        lockedHardware.inputIdleSeconds = 10;
        [lockedController pollAtTime:10];
        CHECK(lockedController.idleOff && lockedHardware.offCalls == 1);
        lockedHardware.state = TBPowerStateOff;
        [lockedController pollAtTime:11];
        lockedHardware.state = TBPowerStateOn; // macOS reactivates during the lock.
        lockedHardware.inputIdleSeconds = 0;
        [lockedController pollAtTime:12];
        CHECK(lockedHardware.offCalls == 2 && lockedHardware.onCalls == 0 && lockedHardware.brightnessCalls == 0);
        lockedHardware.state = TBPowerStateOff;
        lockedHardware.sessionAllowsControl = YES;
        [lockedController pollAtTime:13];
        CHECK(lockedController.idleOff && lockedHardware.onCalls == 0);
        lockedHardware.inputIdleSeconds = 1;
        [lockedController pollAtTime:14];
        CHECK(lockedHardware.onCalls == 0);
        lockedHardware.inputIdleSeconds = 0.1;
        [lockedController pollAtTime:14.5];
        CHECK(!lockedController.idleOff && lockedHardware.onCalls == 1);

        FakeHardware *hardware = [FakeHardware new];
        TBController *controller = MakeController(hardware);
        [controller keepOffAtTime:0];
        CHECK(controller.holdingOff && controller.requestedOff);
        CHECK(controller.observedState == TBPowerStateOff && hardware.offCalls == 0);
        hardware.state = TBPowerStateOn;
        [controller pollAtTime:10];
        CHECK(hardware.offCalls == 1);
        [controller pollAtTime:10.1];
        [controller resumeAtTime:10.2];
        CHECK(hardware.offCalls == 1); // Wake notifications cannot bypass throttling.
        [controller pollAtTime:11];
        CHECK(hardware.offCalls == 2);
        [controller pollAtTime:12];
        CHECK(hardware.offCalls == 3 && controller.holdingOff);
        [controller pollAtTime:13];
        CHECK(controller.failed && !controller.holdingOff && controller.requestedOff);
        [controller pollAtTime:30];
        [controller resumeAtTime:31];
        CHECK(hardware.offCalls == 3); // Failure remains latched until a user retries.
        [controller keepOffAtTime:32];
        CHECK(hardware.offCalls == 4 && controller.holdingOff && !controller.failed);
        hardware.state = TBPowerStateOff;
        [controller pollAtTime:32.1];
        hardware.state = TBPowerStateOn;
        [controller pollAtTime:34];
        CHECK(hardware.offCalls == 5 && !controller.failed);

        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.acceptOff = NO;
        controller = MakeController(hardware);
        [controller keepOffAtTime:0];
        [controller pollAtTime:100];
        CHECK(controller.failed && !controller.holdingOff && hardware.offCalls == 1);

        hardware = [FakeHardware new];
        hardware.state = TBPowerStateUnknown;
        controller = MakeController(hardware);
        [controller keepOffAtTime:0];
        [controller pollAtTime:1.9];
        CHECK(controller.holdingOff);
        [controller pollAtTime:2];
        CHECK(controller.failed && !controller.holdingOff && hardware.offCalls == 0);

        hardware = [FakeHardware new];
        controller = MakeController(hardware);
        [controller keepOffAtTime:0];
        hardware.state = TBPowerStateOn;
        [controller turnOnAtTime:1];
        [controller pollAtTime:2];
        CHECK(!controller.requestedOff && !controller.holdingOff && !controller.failed);
        CHECK(hardware.onCalls == 0 && hardware.offCalls == 0); // Already on: avoid a power-on brightness dip.
        hardware.state = TBPowerStateOff;
        [controller pollAtTime:3];
        CHECK(!controller.failed && hardware.onCalls == 0); // Normal power-off remains allowed.

        hardware = [FakeHardware new];
        hardware.acceptOn = NO;
        controller = MakeController(hardware);
        [controller keepOffAtTime:0];
        [controller turnOnAtTime:1];
        CHECK(controller.failed && !controller.holdingOff && !controller.requestedOff);
        [controller pollAtTime:10];
        CHECK(hardware.onCalls == 1 && hardware.offCalls == 0);

        hardware = [FakeHardware new];
        controller = MakeController(hardware);
        [controller turnOnAtTime:0];
        CHECK(!controller.failed);
        [controller pollAtTime:2];
        CHECK(controller.failed && !controller.holdingOff && hardware.onCalls == 1);

        hardware = [FakeHardware new];
        controller = MakeController(hardware);
        [controller keepOffAtTime:0];
        [controller prepareForSleep];
        CHECK(controller.sleeping && controller.holdingOff);
        NSUInteger readsBeforeSleep = hardware.reads;
        hardware.state = TBPowerStateOn;
        [controller pollAtTime:500];
        CHECK(hardware.reads == readsBeforeSleep && hardware.offCalls == 0);
        [controller resumeAtTime:501];
        CHECK(!controller.sleeping && controller.holdingOff && hardware.offCalls == 1);
        [controller stop];
        [controller pollAtTime:600];
        CHECK(!controller.holdingOff && hardware.onCalls == 0 && hardware.offCalls == 1);

        hardware = [FakeHardware new];
        hardware.available = NO;
        controller = MakeController(hardware);
        [controller keepOffAtTime:0];
        CHECK(controller.failed && !controller.holdingOff);
        [controller turnOnAtTime:1];
        CHECK(hardware.onCalls == 0 && hardware.offCalls == 0);

        // Adopt already-on hardware without a power command or redundant brightness write.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        CHECK(controller.guardingBrightness && controller.brightnessVerified);
        CHECK(hardware.onCalls == 0 && hardware.brightnessCalls == 0);
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        [controller pollAtTime:0.5];
        CHECK(hardware.brightnessCalls == 1 && !controller.brightnessVerified);
        [controller pollAtTime:1];
        CHECK(controller.brightnessVerified && !controller.failed);

        // A brief success must not reset the rolling recovery limit.
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        [controller pollAtTime:1.5];
        [controller pollAtTime:2];
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        [controller pollAtTime:2.5];
        [controller pollAtTime:3];
        CHECK(controller.brightnessVerified && hardware.brightnessCalls == 3);
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        [controller pollAtTime:3.5];
        CHECK(controller.failed && !controller.guardingBrightness && hardware.brightnessCalls == 3);
        [controller resumeAtTime:70];
        CHECK(hardware.brightnessCalls == 3 && controller.failed);
        [controller turnOnAtTime:71];
        [controller pollAtTime:71.5];
        CHECK(!controller.failed && controller.brightnessVerified && hardware.brightnessCalls == 4);

        // Power reactivation and wake recover the level, but never send automatic power-on.
        hardware = [FakeHardware new];
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        CHECK(hardware.onCalls == 0 && hardware.brightnessCalls == 0 && controller.guardingBrightness);
        hardware.state = TBPowerStateOn;
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        [controller pollAtTime:1];
        CHECK(hardware.brightnessCalls == 1 && hardware.onCalls == 0);
        [controller prepareForSleep];
        NSUInteger brightnessReads = hardware.brightnessReads;
        [controller pollAtTime:100];
        CHECK(hardware.brightnessReads == brightnessReads);
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        [controller resumeAtTime:101];
        CHECK(hardware.brightnessCalls == 2 && hardware.onCalls == 0);
        [controller keepOffAtTime:102];
        NSUInteger writesBeforeOff = hardware.brightnessCalls;
        [controller resumeAtTime:103];
        [controller pollAtTime:104];
        CHECK(!controller.guardingBrightness && hardware.brightnessCalls == writesBeforeOff);
        [controller stop];
        CHECK(hardware.onCalls == 0 && hardware.brightnessCalls == writesBeforeOff);

        // Unexpected early dimming skips to Off instead of writing a brighter target.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.brightnessState.dimmingStep = 1;
        hardware.brightnessState.physicalNits = 28;
        hardware.brightnessState.driverNits = 28;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        CHECK(controller.idleOff && hardware.offCalls == 1);
        hardware.state = TBPowerStateOff;
        hardware.inputIdleSeconds = 60;
        [controller pollAtTime:60];
        CHECK(!controller.brightnessVerified && !controller.failed && hardware.brightnessCalls == 0);
        hardware.state = TBPowerStateOn;
        hardware.inputIdleSeconds = 0;
        hardware.brightnessState.dimmingStep = 0;
        [controller pollAtTime:61];
        CHECK(hardware.brightnessCalls == 1);

        // Missing driver telemetry is never reported as successful verification.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.brightnessState.driverNits = NAN;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        [controller pollAtTime:2];
        CHECK(controller.failed && !controller.brightnessVerified && hardware.brightnessCalls == 0);

        // Unsupported brightness leaves reliable off control available and does not turn on.
        hardware = [FakeHardware new];
        hardware.normalBrightnessAvailable = NO;
        controller = MakeController(hardware);
        [controller turnOnAtTime:0];
        CHECK(controller.failed && hardware.onCalls == 0 && hardware.brightnessCalls == 0);
        [controller keepOffAtTime:1];
        CHECK(controller.holdingOff && !controller.failed);

        // A rejected brightness request latches failure, with no automatic retry or restoration.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.brightnessState.normalConfiguration = NO;
        hardware.acceptBrightness = NO;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        [controller pollAtTime:100];
        CHECK(controller.failed && hardware.brightnessCalls == 1 && !controller.guardingBrightness);

        // An accepted power-on request waits for actual on before brightness writes.
        hardware = [FakeHardware new];
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        controller = MakeController(hardware);
        [controller turnOnAtTime:0];
        CHECK(hardware.onCalls == 1 && hardware.brightnessCalls == 0);
        hardware.state = TBPowerStateOn;
        [controller pollAtTime:0.1];
        CHECK(hardware.brightnessCalls == 1);
        [controller pollAtTime:0.7];
        CHECK(controller.brightnessVerified);

        // Accepted writes that never affect readback are bounded and not called verified.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.applyBrightnessChanges = NO;
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        [controller pollAtTime:0.5];
        [controller resumeAtTime:0.6];
        CHECK(hardware.brightnessCalls == 1); // Wake does not bypass the write throttle.
        [controller pollAtTime:1.1];
        [controller pollAtTime:2.2];
        [controller pollAtTime:3.3];
        CHECK(controller.failed && hardware.brightnessCalls == 3 && !controller.brightnessVerified);

        // Policy drift is corrected even if both nits readings are still at target.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.brightnessState.normalConfiguration = NO;
        hardware.brightnessState.automaticBrightness = 1;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        CHECK(hardware.brightnessCalls == 1 && !controller.brightnessVerified);
        [controller pollAtTime:0.5];
        CHECK(controller.brightnessVerified);
        [controller stop];
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        [controller pollAtTime:1];
        CHECK(hardware.brightnessCalls == 1 && !controller.guardingBrightness);

        // Slider snapping, exact working floor, and hardware-derived upper bounds.
        CHECK(TBSnapBrightnessPercent(54.9) == 50);
        CHECK(TBSnapBrightnessPercent(55) == 60);
        CHECK(TBSnapBrightnessPercent(99) == 100);
        CHECK(TBSnapBrightnessPercent(-100) == 50 && TBSnapBrightnessPercent(200) == 100);
        CHECK(TBSnapBrightnessPercent(NAN) == 50 && TBSnapBrightnessPercent(INFINITY) == 50);
        double expectedTargets[] = {184.5, 219.019, 253.539, 288.059, 322.579, 357.099};
        for (NSInteger step = 0; step < 6; step++) {
            double target = TBTargetNits(50 + step * 10, 11.899, 357.099);
            CHECK(fabs(target - expectedTargets[step]) < 0.0001);
            CHECK(target >= 184.5 && target <= 357.099);
        }
        CHECK(isnan(TBTargetNits(50, NAN, 357.099)));
        CHECK(isnan(TBTargetNits(100, 11.899, 180)));
        CHECK(isnan(TBTargetNits(100, 400, 357.099)));
        CHECK(fabs(TBTargetNits(100, 11.899, 300) - 300) < 0.0001);

        // Preferences are validated, persist across instances, and stay isolated in preview.
        FakePreferences *store = [FakePreferences new];
        TBBrightnessPreference *preference = [[TBBrightnessPreference alloc] initWithStore:store];
        CHECK(preference.percent == 50 && store.writes == 0);
        [preference setSelectedPercent:85];
        CHECK(preference.percent == 90 && store.writes == 1);
        preference = [[TBBrightnessPreference alloc] initWithStore:store];
        CHECK(preference.percent == 90);
        TBBrightnessPreference *previewPreference = [[TBBrightnessPreference alloc] initWithStore:nil];
        CHECK(previewPreference.percent == 50);
        [previewPreference setSelectedPercent:100];
        CHECK(previewPreference.percent == 100 && store.writes == 1);
        store.values[@"BrightnessPercent"] = @"invalid";
        preference = [[TBBrightnessPreference alloc] initWithStore:store];
        CHECK(preference.percent == 50);
        store.values[@"BrightnessPercent"] = @500;
        preference = [[TBBrightnessPreference alloc] initWithStore:store];
        CHECK(preference.percent == 100);

        // Off selections only store intent, then On applies the selected target.
        hardware = [FakeHardware new];
        controller = MakeController(hardware);
        [controller setBrightnessPercent:64 atTime:0];
        [controller keepOffAtTime:0.1];
        CHECK(controller.selectedBrightnessPercent == 60);
        CHECK(hardware.brightnessCalls == 0 && hardware.onCalls == 0 && hardware.offCalls == 0);
        [controller turnOnAtTime:1];
        CHECK(hardware.brightnessCalls == 0 && hardware.onCalls == 1);
        hardware.state = TBPowerStateOn;
        [controller pollAtTime:1.1];
        CHECK(fabs(hardware.lastRequestedNits - 219.019) < 0.0001);
        [controller keepOffAtTime:2];
        NSUInteger beforeOffSelection = hardware.brightnessCalls;
        [controller setBrightnessPercent:100 atTime:2.1];
        CHECK(hardware.brightnessCalls == beforeOffSelection && hardware.onCalls == 1);
        [controller turnOnAtTime:3];
        CHECK(fabs(hardware.lastRequestedNits - 357.099) < 0.0001);

        // Rapid explicit selections coalesce under the throttle and do not consume a recovery budget.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        for (NSInteger index = 1; index <= 5; index++)
            [controller setBrightnessPercent:50 + index * 10 atTime:index * 0.1];
        CHECK(hardware.brightnessCalls == 1 && controller.selectedBrightnessPercent == 100);
        [controller pollAtTime:1.2];
        CHECK(hardware.brightnessCalls == 2 && fabs(hardware.lastRequestedNits - 357.099) < 0.0001);
        for (NSInteger index = 0; index < 4; index++) {
            [controller setBrightnessPercent:60 + index * 10 atTime:2.3 + index * 1.1];
            CHECK(!controller.failed);
        }
        CHECK(hardware.brightnessCalls == 6);

        // Fresh hardware limits govern the next request, not a cached hardcoded maximum.
        hardware.brightnessState.hardwareMaximumNits = 300;
        [controller setBrightnessPercent:100 atTime:8];
        CHECK(fabs(hardware.lastRequestedNits - 300) < 0.0001);
        [controller prepareForSleep];
        NSUInteger beforeSleepSelection = hardware.brightnessCalls;
        [controller setBrightnessPercent:80 atTime:9];
        CHECK(hardware.brightnessCalls == beforeSleepSelection);
        [controller resumeAtTime:10];
        CHECK(fabs(hardware.lastRequestedNits - TBTargetNits(80, 11.899, 300)) < 0.0001);

        // Missing bounds can pause protection, but a later explicit On can retry when they return.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        TBBrightnessState *savedState = hardware.brightnessState;
        hardware.brightnessState = nil;
        [controller pollAtTime:1];
        [controller pollAtTime:3];
        CHECK(controller.failed && controller.normalBrightnessAvailable);
        hardware.brightnessState = savedState;
        [controller turnOnAtTime:4];
        CHECK(!controller.failed && controller.brightnessVerified && hardware.onCalls == 0);
        hardware.brightnessState.hardwareMaximumNits = NAN;
        [controller pollAtTime:5];
        CHECK(controller.failed && controller.normalBrightnessAvailable);
        hardware.brightnessState.hardwareMaximumNits = 357.099;
        [controller turnOnAtTime:6];
        CHECK(!controller.failed && controller.brightnessVerified);
        // Idle protection starts at 55 seconds, before the native 60-second dim.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.inputIdleSeconds = 54.99;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:100];
        CHECK(!controller.idleOff && hardware.offCalls == 0 && controller.brightnessVerified);
        hardware.inputIdleSeconds = 55;
        [controller pollAtTime:100.01];
        CHECK(controller.idleOff && controller.holdingOff && !controller.requestedOff);
        CHECK(hardware.offCalls == 1 && hardware.onCalls == 0 && !controller.brightnessVerified);
        [controller pollAtTime:100.02];
        CHECK(hardware.offCalls == 1); // No repeated zero-fade calls during the first second.
        hardware.state = TBPowerStateOff;
        hardware.inputIdleSeconds = 80;
        [controller pollAtTime:125.01];
        CHECK(controller.idleOff && hardware.brightnessCalls == 0 && hardware.onCalls == 0);
        [controller setBrightnessPercent:80 atTime:125.02];
        CHECK(controller.idleOff && hardware.brightnessCalls == 0 && hardware.onCalls == 0);
        // Real input after the hold wakes once, then reapplies the saved target.
        hardware.inputIdleSeconds = 0.1;
        [controller pollAtTime:126];
        CHECK(!controller.idleOff && !controller.holdingOff && hardware.onCalls == 1);
        [controller pollAtTime:126.1];
        CHECK(hardware.onCalls == 1 && hardware.brightnessCalls == 0);
        hardware.state = TBPowerStateOn;
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        [controller pollAtTime:126.2];
        CHECK(hardware.brightnessCalls == 1 && fabs(hardware.lastRequestedNits - 288.059) < 0.001);
        [controller pollAtTime:126.8];
        CHECK(controller.brightnessVerified && !controller.failed);

        // Manual Off replaces idle Off and cannot be reversed by activity or wake.
        hardware.inputIdleSeconds = 56;
        [controller pollAtTime:182];
        CHECK(controller.idleOff);
        [controller keepOffAtTime:182.1];
        hardware.state = TBPowerStateOff;
        hardware.inputIdleSeconds = 0;
        [controller pollAtTime:183];
        [controller prepareForSleep];
        [controller resumeAtTime:184];
        CHECK(controller.requestedOff && controller.holdingOff && !controller.idleOff);
        CHECK(hardware.onCalls == 1 && hardware.brightnessCalls == 1);

        // No immediate wake on adoption while already idle; no timer causes wake by itself.
        hardware = [FakeHardware new];
        hardware.inputIdleSeconds = 60;
        controller = MakeController(hardware);
        [controller turnOnAtTime:0];
        CHECK(controller.idleOff && hardware.onCalls == 0 && hardware.offCalls == 0);
        hardware.inputIdleSeconds = 120;
        [controller pollAtTime:60];
        CHECK(controller.idleOff && hardware.onCalls == 0);
        hardware.state = TBPowerStateOn; // macOS reactivates while the user remains idle.
        [controller pollAtTime:61];
        CHECK(hardware.offCalls == 1 && hardware.onCalls == 0);

        // Unknown/invalid activity keeps the strip off and never counts as new input.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.inputIdleSeconds = NAN;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:10];
        CHECK(controller.idleOff && hardware.offCalls == 1 && hardware.brightnessCalls == 0);
        hardware.state = TBPowerStateOff;
        hardware.inputIdleSeconds = -1;
        [controller pollAtTime:20];
        hardware.inputIdleSeconds = INFINITY;
        [controller pollAtTime:30];
        hardware.inputIdleSeconds = 31;
        [controller pollAtTime:40];
        CHECK(controller.idleOff && hardware.onCalls == 0);
        hardware.inputIdleSeconds = 0.1;
        [controller pollAtTime:41];
        CHECK(hardware.onCalls == 1 && !controller.idleOff);

        // A locked/inactive/asleep display blocks automatic On and brightness writes.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.inputIdleSeconds = 55;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        hardware.state = TBPowerStateOff;
        hardware.sessionAllowsControl = NO;
        hardware.inputIdleSeconds = 0;
        [controller pollAtTime:10];
        CHECK(controller.idleOff && hardware.onCalls == 0 && hardware.brightnessCalls == 0);
        hardware.sessionAllowsControl = YES;
        [controller pollAtTime:11];
        CHECK(hardware.onCalls == 0); // A reset idle clock during unlock isn't fresh input.
        hardware.inputIdleSeconds = 1;
        [controller pollAtTime:12];
        CHECK(hardware.onCalls == 0);
        hardware.inputIdleSeconds = 0.05;
        [controller pollAtTime:12.5];
        CHECK(hardware.onCalls == 1);

        // The sleep notification blocks reads; wake requires fresh post-wake activity.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.inputIdleSeconds = 55;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        hardware.state = TBPowerStateOff;
        [controller prepareForSleep];
        NSUInteger idleSleepReads = hardware.reads;
        [controller pollAtTime:60];
        CHECK(hardware.reads == idleSleepReads && hardware.onCalls == 0);
        hardware.inputIdleSeconds = 0;
        [controller resumeAtTime:61];
        CHECK(hardware.onCalls == 0 && controller.idleOff);
        hardware.inputIdleSeconds = 1;
        [controller pollAtTime:62];
        CHECK(hardware.onCalls == 0);
        hardware.inputIdleSeconds = 0.1;
        [controller pollAtTime:62.5];
        CHECK(hardware.onCalls == 1 && !controller.idleOff);

        // Rejected or unverified automatic Off remains bounded, without auto-recovery.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.inputIdleSeconds = 55;
        hardware.acceptOff = NO;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        [controller pollAtTime:1];
        CHECK(controller.failed && hardware.offCalls == 1 && hardware.onCalls == 0);
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        hardware.inputIdleSeconds = 55;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        [controller pollAtTime:1];
        [controller pollAtTime:2];
        [controller pollAtTime:3];
        CHECK(controller.failed && hardware.offCalls == 3);
        hardware.inputIdleSeconds = 0;
        [controller pollAtTime:4];
        CHECK(hardware.onCalls == 0 && hardware.offCalls == 3);

        // Missing power telemetry during input cannot authorize an automatic On.
        hardware = [FakeHardware new];
        hardware.inputIdleSeconds = 55;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        hardware.state = TBPowerStateUnknown;
        hardware.inputIdleSeconds = 0;
        [controller pollAtTime:1];
        [controller pollAtTime:3];
        CHECK(controller.failed && hardware.onCalls == 0 && hardware.offCalls == 0);

        // A rejected activity wake latches failure and cannot repeat on a timer.
        hardware = [FakeHardware new];
        hardware.inputIdleSeconds = 55;
        hardware.acceptOn = NO;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        hardware.inputIdleSeconds = 0;
        [controller pollAtTime:1];
        [controller pollAtTime:10];
        CHECK(controller.failed && hardware.onCalls == 1 && hardware.brightnessCalls == 0);

        // On selected in a blocked session permits only Off, then needs fresh input.
        hardware = [FakeHardware new];
        hardware.sessionAllowsControl = NO;
        controller = MakeController(hardware);
        [controller turnOnAtTime:0];
        hardware.state = TBPowerStateOn;
        hardware.brightnessState.physicalNits = 12;
        [controller pollAtTime:1];
        CHECK(hardware.onCalls == 0 && hardware.offCalls == 1 && hardware.brightnessCalls == 0);
        hardware.state = TBPowerStateOff;
        hardware.sessionAllowsControl = YES;
        [controller pollAtTime:2];
        CHECK(hardware.brightnessCalls == 0 && hardware.onCalls == 0);
        hardware.inputIdleSeconds = 0.1;
        [controller pollAtTime:2.5];
        CHECK(hardware.onCalls == 1 && hardware.brightnessCalls == 0);

        // If macOS wakes first on input, don't send another On or dip brightness again.
        hardware = [FakeHardware new];
        hardware.inputIdleSeconds = 55;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        hardware.state = TBPowerStateOn;
        hardware.inputIdleSeconds = 0;
        hardware.brightnessState.physicalNits = 12;
        hardware.brightnessState.driverNits = 12;
        [controller pollAtTime:1];
        CHECK(hardware.onCalls == 0 && hardware.brightnessCalls == 1 && !controller.idleOff);

        // Quit stops idle enforcement, even if macOS wakes the strip afterward.
        hardware = [FakeHardware new];
        hardware.inputIdleSeconds = 55;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        [controller stop];
        hardware.state = TBPowerStateOn;
        hardware.inputIdleSeconds = 0;
        [controller pollAtTime:1];
        CHECK(!controller.idleOff && hardware.onCalls == 0 && hardware.offCalls == 0 && hardware.brightnessCalls == 0);

        // A screensaver without a lock forces Off before the normal idle deadline.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        controller = MakeController(hardware);
        [controller resumeOnAtTime:0];
        controller.screensaverActive = YES;
        hardware.inputIdleSeconds = 5;
        [controller pollAtTime:5];
        CHECK(controller.idleOff && hardware.offCalls == 1 && !controller.requestedOff);
        hardware.state = TBPowerStateOff;
        hardware.inputIdleSeconds = 0; // A reset idle clock during the saver is not a wake.
        [controller pollAtTime:6];
        [controller setBrightnessPercent:80 atTime:7];
        CHECK(hardware.onCalls == 0 && hardware.brightnessCalls == 0);
        hardware.state = TBPowerStateOn;
        [controller pollAtTime:8];
        CHECK(hardware.offCalls == 2 && hardware.onCalls == 0);
        hardware.state = TBPowerStateOff;
        controller.screensaverActive = NO;
        hardware.sessionAllowsControl = NO; // Saver stopped, but the screen is still locked.
        [controller pollAtTime:9];
        CHECK(controller.idleOff && hardware.onCalls == 0);
        hardware.sessionAllowsControl = YES;
        [controller pollAtTime:10];
        CHECK(controller.idleOff && hardware.onCalls == 0);
        hardware.inputIdleSeconds = 1;
        [controller pollAtTime:11];
        CHECK(hardware.onCalls == 0);
        hardware.inputIdleSeconds = 0.1;
        [controller pollAtTime:11.5];
        CHECK(!controller.idleOff && hardware.onCalls == 1);

        // Explicit On during the saver must not flash the strip before the next poll.
        hardware = [FakeHardware new];
        controller = MakeController(hardware);
        controller.screensaverActive = YES;
        [controller turnOnAtTime:0];
        CHECK(controller.idleOff && hardware.onCalls == 0 && hardware.brightnessCalls == 0);
        [controller prepareForSleep];
        NSUInteger saverSleepReads = hardware.reads;
        [controller pollAtTime:10];
        CHECK(hardware.reads == saverSleepReads);
        [controller resumeAtTime:11];
        CHECK(controller.idleOff && hardware.onCalls == 0);
        [controller keepOffAtTime:12];
        controller.screensaverActive = NO;
        [controller pollAtTime:13];
        CHECK(controller.requestedOff && controller.holdingOff && hardware.onCalls == 0);

        // Failed Off requests remain bounded even throughout a screensaver.
        hardware = [FakeHardware new];
        hardware.state = TBPowerStateOn;
        controller = MakeController(hardware);
        controller.screensaverActive = YES;
        [controller resumeOnAtTime:0];
        [controller pollAtTime:1];
        [controller pollAtTime:2];
        [controller pollAtTime:3];
        CHECK(controller.failed && hardware.offCalls == 3 && hardware.onCalls == 0);
        controller.screensaverActive = NO;
        [controller pollAtTime:4];
        CHECK(controller.failed && hardware.offCalls == 3 && hardware.onCalls == 0);

        printf("PASS: %lu controller safety assertions. No real hardware provider linked.\n", (unsigned long)assertions);
    }
    return 0;
}
