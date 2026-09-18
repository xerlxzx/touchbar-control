# Contributing

Start with the [engineering structure](docs/engineering.md) and [technical reference](docs/technical-reference.md).

## Build and test

Use macOS with [Apple's Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/) (`xcode-select --install`). Clone the repository first:

```sh
git clone https://github.com/xerlxzx/touchbar-control.git
cd touchbar-control
```

Build into a separate output folder so you don't replace a running copy:

```sh
./build.sh 'work/staged/Touch Bar Control.app'
./test.sh
```

The tests use fake hardware and an in-memory preference store. They do not link the real hardware provider or send Touch Bar commands. They cover retry limits, power transitions, brightness mapping, saved choices, idle Off and activity recovery, lock/sleep gating, and missing readings.

Quit other app instances before opening a preview:

```sh
"./work/staged/Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --preview
```

Preview keeps its choice in memory and leaves the user's saved preference alone. Keep preview results separate from tests on a physical Touch Bar. Check Off and On, then close and reopen the window. Check the slider with the pointer and keyboard.

CI runs the tests, builds the app, verifies its local signature, and checks the CLI help/version entry points on pull requests and pushes to `main`. It does not launch hardware control.

## Package a release

```sh
./scripts/package.sh
```

The command writes a versioned ZIP and SHA-256 checksum to `work/releases/` after the tests and build finish. The ZIP contains an app for the build Mac's architecture with an ad-hoc signature. See [build and packaging](docs/engineering.md#build-and-packaging) for implementation details.

## Changes to hardware control

Preserve the distinction between the requested mode and observed state. A slider change while Off must save the choice without sending a brightness or power-on command. Keep bounds and display checks close to each write, and keep retries finite.

Changes to the lower brightness limit, supported models, dimming behavior, or private API calls need evidence from the affected hardware. Include the macOS version and separate command acceptance from driver readings and visible behavior. Avoid claims that one successful trial proves a hardware repair.

## Report a problem

[Open an issue](https://github.com/xerlxzx/touchbar-control/issues) with the app version, macOS version, and model identifier, such as `MacBookPro17,1`. Describe the chosen mode and brightness, whether the strip was active or idle, and how long the symptom lasted. For idle reports, include the keyboard-backlight inactivity setting and time since the last keyboard input.

For a copy installed in Applications, read its state with these commands:

```sh
"/Applications/Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --status
"/Applications/Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --brightness-status
"/Applications/Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --activity-status
```

Review output and screenshots before posting. Remove serial numbers, account details, and private paths. Short readings around the event help more than a full system dump.

## Pull requests

Describe the behavior change and the checks you ran. Include preview screenshots for interface changes. Keep generated apps, debug symbols, and local investigation files out of commits; `.gitignore` excludes those artifacts.

Use the [MIT license](LICENSE) for contributions.
