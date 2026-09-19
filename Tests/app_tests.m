// Exercise the app delegate with its preview hardware. Real device access aborts.
#define main TBApplicationMain
#import "../Sources/main.m"
#undef main

static NSUInteger assertions = 0;
#define CHECK(condition) do { \
    assertions++; \
    if (!(condition)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); exit(1); } \
} while (0)

TBPowerState TBReadPowerState(void) { abort(); }
NSString *TBPowerStateName(TBPowerState state) {
    return state == TBPowerStateOn ? @"On" : state == TBPowerStateOff ? @"Off" : @"Unavailable";
}
@implementation TBRealHardware
- (instancetype)init { abort(); }
- (BOOL)available { abort(); }
- (NSString *)unavailabilityReason { abort(); }
- (BOOL)normalBrightnessAvailable { abort(); }
- (NSString *)brightnessUnavailabilityReason { abort(); }
- (TBPowerState)readPowerState { abort(); }
- (NSTimeInterval)inputIdleSeconds { abort(); }
- (BOOL)sessionAllowsControl { abort(); }
- (TBBrightnessState *)readBrightnessState { abort(); }
- (BOOL)applyNormalBrightnessAtNits:(double)nits { (void)nits; abort(); }
- (BOOL)requestImmediateOff { abort(); }
- (BOOL)requestOn { abort(); }
- (BOOL)restoreOriginalBrightnessPolicy { abort(); }
@end

@interface TestAppDelegate : TBAppDelegate
@end
@implementation TestAppDelegate
- (void)showWindow:(id)sender { (void)sender; [self refreshLoginItem]; } // No foreground activation.
@end

@interface IdlePreviewHardware : TBPreviewHardware
@property(nonatomic) NSTimeInterval idle;
@end
@implementation IdlePreviewHardware
- (NSTimeInterval)inputIdleSeconds { return self.idle; }
@end

