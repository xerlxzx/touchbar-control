#import <Cocoa/Cocoa.h>
#import "TBController.h"
#import "TBBrightnessPreference.h"
#include <math.h>

static NSString *const TBBundleIdentifier = @"local.touchbarcontrol";

@interface TBStepSlider : NSSlider
@property(nonatomic) BOOL trackingPointer;
@end
@implementation TBStepSlider
- (void)mouseDown:(NSEvent *)event {
    self.trackingPointer = YES;
    @try { [super mouseDown:event]; }
    @finally { self.trackingPointer = NO; }
}
@end

// A UI preview never constructs the real hardware provider.
@interface TBPreviewHardware : NSObject <TBHardware>
@property(nonatomic) TBPowerState state;
@property(nonatomic, strong) TBBrightnessState *brightnessState;
@end
@implementation TBPreviewHardware
- (BOOL)available { return YES; }
- (NSString *)unavailabilityReason { return @""; }
- (BOOL)normalBrightnessAvailable { return YES; }
- (NSTimeInterval)inputIdleSeconds { return 0; }
- (BOOL)sessionAllowsControl { return YES; }
- (NSString *)brightnessUnavailabilityReason { return @""; }
- (TBBrightnessState *)readBrightnessState {
    if (!self.brightnessState) [self applyNormalBrightnessAtNits:184.5];
    return self.brightnessState;
}
- (BOOL)applyNormalBrightnessAtNits:(double)nits {
    self.brightnessState = [TBBrightnessState new];
    self.brightnessState.displayID = 3;
    self.brightnessState.minimum = 0.25;
    self.brightnessState.hardwareMinimumNits = 11.899;
    self.brightnessState.hardwareMaximumNits = 357.099;
    self.brightnessState.brightness = (nits - 11.899) / (357.099 - 11.899);
    self.brightnessState.physicalNits = nits;
    self.brightnessState.driverNits = round(nits);
    self.brightnessState.dimmingStep = 0;
    self.brightnessState.automaticBrightness = 0;
    self.brightnessState.normalConfiguration = YES;
    return YES;
}
- (TBPowerState)readPowerState { return self.state; }
- (BOOL)requestImmediateOff { self.state = TBPowerStateOff; return YES; }
- (BOOL)requestOn {
    self.state = TBPowerStateOn;
    [self applyNormalBrightnessAtNits:184.5];
    self.brightnessState.physicalNits = 12;
    self.brightnessState.driverNits = 12;
    self.brightnessState.normalConfiguration = NO;
    return YES;
}
@end

static NSTextField *TBLabel(NSString *text, NSFont *font) {
    NSTextField *label = [NSTextField wrappingLabelWithString:text];
    label.font = font;
    label.selectable = NO;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

@interface TBAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic) BOOL preview;
@property(nonatomic) BOOL resumeOn;
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) TBController *controller;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSTextField *requestedLabel;
@property(nonatomic, strong) NSTextField *observedLabel;
@property(nonatomic, strong) NSTextField *messageLabel;
@property(nonatomic, strong) NSButton *offButton;
@property(nonatomic, strong) NSButton *onButton;
@property(nonatomic, strong) TBStepSlider *brightnessSlider;
@property(nonatomic, strong) NSTextField *brightnessLabel;
@property(nonatomic, strong) TBBrightnessPreference *brightnessPreference;
@property(nonatomic, strong) NSMenuItem *statusLine;
@property(nonatomic, strong) NSMenuItem *offMenuItem;
@property(nonatomic, strong) NSMenuItem *onMenuItem;
@property(nonatomic, strong) NSMenuItem *offActionMenuItem;
@property(nonatomic, strong) NSMenuItem *onActionMenuItem;
@property(nonatomic, strong) id activity;
@property(nonatomic) BOOL systemSleeping;
@property(nonatomic) BOOL screensSleeping;
@end

