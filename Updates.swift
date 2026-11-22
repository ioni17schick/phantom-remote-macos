import Foundation

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

/// Sucht auf GitHub nach einem neueren Release. Installiert nichts selbst: Die App ist nicht notarisiert,
/// ein stilles Selbst-Update würde unsignierten Code an Gatekeeper vorbei einspielen.
@MainActor
final class UpdateChecker: ObservableObject {
    static let repository = "ioni17schick/phantom-remote-macos"
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle, checking, upToDate
        case available(version: String, page: URL)
        case failed(String)
    }
    @Published private(set) var state: State = .idle
    /// Automatische Prüfung (höchstens einmal pro Tag) – standardmäßig AUS, weil sie GitHub kontaktiert.
    @Published var autoCheck: Bool { didSet { defaults?.set(autoCheck, forKey: "autoUpdateCheck") } }
    let current: AppVersion?

    private let transport: any RemoteTransport
    private let defaults: UserDefaults?

    init(current: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
         transport: any RemoteTransport = HTTPTransport(), defaults: UserDefaults? = .standard) {
        self.current = current.flatMap(AppVersion.init)
        self.transport = transport
        self.defaults = defaults
        self.autoCheck = (defaults?.object(forKey: "autoUpdateCheck") as? Bool) ?? false   // ausdrücklich: ohne Einstellung AUS
    }

    var currentText: String { current.map { "v\($0)" } ?? "Entwicklerversion" }

    /// Beim Start: nur wenn eingeschaltet und die letzte Prüfung über 24 h her ist.
    func checkAutomaticallyIfDue(now: Date = Date()) async {
        guard autoCheck else { return }
        if let last = defaults?.object(forKey: "lastUpdateCheck") as? Date, now.timeIntervalSince(last) < 24 * 3600 { return }
        await check(now: now)
    }

    func check(now: Date = Date()) async {
        guard state != .checking else { return }
        guard let current else { state = .failed("Eigene Versionsnummer unbekannt."); return }
        state = .checking
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases?per_page=20")!)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("PhantomRemote/\(current)", forHTTPHeaderField: "User-Agent")   // keine persönlichen Daten
            request.timeoutInterval = 8
            let (data, code) = try await transport.send(request)
            guard code == 200 else { throw RemoteError.http(code) }
            struct Release: Decodable { let tag_name: String; let html_url: String; let draft: Bool? }
            let releases = try JSONDecoder().decode([Release].self, from: data)
            let newest = releases
                .filter { $0.draft != true }
                .compactMap { r -> (AppVersion, URL)? in
                    guard let v = AppVersion(r.tag_name), let url = Self.trustedPage(r.html_url) else { return nil }
                    return (v, url)
                }
                .max { $0.0 < $1.0 }
            defaults?.set(now, forKey: "lastUpdateCheck")
            if let newest, current < newest.0 {
                state = .available(version: newest.0.description, page: newest.1)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed("Update-Prüfung fehlgeschlagen: \(error.localizedDescription)")
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
