import Foundation

struct DSource: Codable, Hashable, Identifiable, Sendable {
    let sourceId: String
    let deviceId: String
    let type: String
    var id: String { sourceId }
}
struct DSources: Decodable, Sendable { let sources: [DSource] }
struct DDevice: Codable, Identifiable, Sendable {
    let deviceName: String
    let isSystemLeader: Bool?
    let model: String?
    let role: String?
    let deviceId: String
    let systemId: String?
    let serial: String?
    var id: String { deviceId }
}
struct DSystem: Decodable, Sendable {
    let systemName: String
    let devices: [DDevice]
    let systemId: String
    let systemType: String?
    let availableFeatures: [String]?
}
struct DCurrent: Decodable, Sendable {
    struct Src: Decodable, Sendable { let type: String; let sourceId: String? }
    struct Meta: Decodable, Sendable { let title: String?; let artist: String?; let album: String? }
    struct Stream: Decodable, Sendable { let codec: String?; let bitDepth: Int?; let sampleRate: Int? }
    let source: Src?
    let playingState: String?
    let muteState: String?
    let availableOperations: [String]?
    let metadata: Meta?
    let streamInfo: Stream?
    let peerDeviceName: String?
}
struct DVolume: Decodable, Sendable { let volume: Int }
struct DNight: Decodable, Sendable { let nightMode: String }
struct DBalance: Decodable, Sendable { let balance: Int }
struct DEq: Decodable, Sendable {
    struct Band: Decodable, Sendable { let gain: Int }
    struct Bands: Decodable, Sendable { let low: Band; let high: Band }
    struct Range: Decodable, Sendable { let min: Int; let max: Int }
    let preset: String
    let availablePresets: [String]?
    let customEqualization: Bands?
    let gainRange: Range?
}

enum RemoteError: LocalizedError {
    case invalidAddress, http(Int), invalidIdentity, wrongDevice, notLeader, noConnection, missingEndpoint, unsupported
    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "Bitte eine IP-Adresse oder einen Hostnamen eingeben, optional mit Port (1–65535)."
        case .http(let code): return "Der Lautsprecher hat den Befehl abgelehnt (HTTP \(code))."
        case .invalidIdentity: return "Die Antwort enthält keine eindeutige Geräte- und Systemkennung."
        case .wrongDevice: return "Unter dieser Adresse antwortet ein anderes Gerät oder System. Bitte die Auswahl prüfen."
        case .notLeader: return "Dieser Lautsprecher ist kein System-Leader. Er wurde gespeichert; bitte den Leader des Paars auswählen."
        case .noConnection: return "Keine bestätigte Verbindung. Bitte erst verbinden oder erneut prüfen."
        case .missingEndpoint: return "Adresse dieses Lautsprechers unbekannt. Bitte mDNS-Suche starten oder seine IP unter Geräte hinzufügen."
        case .unsupported: return "Diese Funktion wird von der aktuellen Quelle oder Firmware nicht angeboten."
        }
    }
}

struct Endpoint: Codable, Hashable, Sendable {
    let host: String
    let port: Int
    init(_ address: String) throws {
        let input = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !input.contains(where: { $0.isWhitespace }) else { throw RemoteError.invalidAddress }
        // URLComponents requires brackets for literal IPv6 addresses.
        let raw = input.contains("://") ? input : "http://" + (input.filter { $0 == ":" }.count > 1 && !input.hasPrefix("[") ? "[\(input)]" : input)
        guard let c = URLComponents(string: raw), c.scheme == "http", let h = c.host, !h.isEmpty,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              c.path.isEmpty || c.path == "/", (1...65535).contains(c.port ?? 80) else { throw RemoteError.invalidAddress }
        let clean = h.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        guard !clean.contains("%"), clean.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-:").contains($0) }) else { throw RemoteError.invalidAddress }
        host = clean.hasSuffix(".") ? String(clean.dropLast()) : clean
        port = c.port ?? 80
    }
    var address: String { (host.contains(":") ? "[\(host)]" : host) + (port == 80 ? "" : ":\(port)") }
    func url(_ path: String) throws -> URL {
        guard path.hasPrefix("/"), !path.contains("?"), !path.contains("#"), let url = URL(string: "http://\(address)/ipcontrol/v1\(path)") else { throw RemoteError.invalidAddress }
        return url
    }
}
struct Target: Codable, Equatable, Sendable {
    let systemID: String
    let deviceID: String
    var endpoint: Endpoint
}
struct FoundDevice: Identifiable, Sendable {
    let device: DDevice
    let endpoint: Endpoint
    let systemName: String
    var id: String { device.deviceId }
}

