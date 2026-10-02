# Touch Bar Control

Keep your MacBook's Touch Bar off, or turn it on at a brightness you choose.

## Download and install

**[Download Touch Bar Control v1.3.5](https://github.com/xerlxzx/touchbar-control/releases/download/v1.3.5/Touch-Bar-Control-1.3.5-arm64.zip)** · [Release notes](https://github.com/xerlxzx/touchbar-control/releases/tag/v1.3.5) · [SHA-256 checksum](https://github.com/xerlxzx/touchbar-control/releases/download/v1.3.5/Touch-Bar-Control-1.3.5-arm64.zip.sha256)

Install the app through Finder:

1. **Download** the ZIP using the link above.
2. **Open your Downloads folder** and double-click the ZIP to unpack it. Skip this step if you can see the app in Downloads.
3. **Drag Touch Bar Control into Applications** in Finder's sidebar. Exit any older copy before replacing it: choose **Stop protection and quit** in v1.3.4 or later, or **Quit** in earlier versions. Closing the window or pressing ⌘Q in newer versions leaves the old process running.
4. **Open Touch Bar Control** from Applications.

**Apple's first-launch warning:** macOS may say it cannot verify that Touch Bar Control is free of malware, or that it cannot verify the developer. This release uses a local signature and has no Apple notarization.

To open a copy you trust from this repository, dismiss that warning, then go to **System Settings → Privacy & Security**. Scroll down, choose **Open Anyway**, and confirm **Open**. See [Apple's instructions](https://support.apple.com/en-au/102445) for details.

**The Touch Bar starts On**, using your saved brightness and automatic idle protection. Choose **Keep Touch Bar off** if you want it to stay dark.

Use this **experimental release on an Apple Silicon Mac**. Hardware testing covers one **13-inch M1 MacBook Pro with a Touch Bar**. Earlier brightness testing used macOS 26.6.2; the v1.3.5 idle/wake check used macOS 27.0 (26A428). You can adjust brightness on that model. The download won't run on Intel Macs.

## Everyday use

| What you want | What to do |
| --- | --- |
| Keep the Touch Bar dark | Choose **Keep Touch Bar off**. It stays off until you choose On. |
| Use the Touch Bar | Choose **Turn Touch Bar on**. Your usual buttons stay in place. |
| Change its brightness | Move the slider between 50% and 100%. You can save a brightness choice while the Touch Bar is off. |
| Close the app and keep protection | Close the window, press **⌘Q**, or choose **Run in background**. The Dock icon disappears and protection continues in the menu bar. |
| Find the window again | Choose **Show Touch Bar Control** from its menu bar icon, or open the app from Applications. |
| Start automatically | Enable **Launch at login** in the window or menu bar menu (macOS 13 or later). If approval is needed, use **Login Items Settings…**. |
| Stop the app completely | Choose **Stop protection and quit** from its menu. This stops protection, including the 55-second timeout. It doesn't turn the Touch Bar back on or reset its brightness settings. |

While On, the Touch Bar switches off after 55 seconds without input and comes back when you use the keyboard or trackpad. The same 55-second inactivity timeout continues during the screen saver or a locked/inactive session. Starting the screen saver keeps the current Touch Bar state; once the idle timeout turns it off, it waits for fresh input after you return. The app remembers your brightness choice and starts On when its process launches. Reopening the controls preserves the current mode.

Version 1.3.5 removes the default half-second fade from app-issued wake requests. One physical idle/wake check showed no visible flash after this change. Flashing can still occur on wake; see [known issues](docs/known-issues.md).

Protection stays active in the background after closing the window or using ordinary Quit, including **⌘Q** and the Dock's Quit command. Your selected mode and brightness are preserved. **Stop protection and quit**, Force Quit, and logout end protection, so macOS dimming and flickering can return. Launch at login is optional and starts the app after you sign in, not before login.

## Source improvements in 1.3.7

Version 1.3.7 reduces repeated UI updates and hardware-service lookups while preserving the existing control timing and background protection. Five paired local benchmarks measured 80.5% less hidden-window UI update time, 53.0% less power-read time, 47.7% less idle-read time, and 11.6% less process CPU per tick in a representative read-only monitoring loop. These measurements do not establish battery-life or whole-app CPU gains.

Read the [optimization changelog](CHANGELOG.md), [benchmark report and limitations](docs/performance.md), or [raw results](docs/performance-results.json). [Build from source](CONTRIBUTING.md#build-and-test) to use these changes; the packaged download above remains v1.3.5.

## Help and project information

- [Known issue: brief flashes on wake](docs/known-issues.md)
- [Report a problem](https://github.com/xerlxzx/touchbar-control/issues)
- [Technical details and command-line options](docs/technical-reference.md)
- [Contributing and running tests](CONTRIBUTING.md)
- [Architecture, build, and testing](docs/engineering.md)
- [Performance measurements and reproduction](docs/performance.md)
- [What's changed](CHANGELOG.md)

## License

[MIT](LICENSE). Copyright 2026 Touch Bar Control contributors.
