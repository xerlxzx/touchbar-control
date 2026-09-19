# Changelog

## 1.3.2 · 2026-09-19

- Start in On mode using the saved brightness and 55-second idle protection.
- Keep the Touch Bar off during the screen saver and locked/inactive sessions instead of skipping Off enforcement. Require fresh input after eligibility returns.
- Add an optional Launch at login toggle in the window and menu bar on macOS 13 or later, with actual system status, approval guidance, and error handling.
- Clarify that closing the window keeps protection running, while Quit stops the 55-second timeout.
- Pass 195 controller safety assertions and 33 app lifecycle/login-item assertions, with simulated hardware and login items. Native build, signature, and UI preview checks also pass. Physical screen-saver behavior and actual launch after login still need validation.

Investigation of the older installed build found a screen-saver lock followed 59.9 seconds later by TouchBarServer entering its dimming stage, with no Off request logged by the app in between. The session-eligibility early return skipped both idle shutdown and the dimming fallback. This release corrects that control flow; it does not claim a hardware repair or guarantee flash-free wake transitions.

## 1.3.1 · 2026-09-19

- Added a black-and-white Touch Bar app icon for Finder and the Dock, with standard and Retina sizes.
- Replaced the maintainer roadmap with architecture, build, and testing documentation.

## 1.3.0 · 2026-09-18

### Distribution

- First downloadable Apple Silicon ZIP, published as an experimental GitHub Release.
- README starts with download and installation steps; known issues lists only brief flashes on wake.
- Added macOS CI, issue and pull request templates, a packaging script, and an engineering guide.

### Idle protection

- On mode requests immediate Off after 55 seconds without input, then restores the selected brightness on new keyboard or trackpad activity.
- If macOS starts dimming before that cutoff, the app requests immediate Off on detecting the dimming step.
- The interface distinguishes Off while idle from manual Keep off. Manual Off stays off until you choose On.
- Automatic recovery requires an unlocked local session and an awake built-in display. Missing activity readings keep the strip off.
- The read-only `--activity-status` command reports input-idle time and session eligibility.

### Validation

The native build and local signature checks passed, along with 174 hardware-free controller checks. In a two-minute live recording, the early-dimming fallback cut driver power within about 0.41 seconds of the first dim sample and kept the strip off. Subsequent input restored the selected 50% brightness. The observer confirmed that idle Off and recovery worked in this cycle.

The native dim timer and system idle counter differed during this run, so it exercised the fallback rather than the proactive 55-second cutoff. Physical lock/sleep behavior, the proactive cutoff on hardware, and longer-term reliability still need testing.
