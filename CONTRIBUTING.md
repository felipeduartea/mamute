# Contributing to Mamute

Thanks for helping! Bug reports, fixes and small improvements are all welcome.

## Reporting a bug

Open an issue and include:

- your macOS version and Mac model (Apple Silicon or Intel)
- which app's audio misbehaved (e.g. Chrome, Spotify, Zoom) and what you expected
- your output device, if relevant (built-in speakers, AirPods, a USB interface…)

## Building and testing

You need macOS 14.2+ and Xcode (or the Swift toolchain).

```bash
swift test                # unit tests
./scripts/build-app.sh    # builds build/Mamute.app
open build/Mamute.app
```

Quit any running Mamute before opening a new build. macOS asks for the audio permission again after each rebuild unless you have an Apple Development certificate (sign in to Xcode with your Apple ID); the build script picks it up automatically.

## Where things live

- `Sources/MamuteCore`: pure audio math, unit-tested. Put testable logic here.
- `Sources/Mamute`: Core Audio taps, the model and the SwiftUI menu bar panel.
- `docs/design.md`: how it works and why.

## Pull requests

- Keep each PR focused on one change, and explain what it fixes and how you checked it.
- Add or update tests in `Tests/MamuteCoreTests` for logic changes.
- Try it with real audio: play something, mute it, change its volume, quit Mamute and make sure audio comes back.
- CI builds the app and runs the tests on every PR. It needs to pass before merging.
- Before starting something big, open an issue first so we can agree on the approach.

By contributing, you agree your work is released under the [MIT License](LICENSE).
