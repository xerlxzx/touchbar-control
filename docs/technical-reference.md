# Technical reference

For installation and everyday controls, start with the [README](../README.md).

## Compatibility

| Item | Current scope |
| --- | --- |
| Tested hardware | M1 MacBook Pro, `MacBookPro17,1` |
| Tested system | macOS 26.6.2 |
| Brightness controls | Code restricts them to `MacBookPro17,1` |
| Other Touch Bar Macs | Untested; Off support depends on available private APIs and driver state |

The app uses Apple's private `DFRBrightness` and `CoreBrightness` frameworks. macOS updates can change these interfaces. The build target is macOS 12 or later, which does not establish compatibility with those earlier releases.

## Brightness and idle behavior

On mode disables automatic brightness for the Touch Bar, sets its minimum policy to `0.25`, and requests the selected level in nits. The main display retains its settings.

Brightness mapping uses a **fixed lower limit of 184.5 nits** and the upper limit from the Touch Bar driver. Hardware validation of that lower limit covers one Mac. On that machine, the six steps span about 184.5 to 357.1 nits.

The app leaves keyboard-backlight inactivity settings alone. Setting that timer to **Never** avoids a shorter keyboard dim timer but does not disable the Touch Bar's separate 60-second timer. Version 1.3 requests immediate Off at 55 seconds. If dimming starts sooner or the timer runs late, it requests immediate Off on detecting that dimming.

The app starts in On mode at the saved brightness. Screen-saver entry and locked/inactive session checks preserve the current power state while the same 55-second inactivity timeout continues. The timer measures time since the last input; it is not restarted at saver entry. Already-idle or missing activity readings enter an Off hold, and the existing early-dimming fallback remains active. Ineligible sessions block On and brightness writes while allowing idle/dimming reads and bounded Off enforcement. Actual system/display sleep notifications suspend all controller activity until wake.

Automatic wake requires the screen saver to have stopped, an unlocked local session, an awake built-in display, and new input after eligibility returns. A reset idle clock at unlock is not sufficient. Missing activity readings keep the strip off. The app reads elapsed input-idle time without recording keys, pointer positions, or input events. It does not request Input Monitoring or prevent system sleep.

Closing the window leaves the polling timer running. Quitting ends the timer and all enforcement; the 55-second behavior is not installed as a system setting or a separate background service.

## Launch at login

On macOS 13 or later, the window and menu bar provide **Launch at login**, backed by Apple's [`SMAppService.mainAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice). Registration is opt-in. The control reads the operating system's status on activation and menu opening, including changes made in System Settings. Pending approval appears as a mixed checkbox with a settings button; failed operations retain the actual state and show the error.

The macOS 12 build remains supported at compile time, but its startup toggle is disabled. Preview simulates the toggle in memory and never queries or changes real login items. Actual launch after login must be tested using an installed, signed app; automated tests do not register a login item or log the user out.

## Command-line access

Run these options on the executable inside the app bundle. The examples assume you installed it in Applications:

| Option | Effect |
| --- | --- |
| `--status` | Read the Touch Bar power state; no control commands |
| `--brightness-status` | Read brightness, policy, and driver limits; no setters |
| `--activity-status` | Read elapsed input-idle time and session eligibility; no input events or setters |
| `--preview` | Open the interface with simulated hardware |
| `--resume-on` | Adopt On mode without an initial power-on command; includes idle Off and activity recovery |
| `--version`, `--help` | Print version or usage information |

For example:

```sh
"/Applications/Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --brightness-status
```

Quit the current instance before using preview or resume mode. Use `--resume-on` during a controlled app update to adopt On without an initial power-on command. Ordinary launch now starts On too, and can power on an eligible, active strip.

### Return to the fixed baseline policy

`--restore-original-policy` **sets minimum brightness to 0 and enables automatic brightness**. These are fixed values. The app keeps no backup of the prior policy, so this command cannot restore per-device settings from before installation.

Quit the app before running this command. Lower brightness may bring flashing back.

```sh
"/Applications/Touch Bar Control.app/Contents/MacOS/Touch Bar Control" --restore-original-policy
```

The command prints before/after readings and checks the two policy values. It sends no power-on command. It leaves the keyboard inactivity setting and saved slider choice intact. Exit code 4 means another app instance prevented the action; exit code 5 means the command could not verify completion. Inspect the output after a failure because one setting may have changed before the other failed.

Off and Quit do not run this command.
