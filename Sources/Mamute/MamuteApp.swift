import Combine
import SwiftUI

@main
struct MamuteApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    // Everything lives in the status item and its panel; SwiftUI just needs a scene.
    var body: some Scene { Settings { EmptyView() } }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            menuBar = MenuBarController(model: .shared)
            menuBar?.show()
        }
    }

    // Opening Mamute again (Finder, Spotlight) drops the panel down, in case the icon is hidden behind the notch.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        MainActor.assumeIsolated { menuBar?.show() }
        return false
    }
}

/// Menu bar icon plus a panel that drops down under it, like Control Center.
@MainActor
final class MenuBarController {
    private let item: NSStatusItem
    private let panel: DropDownPanel
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var iconWatch: AnyCancellable?

    init(model: AudioModel) {
        // New icons land at the left end of the menu bar items, which on crowded notched Macs is behind the notch.
        // Default to a spot near the clock instead (points from the right edge); a ⌘-drag by the user overrides it.
        // shortcut: relies on AppKit's undocumented autosave key; if it ever stops working the icon just lands in the default spot.
        UserDefaults.standard.register(defaults: ["NSStatusItem Preferred Position mamute": 300])
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "mamute"
        panel = DropDownPanel(content: ContentView(model: model))
        item.button?.target = self
        item.button?.action = #selector(toggle)
        iconWatch = model.$muteAll.sink { [weak self] muteAll in
            self?.item.button?.image = mammothIcon(muted: muteAll)
        }
    }

    @objc private func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        panel.anchorTop = place()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event } // Escape
            self?.hide()
            return nil
        }
    }

    private func hide() {
        panel.orderOut(nil)
        [clickMonitor, keyMonitor].compactMap { $0 }.forEach(NSEvent.removeMonitor)
        clickMonitor = nil
        keyMonitor = nil
    }

    /// Puts the panel under the icon, or at the top-right of the screen if the icon is hidden (e.g. behind the notch).
    /// Returns the top edge the panel stays pinned to as it grows.
    private func place() -> CGFloat {
        if let fitting = panel.contentViewController?.view.fittingSize { panel.setContentSize(fitting) }
        let size = panel.frame.size
        if let window = item.button?.window, window.occlusionState.contains(.visible), let screen = window.screen {
            let icon = window.frame
            let x = min(max(icon.midX - size.width / 2, screen.frame.minX + 8), screen.frame.maxX - size.width - 8)
            panel.setFrameOrigin(NSPoint(x: x, y: icon.minY - 6 - size.height))
            return icon.minY - 6
        }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let top = screen.visibleFrame.maxY - 6
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - size.width - 8, y: top - size.height))
        return top
    }
}

/// Borderless floating panel that grows downward from a fixed top edge.
final class DropDownPanel: NSPanel {
    var anchorTop: CGFloat?

    init<Content: View>(content: Content) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let host = NSHostingController(rootView: content)
        host.sizingOptions = .preferredContentSize
        contentViewController = host
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var rect = frameRect
        if let anchorTop { rect.origin.y = anchorTop - rect.height }
        super.setFrame(rect, display: flag)
    }
}

struct ContentView: View {
    @ObservedObject var model: AudioModel

    private var playingCount: Int { model.rows.filter(\.isPlaying).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Image(nsImage: mammothIcon(muted: false, size: 16)).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                Text("Mamute").font(.system(size: 13, weight: .semibold))
                Text(playingCount == 1 ? "1 playing" : "\(playingCount) playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { model.toggleMuteAll() } label: {
                    Label(model.muteAll ? "Unmute all" : "Mute all",
                          systemImage: model.muteAll ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(model.muteAll ? Color.red.opacity(0.85) : Color.primary.opacity(0.08)))
                        .foregroundStyle(model.muteAll ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .help(model.muteAll ? "Bring every app back to its own volume" : "Silence every app")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if model.rows.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "speaker.zzz").font(.title2).foregroundStyle(.tertiary)
                    Text("No apps are playing sound").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.rows) { AppRowView(row: $0, model: model) }
                            .disabled(model.muteAll)
                            .opacity(model.muteAll ? 0.45 : 1)
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 420)
                .fixedSize(horizontal: false, vertical: true)
            }

            Divider().padding(.horizontal, 14).padding(.top, 8)
            HStack {
                Spacer()
                Button("Quit Mamute") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12)))
    }
}

struct AppRowView: View {
    let row: AppRow
    @ObservedObject var model: AudioModel

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = row.icon { Image(nsImage: icon).resizable() } else { Image(systemName: "app.fill").resizable() }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(row.name).font(.system(size: 13)).lineLimit(1)
                    if row.isPlaying {
                        Image(systemName: "waveform").font(.caption2).foregroundStyle(.secondary).accessibilityLabel("Playing")
                    }
                    if row.failed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .help("Mamute couldn't control this app's audio.")
                    }
                    Spacer()
                    Text(row.setting.muted ? "Muted" : "\(Int((row.setting.volume * 100).rounded()))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(row.setting.muted ? Color.red : Color.secondary)
                }
                HStack(spacing: 6) {
                    Button { model.toggleMute(row.id) } label: {
                        Image(systemName: row.setting.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11))
                            .frame(width: 16)
                            .foregroundStyle(row.setting.muted ? Color.red : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(row.setting.muted ? "Unmute" : "Mute")
                    .accessibilityLabel(row.setting.muted ? "Unmute \(row.name)" : "Mute \(row.name)")
                    Slider(value: Binding(get: { Double(row.setting.volume) },
                                          set: { model.setVolume(row.id, Float($0)) }), in: 0...1)
                        .controlSize(.mini)
                        .opacity(row.setting.muted ? 0.4 : 1)
                        .accessibilityLabel("\(row.name) volume")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}
