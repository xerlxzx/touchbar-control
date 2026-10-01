# Known issues

## Brief flashes on wake

You may still see a short Touch Bar flash when your Mac wakes from system sleep, before the app reapplies Off or your chosen brightness. Full-system sleep/wake has not been validated with the latest wake change.

Version 1.3.5 requests a zero-duration wake instead of the private API's default half-second fade, avoiding the app-requested gradual transition through low brightness. The request is validated and tested with simulated clients. A physical check confirmed no visible flash in one ordinary 55-second idle/wake cycle on the M1 Touch Bar Mac running macOS 27.0 (26A428). That observation does not cover all wake paths: macOS can wake the strip before the app's next poll, and physical panel behavior is not measured by driver telemetry.

## Closing and quitting in older versions

In v1.3.3 and earlier, choosing Quit or pressing ⌘Q destroyed the app's polling timer. macOS could then reach its 60-second dimming transition without the 55-second Off guard, allowing low-brightness flickering to return.

In v1.3.5, closing the window, pressing ⌘Q, or using ordinary Quit hides the controls and Dock icon while the same controller and timer continue in the menu bar. This behavior was first tested in the unpublished v1.3.4 build. Use **Stop protection and quit** to end enforcement explicitly. Force Quit and logout also end protection; Launch at login remains optional.

## Screen saver and lock-screen flickering in v1.3.1

On mode previously returned before Off enforcement whenever the session was locked or inactive. A lock before 55 seconds could therefore bypass the idle shutdown entirely; a later macOS wake could also leave the strip on. There was no screen-saver notification handling for savers that ran without locking.

Version 1.3.3 keeps the 55-second inactivity timeout running through the screen saver and locked/inactive sessions. Saver entry preserves the current state; the idle threshold or early-dimming fallback starts an Off hold. It then continues bounded Off enforcement and requires fresh input after the session becomes eligible again. Regression tests cover these transitions. Visible behavior during a real screen-saver/lock cycle still needs hardware validation. Screen-saver notifications and Touch Bar control depend on undocumented macOS interfaces.

When updating, exit the old copy before replacing it and launch the new copy from Applications. Use **Stop protection and quit** in v1.3.4 or later, or **Quit** in earlier versions. Keeping the older process running does not apply a downloaded or locally built fix. Check **About Touch Bar Control** for version 1.3.5.
