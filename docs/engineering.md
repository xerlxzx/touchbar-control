# Engineering

Touch Bar Control is an Objective-C macOS application built with Clang and Apple's system frameworks. It has no third-party dependencies.

## Source layout

| Component | File | Responsibility |
| --- | --- | --- |
| Application | `Sources/main.m` | App lifecycle, window, menu bar, CLI dispatch, and preview hardware |
| Controller | `Sources/TBController.*` | Requested mode, observed state, idle transitions, brightness verification, and retries |
| Hardware adapter | `Sources/TBHardware.*` | Private API calls, display and session checks, and driver readings |
| Service discovery cache | `Sources/TBServiceCache.*` | Retained IORegistry service handles with termination and sleep/wake invalidation |
| Wake request | `Sources/TBWakeRequest.*` | Private wake-method signature checks and a zero-duration wake command |
| Brightness preferences | `Sources/TBBrightnessPreference.*` | Slider snapping, nits mapping, and preference storage |
| Brightness readings | `Sources/TBBrightnessState.*` | Shared values from the hardware adapter |
| Login item | `Sources/TBLoginItem.*` | System registration/status on macOS 13+, or isolated preview state |
| Controller tests | `Tests/controller_tests.m` | Fake hardware, isolated preferences, and state-transition assertions |
| App tests | `Tests/app_tests.m` | Default launch, window lifecycle, screen-saver callbacks, and login-item UI state |
| Wake tests | `Tests/wake_tests.m` | Wake arguments and failure handling with simulated private-API clients |

## Control flow

The app delegate sends control actions and monotonic timestamps to `TBController`. The controller reads and writes hardware through the `TBHardware` protocol. `TBRealHardware` implements that protocol for the physical device; preview and tests use simulated implementations.

The controller tracks requested mode apart from observed power state. The app activates On at launch after loading the saved brightness. Manual Off stays active until an explicit On request. In On mode, 55 seconds of inactivity starts an idle Off hold; new input restores On when session and display checks permit it. A nonzero dimming step can trigger Off before the idle threshold.

