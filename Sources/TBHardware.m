#import "TBHardware.h"
#import "TBBrightnessPreference.h"
#import <IOKit/IOKitLib.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <math.h>
#include <sys/sysctl.h>
#include <unistd.h>

@interface NSObject (TBPrivateBrightnessClient)
- (BOOL)turnOffWithPeriod:(float)period;
- (BOOL)turnOn;
- (int)getDFRDisplayID;
- (id)copyPropertyForKey:(id)key andDisplay:(unsigned long long)display;
- (BOOL)setProperty:(id)value withKey:(id)key andDisplay:(unsigned long long)display;
@end

static double TBNumber(id value);
typedef struct { double current, minimum, maximum; } TBDriverBrightness;

static TBDriverBrightness TBReadDriverBrightness(void) {
    TBDriverBrightness result = {NAN, NAN, NAN};
    io_service_t parent = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("backlight-dfr"));
    if (!parent) return result;
    io_iterator_t children = IO_OBJECT_NULL;
    if (IORegistryEntryGetChildIterator(parent, kIOServicePlane, &children) == KERN_SUCCESS) {
        io_registry_entry_t child;
        while ((child = IOIteratorNext(children))) {
            CFTypeRef value = IORegistryEntryCreateCFProperty(child, CFSTR("CurrentNits"), kCFAllocatorDefault, 0);
            if (value) {
                if (CFGetTypeID(value) == CFNumberGetTypeID())
                    CFNumberGetValue(value, kCFNumberDoubleType, &result.current);
                CFRelease(value);
            }
            CFTypeRef parameters = IORegistryEntryCreateCFProperty(child, CFSTR("IODisplayParameters"), kCFAllocatorDefault, 0);
            if (parameters) {
                if (CFGetTypeID(parameters) == CFDictionaryGetTypeID()) {
                    id limits = ((__bridge NSDictionary *)parameters)[@"BrightnessMilliNits"];
                    if ([limits isKindOfClass:NSDictionary.class]) {
                        result.minimum = TBNumber(limits[@"min"]) / 1000.0;
                        result.maximum = TBNumber(limits[@"max"]) / 1000.0;
                    }
                }
                CFRelease(parameters);
            }
            IOObjectRelease(child);
            if (isfinite(result.current) && isfinite(result.minimum) && isfinite(result.maximum)) break;
        }
        IOObjectRelease(children);
    }
    IOObjectRelease(parent);
    return result;
}

static double TBNumber(id value) {
    return [value isKindOfClass:NSNumber.class] ? [value doubleValue] : NAN;
}

TBPowerState TBReadPowerState(void) {
    io_service_t parent = IOServiceGetMatchingService(kIOMainPortDefault,
                                                     IOServiceNameMatching("backlight-dfr"));
    if (!parent) return TBPowerStateUnknown;
    io_iterator_t children = IO_OBJECT_NULL;
    kern_return_t result = IORegistryEntryGetChildIterator(parent, kIOServicePlane, &children);
    IOObjectRelease(parent);
    if (result != KERN_SUCCESS) return TBPowerStateUnknown;

    TBPowerState observed = TBPowerStateUnknown;
    io_registry_entry_t child;
    while ((child = IOIteratorNext(children))) {
        CFTypeRef raw = IORegistryEntryCreateCFProperty(child, CFSTR("IOPowerManagement"),
                                                        kCFAllocatorDefault, 0);
        IOObjectRelease(child);
        if (!raw) continue;
        if (CFGetTypeID(raw) == CFDictionaryGetTypeID()) {
            CFTypeRef value = CFDictionaryGetValue(raw, CFSTR("CurrentPowerState"));
            int state = -1;
            if (value && CFGetTypeID(value) == CFNumberGetTypeID() &&
                CFNumberGetValue(value, kCFNumberIntType, &state)) {
                if (state == 0 || state == 1) observed = (TBPowerState)state;
            }
        }
        CFRelease(raw);
        if (observed != TBPowerStateUnknown) break;
    }
    IOObjectRelease(children);
    return observed;
}

NSString *TBPowerStateName(TBPowerState state) {
    switch (state) {
        case TBPowerStateOff: return @"Off";
        case TBPowerStateOn: return @"On";
        default: return @"Unavailable";
    }
}

