#import "TBController.h"
#import "TBBrightnessPreference.h"
#include <math.h>

@implementation TBController {
    id<TBHardware> _hardware;
    NSTimeInterval _lastOffRequest;
    NSTimeInterval _unknownSince;
    NSTimeInterval _onDeadline;
    NSUInteger _unverifiedOffRequests;
    BOOL _awaitingOn;
    NSTimeInterval _lastBrightnessPoll;
    NSTimeInterval _lastBrightnessRequest;
    NSTimeInterval _brightnessUnknownSince;
    NSMutableArray<NSNumber *> *_brightnessAttemptTimes;
    double _hardwareMinimumNits;
    double _hardwareMaximumNits;
}

- (instancetype)initWithHardware:(id<TBHardware>)hardware {
    if (!(self = [super init])) return nil;
    _hardware = hardware;
    _requestedOff = YES;
    _selectedBrightnessPercent = 50;
    TBBrightnessState *initial = hardware.normalBrightnessAvailable ? [hardware readBrightnessState] : nil;
    _hardwareMinimumNits = initial ? initial.hardwareMinimumNits : NAN;
    _hardwareMaximumNits = initial ? initial.hardwareMaximumNits : NAN;
    _observedState = TBPowerStateUnknown;
    _message = @"Starting…";
    _lastOffRequest = -INFINITY;
    _unknownSince = -1;
    _lastBrightnessPoll = -INFINITY;
    _lastBrightnessRequest = -INFINITY;
    _brightnessUnknownSince = -1;
    _brightnessAttemptTimes = [NSMutableArray new];
    return self;
}

- (BOOL)available { return _hardware.available; }
- (BOOL)normalBrightnessAvailable {
    // Capability controls retry availability; each action validates fresh bounds before writing.
    return _hardware.normalBrightnessAvailable;
}
- (double)targetBrightnessNits {
    return TBTargetNits(_selectedBrightnessPercent, _hardwareMinimumNits, _hardwareMaximumNits);
}

- (void)setBrightnessPercent:(double)percent atTime:(NSTimeInterval)now {
    NSInteger snapped = TBSnapBrightnessPercent(percent);
    if (_selectedBrightnessPercent == snapped) return;
    _selectedBrightnessPercent = snapped;
    _brightnessVerified = NO;
    _lastBrightnessPoll = -INFINITY;
    _brightnessUnknownSince = -1;
    [_brightnessAttemptTimes removeAllObjects]; // A new explicit target is a user retry, not a recovery failure.
    if (_requestedOff || _sleeping) return; // Selection while off/sleeping stores intent only.
    if (!self.normalBrightnessAvailable) return;
    _failed = NO;
    _guardingBrightness = YES;
    // Preserve the last write time: rapid keyboard selections still respect the one-second throttle.
    [self pollAtTime:now];
}

- (void)failWithMessage:(NSString *)message {
    _holdingOff = NO;
    _awaitingOn = NO;
    _guardingBrightness = NO;
    _brightnessVerified = NO;
    _failed = YES;
    _message = message;
    NSLog(@"Touch Bar control paused: %@", message);
}

- (void)resetAttempt {
    _failed = NO;
    _awaitingOn = NO;
    _unverifiedOffRequests = 0;
    _unknownSince = -1;
    _lastOffRequest = -INFINITY;
    _guardingBrightness = NO;
    _brightnessVerified = NO;
    _brightnessState = nil;
    _lastBrightnessPoll = -INFINITY;
    _lastBrightnessRequest = -INFINITY;
    _brightnessUnknownSince = -1;
    [_brightnessAttemptTimes removeAllObjects];
}

- (void)keepOffAtTime:(NSTimeInterval)now {
    _requestedOff = YES;
    [self resetAttempt];
    if (!_hardware.available) {
        [self failWithMessage:_hardware.unavailabilityReason];
        return;
    }
    _holdingOff = YES;
    [self pollAtTime:now];
}

- (void)turnOnAtTime:(NSTimeInterval)now {
    [self activateOnAtTime:now requestPower:YES];
}