The delegate observes `com.apple.screensaver.didstart` and `com.apple.screensaver.didstop` through the distributed notification center, with immediate delivery while suspended. These are undocumented notifications also used by [Hammerspoon's screen-state watcher](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/caffeinate/libcaffeinate_watcher.m). Saver start or a failed session-eligibility check blocks On and brightness writes while preserving the normal 55-second inactivity threshold. The blocked-session branch still reads elapsed input-idle time and polls for native dimming, then enters and enforces Off when either guard triggers. It never powers off solely because the saver began. Saver stop does not bypass a remaining lock or authorize an idle-hold wake without new input.

Sleep notifications suspend controller actions. Recovery requires an eligible session and, after an idle hold spanning a screen saver, lock, or sleep transition, input after the session becomes eligible. Rejected commands and sustained missing readings stop control attempts.

## Control invariants

- A brightness selection while Off updates the target without powering on the strip.
- Power-on requests follow the removal of Off enforcement.
- App-issued wake uses `turnOnWithPeriod:0.0f` after checking its Objective-C signature. Unsupported, rejected, or throwing calls do not fall back to the default fade.
- Brightness writes require valid driver limits and an eligible session.
- Off enforcement allows three unverified requests. Brightness recovery allows three requests within 60 seconds, with at least one second between writes.
- Window close and ordinary Quit preserve monitoring, the App Nap activity, and controller state. The controls and Dock icon are hidden until reopened.
- Only **Stop protection and quit** or system termination stops monitoring, without sending a power-on command or resetting the brightness policy. The delegate allows quit events carrying the SDK's logout/restart/shutdown reasons, so background residency does not veto the end of a session.

The app stores the selected percentage through `TBPreferenceStore`, using `NSUserDefaults` in normal operation and isolated memory in preview and tests. The percentage snaps to six steps from 50% to 100%. See the [technical reference](technical-reference.md) for brightness mapping and platform constraints.

The 100 ms protection timer also refreshes menu state and App Nap ownership while the window is hidden. Window-only controls refresh when visible and immediately on reopening; unchanged values are not reassigned. Pointer tracking still previews the selected slider step without committing a hardware write.

The hardware adapter retains discovery handles for `backlight-dfr` and `IOHIDSystem`. It still enumerates children and reads live properties on each observation. The cache runs on the adapter's run-loop thread and releases handles after service-termination notifications, failed readings, or sleep/wake. If notifications cannot be installed, lookups remain uncached. Display identity, session eligibility, driver bounds, and the independent power-state lookup immediately before brightness writes remain freshly validated.

## Build and packaging

`build.sh` compiles for the host architecture with ARC, `-O2`, `-Wall -Wextra -Werror`, and a macOS 12 deployment target. Tests use the same optimization level. Fast-math is not enabled: missing readings rely on NaN and finite-value checks. The build links Cocoa, IOKit, CoreGraphics, and ServiceManagement, copies `Info.plist` into the app bundle, then applies and verifies an ad-hoc signature. ServiceManagement's macOS 13 login-item API is guarded by runtime availability checks.

`Resources/AppIcon.png` is the source artwork. During the build, `scripts/build-icon.sh` uses `sips` and `iconutil` to generate standard and Retina icon sizes from 16 to 1024 pixels. The bundle contains `Contents/Resources/AppIcon.icns`, referenced by `CFBundleIconFile`, before code signing.

`scripts/package.sh` runs the tests and builds into a temporary staging directory. It writes a versioned ZIP and SHA-256 checksum to `work/releases/`, then removes the staging directory. The archive name includes the bundle version and binary architecture.

`Info.plist` contains the application version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`). The CLI version string in `Sources/main.m` matches the application version.

## Test coverage

`test.sh` compiles the controller, brightness values, preferences, and fake hardware against Foundation. A second executable compiles the app delegate with Cocoa, simulated hardware, and preview/fake login items. Both exclude `TBHardware.m` and IOKit; real-device entry points in the app tests abort if reached. Login-item tests never register with ServiceManagement.

The wake API boundary has its own Foundation-only executable. Fake clients expose the real selector shapes, including deliberately incompatible ones; tests check the explicit zero-second duration, absence of default-fade calls, and bounded failure handling. No private framework is loaded by these tests.

Service-cache tests compile the production cache against fake IOKit functions. They verify reference ownership, service replacement after termination, explicit invalidation, failed retains, absent services, notification failures, and cleanup. App tests also check that stable polling does not rewrite labels, hidden controls catch up on reopening, and pointer previews preserve the uncommitted slider position.

The assertions cover power transitions, bounded retries, brightness mapping, saved choices, idle Off, input recovery, screen-saver entry before the deadline, the 54.99/55-second boundary while locked or in a saver, early-dimming fallback, screen-saver/lock/sleep gating, and missing readings. App tests run the scheduled timer after window close and Command-Q, checking idle Off, input recovery, preserved brightness/manual Off, and reopen behavior. They also cover ordinary Quit, explicit-stop cleanup, system quit reasons, sleep/wake activity ownership, and login-item success, errors, pending approval, unsupported systems, and external status changes. The macOS CI workflow runs these tests, checks shell syntax, builds the app, verifies its signature, and checks the CLI help/version paths.

Physical Touch Bar behavior falls outside automated coverage. Hardware reports distinguish command acceptance, driver readings, and visible panel behavior, and identify the app version, Mac model, and macOS version.

Build commands and contribution requirements are in [CONTRIBUTING.md](../CONTRIBUTING.md).

## Performance measurement

`./scripts/benchmark.sh c13ae21 5` compares that baseline revision at `-O0` with the current sources at `-O2`, in five pairs with alternating execution order. It requires supported Touch Bar hardware and writes raw JSON samples and a summary under `work/benchmark.*`. UI measurements use simulated hardware and a window that reports visibility without appearing on screen. Hardware measurements read telemetry only and can run alongside the installed app. The paced workload approximates steady On monitoring at 10 Hz, with brightness reads at 2 Hz, and measures process CPU time. It does not issue hardware writes or measure battery use, server CPU, drawing, or physical wake behavior. See [the recorded comparison](performance.md).
