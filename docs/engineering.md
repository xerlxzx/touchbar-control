# Engineering

Touch Bar Control is an Objective-C macOS application built with Clang and Apple's system frameworks. It has no third-party dependencies.

## Source layout

| Component | File | Responsibility |
| --- | --- | --- |
| Application | `Sources/main.m` | App lifecycle, window, menu bar, CLI dispatch, and preview hardware |
| Controller | `Sources/TBController.*` | Requested mode, observed state, idle transitions, brightness verification, and retries |
| Hardware adapter | `Sources/TBHardware.*` | Private API calls, display and session checks, and driver readings |
| Brightness preferences | `Sources/TBBrightnessPreference.*` | Slider snapping, nits mapping, and preference storage |
| Brightness readings | `Sources/TBBrightnessState.*` | Shared values from the hardware adapter |
| Controller tests | `Tests/controller_tests.m` | Fake hardware, isolated preferences, and state-transition assertions |

## Control flow

The app delegate sends control actions and monotonic timestamps to `TBController`. The controller reads and writes hardware through the `TBHardware` protocol. `TBRealHardware` implements that protocol for the physical device; preview and tests use simulated implementations.

The controller tracks requested mode apart from observed power state. Manual Off stays active until an explicit On request. In On mode, 55 seconds of inactivity starts an idle Off hold; new input restores On when session and display checks permit it. A nonzero dimming step can trigger Off before the idle threshold.

Sleep notifications suspend controller actions. Recovery requires an eligible session and, after an idle hold spanning a lock or sleep transition, input after the session becomes eligible. Rejected commands and sustained missing readings stop control attempts.

## Control invariants

- A brightness selection while Off updates the target without powering on the strip.
- Power-on requests follow the removal of Off enforcement.
- Brightness writes require valid driver limits and an eligible session.
- Off enforcement allows three unverified requests. Brightness recovery allows three requests within 60 seconds, with at least one second between writes.
- Quit stops monitoring without sending a power-on command or resetting the brightness policy.

The app stores the selected percentage through `TBPreferenceStore`, using `NSUserDefaults` in normal operation and isolated memory in preview and tests. The percentage snaps to six steps from 50% to 100%. See the [technical reference](technical-reference.md) for brightness mapping and platform constraints.

## Build and packaging

`build.sh` compiles for the host architecture with ARC, `-Wall -Wextra -Werror`, and a macOS 12 deployment target. It links Cocoa, IOKit, and CoreGraphics, copies `Info.plist` into the app bundle, then applies and verifies an ad-hoc signature.

`Resources/AppIcon.png` is the source artwork. During the build, `scripts/build-icon.sh` uses `sips` and `iconutil` to generate standard and Retina icon sizes from 16 to 1024 pixels. The bundle contains `Contents/Resources/AppIcon.icns`, referenced by `CFBundleIconFile`, before code signing.

`scripts/package.sh` runs the tests and builds into a temporary staging directory. It writes a versioned ZIP and SHA-256 checksum to `work/releases/`, then removes the staging directory. The archive name includes the bundle version and binary architecture.

`Info.plist` contains the application version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`). The CLI version string in `Sources/main.m` matches the application version.

## Test coverage

`test.sh` compiles the controller, brightness values, preferences, and fake hardware against Foundation. It excludes `TBHardware.m` and IOKit, so the tests cannot issue device commands.

The assertions cover power transitions, bounded retries, brightness mapping, saved choices, idle Off, input recovery, lock/sleep gating, and missing readings. The macOS CI workflow runs these tests, checks shell syntax, builds the app, verifies its signature, and checks the CLI help/version paths.

Physical Touch Bar behavior falls outside automated coverage. Hardware reports distinguish command acceptance, driver readings, and visible panel behavior, and identify the app version, Mac model, and macOS version.

Build commands and contribution requirements are in [CONTRIBUTING.md](../CONTRIBUTING.md).
