import AppKit
import CoreAudio
import os

struct AppSetting: Codable, Equatable {
    var volume: Float = 1
    var muted = false
    var gain: Float { muted ? 0 : volume }
}

struct AppRow: Identifiable {
    let id: String // bundle ID
    let name: String
    let icon: NSImage?
    let isPlaying: Bool
    let setting: AppSetting
    let failed: Bool
}

@MainActor
final class AudioModel: ObservableObject {
    static let shared = AudioModel()

    @Published private(set) var rows: [AppRow] = []

    private var settings: [String: AppSetting]
    private var seen: Set<String> = [] // apps that played since launch
    private var taps: [String: AppTap] = [:]
    private var failed: Set<String> = []
    private var timer: Timer?
    private let log = Logger(subsystem: "com.felipeduarte.mamute", category: "audio")
    private static let settingsKey = "settings"

    var anyQuieted: Bool { rows.contains { $0.setting.gain < 1 } }

    init() {
        let data = UserDefaults.standard.data(forKey: Self.settingsKey)
        settings = data.flatMap { try? JSONDecoder().decode([String: AppSetting].self, from: $0) } ?? [:]
        refresh()
        // shortcut: polls once a second instead of Core Audio listeners; cheap, and also catches output device changes. Switch to listeners if CPU shows up.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func setVolume(_ bundleID: String, _ volume: Float) {
        update(bundleID) { $0.volume = volume; if volume > 0 { $0.muted = false } }
    }

    func toggleMute(_ bundleID: String) {
        update(bundleID) { $0.muted.toggle() }
    }

    private func update(_ bundleID: String, _ change: (inout AppSetting) -> Void) {
        var s = settings[bundleID] ?? AppSetting()
        change(&s)
        settings[bundleID] = s == AppSetting() ? nil : s
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: Self.settingsKey) }
        failed.remove(bundleID)
        refresh()
    }

    func refresh() {
        let ownID = Bundle.main.bundleIdentifier
        var groups: [String: (app: NSRunningApplication, processes: Set<AudioObjectID>, playing: Bool)] = [:]
        for process in audioProcesses() {
            guard let app = owningApp(of: process), let id = app.bundleIdentifier, id != ownID else { continue }
            var g = groups[id] ?? (app, [], false)
            g.processes.insert(process.id)
            g.playing = g.playing || process.isPlaying
            groups[id] = g
        }
        for (id, g) in groups where g.playing { seen.insert(id) }

        reconcileTaps(groups.mapValues(\.processes))

        rows = groups
            .filter { id, g in g.playing || seen.contains(id) || settings[id] != nil }
            .map { id, g in
                AppRow(id: id, name: g.app.localizedName ?? id, icon: g.app.icon, isPlaying: g.playing,
                       setting: settings[id] ?? AppSetting(), failed: failed.contains(id))
            }
            .sorted { ($0.isPlaying ? 0 : 1, $0.name.lowercased()) < ($1.isPlaying ? 0 : 1, $1.name.lowercased()) }
    }

    /// Keeps exactly one tap per app whose gain isn't 100%, rebuilt when its processes or the output device change.
    private func reconcileTaps(_ groups: [String: Set<AudioObjectID>]) {
        let output = defaultOutputUID()
        for (id, tap) in taps {
            let gain = settings[id]?.gain ?? 1
            if gain == 1 || groups[id] != tap.processes || tap.outputUID != output { taps[id] = nil }
        }
        guard let output else { return }
        for (id, processes) in groups {
            let gain = settings[id]?.gain ?? 1
            guard gain != 1 else { continue }
            if let tap = taps[id] { tap.setGain(gain); continue }
            guard !failed.contains(id) else { continue }
            do {
                taps[id] = try AppTap(processes: processes, outputUID: output, gain: gain)
            } catch {
                log.error("\(id, privacy: .public): \(String(describing: error), privacy: .public)")
                failed.insert(id)
            }
        }
    }
}
