# Touch Bar Control

A small native macOS app for turning the Touch Bar off and choosing a fixed brightness. It includes a menu bar control and a slider with six steps, from 50% to 100%.

**Experimental:** testing covers one M1 MacBook Pro. A read-only trace confirmed a low-brightness idle phase after about 60 seconds, followed by a reported power-off state around 76 seconds. A user reported flashing during that interval. The keyboard-backlight timer was set to Never. Read the [known issues](docs/known-issues.md) before using On mode.

## Compatibility

| Item | Current scope |
| --- | --- |
| Tested hardware | M1 MacBook Pro, `MacBookPro17,1` |
| Tested system | macOS 26.6.2 |
| Brightness controls | Code restricts them to `MacBookPro17,1` |
| Other Touch Bar Macs | Untested; Off support depends on available private APIs and driver state |

The app uses Apple's private `DFRBrightness` and `CoreBrightness` frameworks. macOS updates can change these interfaces. The build target is macOS 12 or later, which does not establish compatibility with those earlier releases.

## Build and open

Install Apple's Command Line Tools, then run:

```sh
git clone https://github.com/xerlxzx/touchbar-control.git
cd touchbar-control
./build.sh
./test.sh
open "./Touch Bar Control.app"
```

The build script compiles for the current Mac and creates a local ad-hoc signature. It requires no package manager or full Xcode project. The resulting app has no Developer ID signature or notarization for distribution.

Opening the app starts **Keep off** mode. To inspect the interface without controlling the Touch Bar, quit any running instance and use:

```sh
"./Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --preview
```

Preview uses simulated hardware and an in-memory brightness preference.

## Use the controls

- **Keep Touch Bar off** requests an immediate off transition and watches for macOS turning the strip on again.
- **Turn Touch Bar on** enables the strip, applies the selected brightness, and checks its readings. It leaves your Touch Bar buttons and layout intact.
- **Brightness** snaps to 50%, 60%, 70%, 80%, 90%, or 100%. Release the slider to apply a choice. Changing it while off saves the choice for later without lighting the strip.
- **Requested** shows your chosen mode. **Observed** shows the driver's reported state. **Verified** means the software readings match the selected target.

The app saves the brightness percentage. A normal launch starts Off even if the last session used On. Closing the window keeps control running; use the menu bar icon or Dock icon to reopen it. Quitting stops monitoring and leaves the brightness policy in place. It does not send an On command or install a login item.

Use **Command–Shift–O** for Off and **Command–Shift–I** for On while the app has focus.

### Brightness limits

On mode disables automatic brightness for the Touch Bar, sets its minimum policy to `0.25`, and requests the selected level in nits. The main display retains its settings.

The code contains a **fixed lower limit of 184.5 nits**, based on the working level observed on the test Mac. This is not a proven threshold for other panels. The upper limit comes from the Touch Bar driver. On the test Mac, the six steps span about 184.5 to 357.1 nits.

The app leaves keyboard-backlight inactivity settings alone. Setting that timer to **Never** helped an earlier trial, but a separate Touch Bar idle-dimming sequence remains. The selected brightness stays saved while macOS reduces the reported output during idle. Version 1.2 leaves that dimming sequence in control. See [idle dimming and flashing](docs/known-issues.md#idle-dimming-and-flashing).

## Command-line access

Run these options on the executable inside the app bundle:

| Option | Effect |
| --- | --- |
| `--status` | Read the Touch Bar power state; no control commands |
| `--brightness-status` | Read brightness, policy, and driver limits; no setters |
| `--preview` | Open the interface with simulated hardware |
| `--resume-on` | Resume brightness monitoring without a power-on command; wait for macOS if the strip is off |
| `--version`, `--help` | Print version or usage information |

For example:

```sh
"./Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --brightness-status
```

Quit the current instance before using preview or resume mode. Use `--resume-on` during a controlled app update to avoid a default-Off launch.

### Return to the fixed baseline policy

The existing `--restore-original-policy` command has a misleading name: **it sets minimum brightness to 0 and automatic brightness to enabled. It does not recover your Mac's saved prior settings.** Those fixed values matched the original policy on the test Mac.

Quit the app before running this command. Lower brightness may bring flashing back.

```sh
"./Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --restore-original-policy
```

The command prints before/after readings and checks the two policy values. It sends no power-on command. It leaves the keyboard inactivity setting and saved slider choice intact. Exit code 4 means another app instance prevented the action; exit code 5 means the command could not verify completion. Inspect the output after a failure because one setting may have changed before the other failed.

Off and Quit do not run this command.

## Development

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the source layout, tests, and bug reports. Use a separate output path to build an update without replacing a running copy:

```sh
./build.sh 'work/staged/Touch Bar Control.app'
```

## License

[MIT](LICENSE). Copyright 2026 Touch Bar Control contributors.
