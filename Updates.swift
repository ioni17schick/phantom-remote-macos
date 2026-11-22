import Foundation
import AppKit
import CryptoKit

/// Versionsnummer wie „0.1.2“ oder „v0.1.2-beta“. Vergleich: Zahlen zuerst; bei gleichen Zahlen
/// ist eine Vorabversion (mit Suffix) älter als die finale Version.
struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    let numbers: [Int]
    let suffix: String
    let raw: String
    init?(_ text: String) {
        var t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("v") || t.hasPrefix("V") { t.removeFirst() }
        let parts = t.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let core = parts.first, !core.isEmpty else { return nil }
        var nums: [Int] = []
        for piece in core.split(separator: ".", omittingEmptySubsequences: false) {
            guard !piece.isEmpty, piece.allSatisfy(\.isASCII), let n = Int(piece), n >= 0 else { return nil }
            nums.append(n)
        }
        guard (1...4).contains(nums.count) else { return nil }
        numbers = nums
        suffix = parts.count > 1 ? String(parts[1]) : ""
        raw = t
    }
    var description: String { raw }
    private var padded: [Int] { numbers + Array(repeating: 0, count: 4 - numbers.count) }
    static func < (a: AppVersion, b: AppVersion) -> Bool {
        if a.padded != b.padded { return a.padded.lexicographicallyPrecedes(b.padded) }
        if a.suffix.isEmpty != b.suffix.isEmpty { return !a.suffix.isEmpty }   // Beta < Final
        return a.suffix.localizedStandardCompare(b.suffix) == .orderedAscending
    }
    static func == (a: AppVersion, b: AppVersion) -> Bool { a.padded == b.padded && a.suffix == b.suffix }
}

