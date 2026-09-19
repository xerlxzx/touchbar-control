# Known issues

## Brief flashes on wake

You may see a short Touch Bar flash when your Mac wakes, before the app reapplies Off or your chosen brightness.

## Protection stops after Quit

The 55-second timeout runs inside the app. Choosing Quit or pressing ⌘Q stops it, so macOS takes over and low-brightness flickering can return. Close the window instead to keep protection running in the menu bar. Launch at login starts the app again after you sign in; it does not keep a quit app running.

## Screen saver and lock-screen flickering in v1.3.1

On mode previously returned before Off enforcement whenever the session was locked or inactive. A lock before 55 seconds could therefore bypass the idle shutdown entirely; a later macOS wake could also leave the strip on. There was no screen-saver notification handling for savers that ran without locking.

Version 1.3.2 enters an Off hold when the screen saver starts or session checks fail, continues bounded Off enforcement, and requires fresh input after the session becomes eligible again. Regression tests cover these transitions. Visible behavior during a real screen-saver/lock cycle still needs hardware validation. Screen-saver notifications and Touch Bar control depend on undocumented macOS interfaces.

When updating, quit the old copy before replacing it and launch the new copy from Applications. Keeping the older process running does not apply a downloaded or locally built fix. Check **About Touch Bar Control** for version 1.3.2.
