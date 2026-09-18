# Known issues

## Idle dimming and flashing

**Status: v1.3 installed on the test Mac; live validation is incomplete.** A user reported that the Touch Bar dims after about 60 seconds without keyboard activity, flashes for 10–15 seconds, then appears to turn off. The keyboard-backlight inactivity timer was set to **Never**.

A read-only capture on version 1.2 confirmed the software transition below. Times refer to the reported input-idle duration.

| Idle duration | Software readings |
| --- | --- |
| 60.27 seconds | Dimming step changes from 0 to 1 |
| 60.69 seconds | Physical-nits readback falls from 184.5 to 27.675 |
| 75.28 seconds | Dimming step changes to 3; physical-nits readback falls through about 19.2 and 11.9 |
| 75.69 seconds | Driver power state reports Off and physical-nits readback reaches 0 |

The brightness value stayed at `0.5`, the minimum policy stayed at `0.25`, and automatic brightness stayed disabled. The saved brightness choice did not reset. These readings show a separate idle-dimming adjustment reducing output beneath the active brightness target.

Inspection of the installed TouchBarServer binary also found a 60-second default for `secondsUntilDim` and a 15-second second phase. A read-only keyboard query returned an idle timer of zero, the value used for Never. The TouchBarServer path substitutes 60 seconds for values outside its 1–60-second range. This explains the remaining timeout on the test system; it does not establish the behavior of other macOS versions.

The observer confirmed visible flashing during the dim interval in this coordinated capture. The trace records software states, not optical measurements. Together they associate the flashing with the low-brightness idle phase, but do not identify a failed hardware component.

The v1.2 controller suspends brightness writes during a nonzero dimming step and waits for macOS after the driver reports Off. It therefore leaves this low-brightness phase intact. The keyboard-backlight **Never** setting does not provide a complete workaround.

### Version 1.3 idle protection

On mode requests immediate Off after 55 seconds of input inactivity, before the observed 60-second dim transition. It holds Off through idle and reapplies the selected brightness after new activity. Manual Off remains separate and does not wake on activity.

If the app detects a nonzero dimming step before the idle guard runs, it skips the remaining dim phase with an immediate Off request. This fallback reacts after dimming begins, so a brief flash may still occur with a shorter keyboard timer or delayed polling.

Automatic On and brightness writes require an unlocked local session and an awake built-in display. Lock, display sleep, and system sleep suspend automatic recovery. After an idle hold spans one of those transitions, recovery requires new input after the session becomes eligible; the first unlock action may therefore leave the strip off until another input. Missing idle readings keep the strip off. Rejected commands or sustained missing power readings stop retries.

Hardware-free tests cover the 55-second boundary, input recovery, manual Off priority, lock/sleep gating, missing activity readings, and bounded failures.

In the first live recording, native dimming began when the system input-idle counter read about 43 seconds. The app's fallback cut driver power within 0.413 seconds of the first dim sample, and the strip remained off for the rest of the two-minute capture. Subsequent input restored the selected 50% brightness, with readbacks of 184.5 physical nits and 184 driver nits. The reason the native timer and system idle counter differed is not established.

The observer reported that idle Off and brightness recovery worked in this cycle. This result supports the workaround, but does not verify the proactive 55-second cutoff or longer-term behavior. Physical lock/sleep testing also remains pending. These checks do not establish a cure for panel faults or guarantee flash-free wake transitions.

Use **Keep Touch Bar off** if On mode causes recurring flashes. Include your model identifier, macOS version, and symptom timing in a bug report. [CONTRIBUTING.md](../CONTRIBUTING.md) lists read-only status commands.

## Wake flashes

A brief flash can occur during wake before the app gets time to reapply Off or the selected brightness. The app has no control during boot or before it starts. It does not install a background service or login item.

## Limited hardware coverage

Testing covers one `MacBookPro17,1` running macOS 26.6.2. Brightness support includes an explicit model check, private API signature checks, and Touch Bar display checks. Other M1 units, Intel Touch Bar models, and other macOS releases lack validation.

The driver supplies the upper brightness limit, but the code fixes the lower limit at **184.5 nits**. That value came from the test Mac's observed working level. It is not a panel calibration or a guaranteed flicker-free level across devices. The workaround does not establish the hardware fault or long-term reliability.

## Private APIs and reported status

Apple does not document these private interfaces as a supported control API for third-party apps. An OS update can remove or change them. Unsupported controls remain unavailable; a partial failure can leave a policy change in place.

**Observed** and **Verified** refer to software readings from the driver and CoreBrightness. They do not measure the light from the panel. Treat a visible flash as a symptom even if the app reports Off or a matching brightness.

The controller pauses after rejected commands, sustained missing readings, or too many corrections. Off permits three unverified requests. Brightness recovery permits three requests in a rolling 60-second window, with at least one second between requests. A user-selected mode or new brightness choice permits a retry. A new slider choice retains the one-second rate limit.

## Baseline restoration is not a backup

`--restore-original-policy` writes two fixed values: minimum `0` and automatic brightness enabled. The app does not save a per-device copy of the policy that existed before first use. The command name and CLI wording reflect the original development machine, not a general restoration guarantee.

Quit other instances before using it, and read the before/after output. The lower automatic brightness may bring flashing back. The command does not restore the Touch Bar layout, keyboard timer, or saved slider percentage because it does not change those settings.
