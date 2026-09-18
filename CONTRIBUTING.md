# Contributing

Start with the [known issues](docs/known-issues.md), especially the unresolved idle-flashing report and the limits of testing on one Mac.

## Build and test

Use macOS with Apple's Command Line Tools:

```sh
./build.sh 'work/staged/Touch Bar Control.app'
./test.sh
```

The tests use fake hardware and an in-memory preference store. They do not link the real hardware provider or send Touch Bar commands. They cover retry limits, power transitions, brightness mapping, slider persistence, and recovery from missing readings.

Quit other app instances before opening a preview:

```sh
"./work/staged/Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --preview
```

Preview keeps its choice in memory and leaves the user's saved preference alone. Keep preview results separate from tests on a physical Touch Bar. Check Off and On, then close and reopen the window. Check the slider with the pointer and keyboard.

## Source layout

| File | Responsibility |
| --- | --- |
| `Sources/main.m` | Native window, menu bar, command-line options, and sleep notifications |
| `Sources/TBHardware.m` | Private API access, display checks, and driver readings |
| `Sources/TBController.m` | Off enforcement, brightness verification, and retry limits |
| `Sources/TBBrightnessPreference.m` | Slider snapping, range mapping, and saved percentage |
| `Sources/TBBrightnessState.m` | Brightness readings shared by hardware and controller code |
| `Tests/controller_tests.m` | Tests using fake hardware and preferences |

## Changes to hardware control

Preserve the distinction between the requested mode and observed state. A slider change while Off must save the choice without sending a brightness or power-on command. Keep bounds and display checks close to each write, and keep retries finite.

Changes to the lower brightness limit, supported models, dimming behavior, or private API calls need evidence from the affected hardware. Include the macOS version and separate command acceptance from driver readings and visible behavior. Avoid claims that one successful trial proves a hardware repair.

## Report a problem

[Open an issue](https://github.com/xerlxzx/touchbar-control/issues) with the app version, macOS version, and model identifier, such as `MacBookPro17,1`. Describe the chosen mode and brightness, whether the strip was active or idle, and how long the symptom lasted. For idle reports, include the keyboard-backlight inactivity setting and time since the last keyboard input.

These commands read state without sending control commands:

```sh
"./Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --status
"./Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --brightness-status
```

Review output and screenshots before posting. Remove serial numbers, account details, and private paths. Short readings around the event help more than a full system dump.

## Pull requests

Describe the behavior change and the checks you ran. Include preview screenshots for interface changes. Keep generated apps, debug symbols, and local investigation files out of commits; `.gitignore` excludes those artifacts.

Use the [MIT license](LICENSE) for contributions.
