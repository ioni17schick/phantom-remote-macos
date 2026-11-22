import Foundation

actor MockTransport: RemoteTransport {
    var actualVolume = 35
    var night = false
    var mutedState = false
    var offerEmptySource = false
    var failReads = false
    func setEmptySource(_ on: Bool) { offerEmptySource = on }
    func setFailReads(_ on: Bool) { failReads = on }
    var failPosts = false
    var identity = "leader-a"
    var systemID = "system-a"
    var posts: [String] = []
    var bodies: [String] = []
    var volumes: [Int] = []
    var delayReads = false
    var delaySnapshots = false
    var snapshotStarted = false
    var optionalAvailable = true
    func configure(volume: Int? = nil, fail: Bool? = nil, identity: String? = nil, system: String? = nil, delay: Bool? = nil, optional: Bool? = nil) {
        if let volume { actualVolume = volume }
        if let fail { failPosts = fail }
        if let identity { self.identity = identity }
        if let system { systemID = system }
        if let delay { delayReads = delay }
        if let optional { optionalAvailable = optional }
    }
    func count() -> Int { posts.count }
    func lastPost() -> String? { posts.last }
    func lastBody() -> String? { bodies.last }
    func level() -> Int { actualVolume }
    func values() -> [Int] { volumes }
    func sourceIDs() -> [String] { posts.filter { $0.contains("/sources/") && $0.hasSuffix("/playback/play") } }
    func beginSnapshotDelay() { delaySnapshots = true; snapshotStarted = false }
    func snapshotWasStarted() -> Bool { snapshotStarted }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url!.path.replacingOccurrences(of: "/ipcontrol/v1", with: "")
        let secondary = request.url!.host == "secondary.local"
        let deviceID = secondary ? "follower-a" : identity
        var object: [String: Any] = [:]
        var status = 200
        if request.httpMethod == "POST" {
            posts.append(path)
            bodies.append(request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? "")
            if failPosts { return (Data("{}".utf8), 500) }
            let values = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            if let volume = values["volume"] as? Int { actualVolume = volume; volumes.append(volume) }
            if let value = values["nightMode"] as? String { night = value == "on" }
            if path.hasSuffix("/playback/mute") { mutedState = true }
            if path.hasSuffix("/playback/unmute") { mutedState = false }
        } else {
            if failReads { return (Data("{}".utf8), 500) }
            switch path {
            case "/devices/current": object = ["deviceId": deviceID, "deviceName": secondary ? "Right" : "Left", "systemId": systemID, "isSystemLeader": !secondary, "model": "Phantom 95 dB", "role": secondary ? "FrontRight" : "FrontLeft"]
            case "/systems/current": object = ["systemId": systemID, "systemName": "Test Pair", "systemType": "stereo", "devices": [["deviceId": identity, "deviceName": "Left", "role": "FrontLeft", "isSystemLeader": true], ["deviceId": "follower-a", "deviceName": "Right", "role": "FrontRight", "isSystemLeader": false]]]
            case "/groups/current/sources/current": object = ["source": ["type": "opticaljack", "sourceId": "optical-left"], "muteState": mutedState ? "muted" : "unmuted", "playingState": "playing", "availableOperations": ["play"]]
            case "/systems/current/sources/current/soundControl/volume":
                object = ["volume": actualVolume]
                if delayReads { try await Task.sleep(for: .milliseconds(20)) }
                if delaySnapshots {
                    delaySnapshots = false; snapshotStarted = true
                    try await Task.sleep(for: .milliseconds(200))
                }
            case "/groups/current/sources":
                var list: [[String: Any]] = [["sourceId": "optical-right", "deviceId": "follower-a", "type": "opticaljack"], ["sourceId": "optical-left", "deviceId": identity, "type": "opticaljack"], ["sourceId": "airplay", "deviceId": identity, "type": "airplay2"]]
                if offerEmptySource { list.append(["sourceId": "", "deviceId": identity, "type": "opticaljack"]) }
                object = ["sources": list]
            case "/systems/current/settings/audio/nightMode": object = ["nightMode": night ? "on" : "off"]; status = optionalAvailable ? 200 : 404
            case "/systems/current/settings/audio/equalizer": object = ["preset": "flat", "availablePresets": ["flat", "voice", "custom"], "gainRange": ["min": -6, "max": 6], "customEqualization": ["low": ["gain": 0], "high": ["gain": 0]]]; status = optionalAvailable ? 200 : 404
            case "/systems/current/settings/audio/balance": object = ["balance": 0]; status = optionalAvailable ? 200 : 404
            default: status = 404
            }
        }
        return (try JSONSerialization.data(withJSONObject: object), status)
    }
}

