// audio-priority — pick exactly one default output/input device by priority.
//
// Listens for CoreAudio device arrivals/removals (plugging in the WooAudio DAC,
// connecting Bluetooth headphones, docking/undocking) and sets the system
// default output, alert output, and input device to the highest-priority device
// that is currently present, per ~/.config/audio-priority/priority.conf.
//
// It only acts when a device named in the config appears or disappears, so a
// device you pick by hand in Control Center sticks until the hardware changes.
//
// While running as a daemon it also feeds recorders like Loopback, so they never need
// per-app or per-device sources:
//   BlackHole 2ch       receives a mirror of every app's output, taken with a Core Audio
//                       process tap (macOS 14.2+), whatever device the app plays to.
//                       Needs the System Audio Recording permission. (Loopback can't read
//                       a tap-only aggregate directly, hence the mirror into BlackHole.)
//   "Preferred Mic"     wraps the current default input and follows it, whether the
//                       priority list or a manual pick in Control Center changed it.
// Both stop when the daemon stops.
//
// Usage:
//   audio-priority           run as a daemon (what the LaunchAgent does)
//   audio-priority --once    apply the priority list once and exit
//   audio-priority --list    list devices (name, transport, UID) to help write the config
//
// Build: see install.sh (embeds Info.plist so macOS can grant the audio-capture permission).

import CoreAudio
import Foundation

// MARK: - CoreAudio helpers

let systemObject = AudioObjectID(kAudioObjectSystemObject)

func address(_ selector: AudioObjectPropertySelector,
             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
    var addr = address(selector)
    var ref: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &ref) == noErr, let value = ref else { return "" }
    return value.takeRetainedValue() as String
}

func uint32Property(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32 {
    var addr = address(selector)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value)
    return value
}

func streamCount(_ id: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Int {
    var addr = address(kAudioDevicePropertyStreams, scope)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr else { return 0 }
    return Int(size) / MemoryLayout<AudioStreamID>.size
}

struct Device {
    let id: AudioObjectID
    let name: String
    let uid: String
    let transport: UInt32
    let hasOutput: Bool
    let hasInput: Bool

    var isBluetooth: Bool {
        transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
    }

    var transportName: String {
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: return "built-in"
        case kAudioDeviceTransportTypeUSB: return "usb"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "bluetooth"
        case kAudioDeviceTransportTypeHDMI: return "hdmi"
        case kAudioDeviceTransportTypeDisplayPort: return "displayport"
        case kAudioDeviceTransportTypeAggregate: return "aggregate"
        case kAudioDeviceTransportTypeVirtual: return "virtual"
        case kAudioDeviceTransportTypeAirPlay: return "airplay"
        default: return "other"
        }
    }
}

func allDevices() -> [Device] {
    var addr = address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids.map { id in
        Device(id: id,
               name: stringProperty(id, kAudioObjectPropertyName),
               uid: stringProperty(id, kAudioDevicePropertyDeviceUID),
               transport: uint32Property(id, kAudioDevicePropertyTransportType),
               hasOutput: streamCount(id, kAudioObjectPropertyScopeOutput) > 0,
               hasInput: streamCount(id, kAudioObjectPropertyScopeInput) > 0)
    }
}

func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioObjectID {
    uint32Property(systemObject, selector)
}

func setDefaultDevice(_ selector: AudioObjectPropertySelector, _ id: AudioObjectID) -> OSStatus {
    var addr = address(selector)
    var value = id
    return AudioObjectSetPropertyData(systemObject, &addr, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &value)
}

func deviceID(forUID uid: String) -> AudioObjectID {
    var addr = address(kAudioHardwarePropertyTranslateUIDToDevice)
    var cfUID = uid as CFString
    var id = AudioObjectID(0)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = withUnsafeMutablePointer(to: &cfUID) { uidPtr in
        AudioObjectGetPropertyData(systemObject, &addr, UInt32(MemoryLayout<CFString>.size), uidPtr, &size, &id)
    }
    return status == noErr ? id : 0
}

func setCFProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: CFTypeRef) -> OSStatus {
    var addr = address(selector)
    var ref: CFTypeRef = value
    return withUnsafeMutablePointer(to: &ref) { refPtr in
        AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<CFTypeRef>.size), refPtr)
    }
}

// MARK: - Config

let configPath = ProcessInfo.processInfo.environment["AUDIO_PRIORITY_CONFIG"]
    ?? NSString(string: "~/.config/audio-priority/priority.conf").expandingTildeInPath

struct Config {
    var output: [String] = []
    var input: [String] = []
}