- (void)resumeOnAtTime:(NSTimeInterval)now {
    [self activateOnAtTime:now requestPower:NO];
}

- (void)activateOnAtTime:(NSTimeInterval)now requestPower:(BOOL)requestPower {
    // Stop off enforcement before asking macOS to turn the strip on.
    _holdingOff = NO;
    _requestedOff = NO;
    [self resetAttempt];
    if (!_hardware.available) {
        [self failWithMessage:_hardware.unavailabilityReason];
        return;
    }
    TBBrightnessState *limits = _hardware.normalBrightnessAvailable ? [_hardware readBrightnessState] : nil;
    _hardwareMinimumNits = limits ? limits.hardwareMinimumNits : NAN;
    _hardwareMaximumNits = limits ? limits.hardwareMaximumNits : NAN;
    if (!self.normalBrightnessAvailable || !isfinite(self.targetBrightnessNits)) {
        NSString *reason = _hardware.brightnessUnavailabilityReason;
        [self failWithMessage:reason.length ? reason : @"Touch Bar brightness limits are unavailable. Keep off remains available."];
        return;
    }
    // An already-on strip must not be power-cycled during a handoff or retry.
    _observedState = [_hardware readPowerState];
    if (requestPower && _observedState != TBPowerStateOn && ![_hardware requestOn]) {
        [self failWithMessage:@"The on request was rejected. Off control is stopped. Try again after the Mac is awake."];
        return;
    }
    _awaitingOn = requestPower;
    _guardingBrightness = YES;
    _onDeadline = now + 2.0;
    _message = @"Turning on… Checking the brighter configuration.";
    NSLog(@"Touch Bar on mode requested; checking normal brightness.");
    [self pollAtTime:now];
}

- (void)pollAtTime:(NSTimeInterval)now {
    if (_sleeping) return;
    TBPowerState previousState = _observedState;
    _observedState = [_hardware readPowerState];
    if (_failed) return;

    if (!_holdingOff) {
        if (_awaitingOn && _observedState == TBPowerStateOn) _awaitingOn = NO;
        if (_awaitingOn && now >= _onDeadline) {
            [self failWithMessage:@"The Touch Bar did not report on. Off control is stopped; macOS may have dimmed it."];
        } else if (!_awaitingOn && _guardingBrightness) {
            if (_observedState == TBPowerStateOn) {
                _unknownSince = -1;
                if (previousState != TBPowerStateOn) _lastBrightnessPoll = -INFINITY;
                [self monitorBrightnessAtTime:now];
            } else if (_observedState == TBPowerStateOff) {
                _brightnessVerified = NO;
                _unknownSince = -1;
                _message = @"Touch Bar is off. Brightness protection resumes when macOS wakes it.";
            } else {
                _brightnessVerified = NO;
                if (_unknownSince < 0) _unknownSince = now;
                _message = @"Waiting for Touch Bar status…";
                if (now - _unknownSince >= 2.0)
                    [self failWithMessage:@"Touch Bar status is unavailable. Protection paused. Choose Keep off, or retry On."];
            }
        }
        return;
    }

    if (_observedState == TBPowerStateOff) {
        _unverifiedOffRequests = 0;
        _unknownSince = -1;
        _message = @"Keeping it off. Wake may still cause a brief flash.";
        return;
    }
    if (_observedState == TBPowerStateUnknown) {
        if (_unknownSince < 0) _unknownSince = now;
        _message = @"Waiting for Touch Bar status…";
        if (now - _unknownSince >= 2.0)
            [self failWithMessage:@"Touch Bar status is unavailable. Control has paused. Click Keep Touch Bar off to retry."];
        return;
    }
    _unknownSince = -1;
    if (now - _lastOffRequest < 1.0) return;
    if (_unverifiedOffRequests >= 3) {
        [self failWithMessage:@"The Touch Bar stayed on after three attempts. Control has paused. Click Keep Touch Bar off to retry."];
        return;
    }
    _lastOffRequest = now;
    _unverifiedOffRequests++;
    _offRequestCount++;
    if (![_hardware requestImmediateOff]) {
        [self failWithMessage:@"The off request was rejected. Control has paused. Click Keep Touch Bar off to retry."];
        return;
    }
    _message = @"Turning off… Waiting for the Touch Bar to confirm.";
    NSLog(@"Immediate Touch Bar off request %lu accepted.", (unsigned long)_offRequestCount);
}