/// Sucht auf GitHub nach einem neueren Release und installiert es auf Knopfdruck (nie still im Hintergrund).
/// Hinweis: Selbst geladene Dateien tragen keine Quarantäne-Markierung – Gatekeeper fragt danach nicht nach.
/// Deshalb: nur Assets dieses Repositorys, Prüfsumme, Bundle-ID, Version und Signatur werden geprüft.
@MainActor
final class UpdateChecker: ObservableObject {
    static let repository = "ioni17schick/phantom-remote-macos"
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle, checking, upToDate
        case available(version: String, page: URL)
        case installing(String)
        case failed(String)
    }
    @Published private(set) var state: State = .idle
    /// Automatische Prüfung (höchstens einmal pro Tag) – standardmäßig AUS, weil sie GitHub kontaktiert.
    @Published var autoCheck: Bool { didSet { defaults?.set(autoCheck, forKey: "autoUpdateCheck") } }
    let current: AppVersion?
    /// Download-Dateien des gefundenen Updates (nur gesetzt, wenn Zip und Prüfsumme im Release liegen).
    @Published private(set) var availableAsset: ReleaseAsset?
    nonisolated static let bundleID = "org.phantomremote.mac"

    private let transport: any RemoteTransport
    private let defaults: UserDefaults?

    init(current: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
         transport: any RemoteTransport = HTTPTransport(), defaults: UserDefaults? = .standard) {
        self.current = current.flatMap(AppVersion.init)
        self.transport = transport
        self.defaults = defaults
        self.autoCheck = (defaults?.object(forKey: "autoUpdateCheck") as? Bool) ?? false   // ausdrücklich: ohne Einstellung AUS
    }

    var currentText: String { current.map { "v\($0)" } ?? String(localized: "Entwicklerversion") }

    /// Beim Start: nur wenn eingeschaltet und die letzte Prüfung über 24 h her ist.
    func checkAutomaticallyIfDue(now: Date = Date()) async {
        guard autoCheck else { return }
        if let last = defaults?.object(forKey: "lastUpdateCheck") as? Date, now.timeIntervalSince(last) < 24 * 3600 { return }
        await check(now: now)
    }

    func check(now: Date = Date()) async {
        guard state != .checking else { return }
        guard let current else { state = .failed(String(localized: "Eigene Versionsnummer unbekannt.")); return }
        state = .checking
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases?per_page=20")!)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("PhantomRemote/\(current)", forHTTPHeaderField: "User-Agent")   // keine persönlichen Daten
            request.timeoutInterval = 8
            let (data, code) = try await transport.send(request)
            guard code == 200 else { throw RemoteError.http(code) }
            struct Asset: Decodable { let name: String; let browser_download_url: String }
            struct Release: Decodable { let tag_name: String; let html_url: String; let draft: Bool?; let assets: [Asset]? }
            let releases = try JSONDecoder().decode([Release].self, from: data)
            let newest = releases
                .filter { $0.draft != true }
                .compactMap { r -> (AppVersion, URL, ReleaseAsset?)? in
                    guard let v = AppVersion(r.tag_name), let url = Self.trustedPage(r.html_url) else { return nil }
                    let zipName = "Phantom-Remote-\(v)-unsigned.zip"
                    let zip = r.assets?.first { $0.name == zipName }.flatMap { Self.trustedDownload($0.browser_download_url) }
                    let sum = r.assets?.first { $0.name == zipName + ".sha256" }.flatMap { Self.trustedDownload($0.browser_download_url) }
                    let asset = zip.flatMap { z in sum.map { ReleaseAsset(zip: z, checksum: $0) } }
                    return (v, url, asset)
                }
                .max { $0.0 < $1.0 }
            defaults?.set(now, forKey: "lastUpdateCheck")
            if let newest, current < newest.0 {
                availableAsset = newest.2
                state = .available(version: newest.0.description, page: newest.1)
            } else {
                availableAsset = nil
                state = .upToDate
            }
        } catch {
            state = .failed(String(localized: "Update-Prüfung fehlgeschlagen: \(error.localizedDescription)"))
        }
    }

    /// Nur Download-Links genau dieses Repositorys (Weiterleitung zu GitHubs Speicher erlaubt der Downloader).
    static func trustedDownload(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.query == nil,
              url.path.hasPrefix("/\(repository)/releases/download/") else { return nil }
        return url
    }

    /// Wo die laufende App liegt – und ob sie sich dort selbst ersetzen darf.
    var installLocation: URL { Bundle.main.bundleURL }
    var selfUpdateBlocker: String? {
        if Bundle.main.bundleIdentifier != Self.bundleID { return String(localized: "Entwicklerversion – bitte neu bauen statt aktualisieren.") }
        if installLocation.path.contains("/AppTranslocation/") {
            return String(localized: "macOS startet die App aus einem schreibgeschützten Ort. Bitte nach „Programme“ verschieben und neu öffnen.")
        }
        if !FileManager.default.isWritableFile(atPath: installLocation.deletingLastPathComponent().path) {
            return String(localized: "Keine Schreibrechte für \(installLocation.deletingLastPathComponent().path).")
        }
        return nil
    }
    var canSelfUpdate: Bool { availableAsset != nil && selfUpdateBlocker == nil }

    /// Herunterladen → prüfen → alte Version in den Papierkorb → neue an dieselbe Stelle → neu starten.
    func install() async {
        guard case .available(let version, _) = state, let asset = availableAsset,
              let expected = AppVersion(version) else { return }
        if let blocker = selfUpdateBlocker { state = .failed(blocker); return }
        let target = installLocation
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("PhantomRemote-Update-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: work) }
        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            state = .installing(String(localized: "Lade \(version) herunter …"))
            let zip = try await SafeDownloader().download(asset.zip, to: work.appendingPathComponent("update.zip"))
            let sumFile = try await SafeDownloader().download(asset.checksum, to: work.appendingPathComponent("update.sha256"))
            guard let expectedSHA = SelfUpdate.parseChecksum(try String(contentsOf: sumFile, encoding: .utf8)) else { throw UpdateError.missingChecksum }
            state = .installing(String(localized: "Prüfe Download …"))
            let staged = try await Task.detached {
                try SelfUpdate.verifyAndStage(zip: zip, expectedSHA: expectedSHA, expectedVersion: expected,
                                              bundleID: UpdateChecker.bundleID, workDir: work)
            }.value
            state = .installing(String(localized: "Installiere …"))
            try SelfUpdate.replace(current: target, with: staged) { old in
                var trashed: NSURL?
                try FileManager.default.trashItem(at: old, resultingItemURL: &trashed)
                return (trashed as URL?) ?? old
            }
            state = .installing(String(localized: "Starte neu …"))
            try SelfUpdate.relaunch(at: target)
            NSApp.terminate(nil)
        } catch {
            state = .failed(String(localized: "Update nicht installiert: \(error.localizedDescription) Die bisherige Version bleibt erhalten."))
        }
    }

    /// Nur Release-Seiten genau dieses Repositorys werden geöffnet – keine beliebigen Links aus der Antwort.
    static func trustedPage(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.query == nil,
              url.path.hasPrefix("/\(repository)/releases/") else { return nil }
        return url
    }
}

struct ReleaseAsset: Equatable, Sendable { let zip: URL; let checksum: URL }

