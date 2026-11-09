import AppKit
import CoreAudio

struct CoreAudioError: Error, CustomStringConvertible {
    let status: OSStatus, what: String
    var description: String { "\(what) failed (\(status))" }
}

func check(_ status: OSStatus, _ what: String) throws {
    guard status == noErr else { throw CoreAudioError(status: status, what: what) }
}

private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
}

func readValue<T: BitwiseCopyable>(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector, _ fallback: T) -> T {
    var addr = address(selector)
    var value = fallback
    var size = UInt32(MemoryLayout<T>.size)
    return AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &value) == noErr ? value : fallback
}

func readString(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var addr = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &value) == noErr, let v = value else { return nil }
    return v.takeRetainedValue() as String
}

func readObjectList(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
    var addr = address(selector)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(obj, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
}

/// UID of the current default output device.
func defaultOutputUID() -> String? {
    let device = readValue(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, AudioObjectID(kAudioObjectUnknown))
    return device == kAudioObjectUnknown ? nil : readString(device, kAudioDevicePropertyDeviceUID)
}

struct AudioProcess {
    let id: AudioObjectID
    let pid: pid_t
    let bundleID: String?
    let isPlaying: Bool
}

func audioProcesses() -> [AudioProcess] {
    readObjectList(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList).map { id in
        AudioProcess(
            id: id,
            pid: readValue(id, kAudioProcessPropertyPID, pid_t(-1)),
            bundleID: readString(id, kAudioProcessPropertyBundleID),
            isPlaying: readValue(id, kAudioProcessPropertyIsRunningOutput, UInt32(0)) != 0
        )
    }
}

// shortcut: private libsystem symbol, the same one Activity Monitor-style tools use to attribute helper processes;
// looked up at runtime so a missing symbol only falls back to bundle-ID matching. Revisit for App Store builds.
private let responsiblePID: (@convention(c) (pid_t) -> pid_t)? = {
    guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else { return nil }
    return unsafeBitCast(sym, to: (@convention(c) (pid_t) -> pid_t).self)
}()

/// The user-facing app an audio process belongs to (e.g. a Chrome helper → Chrome).
func owningApp(of process: AudioProcess) -> NSRunningApplication? {
    let pid = responsiblePID?(process.pid) ?? process.pid
    if let app = NSRunningApplication(processIdentifier: pid), app.bundleIdentifier != nil, app.activationPolicy != .prohibited {
        return app
    }
    guard let bundleID = process.bundleID else { return nil }
    return NSWorkspace.shared.runningApplications.first {
        $0.activationPolicy == .regular && $0.bundleIdentifier.map { bundleID.hasPrefix($0) } == true
    }
}