@interface FakeLoginItem : TBLoginItem
@property(nonatomic) TBLoginItemStatus simulatedStatus;
@property(nonatomic) TBLoginItemStatus registrationResult;
@property(nonatomic) BOOL rejectChange;
@property(nonatomic) NSUInteger changes;
@end
@implementation FakeLoginItem
- (TBLoginItemStatus)status { return self.simulatedStatus; }
- (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error {
    self.changes++;
    if (self.rejectChange) {
        if (error) *error = [NSError errorWithDomain:@"Test" code:1
                                           userInfo:@{NSLocalizedDescriptionKey:@"Registration rejected"}];
        return NO;
    }
    self.simulatedStatus = enabled ? self.registrationResult : TBLoginItemDisabled;
    return YES;
}
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        TestAppDelegate *delegate = [TestAppDelegate new];
        delegate.preview = YES;
        [delegate applicationDidFinishLaunching:[NSNotification notificationWithName:NSApplicationDidFinishLaunchingNotification object:NSApp]];
        // Ordinary launch should activate On and the idle guard, without a click.
        CHECK(!delegate.controller.requestedOff && delegate.controller.guardingBrightness);
        [delegate.timer fire];
        CHECK(delegate.controller.observedState == TBPowerStateOn);
        CHECK(!delegate.controller.failed);

        // Preview toggles are in-memory and do not persist into a new preview.
        CHECK(delegate.launchAtLoginButton.state == NSControlStateValueOff);
        [delegate toggleLaunchAtLogin:nil];
        CHECK(delegate.loginItem.status == TBLoginItemEnabled);
        CHECK(delegate.launchAtLoginButton.state == NSControlStateValueOn);
        CHECK(delegate.launchAtLoginMenuItem.state == NSControlStateValueOn);
        CHECK([[TBLoginItem alloc] initWithPreview:YES].status == TBLoginItemDisabled);
        [delegate toggleLaunchAtLogin:nil];
        CHECK(delegate.loginItem.status == TBLoginItemDisabled);

        // OS state is authoritative, including failure, pending approval, and changes in Settings.
        FakeLoginItem *login = [FakeLoginItem new];
        login.simulatedStatus = TBLoginItemDisabled;
        login.registrationResult = TBLoginItemEnabled;
        delegate.loginItem = login;
        delegate.preview = NO; // Hardware is still simulated; show the real status messages.
        [delegate refreshLoginItem];
        CHECK(login.changes == 0);
        login.rejectChange = YES;
        [delegate toggleLaunchAtLogin:nil];
        CHECK(delegate.launchAtLoginButton.state == NSControlStateValueOff);
        CHECK([delegate.loginItemMessage.stringValue containsString:@"Registration rejected"]);
        CHECK([delegate.loginItemMessage.textColor isEqual:NSColor.systemRedColor]);
        [delegate applicationDidBecomeActive:[NSNotification notificationWithName:NSApplicationDidBecomeActiveNotification object:NSApp]];
        CHECK([delegate.loginItemMessage.stringValue containsString:@"Registration rejected"]);
        login.rejectChange = NO;
        login.registrationResult = TBLoginItemRequiresApproval;
        [delegate toggleLaunchAtLogin:nil];
        CHECK(delegate.launchAtLoginButton.state == NSControlStateValueMixed);
        CHECK(!delegate.loginItemSettingsButton.hidden);
        CHECK([delegate.loginItemMessage.stringValue containsString:@"Permission"]);
        [delegate toggleLaunchAtLogin:nil]; // Pending registrations can also be removed.
        CHECK(login.status == TBLoginItemDisabled && delegate.loginItemSettingsButton.hidden);
        login.registrationResult = TBLoginItemEnabled;
        [delegate toggleLaunchAtLogin:nil];
        CHECK(delegate.launchAtLoginButton.state == NSControlStateValueOn);
        login.rejectChange = YES;
        [delegate toggleLaunchAtLogin:nil];
        CHECK(delegate.launchAtLoginButton.state == NSControlStateValueOn);
        CHECK([delegate.loginItemMessage.stringValue containsString:@"Registration rejected"]);
        login.simulatedStatus = TBLoginItemDisabled; // Changed outside the app.
        [delegate applicationDidBecomeActive:[NSNotification notificationWithName:NSApplicationDidBecomeActiveNotification object:NSApp]];
        CHECK(delegate.launchAtLoginButton.state == NSControlStateValueOff);
        login.simulatedStatus = TBLoginItemEnabled;
        [delegate menuWillOpen:delegate.statusItem.menu];
        CHECK(delegate.launchAtLoginMenuItem.state == NSControlStateValueOn);
        login.simulatedStatus = TBLoginItemUnavailable;
        [delegate refreshLoginItem];
        CHECK(!delegate.launchAtLoginButton.enabled && !delegate.launchAtLoginMenuItem.enabled);
        login.simulatedStatus = TBLoginItemNotFound;
        [delegate refreshLoginItem];
        CHECK(delegate.launchAtLoginButton.enabled && delegate.launchAtLoginButton.state == NSControlStateValueOff);

        // Closing a window leaves the live timer enforcing the idle deadline.
        IdlePreviewHardware *hardware = [IdlePreviewHardware new];
        hardware.state = TBPowerStateOn;
        delegate.controller = [[TBController alloc] initWithHardware:hardware];
        [delegate.controller resumeOnAtTime:NSProcessInfo.processInfo.systemUptime];
        [delegate.window close];
        CHECK(![delegate applicationShouldTerminateAfterLastWindowClosed:NSApp]);
        CHECK(delegate.timer.valid);
        hardware.idle = 55;
        [delegate.timer fire];
        CHECK(delegate.controller.idleOff && hardware.state == TBPowerStateOff);

        // Screensaver events preserve the idle deadline; the timer enforces Off at 55.
        hardware.idle = 0;
        [delegate.controller turnOnAtTime:NSProcessInfo.processInfo.systemUptime];
        [delegate screensaverChanged:[NSNotification notificationWithName:@"com.apple.screensaver.didstart" object:nil]];
        CHECK(delegate.controller.screensaverActive && !delegate.controller.idleOff);
        CHECK(hardware.state == TBPowerStateOn);
        hardware.idle = 54.99;
        [delegate.timer fire];
        CHECK(!delegate.controller.idleOff && hardware.state == TBPowerStateOn);
        hardware.idle = 55;
        [delegate.timer fire];
        CHECK(delegate.controller.idleOff && hardware.state == TBPowerStateOff);
        [delegate screensaverChanged:[NSNotification notificationWithName:@"com.apple.screensaver.didstop" object:nil]];
        CHECK(!delegate.controller.screensaverActive && delegate.controller.idleOff);
        CHECK(hardware.state == TBPowerStateOff); // Stopping the saver alone does not authorize On.

        [delegate applicationWillTerminate:[NSNotification notificationWithName:NSApplicationWillTerminateNotification object:NSApp]];
        CHECK(!delegate.timer.valid && !delegate.controller.guardingBrightness);
        printf("PASS: %lu app lifecycle and login-item assertions. Real hardware access aborts.\n", (unsigned long)assertions);
    }
    return 0;
}
