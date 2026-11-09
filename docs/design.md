# Mamute — design

Mute or turn down individual apps on macOS. macOS only has one system volume; Mamute adds a per-app mute button and volume slider.

## Goals
- Menu bar app. Click the icon → list of apps making sound → mute button + volume slider (0–100%) per app.
- Settings remembered per app (bundle ID), so Spotify stays at 30% across restarts.
- Nice, native look (SwiftUI). Built so it can be shared later: real app bundle, own bundle ID, signable/notarizable.

## Non-goals (for now)
- Boost above 100%, EQ, per-app output device routing, per-tab control in browsers.
- Accounts, pricing, auto-update, launch at login.

## Anti-goals
- Installing a kernel extension or virtual audio driver.
- Ever leaving an app silent after Mamute quits. Taps are private to the Mamute process, so quitting Mamute restores all audio.

## How it works
- **Requires macOS 14.2+** (Core Audio process taps).
- **Finding apps:** read `kAudioHardwarePropertyProcessObjectList` once a second. Each audio process is attributed to the app responsible for it (so Chrome/Safari helper processes count as Chrome/Safari). The list shows apps playing now, apps that played since Mamute started, and apps with a saved setting.
- **Mute and volume, one mechanism:** an app at 100% and unmuted is left alone (zero overhead). Otherwise Mamute creates a private process tap on all of that app's audio processes with `mutedWhenTapped`, puts it in a private aggregate device with the current output device, and an IOProc copies the tapped audio to the output multiplied by the gain (0 when muted). Gain changes ramp across one buffer to avoid clicks.
- **Rebuild** an app's tap when its set of audio processes changes (e.g. Chrome spawns a new helper) or the default output device changes (e.g. AirPods connect).
- **Permission:** macOS asks once for "System Audio Recording" (`NSAudioCaptureUsageDescription`).

## Layout
- `Sources/MamuteCore` — pure audio math (buffer mixing with gain), unit-tested.
- `Sources/Mamute` — Core Audio plumbing, model, SwiftUI menu bar UI.
- `scripts/build-app.sh` — builds with SwiftPM and assembles `build/Mamute.app` (ad-hoc signed).

## Known risks
- If the user denies the audio permission, a tapped app may go silent instead of at the chosen volume. There is no public API to check that permission; first version shows the prompt and relies on the user allowing it.
- Ad-hoc signing changes every build, so macOS may re-ask for permission after rebuilds. Fixed by signing with a Developer ID later.
