import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SourceInfo { let label: String; let icon: String; let hint: String }
func sourceInfo(_ type: String) -> SourceInfo {
    switch type {
    case "opticaljack", "optical": return .init(label: "Optisch", icon: "cable.connector", hint: "Digitaler Eingang")
    case "airplay2": return .init(label: "AirPlay", icon: "airplayaudio", hint: "Mac, iPhone")
    case "spotifyconnect": return .init(label: "Spotify", icon: "music.note", hint: "Spotify Connect")
    case "bluetooth": return .init(label: "Bluetooth", icon: "dot.radiowaves.left.and.right", hint: "Vom Zuspieler starten")
    case "upnp": return .init(label: "UPnP", icon: "network", hint: "DLNA")
    case "raat": return .init(label: "Roon", icon: "waveform", hint: "Roon Ready")
    case "line": return .init(label: "Line-In", icon: "cable.connector.horizontal", hint: "Analoger Eingang")
    default: return .init(label: type.isEmpty ? "–" : type, icon: "speaker.wave.2", hint: "")
    }
}

@MainActor
final class Phantom: ObservableObject {
    static let shared = Phantom()
    @Published private(set) var target: Target?
    @Published private(set) var foundDevices: [FoundDevice] = []
    @Published var addressInput = ""
    @Published var deviceSheet = false
    @Published private(set) var searching = false
    @Published private(set) var connecting = false
    @Published private(set) var online = false
    @Published private(set) var everConnected = false
    @Published private(set) var systemName = "Phantom Remote"
    @Published private(set) var speakers: [DDevice] = []
    @Published private(set) var model = "Phantom"
    @Published var volume: Double = 0
    @Published private(set) var muted = false
    @Published private(set) var playing = false
    @Published private(set) var currentType = ""
    @Published private(set) var currentSourceID = ""
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var peer = ""
    @Published private(set) var codec = ""
    @Published private(set) var ops: [String] = []
    @Published private(set) var sources: [DSource] = []
    @Published private(set) var nightMode = false
    @Published private(set) var eqPreset = "flat"
    @Published var eqLow: Double = 0
    @Published var eqHigh: Double = 0
    @Published var balance: Double = 0
    @Published private(set) var supportsNight = false
    @Published private(set) var supportsEq = false
    @Published private(set) var supportsBalance = false
    @Published private(set) var eqPresets: [String] = []
    @Published private(set) var eqRange: ClosedRange<Double> = -6...6
    @Published private(set) var status = "Bitte ein System auswählen"
    @Published var errorMessage: String?
    @Published var volumeLimit: Int = 60 {
        didSet {
            let clamped = max(0, min(100, volumeLimit))
            if clamped != volumeLimit { volumeLimit = clamped; return }   // löst didSet erneut mit gültigem Wert aus
            defaults?.set(clamped, forKey: "volumeLimit")
        }
    }
    @Published private(set) var pingMs: [String: Int?] = [:]
    @Published private(set) var identifying: Set<String> = []
    @Published private(set) var identifyFailed: Set<String> = []
    @Published private(set) var pending = 0
    private(set) var dragging = false
    var host: String { target?.endpoint.address ?? "" }
    var busy: Bool { pending > 0 || connecting || dragging }
    var canControl: Bool { online && target != nil && !connecting }

    private let api: RemoteAPI
    private let defaults: UserDefaults?
    private let discovery: Discovery
    private var endpoints: [String: Endpoint] = [:]
    private var refreshRunning = false
    private var pinging = false
    private var revision = 0
    private var tail: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var volumeToken = UUID()
    private var eqToken = UUID()
    private var balanceToken = UUID()
    private var visibleViews = 0
    private var identifyQueued: Set<String> = []