@implementation TBAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    id<TBHardware> hardware;
    if (self.preview) {
        TBPreviewHardware *preview = [TBPreviewHardware new];
        preview.state = TBPowerStateOff;
        hardware = preview;
    } else {
        hardware = [TBRealHardware new];
    }
    self.controller = [[TBController alloc] initWithHardware:hardware];
    // Preview is entirely in memory and cannot read or overwrite the user's saved selection.
    id<TBPreferenceStore> store = self.preview ? nil : (id<TBPreferenceStore>)NSUserDefaults.standardUserDefaults;
    self.brightnessPreference = [[TBBrightnessPreference alloc] initWithStore:store];
    [self.controller setBrightnessPercent:self.brightnessPreference.percent atTime:NSProcessInfo.processInfo.systemUptime];
    [self buildMenus];
    [self buildWindow];
    if (self.resumeOn) [self.controller resumeOnAtTime:NSProcessInfo.processInfo.systemUptime];
    else [self.controller keepOffAtTime:NSProcessInfo.processInfo.systemUptime];
    [self refresh];
    __weak TBAppDelegate *weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        TBAppDelegate *self = weakSelf;
        if (!self) return;
        [self.controller pollAtTime:NSProcessInfo.processInfo.systemUptime];
        [self refresh];
    }];
    self.timer.tolerance = 0.02;
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    NSNotificationCenter *notifications = NSWorkspace.sharedWorkspace.notificationCenter;
    [notifications addObserver:self selector:@selector(willSleep:)
                          name:NSWorkspaceWillSleepNotification object:nil];
    [notifications addObserver:self selector:@selector(willSleep:)
                          name:NSWorkspaceScreensDidSleepNotification object:nil];
    [notifications addObserver:self selector:@selector(didWake:)
                          name:NSWorkspaceDidWakeNotification object:nil];
    [notifications addObserver:self selector:@selector(didWake:)
                          name:NSWorkspaceScreensDidWakeNotification object:nil];
    [self showWindow:nil];
}