/// Lines look like `output: WooAudio` or `input: MacBook Pro Microphone`; order = priority.
/// `#` starts a comment. Re-read on every apply, so edits take effect on the next device change
/// (or immediately with `audio-priority --once`).
func loadConfig() -> Config {
    var config = Config()
    guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else {
        log("config not found at \(configPath); nothing to do")
        return config
    }
    for rawLine in text.split(whereSeparator: \.isNewline) {
        let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[1].isEmpty else { continue }
        switch parts[0].lowercased() {
        case "output": config.output.append(parts[1])
        case "input": config.input.append(parts[1])
        default: log("ignoring unknown config key '\(parts[0])'")
        }
    }
    return config
}

/// Pattern forms:
///   bluetooth      any Bluetooth / Bluetooth LE device
///   uid:<UID>      exact CoreAudio device UID (see --list)
///   <text>         case-insensitive substring of the device name; runs of whitespace are
///                  treated as one space, since the same model can report "USB AUDIO  CODEC"
///                  on one Mac and "USB Audio CODEC " on another
func matches(_ pattern: String, _ device: Device) -> Bool {
    let lowered = pattern.lowercased()
    if lowered == "bluetooth" { return device.isBluetooth }
    if lowered.hasPrefix("uid:") {
        return device.uid == pattern.dropFirst(4).trimmingCharacters(in: .whitespaces)
    }
    return normalized(device.name).contains(normalized(pattern))
}

func normalized(_ text: String) -> String {
    text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

func pick(_ patterns: [String], from devices: [Device]) -> Device? {
    for pattern in patterns {
        if let device = devices.first(where: { matches(pattern, $0) }) { return device }
    }
    return nil
}

// MARK: - Apply

func log(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    print("\(stamp) \(message)")
    fflush(stdout)
}

func setIfNeeded(_ selector: AudioObjectPropertySelector, _ device: Device, _ label: String) {
    guard defaultDevice(selector) != device.id else { return }
    let status = setDefaultDevice(selector, device)
    log(status == noErr ? "\(label) -> \(device.name)" : "failed to set \(label) to \(device.name) (OSStatus \(status))")
}

func setDefaultDevice(_ selector: AudioObjectPropertySelector, _ device: Device) -> OSStatus {
    setDefaultDevice(selector, device.id)
}

func apply(reason: String) {
    let config = loadConfig()
    // Never pick the devices this daemon publishes.
    let devices = allDevices().filter { !$0.uid.hasPrefix(uidPrefix) }
    log("applying (\(reason))")
    if let out = pick(config.output, from: devices.filter(\.hasOutput)) {
        setIfNeeded(kAudioHardwarePropertyDefaultOutputDevice, out, "output")
        // Keep alert/UI sounds on the same device so nothing plays on two devices.
        setIfNeeded(kAudioHardwarePropertyDefaultSystemOutputDevice, out, "alert output")
    } else {
        log("no configured output device present; leaving output unchanged")
    }
    if let inp = pick(config.input, from: devices.filter(\.hasInput)) {
        setIfNeeded(kAudioHardwarePropertyDefaultInputDevice, inp, "input")
    } else {
        log("no configured input device present; leaving input unchanged")
    }
}

/// Signature of the configured devices that are present right now. Changes only when a device
/// we care about arrives or leaves, so unrelated churn (Loopback edits, Zoom/Teams virtual
/// devices) doesn't clobber a manual selection.
func relevantSignature() -> Set<String> {
    let config = loadConfig()
    var signature = Set<String>()
    for device in allDevices() {
        if device.hasOutput, config.output.contains(where: { matches($0, device) }) { signature.insert("out:" + device.uid) }
        if device.hasInput, config.input.contains(where: { matches($0, device) }) { signature.insert("in:" + device.uid) }
    }
    return signature
}

// MARK: - Published devices (daemon mode only)

let uidPrefix = "com.bschur.audio-priority"
let systemAudioUID = uidPrefix + ".system-audio"
let preferredMicUID = uidPrefix + ".preferred-mic"
/// Where the system-audio mirror is written. Loopback reads this like any hardware input.
let mirrorDeviceUID = ProcessInfo.processInfo.environment["AUDIO_PRIORITY_MIRROR_UID"] ?? "BlackHole2ch_UID"

var systemTapID = AudioObjectID(0)
var systemAudioID = AudioObjectID(0)
var systemAudioProc: AudioDeviceIOProcID?
var preferredMicID = AudioObjectID(0)
var preferredMicSource = ""

/// Public aggregates outlive the process that made them, so clear any left by a crash.
func destroyLeftover(_ uid: String) {
    let id = deviceID(forUID: uid)
    if id != 0 { AudioHardwareDestroyAggregateDevice(id) }
}

func ownProcessObject() -> AudioObjectID {
    var addr = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
    var pid = getpid()
    var object = AudioObjectID(0)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    AudioObjectGetPropertyData(systemObject, &addr, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
    return object
}

/// Mirrors every app's output into BlackHole 2ch.
///
/// Loopback can't record a tap-only aggregate (it opens an aggregate's hardware sub-devices and
/// ignores taps), so instead the daemon runs a private aggregate of [BlackHole + global tap] and
/// copies the tap's input straight to BlackHole's output in one IO callback, sharing one clock.
/// This process is excluded from the tap so the mirror doesn't feed back into itself.
func createSystemAudio() {
    destroyLeftover(systemAudioUID)
    let mirror = deviceID(forUID: mirrorDeviceUID)
    guard mirror != 0 else {
        log("mirror device \(mirrorDeviceUID) not found; system audio mirror disabled")
        return
    }

    let tap = CATapDescription(stereoGlobalTapButExcludeProcesses: [ownProcessObject()])
    tap.name = "audio-priority system tap"
    tap.isPrivate = true
    tap.muteBehavior = .unmuted
    var status = AudioHardwareCreateProcessTap(tap, &systemTapID)
    guard status == noErr else { log("failed to create system audio tap (OSStatus \(status))"); return }

    let composition: [String: Any] = [
        kAudioAggregateDeviceNameKey: "audio-priority system audio mirror",
        kAudioAggregateDeviceUIDKey: systemAudioUID,
        kAudioAggregateDeviceIsPrivateKey: 1,
        kAudioAggregateDeviceMainSubDeviceKey: mirrorDeviceUID,
        kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: mirrorDeviceUID]],
        kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tap.uuid.uuidString,
                                           kAudioSubTapDriftCompensationKey: 1]],
    ]
    status = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &systemAudioID)
    guard status == noErr else { log("failed to create system audio mirror (OSStatus \(status))"); return }

    // Input buffers are the sub-device's (BlackHole) input streams first, then the tap's.
    let mirrorInputStreams = streamCount(mirror, kAudioObjectPropertyScopeInput)
    status = AudioDeviceCreateIOProcIDWithBlock(&systemAudioProc, systemAudioID, nil) { _, inData, _, outData, _ in
        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
        let outputs = UnsafeMutableAudioBufferListPointer(outData)
        for (index, out) in outputs.enumerated() {
            guard let dst = out.mData else { continue }
            let tapIndex = mirrorInputStreams + index
            if tapIndex < inputs.count, let src = inputs[tapIndex].mData {
                memcpy(dst, src, Int(min(out.mDataByteSize, inputs[tapIndex].mDataByteSize)))
            } else {
                memset(dst, 0, Int(out.mDataByteSize))
            }
        }
    }
    guard status == noErr else { log("failed to create mirror IO proc (OSStatus \(status))"); return }
    status = AudioDeviceStart(systemAudioID, systemAudioProc)
    log(status == noErr ? "mirroring all system audio into \(mirrorDeviceUID)"
                        : "failed to start system audio mirror (OSStatus \(status))")
}