    init(api: RemoteAPI = RemoteAPI(), defaults: UserDefaults? = .standard, startAutomatically: Bool = true) {
        self.api = api; self.defaults = defaults; self.discovery = Discovery(api: api)
        if let data = defaults?.data(forKey: "selectedTarget"), let saved = try? JSONDecoder().decode(Target.self, from: data),
           !saved.deviceID.isEmpty, !saved.systemID.isEmpty, (try? Endpoint(saved.endpoint.address)) != nil { target = saved }
        if let data = defaults?.data(forKey: "deviceEndpoints"), let saved = try? JSONDecoder().decode([String: Endpoint].self, from: data) { endpoints = saved }
        if defaults?.object(forKey: "volumeLimit") != nil { volumeLimit = max(0, min(100, defaults?.integer(forKey: "volumeLimit") ?? 60)) }
        discovery.onDevice = { [weak self] in self?.receive($0) }
        discovery.onState = { [weak self] active, message in
            self?.searching = active
            if let message { self?.errorMessage = message }
        }
        guard startAutomatically else { return }
        deviceSheet = target == nil
        pollTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                if let self {
                    if tick == 0 { self.rediscover() }
                    if self.visibleViews > 0 || tick % 10 == 0 { await self.refresh() }
                    if tick % 15 == 0 && !self.online && !self.searching { self.rediscover() }
                }
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
                tick += 1
            }
        }
    }
    func shutdown() { pollTask?.cancel(); discovery.stop() }
    func viewAppeared() { visibleViews += 1; Task { await refresh() } }
    func viewDisappeared() { visibleViews = max(0, visibleViews - 1) }
    func rediscover() { discovery.start() }
    private func persist() {
        defaults?.set(try? JSONEncoder().encode(target), forKey: "selectedTarget")
        defaults?.set(try? JSONEncoder().encode(endpoints), forKey: "deviceEndpoints")
    }
    private func receive(_ found: FoundDevice) {
        foundDevices.removeAll { $0.id == found.id }; foundDevices.append(found)
        foundDevices.sort { $0.systemName.localizedStandardCompare($1.systemName) == .orderedAscending }
        endpoints[found.id] = found.endpoint
        // Reconnect only the explicitly selected device AND system, never the first responder.
        if let selected = target, selected.deviceID == found.id, selected.systemID == found.device.systemId,
           found.device.isSystemLeader == true, !busy, selected.endpoint != found.endpoint {
            revision += 1
            target = Target(systemID: selected.systemID, deviceID: selected.deviceID, endpoint: found.endpoint)
            online = false
        }
        persist()
    }
    func addAddress() async {
        guard !busy else { return }
        connecting = true; defer { connecting = false }
        do {
            let found = try await api.probe(Endpoint(addressInput))
            receive(found); errorMessage = nil; addressInput = ""
        } catch { errorMessage = error.localizedDescription }
    }
    func connect(_ found: FoundDevice) async {
        guard !busy else { return }
        connecting = true
        do {
            let verified = try await api.probe(found.endpoint)
            guard verified.id == found.id, verified.device.systemId == found.device.systemId else { throw RemoteError.wrongDevice }
            guard verified.device.isSystemLeader == true else { throw RemoteError.notLeader }
            guard let system = verified.device.systemId else { throw RemoteError.invalidIdentity }
            revision += 1; dragging = false
            target = Target(systemID: system, deviceID: verified.id, endpoint: verified.endpoint)
            endpoints[verified.id] = verified.endpoint
            online = false; everConnected = false; speakers = []; sources = []; pingMs = [:]
            systemName = verified.systemName; status = "Verbinde …"; errorMessage = nil
            persist(); deviceSheet = false
        } catch { errorMessage = error.localizedDescription }
        connecting = false
        await refresh()
    }
    func forgetTarget() {
        guard !busy else { return }
        revision += 1; target = nil; online = false; everConnected = false
        speakers = []; sources = []; pingMs = [:]; systemName = "Phantom Remote"
        status = "Bitte ein System auswählen"; defaults?.removeObject(forKey: "selectedTarget")
        deviceSheet = true
    }

    func refresh() async {
        guard let selected = target, !refreshRunning, !busy, !dragging else { return }
        refreshRunning = true; let version = revision
        defer { refreshRunning = false }
        do {
            try await api.verify(selected)
            async let sysR = api.get(selected.endpoint, "/systems/current", as: DSystem.self)
            async let curR = api.get(selected.endpoint, "/groups/current/sources/current", as: DCurrent.self)
            async let volR = api.get(selected.endpoint, "/systems/current/sources/current/soundControl/volume", as: DVolume.self)
            async let srcR = api.get(selected.endpoint, "/groups/current/sources", as: DSources.self)
            async let devR = api.get(selected.endpoint, "/devices/current", as: DDevice.self)
            async let nmR = try? api.get(selected.endpoint, "/systems/current/settings/audio/nightMode", as: DNight.self)
            async let eqR = try? api.get(selected.endpoint, "/systems/current/settings/audio/equalizer", as: DEq.self)
            async let balR = try? api.get(selected.endpoint, "/systems/current/settings/audio/balance", as: DBalance.self)
            let (sys, cur, vol, src, dev) = try await (sysR, curR, volR, srcR, devR)
            let (nm, eq, bal) = await (nmR, eqR, balR)
            guard version == revision, selected == target, !busy, !dragging else { return }
            guard sys.systemId == selected.systemID, dev.deviceId == selected.deviceID, dev.systemId == selected.systemID else { throw RemoteError.wrongDevice }
            online = true; everConnected = true
            systemName = sys.systemName; model = dev.model ?? "Phantom"
            speakers = sys.devices.sorted { ($0.role ?? "") < ($1.role ?? "") }
            volume = Double(VolumePolicy.clamp(Double(vol.volume)))
            muted = cur.muteState == "muted"; playing = cur.playingState == "playing"
            currentType = cur.source?.type ?? ""; currentSourceID = cur.source?.sourceId ?? ""
            ops = cur.availableOperations ?? []; title = cur.metadata?.title ?? ""; artist = cur.metadata?.artist ?? ""; peer = cur.peerDeviceName ?? ""
            if let stream = cur.streamInfo {
                codec = [stream.codec?.uppercased(), stream.bitDepth.map { "\($0) bit" }, stream.sampleRate.map { "\(Double($0) / 1000) kHz" }].compactMap { $0 }.joined(separator: " · ")
            } else { codec = "" }
            sources = src.sources
            supportsNight = nm != nil; supportsEq = eq != nil; supportsBalance = bal != nil
            if let nm { nightMode = nm.nightMode == "on" }
            if let eq {
                eqPreset = eq.preset; eqPresets = eq.availablePresets ?? [eq.preset]
                if let range = eq.gainRange, range.min <= range.max { eqRange = Double(range.min)...Double(range.max) }
                if let bands = eq.customEqualization { eqLow = Double(bands.low.gain); eqHigh = Double(bands.high.gain) }
            }
            if let bal { balance = Double(bal.balance) }
            status = "Verbunden"
            await pingSpeakers()
        } catch {
            guard version == revision, selected == target else { return }
            online = false; status = "Nicht erreichbar – Geräte prüfen"
            pingMs = Dictionary(uniqueKeysWithValues: speakers.map { ($0.id, nil as Int?) })
            if case RemoteError.wrongDevice = error { errorMessage = error.localizedDescription }
        }
    }

    /// All mutations run sequentially, with an identity check directly before each operation.
    private func enqueue(_ label: String, operation: @escaping @MainActor (Target) async throws -> Void) {
        guard canControl, let selected = target else { errorMessage = RemoteError.noConnection.localizedDescription; return }
        revision += 1; pending += 1
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                guard self.target == selected, self.online else { throw RemoteError.noConnection }
                try await self.api.verify(selected)
                try await operation(selected)
            } catch {
                self.errorMessage = "\(label): \(error.localizedDescription)"
                // Fail closed: queued commands cannot run after an uncertain response.
                self.online = false
            }
            self.pending -= 1
            if self.pending == 0 { self.identifyQueued.removeAll(); await self.refresh() }
        }
    }
    func waitUntilIdle() async { await tail?.value }
    private func body(_ values: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: values) }
    private func setVolume(_ value: Int, target: Target) async throws {
        let actual = try await api.get(target.endpoint, "/systems/current/sources/current/soundControl/volume", as: DVolume.self).volume
        let safe = VolumePolicy.requested(value, current: actual, limit: volumeLimit)
        try await api.post(target.endpoint, "/systems/current/sources/current/soundControl/volume", body: body(["volume": safe]))
        volume = Double(safe)
    }
    func beginDrag() { dragging = true }
    func endDrag() { dragging = false }
    func sendVolume() {
        let value = VolumePolicy.clamp(volume)
        let token = UUID(); volumeToken = token
        enqueue("Lautstärke") { [self] selected in
            try await Task.sleep(for: .milliseconds(80))
            guard token == volumeToken else { return }
            try await setVolume(value, target: selected)
        }
    }
    func step(_ delta: Int, hud: Bool = true) async {
        enqueue("Lautstärke") { [self] selected in
            let actual = try await api.get(selected.endpoint, "/systems/current/sources/current/soundControl/volume", as: DVolume.self).volume
            let safe = VolumePolicy.requested(actual + delta, current: actual, limit: volumeLimit)
            try await api.post(selected.endpoint, "/systems/current/sources/current/soundControl/volume", body: body(["volume": safe]))
            volume = Double(safe)
            if hud { HUD.show(volume: safe, muted: muted) }
        }
    }
    func toggleMute(hud: Bool = true) async {
        enqueue("Stummschaltung") { [self] selected in
            let current = try await api.get(selected.endpoint, "/groups/current/sources/current", as: DCurrent.self)
            let value = current.muteState != "muted"
            try await api.post(selected.endpoint, "/groups/current/sources/current/playback/" + (value ? "mute" : "unmute"))
            muted = value
            if hud { HUD.show(volume: Int(volume), muted: muted) }
        }
    }
    private func transport(_ requested: String?) {
        enqueue("Wiedergabe") { [self] selected in
            let current = try await api.get(selected.endpoint, "/groups/current/sources/current", as: DCurrent.self)
            let operation = requested ?? (current.playingState == "playing" ? "pause" : "play")
            guard current.availableOperations?.contains(operation) == true else { throw RemoteError.unsupported }
            try await api.post(selected.endpoint, "/groups/current/sources/current/playback/\(operation)")
        }
    }
    func playPause() async { transport(nil) }
    func next() async { transport("next") }
    func previous() async { transport("previous") }
    func select(_ source: DSource) async {
        enqueue("Quelle") { [self] selected in
            let live = try await api.get(selected.endpoint, "/groups/current/sources", as: DSources.self)
            guard live.sources.contains(source), ["opticaljack", "line"].contains(source.type),
                  source.sourceId.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { throw RemoteError.unsupported }
            try await api.post(selected.endpoint, "/groups/current/sources/\(source.sourceId)/playback/play")
        }
    }
    func setNight(_ value: Bool) async {
        guard supportsNight, value != nightMode else { return }   // keine Schreibbefehle ohne echte Änderung
        enqueue("Nachtmodus") { [self] selected in
            try await api.post(selected.endpoint, "/systems/current/settings/audio/nightMode", body: body(["nightMode": value ? "on" : "off"]))
            nightMode = value
        }
    }
    func setEq(_ value: String) async {
        guard supportsEq, eqPresets.contains(value), value != eqPreset else { return }
        enqueue("Equalizer") { [self] selected in
            try await api.post(selected.endpoint, "/systems/current/settings/audio/equalizer", body: body(["preset": value]))
            eqPreset = value
        }
    }
    func sendCustomEq() {
        guard supportsEq, eqPresets.contains("custom") else { return }
        let low = Int(min(eqRange.upperBound, max(eqRange.lowerBound, eqLow)).rounded())
        let high = Int(min(eqRange.upperBound, max(eqRange.lowerBound, eqHigh)).rounded())
        let token = UUID(); eqToken = token
        enqueue("Equalizer") { [self] selected in
            try await Task.sleep(for: .milliseconds(120)); guard token == eqToken else { return }
            try await api.post(selected.endpoint, "/systems/current/settings/audio/equalizer", body: body(["preset": "custom", "customEqualization": ["low": ["gain": low], "high": ["gain": high]]]))
            eqPreset = "custom"
        }
    }
    func sendBalance() {
        guard supportsBalance else { return }
        let value = max(-10, min(10, Int(balance.rounded())))
        let token = UUID(); balanceToken = token
        enqueue("Balance") { [self] selected in
            try await Task.sleep(for: .milliseconds(120)); guard token == balanceToken else { return }
            try await api.post(selected.endpoint, "/systems/current/settings/audio/balance", body: body(["balance": value]))
        }
    }
    func pingSpeakers() async {
        guard let selected = target, !pinging else { return }
        pinging = true; defer { pinging = false }
        let devices = speakers, addresses = endpoints, api = api
        await withTaskGroup(of: (String, Int?).self) { group in
            for d in devices {
                let endpoint = d.id == selected.deviceID ? selected.endpoint : addresses[d.id]
                group.addTask {
                    guard let endpoint else { return (d.id, nil) }
                    let start = ContinuousClock.now
                    guard let actual = try? await api.get(endpoint, "/devices/current", as: DDevice.self), actual.deviceId == d.id, actual.systemId == selected.systemID else { return (d.id, nil) }
                    let elapsed = start.duration(to: .now).components
                    return (d.id, Int(elapsed.seconds * 1000 + elapsed.attoseconds / 1_000_000_000_000_000))
                }
            }
            for await (id, ms) in group where target == selected {
                pingMs[id] = .some(ms)
                if ms != nil { identifyFailed.remove(id) }
            }
        }
    }
    func identify(_ device: DDevice) async {
        guard canControl, !identifying.contains(device.id), !identifyQueued.contains(device.id), let selected = target else { return }
        guard let endpoint = device.id == selected.deviceID ? selected.endpoint : endpoints[device.id] else { errorMessage = RemoteError.missingEndpoint.localizedDescription; return }
        identifyQueued.insert(device.id)
        enqueue("Identifizieren") { [self] selected in
            defer { identifyQueued.remove(device.id) }
            let actual = try await api.get(endpoint, "/devices/current", as: DDevice.self)
            guard actual.deviceId == device.id, actual.systemId == selected.systemID else { throw RemoteError.wrongDevice }
            do { try await api.post(endpoint, "/devices/current/identify") }
            catch { identifyFailed.insert(device.id); throw error }
            identifying.insert(device.id); identifyFailed.remove(device.id)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.identifying.remove(device.id)
            }
        }
    }
    func openAirPlaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") { NSWorkspace.shared.open(url) }
    }
    var uniqueSources: [DSource] {
        var seen = Set<String>()
        return sources.filter { source in
            ["opticaljack", "line"].contains(source.type) || seen.insert(source.type).inserted
        }.sorted {
            let order = ["opticaljack", "line", "airplay2", "spotifyconnect", "bluetooth", "raat", "upnp"]
            let a = order.firstIndex(of: $0.type) ?? 99, b = order.firstIndex(of: $1.type) ?? 99
            if a != b { return a < b }
            if ($0.deviceId == target?.deviceID) != ($1.deviceId == target?.deviceID) { return $0.deviceId == target?.deviceID }
            return $0.id < $1.id
        }
    }
    var selectableSources: [DSource] { uniqueSources.filter { ["opticaljack", "line"].contains($0.type) } }
    func sourceLabel(_ source: DSource) -> String {
        let name = speakers.first { $0.id == source.deviceId }?.deviceName ?? "Gerät"
        return "\(sourceInfo(source.type).label) · \(name)"
    }
}
// MARK: - Lautstärke-Einblendung

