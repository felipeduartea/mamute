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

## Download

Requires macOS 14.2 or newer, on Apple Silicon or Intel.

1. Download **Mamute.zip** from the [latest release](https://github.com/felipeduartea/mamute/releases/latest) and unzip it.
2. Drag **Mamute** into your **Applications** folder and double-click it.
3. macOS will say it can't verify the app, because Mamute isn't signed by an Apple-registered developer yet. Click **Done**, then open **System Settings → Privacy & Security**, scroll down to the message about Mamute and click **Open Anyway**. Confirm with your password. You only need to do this once.
4. The first time you change an app's volume, macOS asks to allow **System Audio Recording**. Click **Allow**; Mamute needs it to control app audio.

## Build from source

Needs Xcode (or the Swift toolchain).

```bash
git clone https://github.com/felipeduartea/mamute.git
cd mamute
./scripts/build-app.sh
open build/Mamute.app
```

If you deny the **System Audio Recording** permission, an app you turn down may go fully silent instead. You can change this later in System Settings → Privacy & Security.

Run the tests with `swift test`.

## How it works

Mamute uses Core Audio process taps (macOS 14.2+). Apps at 100% are left alone. For an app you mute or turn down, Mamute taps its audio, which silences the app's normal output, and plays the tapped audio to your output device at the volume you picked (silence when muted). The taps are private to Mamute, so they disappear when it quits.

More detail in [docs/design.md](docs/design.md).

## License

MIT, see [LICENSE](LICENSE).