@implementation TBRealHardware {
    id _client;
    BOOL _available;
    NSString *_unavailabilityReason;
    id _brightnessClient;
    BOOL _normalBrightnessAvailable;
    NSString *_brightnessUnavailabilityReason;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _unavailabilityReason = @"";
    _brightnessUnavailabilityReason = @"Normal brightness is unavailable. Keep off is still available.";
    // Keep the framework loaded for the client's lifetime. No private symbols are linked at build time.
    if (!dlopen("/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness",
                RTLD_LAZY | RTLD_LOCAL)) {
        _unavailabilityReason = @"Touch Bar control is unavailable on this version of macOS.";
        return self;
    }
    @try {
        _client = [[NSClassFromString(@"DFRBrightnessClient") alloc] init];
        NSMethodSignature *off = [_client methodSignatureForSelector:@selector(turnOffWithPeriod:)];
        NSMethodSignature *on = [_client methodSignatureForSelector:@selector(turnOn)];
        _available = off && on && off.numberOfArguments == 3 && on.numberOfArguments == 2 &&
                     strcmp(off.methodReturnType, @encode(BOOL)) == 0 &&
                     strcmp(on.methodReturnType, @encode(BOOL)) == 0 &&
                     strcmp([off getArgumentTypeAtIndex:2], @encode(float)) == 0;
    } @catch (NSException *exception) {
        (void)exception;
        _available = NO;
    }
    if (!_available) _unavailabilityReason = @"This macOS version does not provide the expected Touch Bar controls.";
    if (_available && TBReadPowerState() == TBPowerStateUnknown) {
        _available = NO;
        _unavailabilityReason = @"No supported Touch Bar was found. Reopen the app after the Mac is fully awake.";
    }
    if (_available) [self prepareBrightnessSupport];
    return self;
}

- (void)prepareBrightnessSupport {
    // This brightness configuration has only been validated on this model.
    char model[128] = {0};
    size_t length = sizeof(model);
    if (sysctlbyname("hw.model", model, &length, NULL, 0) || strcmp(model, "MacBookPro17,1")) {
        _brightnessUnavailabilityReason = @"The brightness fix has only been validated on MacBookPro17,1. Keep off remains available.";
        return;
    }
    if (!dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY | RTLD_LOCAL)) return;
    Class brightnessClass = NSClassFromString(@"BrightnessSystemClient");
    Method getter = class_getInstanceMethod(brightnessClass, @selector(copyPropertyForKey:andDisplay:));
    Method setter = class_getInstanceMethod(brightnessClass, @selector(setProperty:withKey:andDisplay:));
    Method identifier = class_getInstanceMethod([_client class], @selector(getDFRDisplayID));
    if (!getter || !setter || !identifier ||
        strcmp(method_getTypeEncoding(getter), "@32@0:8@16Q24") ||
        strcmp(method_getTypeEncoding(setter), "B40@0:8@16@24Q32") ||
        strcmp(method_getTypeEncoding(identifier), "i16@0:8")) {
        _brightnessUnavailabilityReason = @"The brightness API has changed. Keep off remains available.";
        return;
    }
    @try {
        _brightnessClient = [[brightnessClass alloc] init];
        TBBrightnessState *state = [self readBrightnessState];
        _normalBrightnessAvailable = _brightnessClient && state &&
            isfinite(TBTargetNits(50, state.hardwareMinimumNits, state.hardwareMaximumNits));
    } @catch (NSException *exception) { (void)exception; }
    if (_normalBrightnessAvailable) _brightnessUnavailabilityReason = @"";
}

- (int)validatedDFRDisplay {
    if (!_brightnessClient) return -1;
    int display = [_client getDFRDisplayID];
    if (display <= 0 || (CGDirectDisplayID)display == CGMainDisplayID()) return -1;
    id type = [_brightnessClient copyPropertyForKey:@"CBDisplayType" andDisplay:(unsigned long long)display];
    if (![type isKindOfClass:NSNumber.class] || [type intValue] != 3) return -1;
    return display;
}

- (BOOL)normalBrightnessAvailable { return _normalBrightnessAvailable; }
- (NSString *)brightnessUnavailabilityReason { return _brightnessUnavailabilityReason; }

- (TBBrightnessState *)readBrightnessState {
    @try {
        int display = [self validatedDFRDisplay];
        if (display <= 0) return nil;
        unsigned long long identifier = (unsigned long long)display;
        double minimum = TBNumber([_brightnessClient copyPropertyForKey:@"DisplayBrightnessMin" andDisplay:identifier]);
        double maximum = TBNumber([_brightnessClient copyPropertyForKey:@"DisplayBrightnessMax" andDisplay:identifier]);
        if (!isfinite(minimum) || !isfinite(maximum) || minimum < 0 || minimum > 0.2501 || maximum < 0.25 || maximum > 1.0001) return nil;
        TBBrightnessState *state = [TBBrightnessState new];
        state.displayID = display;
        state.minimum = minimum;
        id brightness = [_brightnessClient copyPropertyForKey:@"DisplayBrightness" andDisplay:identifier];
        if ([brightness isKindOfClass:NSDictionary.class]) {
            state.brightness = TBNumber(brightness[@"Brightness"]);
            state.physicalNits = TBNumber(brightness[@"NitsPhysical"]);
        }
        TBDriverBrightness driver = TBReadDriverBrightness();
        state.driverNits = driver.current;
        state.hardwareMinimumNits = driver.minimum;
        state.hardwareMaximumNits = driver.maximum;
        double automatic = TBNumber([_brightnessClient copyPropertyForKey:@"DisplayBrightnessAuto" andDisplay:identifier]);
        if (automatic == 0 || automatic == 1) state.automaticBrightness = (NSInteger)automatic;
        double dimming = TBNumber([_brightnessClient copyPropertyForKey:@"DimmingStep" andDisplay:identifier]);
        if (isfinite(dimming) && dimming >= 0 && dimming <= 10 && floor(dimming) == dimming) state.dimmingStep = (NSInteger)dimming;
        state.normalConfiguration = fabs(minimum - 0.25) <= 0.0001 && state.automaticBrightness == 0;
        return state;
    } @catch (NSException *exception) { (void)exception; return nil; }
}