@MainActor
enum HUD {
    static var panel: NSPanel?
    static var hide: DispatchWorkItem?
    static func show(volume: Int, muted: Bool) {
        let view = NSHostingView(rootView:
            VStack(spacing: 12) {
                Image(systemName: muted ? "speaker.slash.fill" : "hifispeaker.2.fill").font(.system(size: 38, weight: .light))
                ProgressView(value: Double(muted ? 0 : volume), total: 100).tint(.white).frame(width: 150)
                Text(muted ? "Stumm" : "\(volume)").font(.system(size: 22, weight: .light, design: .rounded).monospacedDigit())
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(width: 200, height: 170)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .environment(\.colorScheme, .dark))
        if panel == nil {
            let p = NSPanel(contentRect: .init(x: 0, y: 0, width: 200, height: 170),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false; p.backgroundColor = .clear; p.level = .screenSaver
            p.ignoresMouseEvents = true; p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel = p
        }
        guard let p = panel else { return }
        p.contentView = view
        if let s = NSScreen.main?.frame { p.setFrameOrigin(.init(x: s.midX - 100, y: s.minY + s.height * 0.16)) }
        p.alphaValue = 1; p.orderFrontRegardless()
        hide?.cancel()
        let w = DispatchWorkItem { NSAnimationContext.runAnimationGroup { $0.duration = 0.4; p.animator().alphaValue = 0 } }
        hide = w; DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: w)
    }
}

// MARK: - Globale Tastenkürzel (⌃⌥↑ / ⌃⌥↓ / ⌃⌥M)

@MainActor
enum Hotkeys {
    static func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, ev, _ in
            var hk = EventHotKeyID()
            GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            Task { @MainActor in
                let p = Phantom.shared
                switch hk.id { case 1: await p.step(3); case 2: await p.step(-3); case 3: await p.toggleMute(); default: break }
            }
            return noErr
        }, 1, &spec, nil, nil)
        guard handlerStatus == noErr else {
            Phantom.shared.errorMessage = "Globale Tastenkürzel konnten nicht eingerichtet werden (\(handlerStatus))."
            return
        }
        var failed = false
        let mods = UInt32(controlKey | optionKey)
        for (id, key) in [(1, kVK_UpArrow), (2, kVK_DownArrow), (3, kVK_ANSI_M)] {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(key), mods, EventHotKeyID(signature: OSType(0x44564C54), id: UInt32(id)),
                                GetApplicationEventTarget(), 0, &ref)
            if status != noErr { failed = true }
        }
        if failed { Phantom.shared.errorMessage = "Mindestens ein globales Tastenkürzel ist bereits belegt. Die Fensterbedienung funktioniert weiterhin." }
    }
}