enum UpdateError: LocalizedError {
    case missingChecksum, checksumMismatch, badArchive, wrongBundle, wrongVersion(String), badSignature, download(Int), redirectBlocked
    var errorDescription: String? {
        switch self {
        case .missingChecksum: return String(localized: "Prüfsummendatei fehlt oder ist unlesbar.")
        case .checksumMismatch: return String(localized: "Die Prüfsumme des Downloads stimmt nicht.")
        case .badArchive: return String(localized: "Das Archiv enthält nicht genau eine App.")
        case .wrongBundle: return String(localized: "Das Archiv enthält nicht Phantom Remote.")
        case .wrongVersion(let found): return String(localized: "Das Archiv enthält Version \(found) statt der erwarteten.")
        case .badSignature: return String(localized: "Die Code-Signatur der neuen App ist beschädigt.")
        case .download(let code): return String(localized: "Download fehlgeschlagen (HTTP \(code)).")
        case .redirectBlocked: return String(localized: "Download-Weiterleitung zu einem fremden Server blockiert.")
        }
    }
}

/// Lädt nur über HTTPS; Weiterleitungen nur zu GitHub bzw. GitHubs Download-Speicher.
final class SafeDownloader: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static func allowedRedirect(_ url: URL?) -> Bool {
        guard let url, url.scheme == "https", let host = url.host else { return false }
        return host == "github.com" || host.hasSuffix(".githubusercontent.com")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(Self.allowedRedirect(request.url) ? request : nil)
    }
    func download(_ url: URL, to destination: URL) async throws -> URL {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 120
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.setValue("PhantomRemote-Updater", forHTTPHeaderField: "User-Agent")
        let (file, response) = try await session.download(for: request)
        let http = response as? HTTPURLResponse
        guard let http, http.statusCode == 200 else {
            try? FileManager.default.removeItem(at: file)
            if let code = http?.statusCode, (300..<400).contains(code) { throw UpdateError.redirectBlocked }
            throw UpdateError.download(http?.statusCode ?? 0)
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: file, to: destination)
        return destination
    }
}

/// Dateisystem-Schritte des Updates, ohne Oberfläche – damit testbar.
enum SelfUpdate {
    /// Erste 64-stellige Hex-Zahl aus einer `shasum`-Zeile („<hash>  <datei>“).
    static func parseChecksum(_ text: String) -> String? {
        guard let token = text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).first,
              token.count == 64, token.allSatisfy(\.isHexDigit) else { return nil }
        return token.lowercased()
    }
    static func sha256(of file: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: file, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
    }
    @discardableResult
    static func run(_ tool: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        return process.terminationStatus
    }
    /// Prüft Prüfsumme, entpackt, prüft Bundle-ID, Version und Signatur. Liefert die entpackte App.
    static func verifyAndStage(zip: URL, expectedSHA: String, expectedVersion: AppVersion, bundleID: String, workDir: URL) throws -> URL {
        guard try sha256(of: zip) == expectedSHA.lowercased() else { throw UpdateError.checksumMismatch }
        let out = workDir.appendingPathComponent("extracted")
        try? FileManager.default.removeItem(at: out)
        guard try run("/usr/bin/ditto", ["-x", "-k", zip.path, out.path]) == 0 else { throw UpdateError.badArchive }
        let apps = try FileManager.default.contentsOfDirectory(at: out, includingPropertiesForKeys: nil).filter { $0.pathExtension == "app" }
        guard apps.count == 1, let app = apps.first else { throw UpdateError.badArchive }
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == bundleID else { throw UpdateError.wrongBundle }
        let found = info["CFBundleShortVersionString"] as? String ?? "?"
        guard let v = AppVersion(found), v.numbers + Array(repeating: 0, count: 4 - v.numbers.count)
                == expectedVersion.numbers + Array(repeating: 0, count: 4 - expectedVersion.numbers.count) else {
            throw UpdateError.wrongVersion(found)
        }
        guard try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]) == 0 else { throw UpdateError.badSignature }
        return app
    }
    /// Alte App wegräumen (Papierkorb), neue an ihre Stelle; bei Fehler alte zurücklegen.
    static func replace(current: URL, with new: URL, putAside: (URL) throws -> URL) throws {
        let aside = try putAside(current)
        do { try FileManager.default.moveItem(at: new, to: current) }
        catch {
            try? FileManager.default.moveItem(at: aside, to: current)
            throw error
        }
    }
    /// Startet die App neu, sobald dieser Prozess beendet ist (Pfad als Argument, nicht in den Befehl eingesetzt).
    static func relaunch(at app: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$2\"",
                             "relaunch", String(ProcessInfo.processInfo.processIdentifier), app.path]
        try process.run()
    }
}