- (BOOL)applyNormalBrightnessAtNits:(double)nits {
    if (!_normalBrightnessAvailable || ![self sessionAllowsControl]) return NO;
    @try {
        TBBrightnessState *state = [self readBrightnessState];
        // Revalidate identity and active state immediately before any write.
        if (!state || state.displayID <= 0 || state.dimmingStep != 0 || TBReadPowerState() != TBPowerStateOn ||
            !isfinite(TBTargetNits(50, state.hardwareMinimumNits, state.hardwareMaximumNits)) ||
            !isfinite(nits) || nits < 184.5 || nits > state.hardwareMaximumNits) return NO;
        unsigned long long display = (unsigned long long)state.displayID;
        if (![_brightnessClient setProperty:@0.25f withKey:@"DisplayBrightnessMin" andDisplay:display]) return NO;
        if ([self validatedDFRDisplay] != state.displayID) return NO;
        if (![_brightnessClient setProperty:@NO withKey:@"DisplayBrightnessAuto" andDisplay:display]) return NO;
        if ([self validatedDFRDisplay] != state.displayID) return NO;
        return [_brightnessClient setProperty:@(nits) withKey:@"DisplayNitsKey" andDisplay:display];
    } @catch (NSException *exception) { (void)exception; return NO; }
}

- (BOOL)restoreOriginalBrightnessPolicy {
    if (!_normalBrightnessAvailable) return NO;
    @try {
        TBBrightnessState *state = [self readBrightnessState];
        if (!state || state.displayID <= 0) return NO;
        unsigned long long display = (unsigned long long)state.displayID;
        if (![_brightnessClient setProperty:@0.0f withKey:@"DisplayBrightnessMin" andDisplay:display]) return NO;
        if ([self validatedDFRDisplay] != state.displayID) return NO;
        return [_brightnessClient setProperty:@YES withKey:@"DisplayBrightnessAuto" andDisplay:display];
    } @catch (NSException *exception) { (void)exception; return NO; }
}

- (BOOL)available { return _available; }
- (NSString *)unavailabilityReason { return _unavailabilityReason; }
- (TBPowerState)readPowerState { return TBReadPowerState(); }
- (NSTimeInterval)inputIdleSeconds {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"));
    if (!service) return NAN;
    CFTypeRef raw = IORegistryEntryCreateCFProperty(service, CFSTR("HIDIdleTime"), kCFAllocatorDefault, 0);
    IOObjectRelease(service);
    double nanoseconds = NAN;
    if (raw) {
        if (CFGetTypeID(raw) == CFNumberGetTypeID())
            CFNumberGetValue(raw, kCFNumberDoubleType, &nanoseconds);
        CFRelease(raw);
    }
    return isfinite(nanoseconds) && nanoseconds >= 0 ? nanoseconds / 1e9 : NAN;
}
- (BOOL)sessionAllowsControl {
    NSDictionary *session = CFBridgingRelease(CGSessionCopyCurrentDictionary());
    NSNumber *console = session[(__bridge NSString *)kCGSessionOnConsoleKey];
    NSNumber *loggedIn = session[(__bridge NSString *)kCGSessionLoginDoneKey];
    NSNumber *uid = session[(__bridge NSString *)kCGSessionUserIDKey];
    id locked = session[@"CGSSessionScreenIsLocked"];
    if (![console isKindOfClass:NSNumber.class] || !console.boolValue ||
        ![loggedIn isKindOfClass:NSNumber.class] || !loggedIn.boolValue ||
        ![uid isKindOfClass:NSNumber.class] || uid.unsignedIntValue != getuid() ||
        (locked && (![locked isKindOfClass:NSNumber.class] || [locked boolValue]))) return NO;
    // A closed lid or sleeping built-in display must not trigger a Touch Bar wake.
    CGDirectDisplayID displays[16];
    uint32_t count = 0;
    if (CGGetActiveDisplayList(16, displays, &count) != kCGErrorSuccess) return NO;
    for (uint32_t index = 0; index < count; index++)
        if (CGDisplayIsBuiltin(displays[index]) && !CGDisplayIsAsleep(displays[index])) return YES;
    return NO;
}
- (BOOL)requestImmediateOff {
    if (!_available) return NO;
    @try { return [_client turnOffWithPeriod:0.0f]; }
    @catch (NSException *exception) { (void)exception; return NO; }
}
- (BOOL)requestOn {
    if (!_available || ![self sessionAllowsControl]) return NO;
    @try { return [_client turnOn]; }
    @catch (NSException *exception) { (void)exception; return NO; }
}
@end