- (void)buildMenus {
    NSMenu *main = [NSMenu new];
    NSMenuItem *appItem = [NSMenuItem new];
    [main addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Touch Bar Control"];
    appItem.submenu = appMenu;
    NSMenuItem *about = [appMenu addItemWithTitle:@"About Touch Bar Control"
                                        action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    about.target = NSApp;
    [appMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [appMenu addItemWithTitle:@"Quit Touch Bar Control"
                                       action:@selector(terminate:) keyEquivalent:@"q"];
    quit.target = NSApp;
    NSMenuItem *controlItem = [NSMenuItem new];
    [main addItem:controlItem];
    NSMenu *controlMenu = [[NSMenu alloc] initWithTitle:@"Control"];
    controlMenu.autoenablesItems = NO;
    controlItem.submenu = controlMenu;
    self.offActionMenuItem = [controlMenu addItemWithTitle:@"Keep Touch Bar off"
                                                  action:@selector(keepOff:) keyEquivalent:@"o"];
    self.onActionMenuItem = [controlMenu addItemWithTitle:@"Turn Touch Bar on"
                                                 action:@selector(turnOn:) keyEquivalent:@"i"];
    for (NSMenuItem *item in @[self.offActionMenuItem, self.onActionMenuItem]) {
        item.target = self;
        item.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    }
    NSMenuItem *windowItem = [NSMenuItem new];
    [main addItem:windowItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    windowItem.submenu = windowMenu;
    NSMenuItem *show = [windowMenu addItemWithTitle:@"Show Touch Bar Control"
                                           action:@selector(showWindow:) keyEquivalent:@"1"];
    show.target = self;
    [windowMenu addItemWithTitle:@"Close window" action:@selector(performClose:) keyEquivalent:@"w"];
    NSApp.mainMenu = main;
    NSApp.windowsMenu = windowMenu;

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    NSImage *symbol = [NSImage imageWithSystemSymbolName:@"keyboard" accessibilityDescription:@"Touch Bar Control"];
    symbol.template = YES;
    self.statusItem.button.image = symbol;
    if (!symbol) self.statusItem.button.title = @"TB";
    self.statusItem.button.accessibilityLabel = @"Touch Bar Control";
    NSMenu *statusMenu = [NSMenu new];
    statusMenu.autoenablesItems = NO;
    self.statusLine = [statusMenu addItemWithTitle:@"Touch Bar: checking…" action:nil keyEquivalent:@""];
    self.statusLine.enabled = NO;
    [statusMenu addItem:NSMenuItem.separatorItem];
    show = [statusMenu addItemWithTitle:@"Show Touch Bar Control" action:@selector(showWindow:) keyEquivalent:@""];
    show.target = self;
    self.offMenuItem = [statusMenu addItemWithTitle:@"Keep Touch Bar off" action:@selector(keepOff:) keyEquivalent:@""];
    self.offMenuItem.target = self;
    self.onMenuItem = [statusMenu addItemWithTitle:@"Turn Touch Bar on" action:@selector(turnOn:) keyEquivalent:@""];
    self.onMenuItem.target = self;
    [statusMenu addItem:NSMenuItem.separatorItem];
    quit = [statusMenu addItemWithTitle:@"Quit Touch Bar Control" action:@selector(terminate:) keyEquivalent:@"q"];
    quit.target = NSApp;
    self.statusItem.menu = statusMenu;
}

- (void)buildWindow {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 450)
                                            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                      NSWindowStyleMaskMiniaturizable
                                              backing:NSBackingStoreBuffered defer:NO];
    self.window.title = self.preview ? @"Touch Bar Control — Preview" : @"Touch Bar Control";
    self.window.releasedWhenClosed = NO;
    self.window.delegate = self;
    [self.window center];

    NSStackView *stack = [NSStackView new];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor constant:22]
    ]];

    NSStackView *heading = [NSStackView new];
    heading.orientation = NSUserInterfaceLayoutOrientationVertical;
    heading.alignment = NSLayoutAttributeLeading;
    heading.spacing = 5;
    [heading addArrangedSubview:TBLabel(@"Touch Bar", [NSFont systemFontOfSize:24 weight:NSFontWeightSemibold])];
    NSTextField *subtitle = TBLabel(self.preview ? @"Preview — controls do not affect your Touch Bar."
                                                 : @"Turn the strip on or keep it off.",
                                    [NSFont systemFontOfSize:13]);
    subtitle.textColor = NSColor.secondaryLabelColor;
    [heading addArrangedSubview:subtitle];
    [stack addArrangedSubview:heading];

    NSBox *statusBox = [NSBox new];
    statusBox.boxType = NSBoxPrimary;
    statusBox.title = @"Status";
    statusBox.contentViewMargins = NSMakeSize(12, 10);
    statusBox.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:statusBox];
    [statusBox.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [statusBox.heightAnchor constraintEqualToConstant:90].active = YES;

    NSTextField *requestedTitle = TBLabel(@"Requested", [NSFont systemFontOfSize:13]);
    requestedTitle.textColor = NSColor.secondaryLabelColor;
    NSTextField *observedTitle = TBLabel(@"Observed", [NSFont systemFontOfSize:13]);
    observedTitle.textColor = NSColor.secondaryLabelColor;
    self.requestedLabel = TBLabel(@"Keep off", [NSFont systemFontOfSize:13 weight:NSFontWeightMedium]);
    self.observedLabel = TBLabel(@"Checking…", [NSFont systemFontOfSize:13 weight:NSFontWeightMedium]);
    self.requestedLabel.accessibilityLabel = @"Requested Touch Bar state";
    self.observedLabel.accessibilityLabel = @"Observed Touch Bar power state";
    NSGridView *grid = [NSGridView gridViewWithViews:@[@[requestedTitle, self.requestedLabel],
                                                     @[observedTitle, self.observedLabel]]];
    grid.rowSpacing = 9;
    grid.columnSpacing = 22;
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    [statusBox.contentView addSubview:grid];
    [NSLayoutConstraint activateConstraints:@[
        [grid.leadingAnchor constraintEqualToAnchor:statusBox.contentView.leadingAnchor],
        [grid.topAnchor constraintEqualToAnchor:statusBox.contentView.topAnchor],
        [grid.trailingAnchor constraintLessThanOrEqualToAnchor:statusBox.contentView.trailingAnchor]
    ]];

    NSStackView *brightnessGroup = [NSStackView new];
    brightnessGroup.orientation = NSUserInterfaceLayoutOrientationVertical;
    brightnessGroup.alignment = NSLayoutAttributeLeading;
    brightnessGroup.spacing = 6;
    [stack addArrangedSubview:brightnessGroup];
    [brightnessGroup.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    self.brightnessLabel = TBLabel(@"Brightness 50%", [NSFont systemFontOfSize:13 weight:NSFontWeightMedium]);
    [brightnessGroup addArrangedSubview:self.brightnessLabel];
    self.brightnessSlider = [TBStepSlider sliderWithValue:50 minValue:50 maxValue:100 target:self action:@selector(changeBrightness:)];
    self.brightnessSlider.numberOfTickMarks = 6;
    self.brightnessSlider.allowsTickMarkValuesOnly = YES;
    self.brightnessSlider.continuous = NO; // Commit on release; dragging does not send a stream of writes.
    self.brightnessSlider.accessibilityLabel = @"Touch Bar brightness";
    self.brightnessSlider.accessibilityHelp = @"50 to 100 percent, in steps of 10. Changes while off are saved for the next time it turns on.";
    [brightnessGroup addArrangedSubview:self.brightnessSlider];
    [self.brightnessSlider.widthAnchor constraintEqualToAnchor:brightnessGroup.widthAnchor].active = YES;
    NSTextField *brightnessHint = TBLabel(@"50% is the tested working minimum. Changes while off are saved.", [NSFont systemFontOfSize:11]);
    brightnessHint.textColor = NSColor.secondaryLabelColor;
    [brightnessGroup addArrangedSubview:brightnessHint];
    [brightnessHint.widthAnchor constraintEqualToAnchor:brightnessGroup.widthAnchor].active = YES;

    self.messageLabel = TBLabel(@"Starting…", [NSFont systemFontOfSize:13]);
    self.messageLabel.maximumNumberOfLines = 3;
    [stack addArrangedSubview:self.messageLabel];
    [self.messageLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [self.messageLabel.heightAnchor constraintEqualToConstant:48].active = YES;
    [stack setCustomSpacing:10 afterView:self.messageLabel];

    NSStackView *buttons = [NSStackView new];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.spacing = 10;
    self.offButton = [NSButton buttonWithTitle:@"Keep Touch Bar off" target:self action:@selector(keepOff:)];
    self.onButton = [NSButton buttonWithTitle:@"Turn Touch Bar on" target:self action:@selector(turnOn:)];
    self.offButton.bezelStyle = NSBezelStyleRounded;
    self.onButton.bezelStyle = NSBezelStyleRounded;
    self.offButton.controlSize = NSControlSizeLarge;
    self.onButton.controlSize = NSControlSizeLarge;
    self.offButton.toolTip = @"Keep the Touch Bar dark until you turn it on or quit this app.";
    self.onButton.toolTip = @"Use normal Touch Bar controls at your selected brightness, with automatic off after 55 seconds idle.";
    [buttons addArrangedSubview:self.offButton];
    [buttons addArrangedSubview:self.onButton];
    [stack addArrangedSubview:buttons];

    NSTextField *footer = TBLabel(@"Starts with the Touch Bar off. Closing this window keeps control running in the menu bar. Quitting stops control without turning it on.", [NSFont systemFontOfSize:11]);
    footer.textColor = NSColor.secondaryLabelColor;
    [stack addArrangedSubview:footer];
    [footer.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [stack.bottomAnchor constraintLessThanOrEqualToAnchor:self.window.contentView.bottomAnchor constant:-18].active = YES;
}

- (void)refresh {
    TBController *controller = self.controller;
    NSString *requested = controller.requestedOff ? @"Keep off" : [NSString stringWithFormat:@"On · %ld%% brightness", (long)controller.selectedBrightnessPercent];
    if (controller.failed) requested = [requested stringByAppendingString:@" · paused"];
    else if (controller.sleeping) requested = [requested stringByAppendingString:@" · sleeping"];
    else if (controller.idleOff) requested = [requested stringByAppendingString:@" · idle"];
    else if (controller.holdingOff) requested = [requested stringByAppendingString:@" · active"];
    self.requestedLabel.stringValue = requested;
    NSInteger displayedPercent = self.brightnessSlider.trackingPointer
        ? TBSnapBrightnessPercent(self.brightnessSlider.doubleValue) : controller.selectedBrightnessPercent;
    self.brightnessLabel.stringValue = [NSString stringWithFormat:@"Brightness %ld%%", (long)displayedPercent];
    // Avoid moving the thumb back to the committed value while the user drags it.
    if (!self.brightnessSlider.trackingPointer) self.brightnessSlider.doubleValue = controller.selectedBrightnessPercent;
    self.brightnessSlider.enabled = controller.normalBrightnessAvailable;
    NSString *observed = TBPowerStateName(controller.observedState);
    if (!controller.sleeping && controller.observedState == TBPowerStateOn &&
        !controller.requestedOff && !controller.idleOff && isfinite(controller.brightnessState.driverNits) && controller.brightnessState) {
        observed = [NSString stringWithFormat:@"On · %.0f nits reported%@", controller.brightnessState.driverNits,
                    controller.brightnessVerified ? @" · verified" : @""];
    }
    self.observedLabel.stringValue = controller.sleeping
        ? [NSString stringWithFormat:@"Sleeping · last reported %@", TBPowerStateName(controller.observedState)]
        : observed;
    BOOL messageChanged = ![self.messageLabel.stringValue isEqualToString:controller.message];
    self.messageLabel.stringValue = controller.message;
    self.messageLabel.textColor = controller.failed ? NSColor.systemRedColor : NSColor.labelColor;
    BOOL canRetryOff = controller.available && (!controller.holdingOff || controller.idleOff);
    self.offButton.enabled = canRetryOff;
    self.onButton.enabled = controller.available && controller.normalBrightnessAvailable;
    self.offMenuItem.enabled = canRetryOff;
    self.onMenuItem.enabled = self.onButton.enabled;
    self.offActionMenuItem.enabled = canRetryOff;
    self.onActionMenuItem.enabled = self.onButton.enabled;
    self.offMenuItem.state = controller.holdingOff && controller.requestedOff ? NSControlStateValueOn : NSControlStateValueOff;
    self.onMenuItem.state = (!controller.requestedOff && !controller.failed) ? NSControlStateValueOn : NSControlStateValueOff;
    self.statusLine.title = [NSString stringWithFormat:@"Touch Bar: %@%@", TBPowerStateName(controller.observedState),
                            controller.failed ? @" · control paused" : controller.idleOff ? @" · idle protection" : controller.holdingOff ? @" · keeping off" : @""];
    self.statusItem.button.toolTip = self.statusLine.title;
    BOOL needsActivity = (controller.holdingOff || controller.guardingBrightness) && !controller.sleeping;
    if (needsActivity && !self.activity) {
        // Prevent App Nap while monitoring, without preventing display or system sleep.
        self.activity = [NSProcessInfo.processInfo beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep
                                                                   reason:@"Maintain Touch Bar control"];
    } else if (!needsActivity && self.activity) {
        [NSProcessInfo.processInfo endActivity:self.activity];
        self.activity = nil;
    }
    if (messageChanged && controller.failed)
        NSAccessibilityPostNotification(self.messageLabel, NSAccessibilityValueChangedNotification);
}

- (void)keepOff:(id)sender {
    (void)sender;
    [self.controller keepOffAtTime:NSProcessInfo.processInfo.systemUptime];
    [self refresh];
}
- (void)turnOn:(id)sender {
    (void)sender;
    [self.controller turnOnAtTime:NSProcessInfo.processInfo.systemUptime];
    [self refresh];
}
- (void)changeBrightness:(id)sender {
    (void)sender;
    [self.brightnessPreference setSelectedPercent:self.brightnessSlider.doubleValue];
    [self.controller setBrightnessPercent:self.brightnessPreference.percent atTime:NSProcessInfo.processInfo.systemUptime];
    [self refresh];
}
- (void)showWindow:(id)sender {
    (void)sender;
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
- (void)willSleep:(NSNotification *)notification {
    if ([notification.name isEqualToString:NSWorkspaceWillSleepNotification]) self.systemSleeping = YES;
    else self.screensSleeping = YES;
    [self.controller prepareForSleep];
    [self refresh];
}
- (void)didWake:(NSNotification *)notification {
    if ([notification.name isEqualToString:NSWorkspaceDidWakeNotification]) self.systemSleeping = NO;
    else self.screensSleeping = NO;
    if (!self.systemSleeping && !self.screensSleeping)
        [self.controller resumeAtTime:NSProcessInfo.processInfo.systemUptime];
    [self refresh];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    (void)sender; (void)flag;
    [self showWindow:nil];
    return YES;
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return NO;
}
- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.timer invalidate];
    [self.controller stop];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    if (self.activity) [NSProcessInfo.processInfo endActivity:self.activity];
    if (self.statusItem) [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
}
@end

static id TBJSONNumber(double value) { return isfinite(value) ? @(value) : NSNull.null; }

static NSDictionary *TBBrightnessJSON(TBRealHardware *hardware) {
    TBBrightnessState *state = [hardware readBrightnessState];
    return @{@"supported":@(hardware.normalBrightnessAvailable),
             @"reason":hardware.brightnessUnavailabilityReason ?: @"",
             @"displayID":state ? @(state.displayID) : NSNull.null,
             @"minimum":state ? TBJSONNumber(state.minimum) : NSNull.null,
             @"automaticBrightness":state && state.automaticBrightness >= 0 ? @(state.automaticBrightness) : NSNull.null,
             @"brightness":state ? TBJSONNumber(state.brightness) : NSNull.null,
             @"physicalNits":state ? TBJSONNumber(state.physicalNits) : NSNull.null,
             @"driverNits":state ? TBJSONNumber(state.driverNits) : NSNull.null,
             @"hardwareMinimumNits":state ? TBJSONNumber(state.hardwareMinimumNits) : NSNull.null,
             @"hardwareMaximumNits":state ? TBJSONNumber(state.hardwareMaximumNits) : NSNull.null,
             @"dimmingStep":state && state.dimmingStep >= 0 ? @(state.dimmingStep) : NSNull.null};
}

static void TBPrintJSON(NSDictionary *value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:NULL];
    puts(data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String : "{}");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 2 && strcmp(argv[1], "--status") == 0) {
            TBPowerState state = TBReadPowerState();
            printf("{\"observed_power_state\":%ld,\"observed\":\"%s\",\"read_only\":true}\n",
                   (long)state, TBPowerStateName(state).UTF8String);
            return state == TBPowerStateUnknown ? 3 : 0;
        }
        if (argc == 2 && strcmp(argv[1], "--version") == 0) {
            puts("Touch Bar Control 1.3.0");
            return 0;
        }
        if (argc == 2 && strcmp(argv[1], "--help") == 0) {
            puts("Usage: Touch Bar Control [--status | --brightness-status | --activity-status | --preview | --resume-on | --restore-original-policy | --version | --help]\n"
                 "No arguments: open the app and keep the Touch Bar off.\n"
                 "--status: read hardware power state without sending commands.\n"
                 "--brightness-status: read brightness telemetry without sending commands.\n"
                 "--activity-status: read input-idle time and session eligibility; no key events or commands.\n"
                 "--preview: open a simulated UI; never access hardware.\n"
                 "--resume-on: adopt On mode without an initial power-on command; includes idle protection.\n"
                 "--restore-original-policy: explicitly restore this Mac's original Touch Bar minimum0 and automatic brightness. Quit the app first; flashing may return.");
            return 0;
        }
        if (argc == 2 && strcmp(argv[1], "--brightness-status") == 0) {
            TBRealHardware *hardware = [TBRealHardware new];
            TBPrintJSON(@{@"read_only":@YES, @"brightness":TBBrightnessJSON(hardware), @"powerState":@(TBReadPowerState())});
            return hardware.normalBrightnessAvailable ? 0 : 3;
        }
        if (argc == 2 && strcmp(argv[1], "--activity-status") == 0) {
            TBRealHardware *hardware = [TBRealHardware new];
            NSTimeInterval idle = [hardware inputIdleSeconds];
            TBPrintJSON(@{@"read_only":@YES, @"inputIdleSeconds":TBJSONNumber(idle),
                          @"sessionAllowsControl":@([hardware sessionAllowsControl]), @"idleOffDelaySeconds":@55});
            return isfinite(idle) && idle >= 0 ? 0 : 3;
        }
        BOOL preview = argc == 2 && strcmp(argv[1], "--preview") == 0;
        BOOL resumeOn = argc == 2 && strcmp(argv[1], "--resume-on") == 0;
        BOOL restorePolicy = argc == 2 && strcmp(argv[1], "--restore-original-policy") == 0;
        if (argc > 1 && !preview && !resumeOn && !restorePolicy) {
            fputs("Unknown arguments. Use --help.\n", stderr);
            return 2;
        }
        // Launch Services normally ensures this; also protect direct executable launches.
        for (NSRunningApplication *application in [NSRunningApplication runningApplicationsWithBundleIdentifier:TBBundleIdentifier]) {
            if (application.processIdentifier != NSProcessInfo.processInfo.processIdentifier) {
                if (preview || resumeOn || restorePolicy) {
                    fputs("Action not started: Touch Bar Control is already running. Quit that instance first.\n", stderr);
                    return 4;
                }
                [application activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];
                return 0;
            }
        }
        if (restorePolicy) {
            TBRealHardware *hardware = [TBRealHardware new];
            NSDictionary *before = TBBrightnessJSON(hardware);
            BOOL accepted = [hardware restoreOriginalBrightnessPolicy];
            BOOL verified = NO;
            if (accepted) {
                NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 2.0;
                do {
                    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                    TBBrightnessState *state = [hardware readBrightnessState];
                    verified = state && fabs(state.minimum) <= 0.0001 && state.automaticBrightness == 1;
                } while (!verified && NSProcessInfo.processInfo.systemUptime < deadline);
            }
            TBPrintJSON(@{@"action":@"restore-original-policy", @"accepted":@(accepted), @"verified":@(verified),
                          @"before":before, @"after":TBBrightnessJSON(hardware),
                          @"notice":@"Restored policy can allow low-brightness flashing again. No power-on command was sent."});
            return accepted && verified ? 0 : 5;
        }
        NSApplication *application = NSApplication.sharedApplication;
        [application setActivationPolicy:NSApplicationActivationPolicyRegular];
        TBAppDelegate *delegate = [TBAppDelegate new];
        delegate.preview = preview;
        delegate.resumeOn = resumeOn;
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