/// The default input, unless it's something Preferred Mic can't safely wrap: our own devices,
/// or a virtual/aggregate device such as Meeting Capture, which could feed back into itself.
func wrappableDefaultInput() -> Device? {
    let id = defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
    guard let device = allDevices().first(where: { $0.id == id }),
          !device.uid.hasPrefix(uidPrefix),
          device.transport != kAudioDeviceTransportTypeVirtual,
          device.transport != kAudioDeviceTransportTypeAggregate else { return nil }
    return device
}

func createPreferredMic() {
    destroyLeftover(preferredMicUID)
    guard let mic = wrappableDefaultInput() else {
        log("default input isn't a hardware mic; \"Preferred Mic\" not published yet")
        return
    }
    let composition: [String: Any] = [
        kAudioAggregateDeviceNameKey: "Preferred Mic",
        kAudioAggregateDeviceUIDKey: preferredMicUID,
        kAudioAggregateDeviceIsPrivateKey: 0,
        kAudioAggregateDeviceMainSubDeviceKey: mic.uid,
        kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: mic.uid]],
    ]
    let status = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &preferredMicID)
    if status == noErr {
        preferredMicSource = mic.uid
        log("published \"Preferred Mic\" -> \(mic.name)")
    } else {
        log("failed to publish \"Preferred Mic\" (OSStatus \(status))")
    }
}

