# Polling optimization measurements

Measured on 2026-10-02 on an Apple M1 MacBook Pro (`MacBookPro17,1`, 8 GB RAM), running macOS 27.0 (26A428), using Apple Clang 21.0.0. The baseline is `c13ae21` (Quality of Life Changes), built with its original unoptimized setting. The optimized sources on `codex/reduce-polling-overhead` use `-O2`. These changes are included in v1.3.7 (build 14). The measurements and recorded source fingerprint precede the version-only bump from 1.3.6 to 1.3.7; the measured control and rendering code is unchanged.

## Results

Five paired runs, with execution order alternating between baseline-first and optimized-first. Values are medians of each run's average time per operation. Lower is better.

| Workload | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Hidden-window UI refresh | 5.36 µs | 1.05 µs | 80.5% |
| Visible-state UI refresh | 5.41 µs | 4.37 µs | 19.2% |
| Power-state read | 17.89 µs | 8.41 µs | 53.0% |
| Input-idle read | 8.62 µs | 4.51 µs | 47.7% |
| Brightness read | 579.66 µs | 546.69 µs | 5.7% |
| Session eligibility read | 119.98 µs | 114.67 µs | 4.4% |
| Paced read-only loop, **process CPU per tick** | 2.016 ms | 1.782 ms | 11.6% |

The larger UI and registry-read improvements were consistent: before/after run ranges did not overlap. The paced loop's CPU ranges were 1.928–2.383 ms before and 1.626–1.869 ms after. Brightness and session-read ranges overlapped substantially; their small differences should be treated as run variation rather than established gains. Session reads were not deliberately reduced or cached.

[Raw samples, ranges, metadata, and source fingerprint](performance-results.json) are included for verification. Reduction is `100 × (1 − after median / before median)`; these are reductions in time, not percentages of the entire application's resource use.

## Changes measured

- Window controls update only when values differ and defer updates while hidden. Reopening refreshes them immediately. Menu state and App Nap activity continue to update in the background.
- Discovery handles for `backlight-dfr` and `IOHIDSystem` are retained. Child enumeration, property readings, session checks, and validation immediately before writes remain fresh. Service termination, failed readings, and sleep/wake invalidate the cache. Notification setup failure falls back to uncached discovery.
- Release builds and tests use `-O2`, without fast-math.

The polling interval, tolerance, brightness sampling interval, 55-second inactivity threshold, immediate wake, and retry limits are unchanged. No experimental wake guard or additional delays were introduced.

## Method and limits

Run from a checkout with the supported hardware and an active, unlocked session:

```sh
./scripts/benchmark.sh c13ae21 5
```

The script builds the same benchmark harness against an exported baseline and the current sources, then saves each run under `work/benchmark.*`. It measures 20,000 refreshes for each UI case, 2,000 power and idle reads each, 1,000 session checks, and 300 brightness reads. Initialization and warmup are excluded. Missing telemetry or an ineligible session fails the benchmark.

UI tests exercise the real delegate and AppKit setters using simulated hardware and a window reporting visible/hidden state without appearing on screen. They measure update work, not frame rendering. Hardware measurements use real read-only telemetry while the installed protection app continues running.

The paced workload runs 100 ticks at approximately 100 ms intervals, with power, session, and idle reads each tick, brightness reads every fifth tick, and hidden-window refresh. CPU time includes this benchmark process's threads and run-loop work. It approximates steady On monitoring; it does not execute the complete hardware-writing controller or measure battery consumption, system-service CPU, physical wake behavior, or the installed app's overall CPU reduction. Compiler and source changes are measured together.

The computer remained in normal use, so these are local measurements rather than a controlled laboratory benchmark. A preliminary run preceded the final run with per-read validation; the table uses only the validated run.

## Verification

All 352 assertions pass at `-O2`: 56 service-cache, 12 wake API, 207 controller, and 77 app lifecycle/UI/login-item assertions. Coverage includes cache ownership and invalidation, notification failure, background timer operation, reopen updates, pointer previews, the idle deadline, bounded retries, and sleep/wake gating. The optimized app builds and its ad-hoc signature verifies. Physical sleep/wake behavior with the optimized app has not been tested. The installed app was not replaced during benchmarking; measurements ran alongside it.
