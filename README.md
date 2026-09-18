# Touch Bar Control

Keep your MacBook's Touch Bar off, or turn it on at a brightness you choose.

## Download and install

**[Download Touch Bar Control v1.3.1](https://github.com/xerlxzx/touchbar-control/releases/download/v1.3.1/Touch-Bar-Control-1.3.1-arm64.zip)** · [Release notes](https://github.com/xerlxzx/touchbar-control/releases/tag/v1.3.1)

Install the app through Finder:

1. **Download** the ZIP using the link above.
2. **Open your Downloads folder** and double-click the ZIP to unpack it. Skip this step if you can see the app in Downloads.
3. **Drag Touch Bar Control into Applications** in Finder's sidebar. Quit any older copy before replacing it.
4. **Open Touch Bar Control** from Applications.

**If macOS can't verify the developer:** after trying to open it, go to **System Settings → Privacy & Security**, scroll down, and choose **Open Anyway**, then **Open**. Use this exception for a copy you trust from this repository. This release uses a local signature; Apple hasn't notarized it. See [Apple's instructions](https://support.apple.com/en-au/102445) for the developer-verification warning.

**The Touch Bar turns off when the app opens.** Choose **Turn Touch Bar on** in the app if you want it back on.

Use this **experimental release on an Apple Silicon Mac**. Hardware testing covers one **13-inch M1 MacBook Pro with a Touch Bar**, running macOS 26.6.2. You can adjust brightness on that model. The download won't run on Intel Macs.

## Everyday use

| What you want | What to do |
| --- | --- |
| Keep the Touch Bar dark | Choose **Keep Touch Bar off**. It stays off until you choose On. |
| Use the Touch Bar | Choose **Turn Touch Bar on**. Your usual buttons stay in place. |
| Change its brightness | Move the slider between 50% and 100%. You can save a brightness choice while the Touch Bar is off. |
| Find the window again | Click the app's menu bar or Dock icon. Closing the window keeps the app running. |
| Stop the app | Choose **Quit** from its menu. Quitting doesn't turn the Touch Bar back on or reset its brightness settings. |

While On, the Touch Bar switches off after 55 seconds without input and comes back when you use the keyboard or trackpad. The app remembers your brightness choice, but starts Off each time you open it. Open it from Applications after logging in.

## Help and project information

- [Known issue: brief flashes on wake](docs/known-issues.md)
- [Report a problem](https://github.com/xerlxzx/touchbar-control/issues)
- [Technical details and command-line options](docs/technical-reference.md)
- [Contributing and running tests](CONTRIBUTING.md)
- [Architecture, build, and testing](docs/engineering.md)
- [What's changed](CHANGELOG.md)

## License

[MIT](LICENSE). Copyright 2026 Touch Bar Control contributors.