- (void)monitorBrightnessAtTime:(NSTimeInterval)now {
    if (!_guardingBrightness || _requestedOff || _sleeping || _observedState != TBPowerStateOn) return;
    if (now - _lastBrightnessPoll < 0.5) return;
    _lastBrightnessPoll = now;
    _brightnessState = [_hardware readBrightnessState];
    TBBrightnessState *state = _brightnessState;
    _hardwareMinimumNits = state ? state.hardwareMinimumNits : NAN;
    _hardwareMaximumNits = state ? state.hardwareMaximumNits : NAN;
    if (!state || state.dimmingStep < 0 || !isfinite(state.physicalNits) || !isfinite(state.driverNits)) {
        _brightnessVerified = NO;
        if (_brightnessUnknownSince < 0) _brightnessUnknownSince = now;
        _message = @"Waiting for brightness readings…";
        if (now - _brightnessUnknownSince >= 2.0)
            [self failWithMessage:@"Brightness could not be verified. Protection paused. Choose Keep off, or retry On."];
        return;
    }
    _brightnessUnknownSince = -1;
    if (!isfinite(self.targetBrightnessNits)) {
        [self failWithMessage:@"Touch Bar brightness limits are unavailable. Protection paused; choose Keep off."];
        return;
    }
    if (state.dimmingStep != 0) {
        _brightnessVerified = NO;
        _message = @"Inactivity dimming is active. Set keyboard-backlight inactivity to Never, or choose Keep off.";
        return; // Never fight the user's inactivity or sleep policy.
    }
    double target = self.targetBrightnessNits;
    BOOL nearTarget = fabs(state.physicalNits - target) <= 5.0 && fabs(state.driverNits - round(target)) <= 5.0;
    if (state.normalConfiguration && nearTarget) {
        _brightnessVerified = YES;
        _message = @"Brighter setting verified. Keep keyboard-backlight inactivity set to Never.";
        return;
    }
    _brightnessVerified = NO;
    if (now - _lastBrightnessRequest < 1.0) {
        _message = @"Applying brighter setting… Waiting for brightness readings.";
        return;
    }
    while (_brightnessAttemptTimes.count && now - _brightnessAttemptTimes.firstObject.doubleValue >= 60.0)
        [_brightnessAttemptTimes removeObjectAtIndex:0];
    if (_brightnessAttemptTimes.count >= 3) {
        [self failWithMessage:@"Brightness needed too many corrections. Protection paused. Choose Keep off, or retry On."];
        return;
    }
    [_brightnessAttemptTimes addObject:@(now)];
    _lastBrightnessRequest = now;
    _brightnessRequestCount++;
    if (![_hardware applyNormalBrightnessAtNits:target]) {
        [self failWithMessage:@"The brightness request failed. Protection paused. Choose Keep off, or retry On."];
        return;
    }
    _message = @"Applying brighter setting… Waiting for brightness readings.";
    NSLog(@"Touch Bar normal-brightness request %lu accepted.", (unsigned long)_brightnessRequestCount);
}

- (void)prepareForSleep {
    _sleeping = YES;
    _brightnessVerified = NO;
    if (!_failed) _message = @"Mac is sleeping. Control resumes on wake.";
}

- (void)resumeAtTime:(NSTimeInterval)now {
    _sleeping = NO;
    // Wake must not remove an existing failure limit; retry is an explicit action.
    if (_holdingOff) {
        _unknownSince = -1;
    }
    if (_awaitingOn) _onDeadline = now + 2.0;
    _lastBrightnessPoll = -INFINITY;
    _brightnessUnknownSince = -1;
    [self pollAtTime:now];
}

- (void)stop {
    _holdingOff = NO;
    _awaitingOn = NO;
    _guardingBrightness = NO;
    _brightnessVerified = NO;
    _message = @"Control stopped. No on request was sent.";
}
@end
