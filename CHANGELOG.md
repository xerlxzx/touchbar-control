# Changelog

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
