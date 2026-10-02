// Used against both the baseline and current Sources directories. Hardware
// workloads call read methods only; UI workloads use the preview controller.
#define main TBApplicationMain
#import "main.m"
#undef main
#include <time.h>

@interface BenchmarkWindow : NSWindow
@property(nonatomic) BOOL benchmarkVisible;
@end
@implementation BenchmarkWindow
- (BOOL)isVisible { return self.benchmarkVisible; }
@end

static double Seconds(clockid_t clock) {
    struct timespec value;
    clock_gettime(clock, &value);
    return value.tv_sec + value.tv_nsec / 1e9;
}

static void ReadPower(TBRealHardware *hardware) {
    if ([hardware readPowerState] == TBPowerStateUnknown) {
        fputs("Power reading unavailable during benchmark.\n", stderr);
        exit(3);
    }
}
static void ReadIdle(TBRealHardware *hardware) {
    double idle = [hardware inputIdleSeconds];
    if (!isfinite(idle) || idle < 0) {
        fputs("Input-idle reading unavailable during benchmark.\n", stderr);
        exit(3);
    }
}
static void ReadBrightness(TBRealHardware *hardware) {
    TBBrightnessState *state = [hardware readBrightnessState];
    if (!state || !isfinite(state.driverNits) || !isfinite(state.physicalNits) ||
        !isfinite(state.hardwareMinimumNits) || !isfinite(state.hardwareMaximumNits)) {
        fputs("Brightness reading unavailable during benchmark.\n", stderr);
        exit(3);
    }
}
static void ReadSession(TBRealHardware *hardware) {
    if (![hardware sessionAllowsControl]) {
        fputs("Benchmark requires an active, unlocked session.\n", stderr);
        exit(3);
    }
}

static NSDictionary *Measure(NSUInteger count, void (^work)(NSUInteger)) {
    double cpu = Seconds(CLOCK_PROCESS_CPUTIME_ID), wall = Seconds(CLOCK_MONOTONIC);
    for (NSUInteger i = 0; i < count; i++) {
        @autoreleasepool { work(i); }
    }
    wall = Seconds(CLOCK_MONOTONIC) - wall;
    cpu = Seconds(CLOCK_PROCESS_CPUTIME_ID) - cpu;
    return @{@"iterations":@(count), @"wall_us_per_iteration":@(wall * 1e6 / count),
             @"cpu_us_per_iteration":@(cpu * 1e6 / count), @"elapsed_seconds":@(wall)};
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        TBAppDelegate *delegate = [TBAppDelegate new];
        delegate.preview = YES;
        TBPreviewHardware *preview = [TBPreviewHardware new];
        preview.state = TBPowerStateOn;
        delegate.controller = [[TBController alloc] initWithHardware:preview];
        [delegate.controller resumeOnAtTime:NSProcessInfo.processInfo.systemUptime];
        [delegate buildMenus];
        [delegate buildWindow];
        // Exercise AppKit setters without displaying or activating any windows.
        BenchmarkWindow *window = [[BenchmarkWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 570)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        window.contentView = delegate.window.contentView;
        delegate.window = window;
        window.benchmarkVisible = YES;
        for (NSUInteger i = 0; i < 100; i++) [delegate refresh];
        NSMutableDictionary *results = [NSMutableDictionary new];
        results[@"ui_visible"] = Measure(20000, ^(NSUInteger i) { (void)i; [delegate refresh]; });
        window.benchmarkVisible = NO;
        results[@"ui_hidden"] = Measure(20000, ^(NSUInteger i) { (void)i; [delegate refresh]; });

        TBRealHardware *hardware = [TBRealHardware new];
        if (!hardware.available || !hardware.normalBrightnessAvailable) {
            fputs("Read-only hardware benchmark requires the supported Touch Bar.\n", stderr);
            return 3;
        }
        for (NSUInteger i = 0; i < 20; i++) {
            ReadPower(hardware);
            ReadIdle(hardware);
            ReadBrightness(hardware);
        }
        results[@"power_read"] = Measure(2000, ^(NSUInteger i) { (void)i; ReadPower(hardware); });
        results[@"idle_read"] = Measure(2000, ^(NSUInteger i) { (void)i; ReadIdle(hardware); });
        results[@"session_read"] = Measure(1000, ^(NSUInteger i) { (void)i; ReadSession(hardware); });
        results[@"brightness_read"] = Measure(300, ^(NSUInteger i) { (void)i; ReadBrightness(hardware); });
        // A read-only approximation of steady On monitoring: 10 Hz power,
        // session and idle reads; 2 Hz brightness reads; hidden UI refresh.
        // This measures our process CPU, not server CPU or battery consumption.
        results[@"paced_read_loop"] = Measure(100, ^(NSUInteger i) {
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.1];
            ReadPower(hardware);
            ReadSession(hardware);
            ReadIdle(hardware);
            if (i % 5 == 0) ReadBrightness(hardware);
            [delegate refresh];
            [NSRunLoop.currentRunLoop runUntilDate:deadline];
        });
        TBPrintJSON(results);
        [delegate applicationWillTerminate:[NSNotification notificationWithName:NSApplicationWillTerminateNotification object:NSApp]];
    }
    return 0;
}