/// A transparent transport boundary allows deterministic tests without speaker access.
protocol RemoteTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}
final class HTTPTransport: NSObject, RemoteTransport, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil) // Never redirect control commands to another host.
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 6
        config.httpShouldSetCookies = false
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
struct RemoteAPI: Sendable {
    let transport: any RemoteTransport
    init(transport: any RemoteTransport = HTTPTransport()) { self.transport = transport }
    func get<T: Decodable & Sendable>(_ endpoint: Endpoint, _ path: String, as type: T.Type) async throws -> T {
        var request = URLRequest(url: try endpoint.url(path)); request.timeoutInterval = 4
        let (data, code) = try await transport.send(request)
        guard code == 200 else { throw RemoteError.http(code) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func post(_ endpoint: Endpoint, _ path: String, body: Data? = nil) async throws {
        var request = URLRequest(url: try endpoint.url(path)); request.httpMethod = "POST"; request.timeoutInterval = 4
        request.httpBody = body
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (_, code) = try await transport.send(request)
        guard (200...299).contains(code) else { throw RemoteError.http(code) }
    }
    func probe(_ endpoint: Endpoint) async throws -> FoundDevice {
        async let device = get(endpoint, "/devices/current", as: DDevice.self)
        async let system = get(endpoint, "/systems/current", as: DSystem.self)
        let (d, s) = try await (device, system)
        guard !d.deviceId.isEmpty, let id = d.systemId, !id.isEmpty, id == s.systemId,
              s.devices.contains(where: { $0.deviceId == d.deviceId }) else { throw RemoteError.invalidIdentity }
        return FoundDevice(device: d, endpoint: endpoint, systemName: s.systemName)
    }
    func verify(_ target: Target) async throws {
        let d = try await get(target.endpoint, "/devices/current", as: DDevice.self)
        guard d.deviceId == target.deviceID, d.systemId == target.systemID, d.isSystemLeader == true else { throw RemoteError.wrongDevice }
    }
}

enum VolumePolicy {
    static func clamp(_ value: Double) -> Int { value.isFinite ? Int(max(0, min(100, value.rounded()))) : 0 }
    /// Relative dragging: a click (zero translation) never changes the level.
    static func dragged(start: Double, translationY: Double, limit: Int) -> Int {
        let desired = clamp(start - translationY / 3)
        return min(desired, max(clamp(start), limit))
    }
    static func requested(_ value: Int, current: Int, limit: Int) -> Int {
        min(max(0, min(100, value)), max(current, limit))
    }
}

/// Welche Ansicht bei welcher Fenstergröße: klein = nur Lautstärke, groß/Vollbild = „Now Playing“.
enum LayoutMode: Equatable, Sendable {
    case compact, regular, large
    static let compactBelow = (width: 640.0, height: 600.0)
    static let largeFrom = (width: 1100.0, height: 780.0)
    init(width: Double, height: Double) {
        if width < Self.compactBelow.width || height < Self.compactBelow.height { self = .compact }
        else if width >= Self.largeFrom.width && height >= Self.largeFrom.height { self = .large }
        else { self = .regular }
    }
}

extension LayoutMode {
    /// Bezugsgrößen, in denen die jeweilige Ansicht im Maßstab 1 genau passt.
    static let regularReference = (width: 780.0, height: 720.0)
    static let largeReference = (width: 1300.0, height: 780.0)
    /// Gemeinsamer Skalierungsfaktor für Schrift, Rad, Lautsprecher, Abstände – folgt der knapperen Achse.
    static func scale(_ mode: LayoutMode, width: Double, height: Double) -> Double {
        switch mode {
        case .compact: return 1
        case .regular:
            return min(1.6, max(0.75, min(width / regularReference.width, height / regularReference.height)))
        case .large:
            return min(2.2, max(0.8, min(width / largeReference.width, height / largeReference.height)))
        }
    }
}

/// Direkte Berechnung statt Ausprobieren: Maßstab = verfügbare Höhe ÷ gemessene Inhaltshöhe bei Maßstab 1
/// (begrenzt durch die Breite). Reicht der Platz für die Karten nicht, wird ohne Karten gerechnet.
struct LayoutFit: Equatable, Sendable {
    let scale: Double
    let cards: Bool
    static let minimumWithCards = 0.72
    static func choose(_ mode: LayoutMode, width: Double, height: Double, unitWithCards: Double, unitWithoutCards: Double) -> LayoutFit {
        switch mode {
        case .compact:
            return LayoutFit(scale: 1, cards: false)
        case .regular:
            let byWidth = min(1.8, max(0.6, width / LayoutMode.regularReference.width))
            let full = min(byWidth, height / max(1, unitWithCards))
            if full >= minimumWithCards { return LayoutFit(scale: full, cards: true) }
            return LayoutFit(scale: max(0.6, min(byWidth, height / max(1, unitWithoutCards))), cards: false)
        case .large:
            let byWidth = min(2.2, max(0.6, width / LayoutMode.largeReference.width))
            return LayoutFit(scale: max(0.6, min(byWidth, height / max(1, unitWithCards))), cards: true)
        }
    }
}
