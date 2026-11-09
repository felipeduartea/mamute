import CoreAudio
import Foundation
import MamuteCore

/// Silences an app's own output and replays it to the output device at `gain`.
/// Everything is private to this process, so it all goes away if Mamute quits or crashes.
final class AppTap {
    let processes: Set<AudioObjectID>
    let outputUID: String
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    // shortcut: plain Float shared with the audio thread (word-sized writes are atomic on Apple CPUs); use Atomic once we require macOS 15.
    private let gain = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private let queue = DispatchQueue(label: "mamute.tap", qos: .userInteractive)

    init(processes: Set<AudioObjectID>, outputUID: String, gain initial: Float) throws {
        self.processes = processes
        self.outputUID = outputUID
        gain.initialize(to: initial)
        do { try start() } catch { stop(); throw error }
    }

    deinit { stop(); gain.deallocate() }

    func setGain(_ value: Float) { gain.pointee = value }

    private func start() throws {
        let desc = CATapDescription(stereoMixdownOfProcesses: Array(processes))
        desc.uuid = UUID()
        desc.isPrivate = true
        desc.muteBehavior = .mutedWhenTapped
        try check(AudioHardwareCreateProcessTap(desc, &tapID), "Create tap")

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Mamute",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: desc.uuid.uuidString]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &deviceID), "Create aggregate device")

        let gain = self.gain
        var applied = gain.pointee
        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, queue) { _, input, _, output, _ in
            let target = gain.pointee
            mix(input: UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)),
                output: UnsafeMutableAudioBufferListPointer(output), from: applied, to: target)
            applied = target
        }, "Create IO proc")
        try check(AudioDeviceStart(deviceID, procID), "Start device")
    }

    private func stop() {
        if let procID {
            AudioDeviceStop(deviceID, procID)
            AudioDeviceDestroyIOProcID(deviceID, procID)
            self.procID = nil
        }
        if deviceID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(deviceID); deviceID = AudioObjectID(kAudioObjectUnknown) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID); tapID = AudioObjectID(kAudioObjectUnknown) }
    }
}
