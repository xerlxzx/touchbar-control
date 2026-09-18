# Engineering structure

## Source layout

Keep `Sources/` and `Tests/` for this small Objective-C app. You can build it with Apple’s Command Line Tools; it has no third-party dependencies.

| Area | Home | Responsibility |
| --- | --- | --- |
| App and interface | `Sources/main.m` | Window, menu bar, lifecycle, CLI, and preview hardware |
| Behavior | `Sources/TBController.*` | Requested state, retries, idle protection, and recovery |
| Hardware boundary | `Sources/TBHardware.*` | Private APIs, eligibility checks, and device readings |
| Values and preferences | `Sources/TBBrightness*.{h,m}` | Brightness readings, mapping, and persistence |
| Automated checks | `Tests/`, `.github/workflows/ci.yml` | Fake-hardware tests, compilation, signature checks, and CLI smoke checks |
| Packaging | `scripts/package.sh` | Versioned ZIP and checksum for the build Mac's architecture |
| User documentation | `README.md`, `docs/known-issues.md` | Installation, everyday use, and the wake-flash issue |
| Maintainer documentation | `CONTRIBUTING.md`, `docs/technical-reference.md` | Development and advanced controls |

Use the controller’s `TBHardware` protocol to test behavior with fake hardware. Run physical Touch Bar checks on a supported Mac; the CI runner has no Touch Bar.

## Next changes, in priority order

1. **Add Developer ID signing and notarization.** Users can download the [v1.3.0 ZIP](https://github.com/xerlxzx/touchbar-control/releases/tag/v1.3.0). Sign and notarize future builds to remove the extra developer-verification step at first launch. See [Apple's guidance](https://support.apple.com/en-au/102445).
2. **Require CI before merging.** Configure a `main` branch ruleset requiring pull requests and the **Build and controller tests** check. Use `./build.sh` and `./test.sh` both on your Mac and in CI. The repository includes the workflow; configure the ruleset in GitHub settings.
3. **Record hardware checks for each release.** Test manual Off, each brightness step, idle cutoff, early dimming, recovery, lock/unlock, and sleep/wake. Record the app version, Mac model, macOS version, and a pass/fail/not-tested result for each check. Test another model before claiming support for it.
4. **Split `main.m` as you work on it.** Extract the app delegate/UI, CLI handling, and preview hardware into separate files. Keep the entry point in `main.m` and preserve behavior. Add CLI tests during that extraction.
5. **Centralize the version.** Read the CLI version from bundle metadata. Until then, update `Info.plist` and the CLI version together.

## Release checklist

- Update the app version/build in `Info.plist`, CLI version, and `CHANGELOG.md`.
- Pass CI and record the hardware checks above, including anything untested.
- Run `./scripts/package.sh` from the release commit. Check the ZIP and SHA-256 checksum under `work/releases/`. The script runs tests and verifies the local app signature before packaging.
- Test the extracted app on a separate Mac of the advertised architecture. For a release without Developer ID signing, document any Gatekeeper prompts. Add signing and notarization to the packaging script before using it for notarized releases.
- Tag the release and publish the ZIP and checksum with supported systems and concise release notes. Verify the GitHub acting account is `xerlxzx` before publishing.
- Test installation from the download and update the README with the release link.

Use GitHub issues for actionable work, PRs for reviewed changes, and the changelog for completed behavior changes.
