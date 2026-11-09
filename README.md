# Mamute

Mute or turn down individual apps on your Mac.

macOS only gives you one volume for everything. Mamute adds a mute button and a volume slider for each app, so you can silence Slack, keep Spotify at 30%, and leave your call at full volume.

## Features

- Click the mammoth in the menu bar and a panel drops down with the apps that are playing sound, each with a mute button and a 0–100% slider
- **Mute all** silences every app at once (the mammoth gets a slash so you know). Turn it off and each app goes back to the volume you set
- Remembers your settings per app, even after the app or your Mac restarts
- Browser audio is grouped under the browser (Chrome, Safari, …), not its helper processes
- Follows you when the output device changes (e.g. AirPods connect)
- No drivers or system extensions. Quit Mamute and every app's audio goes back to normal
- Plays nice with notched MacBooks: the icon starts out right of the notch (⌘-drag it anywhere you like), and opening Mamute from Spotlight or Finder drops the panel down even if the icon is hidden

## Requirements

- macOS 14.2 or newer
- Xcode (or the Swift toolchain) to build it

## Build and run

```bash
git clone https://github.com/felipeduartea/mamute.git
cd mamute
./scripts/build-app.sh
open build/Mamute.app
```

The first time you change an app's volume, macOS asks to allow **System Audio Recording**. Mamute needs it to control app audio; if you deny it, an app you turn down may go fully silent instead. You can change this later in System Settings → Privacy & Security.

Run the tests with `swift test`.

## How it works

Mamute uses Core Audio process taps (macOS 14.2+). Apps at 100% are left alone. For an app you mute or turn down, Mamute taps its audio, which silences the app's normal output, and plays the tapped audio to your output device at the volume you picked (silence when muted). The taps are private to Mamute, so they disappear when it quits.

More detail in [docs/design.md](docs/design.md).

## Known limitations

- Muting is per app, not per browser tab. System alert sounds are not affected.
- Builds are ad-hoc signed, so macOS may ask for the audio permission again after you rebuild.

## License

MIT, see [LICENSE](LICENSE).
