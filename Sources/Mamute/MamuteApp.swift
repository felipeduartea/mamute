import SwiftUI

@main
struct MamuteApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @ObservedObject private var model = AudioModel.shared

    var body: some Scene {
        MenuBarExtra {
            ContentView(model: model)
        } label: {
            Image(systemName: model.anyQuieted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar icons can end up hidden behind the notch when the bar is crowded,
/// so opening Mamute again (Finder, Spotlight, Dock) shows the same panel as a window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { showWindow() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        MainActor.assumeIsolated { showWindow() }
        return false
    }

    @MainActor private func showWindow() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: ContentView(model: AudioModel.shared)))
            w.title = "Mamute"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct ContentView: View {
    @ObservedObject var model: AudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Mamute").font(.headline).padding([.horizontal, .top], 14).padding(.bottom, 8)
            if model.rows.isEmpty {
                Text("No apps are playing sound.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(model.rows) { AppRowView(row: $0, model: model) }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 420)
                .fixedSize(horizontal: false, vertical: true)
            }
            Divider().padding(.top, 8)
            HStack {
                Spacer()
                Button("Quit Mamute") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("q")
            }
            .padding(10)
        }
        .frame(width: 320)
    }
}

struct AppRowView: View {
    let row: AppRow
    @ObservedObject var model: AudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let icon = row.icon { Image(nsImage: icon).resizable().frame(width: 20, height: 20) }
                Text(row.name).lineLimit(1)
                if row.isPlaying {
                    Image(systemName: "waveform").foregroundStyle(.secondary).accessibilityLabel("Playing")
                }
                Spacer()
                if row.failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .help("Mamute couldn't control this app's audio.")
                }
                Text(row.setting.muted ? "Muted" : "\(Int((row.setting.volume * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            HStack(spacing: 8) {
                Button { model.toggleMute(row.id) } label: {
                    Image(systemName: row.setting.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 20)
                        .foregroundStyle(row.setting.muted ? Color.red : Color.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(row.setting.muted ? "Unmute \(row.name)" : "Mute \(row.name)")
                Slider(value: Binding(get: { Double(row.setting.volume) },
                                      set: { model.setVolume(row.id, Float($0)) }), in: 0...1)
                    .controlSize(.small)
                    .opacity(row.setting.muted ? 0.4 : 1)
                    .accessibilityLabel("\(row.name) volume")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}