func updatePreferredMic() {
    guard let mic = wrappableDefaultInput(), mic.uid != preferredMicSource else { return }
    guard preferredMicID != 0 else { createPreferredMic(); return }
    let listStatus = setCFProperty(preferredMicID, kAudioAggregateDevicePropertyFullSubDeviceList, [mic.uid] as CFArray)
    let mainStatus = setCFProperty(preferredMicID, kAudioAggregateDevicePropertyMainSubDevice, mic.uid as CFString)
    if listStatus == noErr && mainStatus == noErr {
        preferredMicSource = mic.uid
        log("\"Preferred Mic\" -> \(mic.name)")
    } else {
        // Fall back to rebuilding the device from scratch.
        log("retargeting \"Preferred Mic\" failed (OSStatus \(listStatus)/\(mainStatus)); recreating")
        AudioHardwareDestroyAggregateDevice(preferredMicID)
        preferredMicID = 0
        createPreferredMic()
    }
}

func destroyPublishedDevices() {
    if preferredMicID != 0 { AudioHardwareDestroyAggregateDevice(preferredMicID) }
    if systemAudioID != 0 {
        if let proc = systemAudioProc {
            AudioDeviceStop(systemAudioID, proc)
            AudioDeviceDestroyIOProcID(systemAudioID, proc)
        }
        AudioHardwareDestroyAggregateDevice(systemAudioID)
    }
    if systemTapID != 0 { AudioHardwareDestroyProcessTap(systemTapID) }
    preferredMicID = 0; systemAudioID = 0; systemTapID = 0; systemAudioProc = nil
}

/// BlackHole can vanish (driver reload) and come back; rebuild the mirror when it does.
func ensureSystemAudioMirror() {
    let mirrorPresent = deviceID(forUID: mirrorDeviceUID) != 0
    let running = systemAudioID != 0 && allDevices().contains { $0.id == systemAudioID }
    guard mirrorPresent != running else { return }
    if let proc = systemAudioProc, systemAudioID != 0 {
        AudioDeviceStop(systemAudioID, proc)
        AudioDeviceDestroyIOProcID(systemAudioID, proc)
    }
    if systemAudioID != 0 { AudioHardwareDestroyAggregateDevice(systemAudioID) }
    if systemTapID != 0 { AudioHardwareDestroyProcessTap(systemTapID) }
    systemAudioID = 0; systemTapID = 0; systemAudioProc = nil
    if mirrorPresent { createSystemAudio() } else { log("mirror device gone; system audio mirror paused") }
}

// MARK: - Main

let args = CommandLine.arguments.dropFirst()

if args.contains("--list") {
    for d in allDevices() {
        let dirs = [d.hasOutput ? "out" : nil, d.hasInput ? "in" : nil].compactMap { $0 }.joined(separator: "+")
        print("\(d.name)\t[\(dirs), \(d.transportName)]\tuid:\(d.uid)")
    }
    exit(0)
}

if args.contains("--once") {
    apply(reason: "manual")
    exit(0)
}

let queue = DispatchQueue(label: "audio-priority")
var lastSignature = Set<String>()
var pending: [DispatchWorkItem] = []

func handleDeviceChange() {
    // Debounce: devices (especially Bluetooth) arrive in bursts, and macOS runs its own
    // auto-switch right after a device connects. Settle first, then check once more later
    // so our choice is the one that sticks.
    pending.forEach { $0.cancel() }
    let settle = DispatchWorkItem {
        ensureSystemAudioMirror()
        let signature = relevantSignature()
        guard signature != lastSignature else { return }
        lastSignature = signature
        apply(reason: "device change")
        let followUp = DispatchWorkItem { apply(reason: "device change, follow-up") }
        pending = [followUp]
        queue.asyncAfter(deadline: .now() + 2.5, execute: followUp)
    }
    pending = [settle]
    queue.asyncAfter(deadline: .now() + 1.5, execute: settle)
}

var devicesAddress = address(kAudioHardwarePropertyDevices)
let status = AudioObjectAddPropertyListenerBlock(systemObject, &devicesAddress, queue) { _, _ in
    handleDeviceChange()
}
guard status == noErr else {
    log("failed to register device listener (OSStatus \(status))")
    exit(1)
}

// Keep "Preferred Mic" on whatever the default input is, including manual picks.
var defaultInputAddress = address(kAudioHardwarePropertyDefaultInputDevice)
AudioObjectAddPropertyListenerBlock(systemObject, &defaultInputAddress, queue) { _, _ in
    updatePreferredMic()
}

// Remove the published devices on a normal stop (launchctl bootout/kickstart, Ctrl-C).
signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)
let signalSources = [SIGTERM, SIGINT].map { sig -> DispatchSourceSignal in
    let source = DispatchSource.makeSignalSource(signal: sig, queue: queue)
    source.setEventHandler {
        destroyPublishedDevices()
        log("stopped")
        exit(0)
    }
    source.resume()
    return source
}

queue.async {
    lastSignature = relevantSignature()
    apply(reason: "startup")
    createSystemAudio()
    createPreferredMic()
}
log("watching for audio device changes (config: \(configPath))")
dispatchMain()
