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


actor GitHubMock: RemoteTransport {
    var body = "[]"
    var status = 200
    var requests: [URLRequest] = []
    func set(_ json: String, status: Int = 200) { body = json; self.status = status }
    func count() -> Int { requests.count }
    func lastUserAgent() -> String? { requests.last?.value(forHTTPHeaderField: "User-Agent") }
    func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(body.utf8), status) }
}


/// Baut eine kleine, ad hoc signierte Test-App und packt sie wie das Release-Zip.
func makeFakeRelease(in dir: URL, bundleID: String, version: String, tamper: Bool = false) throws -> URL {
    let fm = FileManager.default
    let src = dir.appendingPathComponent("src-\(UUID().uuidString)")
    let app = src.appendingPathComponent("Phantom Remote.app")
    try fm.createDirectory(at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    let plist: NSDictionary = ["CFBundleIdentifier": bundleID, "CFBundleShortVersionString": version,
                               "CFBundleExecutable": "PhantomRemote", "CFBundlePackageType": "APPL"]
    plist.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true)
    try fm.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: app.appendingPathComponent("Contents/MacOS/PhantomRemote"))
    _ = try SelfUpdate.run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
    if tamper {   // nach dem Signieren verändern → Signatur muss ungültig sein
        let bin = app.appendingPathComponent("Contents/MacOS/PhantomRemote")
        var data = try Data(contentsOf: bin); data.append(0x00); try data.write(to: bin)
    }
    let zip = dir.appendingPathComponent("release-\(UUID().uuidString).zip")
    _ = try SelfUpdate.run("/usr/bin/ditto", ["-c", "-k", "--keepParent", app.path, zip.path])
    return zip
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
        // --- Update-Prüfung (simulierte GitHub-Antwort, kein Internet) ---
        func v(_ t: String) -> AppVersion { AppVersion(t)! }
        expect(v("0.1.1") < v("0.1.2-beta") && v("0.1.9") < v("0.1.10"), "versions compare numerically, not as text")
        expect(v("v0.1.1-beta") < v("0.1.1") && v("0.1.1") == v("v0.1.1"), "beta is older than final; leading v ignored")
        expect(v("1.0-beta.2") < v("1.0-beta.10"), "pre-release suffixes compare naturally")
        expect(AppVersion("abc") == nil && AppVersion("1..2") == nil && AppVersion("") == nil, "garbage versions are rejected")
        let repo = UpdateChecker.repository
        expect(UpdateChecker.trustedPage("https://github.com/\(repo)/releases/tag/v9.0") != nil, "own release page is trusted")
        for bad in ["http://github.com/\(repo)/releases/tag/v9", "https://evil.example/\(repo)/releases/tag/v9",
                    "https://github.com/someone/else/releases/tag/v9", "https://user@github.com/\(repo)/releases/tag/v9"] {
            expect(UpdateChecker.trustedPage(bad) == nil, "foreign link is never opened: \(bad)")
        }
        let gh = GitHubMock()
        let releasesJSON = """
        [{"tag_name":"v0.1.2-beta","html_url":"https://github.com/\(repo)/releases/tag/v0.1.2-beta","draft":false},
         {"tag_name":"v9.9.9","html_url":"https://github.com/\(repo)/releases/tag/v9.9.9","draft":true},
         {"tag_name":"v5.0.0","html_url":"https://evil.example/x","draft":false},
         {"tag_name":"v0.1.1-beta","html_url":"https://github.com/\(repo)/releases/tag/v0.1.1-beta","draft":false}]
        """
        await gh.set(releasesJSON)
        let older = UpdateChecker(current: "0.1.1", transport: gh, defaults: nil)
        await older.check()
        expect(older.state == .available(version: "0.1.2-beta", page: URL(string: "https://github.com/\(repo)/releases/tag/v0.1.2-beta")!),
               "newer release found; drafts and foreign links ignored")
        let ua = await gh.lastUserAgent() ?? ""
        expect(ua == "PhantomRemote/0.1.1", "request identifies only app and version")
        let same = UpdateChecker(current: "0.1.2", transport: gh, defaults: nil)
        await same.check()
        expect(same.state == .upToDate, "no update offered when current is newest")
        await gh.set("{}", status: 403)
        let limited = UpdateChecker(current: "0.1.1", transport: gh, defaults: nil)
        await limited.check()
        if case .failed = limited.state { expect(true, "API error is shown as failure, not as up to date") }
        else { expect(false, "API error is shown as failure, not as up to date") }

        let suite = "phantomremote.tests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { store.removePersistentDomain(forName: suite) }
        await gh.set(releasesJSON)
        let ghBefore = await gh.count()
        let auto = UpdateChecker(current: "0.1.1", transport: gh, defaults: store)
        expect(!auto.autoCheck, "automatic update check is off by default")
        await auto.checkAutomaticallyIfDue()
        let afterOff = await gh.count()
        expect(afterOff == ghBefore, "no network request while automatic check is off")
        auto.autoCheck = true
        let t0 = Date()
        await auto.checkAutomaticallyIfDue(now: t0)
        await auto.checkAutomaticallyIfDue(now: t0.addingTimeInterval(3600))
        let afterTwo = await gh.count()
        expect(afterTwo == ghBefore + 1, "automatic check runs at most once per day")
        await auto.checkAutomaticallyIfDue(now: t0.addingTimeInterval(25 * 3600))
        let afterDay = await gh.count()
        expect(afterDay == ghBefore + 2, "automatic check runs again after 24 hours")
        // --- Fenstergrößen → Ansicht ---
        expect(LayoutMode(width: 300, height: 360) == .compact, "small window shows only the volume control")
        expect(LayoutMode(width: 1200, height: 500) == .compact, "wide but flat window stays compact")
        expect(LayoutMode(width: 780, height: 800) == .regular, "default window size shows the regular view")
        expect(LayoutMode(width: 1099, height: 1000) == .regular, "just below the large threshold stays regular")
        expect(LayoutMode(width: 1440, height: 900) == .large && LayoutMode(width: 1920, height: 1080) == .large, "full screen shows now playing")
        // --- Selbst-Update: Links, Weiterleitungen, Prüfsumme, Paketprüfung, Austausch ---
        let dl = "https://github.com/\(repo)/releases/download/v0.2.0-beta/Phantom-Remote-0.2.0-beta-unsigned.zip"
        expect(UpdateChecker.trustedDownload(dl) != nil, "own release download is trusted")
        for bad in ["https://github.com/someone/else/releases/download/v1/x.zip", "http://github.com/\(repo)/releases/download/v1/x.zip",
                    "https://evil.example/\(repo)/releases/download/v1/x.zip", "https://github.com/\(repo)/archive/main.zip"] {
            expect(UpdateChecker.trustedDownload(bad) == nil, "foreign download rejected: \(bad)")
        }
        expect(SafeDownloader.allowedRedirect(URL(string: "https://objects.githubusercontent.com/x")) &&
               SafeDownloader.allowedRedirect(URL(string: "https://release-assets.githubusercontent.com/x")), "redirect to GitHub storage allowed")
        for bad in ["http://objects.githubusercontent.com/x", "https://evil.example/x", "https://githubusercontent.com.evil.example/x", "https://evilgithubusercontent.com/x"] {
            expect(!SafeDownloader.allowedRedirect(URL(string: bad)), "redirect blocked: \(bad)")
        }
        let hex = String(repeating: "ab", count: 32)
        expect(SelfUpdate.parseChecksum("\(hex)  Phantom-Remote.zip\n") == hex, "checksum line is parsed")
        expect(SelfUpdate.parseChecksum("") == nil && SelfUpdate.parseChecksum("xyz  file") == nil && SelfUpdate.parseChecksum(String(hex.dropLast())) == nil, "invalid checksum lines are rejected")

        let withAssets = """
        [{"tag_name":"v0.2.0-beta","html_url":"https://github.com/\(repo)/releases/tag/v0.2.0-beta","draft":false,
          "assets":[{"name":"Phantom-Remote-0.2.0-beta-unsigned.zip","browser_download_url":"\(dl)"},
                    {"name":"Phantom-Remote-0.2.0-beta-unsigned.zip.sha256","browser_download_url":"\(dl).sha256"}]},
         {"tag_name":"v0.1.9","html_url":"https://github.com/\(repo)/releases/tag/v0.1.9","draft":false,
          "assets":[{"name":"Phantom-Remote-0.1.9-unsigned.zip","browser_download_url":"https://evil.example/x.zip"},
                    {"name":"Phantom-Remote-0.1.9-unsigned.zip.sha256","browser_download_url":"https://evil.example/x.sha256"}]}]
        """
        await gh.set(withAssets)
        let assetChecker = UpdateChecker(current: "0.1.3", transport: gh, defaults: nil)
        await assetChecker.check()
        expect(assetChecker.availableAsset == ReleaseAsset(zip: URL(string: dl)!, checksum: URL(string: dl + ".sha256")!), "zip and checksum of the newest release are found")
        let noAssetChecker = UpdateChecker(current: "0.1.3", transport: gh, defaults: nil)
        await gh.set(releasesJSON)
        await noAssetChecker.check()
        expect(noAssetChecker.availableAsset == nil && !noAssetChecker.canSelfUpdate, "release without checksum offers only the release page")

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("phantom-selfupdate-test-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let bid = UpdateChecker.bundleID, want = AppVersion("0.2.0-beta")!
        let good = try makeFakeRelease(in: work, bundleID: bid, version: "0.2.0")
        let goodSHA = try SelfUpdate.sha256(of: good)
        let staged = try? SelfUpdate.verifyAndStage(zip: good, expectedSHA: goodSHA, expectedVersion: want, bundleID: bid, workDir: work.appendingPathComponent("w1"))
        expect(staged?.lastPathComponent == "Phantom Remote.app", "valid release passes all checks")
        func rejects(_ zip: URL, sha: String, _ label: String) {
            let result = try? SelfUpdate.verifyAndStage(zip: zip, expectedSHA: sha, expectedVersion: want, bundleID: bid, workDir: work.appendingPathComponent(UUID().uuidString))
            expect(result == nil, label)
        }
        rejects(good, sha: String(repeating: "0", count: 64), "wrong checksum is rejected")
        let other = try makeFakeRelease(in: work, bundleID: "com.example.other", version: "0.2.0")
        rejects(other, sha: try SelfUpdate.sha256(of: other), "different app in the archive is rejected")
        let oldVersion = try makeFakeRelease(in: work, bundleID: bid, version: "0.1.0")
        rejects(oldVersion, sha: try SelfUpdate.sha256(of: oldVersion), "unexpected version in the archive is rejected")
        let tampered = try makeFakeRelease(in: work, bundleID: bid, version: "0.2.0", tamper: true)
        rejects(tampered, sha: try SelfUpdate.sha256(of: tampered), "code modified after signing is rejected")

        let installed = work.appendingPathComponent("Applications/Phantom Remote.app")
        try fm.createDirectory(at: installed, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: installed.appendingPathComponent("marker"))
        let fresh = work.appendingPathComponent("fresh.app")
        try fm.createDirectory(at: fresh, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: fresh.appendingPathComponent("marker"))
        let aside = work.appendingPathComponent("trash")
        try fm.createDirectory(at: aside, withIntermediateDirectories: true)
        let putAside: (URL) throws -> URL = { old in
            let dest = aside.appendingPathComponent(UUID().uuidString + ".app"); try fm.moveItem(at: old, to: dest); return dest
        }
        try SelfUpdate.replace(current: installed, with: fresh, putAside: putAside)
        let nowInstalled = try String(contentsOf: installed.appendingPathComponent("marker"), encoding: .utf8)
        let kept = try fm.contentsOfDirectory(atPath: aside.path).count
        expect(nowInstalled == "new" && kept == 1, "new version replaces the old one, old one is kept aside")
        let missing = work.appendingPathComponent("does-not-exist.app")
        let failed = (try? SelfUpdate.replace(current: installed, with: missing, putAside: putAside)) == nil
        let restored = (try? String(contentsOf: installed.appendingPathComponent("marker"), encoding: .utf8)) == "new"
        expect(failed && restored, "failed replacement restores the previous version")
        // --- Skalierung: folgt der knapperen Achse, Referenzgröße = Maßstab 1 ---
        let rr = LayoutMode.regularReference, lr = LayoutMode.largeReference
        expect(LayoutMode.scale(.regular, width: rr.width, height: rr.height) == 1 && LayoutMode.scale(.large, width: lr.width, height: lr.height) == 1, "reference sizes have scale 1")
        expect(LayoutMode.scale(.regular, width: 1000, height: rr.height) == 1, "wider window alone does not overflow vertically")
        expect(LayoutMode.scale(.regular, width: 1090, height: 1000) > 1.2, "bigger window enlarges the interface")
        expect(LayoutMode.scale(.regular, width: 640, height: 600) >= 0.75 && LayoutMode.scale(.regular, width: 300, height: 300) == 0.75, "scale never drops below its lower bound")
        expect(LayoutMode.scale(.large, width: 2560, height: 1440) == min(2560.0 / lr.width, 1440.0 / lr.height), "large screens scale up proportionally")
        expect(LayoutMode.scale(.large, width: 9000, height: 9000) == 2.2, "scale has an upper bound")
        expect(LayoutMode.scale(.large, width: 1512, height: 945) > 1.1, "MacBook full screen uses the available space")
        print("\(checks) checks passed. Mock transport only; no physical devices contacted.")
    }
}