@main struct RegressionTests {
    @MainActor static var checks = 0
    @MainActor static func expect(_ condition: Bool, _ label: String) {
        checks += 1
        guard condition else { print("FAIL: \(label)"); exit(1) }
        print("PASS: \(label)")
    }
    @MainActor static func fixture() async throws -> (Phantom, MockTransport, RemoteAPI) {
        let transport = MockTransport(), api = RemoteAPI(transport: transport)
        let app = Phantom(api: api, defaults: nil, startAutomatically: false)
        let found = try await api.probe(Endpoint("speaker.local"))
        await app.connect(found)
        return (app, transport, api)
    }
    @MainActor static func main() async throws {
        // Validation: requests cannot include credentials, arbitrary paths, or redirects.
        for good in ["192.0.2.1", "speaker.local", "speaker.local.:8080", "http://speaker.local/", "[2001:db8::1]:8080", "2001:db8::1"] {
            let endpoint = try Endpoint(good)
            expect((try? endpoint.url("/devices/current")) != nil, "valid endpoint: \(good)")
        }
        for bad in ["", "https://speaker.local", "http://user:pass@speaker.local", "speaker.local/path", "speaker.local?x=1", "speaker.local#fragment", "speaker.local:0", "speaker.local:99999", "bad host"] {
            expect((try? Endpoint(bad)) == nil, "reject malformed endpoint: \(bad)")
        }
        expect(VolumePolicy.dragged(start: 35, translationY: 0, limit: 60) == 35, "centre click leaves volume unchanged")
        expect(VolumePolicy.dragged(start: 35, translationY: -300, limit: 60) == 60, "drag respects configured limit")
        expect(VolumePolicy.dragged(start: 35, translationY: 300, limit: 60) == 0, "drag has lower bound")
        expect(VolumePolicy.clamp(.nan) == 0, "invalid volume does not crash")
        expect(VolumePolicy.clamp(.greatestFiniteMagnitude) == 100, "huge finite volume is safely clamped")

        let (app, mock, _) = try await fixture()
        expect(app.online, "explicit selection connects")
        expect(await mock.count() == 0, "startup and discovery never write speaker settings")
        expect(app.selectableSources.count == 2, "both optical inputs remain selectable")
        expect(app.selectableSources.first?.sourceId == "optical-left", "leader input sorted first")
        await app.select(app.selectableSources[1]); await app.waitUntilIdle()
        expect(await mock.sourceIDs().last?.contains("optical-right") == true, "explicit follower source is preserved")

        await mock.configure(delay: true)
        async let one: Void = app.step(3, hud: false)
        async let two: Void = app.step(3, hud: false)
        _ = await (one, two); await app.waitUntilIdle()
        expect(await mock.level() == 41, "two rapid +3 operations: 35 -> 41")
        expect(await mock.values() == [38, 41], "volume POSTs are ordered")
        app.volume = 100; app.sendVolume(); await app.waitUntilIdle()
        expect(await mock.level() == 60, "absolute volume respects limit")
        await mock.configure(volume: 80); await app.refresh()
        await app.step(-2, hud: false); await app.waitUntilIdle()
        expect(await mock.level() == 78, "volume above limit can decrease gradually")
        await app.step(3, hud: false); await app.waitUntilIdle()
        expect(await mock.level() == 78, "volume above limit cannot increase")

        await mock.configure(fail: true)
        await app.setNight(true); await app.waitUntilIdle()
        expect(!app.nightMode, "HTTP 500 does not display enabled night mode")
        expect(app.errorMessage?.contains("500") == true, "write failures are visible")
        await mock.configure(fail: false)
        let count = await mock.count()
        await mock.configure(identity: "different-device")
        await app.step(3, hud: false); await app.waitUntilIdle()
        expect(await mock.count() == count, "changed device identity blocks all POSTs")
        expect(app.target?.deviceID == "leader-a", "failed reconnect never switches selected identity")

        let (unsupported, unsupportedMock, _) = try await fixture()
        await unsupportedMock.configure(optional: false); await unsupported.refresh()
        expect(!unsupported.supportsNight && !unsupported.supportsEq && !unsupported.supportsBalance, "unsupported settings hidden")
        await unsupported.setNight(true); await unsupported.waitUntilIdle()
        expect(await unsupportedMock.count() == 0, "unsupported setting sends no command")
        await unsupported.playPause(); await unsupported.waitUntilIdle()
        expect(await unsupportedMock.count() == 0, "unsupported pause sends no command")

        let (identifyApp, identifyMock, _) = try await fixture()
        let follower = identifyApp.speakers[1]
        await identifyApp.identify(follower); await identifyApp.waitUntilIdle()
        expect(await identifyMock.count() == 0, "unknown follower address is not guessed")
        identifyApp.addressInput = "secondary.local"; await identifyApp.addAddress()
        expect(identifyApp.target?.deviceID == "leader-a", "manual follower address does not change selected system")
        await identifyApp.identify(follower); await identifyApp.waitUntilIdle()
        expect(await identifyMock.count() == 1, "verified follower receives identification command")

        let (staleApp, staleMock, _) = try await fixture()
        await staleMock.beginSnapshotDelay()
        let oldRefresh = Task { await staleApp.refresh() }
        while !(await staleMock.snapshotWasStarted()) { await Task.yield() }
        await staleApp.step(3, hud: false); await staleApp.waitUntilIdle()
        await oldRefresh.value
        expect(staleApp.volume == 38, "stale polling response cannot overwrite completed command")
        // --- Ergänzende Sicherheits- und Randfalltests ---
        expect((try? Endpoint("fe80::1%en0")) == nil, "IPv6 zone identifiers are rejected")
        let plain = try Endpoint("speaker.local")
        expect((try? plain.url("devices/current")) == nil, "API paths must be absolute")
        expect((try? plain.url("/devices/current?x=1")) == nil, "API paths cannot carry queries")
        expect(VolumePolicy.requested(-20, current: 30, limit: 60) == 0, "negative volume request clamps to 0")
        expect(VolumePolicy.requested(200, current: 30, limit: 100) == 100, "volume never exceeds 100")

        let (noop, noopMock, _) = try await fixture()
        await noop.setNight(false); await noop.waitUntilIdle()
        expect(await noopMock.count() == 0, "unchanged night mode sends nothing")
        await noop.setEq("flat"); await noop.waitUntilIdle()
        expect(await noopMock.count() == 0, "unchanged EQ preset sends nothing")
        await noop.setEq("bogus"); await noop.waitUntilIdle()
        expect(await noopMock.count() == 0, "unknown EQ preset sends nothing")
        await noop.setNight(true); await noop.waitUntilIdle()
        let nightBody = await noopMock.lastBody()
        expect(noop.nightMode && nightBody?.contains("\"on\"") == true, "changed night mode is sent once")

        noop.eqLow = 50; noop.eqHigh = -50; noop.sendCustomEq(); await noop.waitUntilIdle()
        let eqBody = await noopMock.lastBody() ?? ""
        expect(eqBody.contains("\"gain\":6") && eqBody.contains("\"gain\":-6"), "custom EQ gains clamp to device range")
        noop.balance = 99; noop.sendBalance(); await noop.waitUntilIdle()
        expect(await noopMock.lastBody()?.contains("\"balance\":10") == true, "balance clamps to ±10")

        await noop.toggleMute(hud: false); await noop.waitUntilIdle()
        let mutePost = await noopMock.lastPost()
        expect(mutePost?.hasSuffix("/playback/mute") == true && noop.muted, "toggle mute sends mute")

        let beforeForeign = await noopMock.count()
        let injected = DSource(sourceId: "../../systems/current/powerOff", deviceId: "leader-a", type: "opticaljack")
        await noop.select(injected); await noop.waitUntilIdle()
        expect(await noopMock.count() == beforeForeign, "source IDs not offered by the device are never posted")
        let airplay = DSource(sourceId: "airplay", deviceId: "leader-a", type: "airplay2")
        await noop.select(airplay); await noop.waitUntilIdle()
        expect(await noopMock.count() == beforeForeign, "network sources cannot be force-selected")

        noop.volumeLimit = 150
        expect(noop.volumeLimit == 100, "volume limit above 100 is clamped")
        noop.volumeLimit = -5
        expect(noop.volumeLimit == 0, "negative volume limit is clamped")
        noop.volumeLimit = 60

        let (sysApp, sysMock, _) = try await fixture()
        await sysMock.configure(system: "system-b")
        await sysApp.step(3, hud: false); await sysApp.waitUntilIdle()
        expect(await sysMock.count() == 0, "same device in a different system receives no command")
        await sysApp.refresh()
        expect(!sysApp.online && sysApp.errorMessage != nil, "identity mismatch is shown, not silently ignored")

        let (forgetApp, forgetMock, _) = try await fixture()
        forgetApp.forgetTarget()
        await forgetApp.step(3, hud: false); await forgetApp.waitUntilIdle()
        let forgetCount = await forgetMock.count()
        expect(forgetCount == 0 && forgetApp.target == nil, "forgotten system receives no command")
        // --- Review-Korrekturen: ehrliche async-Funktionen, getrennte Fehlerarten ---
        let (asyncApp, asyncMock, _) = try await fixture()
        await asyncApp.step(3, hud: false)          // bewusst OHNE waitUntilIdle()
        let levelAfterAwait = await asyncMock.level()
        expect(levelAfterAwait == 38 && asyncApp.volume == 38, "await step() returns after the command completed")
        await asyncApp.toggleMute(hud: false)
        expect(asyncApp.muted, "await toggleMute() returns after the command completed")

        let (unsupApp, unsupMock, _) = try await fixture()
        // Mock bietet nur "play" an, spielt aber → "pause" fehlt. Der danach eingereihte Lautstärkebefehl
        // darf deshalb NICHT verworfen werden (nur echte Verbindungsfehler verwerfen die Warteschlange).
        async let pauseAttempt: Void = unsupApp.playPause()
        async let followUp: Void = unsupApp.step(3, hud: false)
        _ = await (pauseAttempt, followUp)
        let followUpLevel = await unsupMock.level()
        expect(followUpLevel == 38, "unsupported command does not drop the next queued command")
        expect(unsupApp.online, "unsupported command keeps the connection online")
        expect(unsupApp.errorMessage?.contains("nicht angeboten") == true, "unsupported command shows a clear message")

        let (emptyApp, emptyMock, _) = try await fixture()
        await emptyMock.setEmptySource(true); await emptyApp.refresh()
        let before = await emptyMock.count()
        if let empty = emptyApp.sources.first(where: { $0.sourceId.isEmpty }) { await emptyApp.select(empty) }
        let afterEmpty = await emptyMock.count()
        expect(emptyApp.sources.contains(where: { $0.sourceId.isEmpty }) && afterEmpty == before, "empty source ID from the device is never posted")

        let (lostApp, lostMock, _) = try await fixture()
        await lostMock.setFailReads(true); await lostApp.refresh()
        expect(!lostApp.online && lostApp.errorMessage?.contains("Verbindung") == true, "losing the connection while reading is shown in the banner")
        print("\(checks) checks passed. Mock transport only; no physical devices contacted.")
    }
}
