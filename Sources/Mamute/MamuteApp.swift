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
        }
        // Give AppKit a moment to place the menu bar icon so the panel can hang under it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            MainActor.assumeIsolated { self?.menuBar?.show() }
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
    private var model: AudioModel!

    init(model: AudioModel) {
        // New icons land at the left end of the menu bar items, which on crowded notched Macs is behind the notch.
        // Default to a spot near the clock instead (points from the right edge); a ⌘-drag by the user overrides it.
        // shortcut: relies on AppKit's undocumented autosave key; if it ever stops working the icon just lands in the default spot.
        UserDefaults.standard.register(defaults: ["NSStatusItem Preferred Position mamute": 300])
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "mamute"
        panel = DropDownPanel(content: ContentView(model: model))
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        iconWatch = model.$muteAll.sink { [weak self] muteAll in
            self?.item.button?.image = mammothIcon(muted: muteAll)
        }
        self.model = model
    }

    @objc private func clicked() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRightClick { showContextMenu() } else { panel.isVisible ? hide() : show() }
    }

    /// Right-click menu: Mute all / Unmute all and Quit.
    private func showContextMenu() {
        hide()
        let menu = NSMenu()
        let mute = NSMenuItem(title: model.muteAll ? "Unmute all" : "Mute all", action: #selector(toggleMuteAll), keyEquivalent: "")
        mute.target = self
        menu.addItem(mute)
        menu.addItem(.separator())
        // Custom action instead of NSApplication.terminate: macOS adds a system icon to the standard Quit action.
        let quit = NSMenuItem(title: "Quit Mamute", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        // Attach only for this click, otherwise the menu would also open on a normal left click.
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func toggleMuteAll() { model.toggleMuteAll() }

    func show() {
        panel.anchor = anchor()
        panel.reposition()
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

    private func isBehindNotch(_ icon: NSRect, on screen: NSScreen) -> Bool {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return false }
        return icon.midX > left.maxX && icon.midX < right.minX
    }

    /// Where the panel hangs: under the icon, or at the top-right of the screen if the icon is hidden (e.g. behind the notch).
    private func anchor() -> DropDownPanel.Anchor {
        if let window = item.button?.window, let screen = window.screen, window.frame.height > 0, // 0 until AppKit places the icon
           window.frame.maxY >= screen.frame.maxY - 1, !isBehindNotch(window.frame, on: screen) {
            return .init(top: window.frame.minY - 6, midX: window.frame.midX, screen: screen.frame)
        }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        return .init(top: screen.visibleFrame.maxY - 6, midX: screen.visibleFrame.maxX, screen: screen.visibleFrame)
    }
}

/// Borderless floating panel that grows downward from a fixed top edge.
final class DropDownPanel: NSPanel {
    struct Anchor { let top: CGFloat, midX: CGFloat, screen: NSRect }
    var anchor: Anchor?
    private var resizeWatch: NSObjectProtocol?

    init<Content: View>(content: Content) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let host = FirstClickHostingView(rootView: content)
        host.sizingOptions = [.minSize, .maxSize] // window always matches the SwiftUI content's size
        contentView = host
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        // Re-anchor after SwiftUI resizes the panel. Done on the next run loop turn, not inside the
        // resize, because moving the window mid-layout recursed until the stack overflowed.
        resizeWatch = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [weak self] _ in
            DispatchQueue.main.async { self?.reposition() }
        }
    }

    /// Hangs the panel from its anchor at its current size, centered but kept 8pt inside the screen.
    func reposition() {
        guard let anchor else { return }
        let width = frame.width
        let x = min(max(anchor.midX - width / 2, anchor.screen.minX + 8), anchor.screen.maxX - width - 8)
        let origin = NSPoint(x: x, y: anchor.top - frame.height)
        if frame.origin != origin { setFrameOrigin(origin) }
    }

    override var canBecomeKey: Bool { true }
}

/// Lets the first click on the panel press buttons right away, even when Mamute isn't the active app.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct ContentView: View {
    @ObservedObject var model: AudioModel

    private static let rowHeight: CGFloat = 54
    private static let rowSpacing: CGFloat = 6

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
                // Fixed row height so the list's size never depends on its own layout (that fed a resize loop).
                ScrollView {
                    VStack(spacing: Self.rowSpacing) {
                        ForEach(model.rows) { AppRowView(row: $0, model: model).frame(height: Self.rowHeight) }
                            .disabled(model.muteAll)
                            .opacity(model.muteAll ? 0.45 : 1)
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: min(CGFloat(model.rows.count) * (Self.rowHeight + Self.rowSpacing) - Self.rowSpacing, 420))
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
                    if row.setting.muted {
                        Text("Muted")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.red))
                    } else {
                        Text("\(Int((row.setting.volume * 100).rounded()))%")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Button { model.toggleMute(row.id) } label: {
                        Image(systemName: row.setting.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: row.setting.muted ? .bold : .regular))
                            .foregroundStyle(row.setting.muted ? Color.primary : Color.secondary)
                            .frame(width: 22, height: 18)
                            .contentShape(Rectangle()) // whole box is clickable, not just the glyph
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
