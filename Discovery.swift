import Foundation

/// Bonjour callbacks arrive on the main run loop. Generation tokens discard stale results.
@MainActor
final class Discovery: NSObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var generation = UUID()
    private var stopTask: Task<Void, Never>?
    private let api: RemoteAPI
    var onDevice: ((FoundDevice) -> Void)?
    var onState: ((Bool, String?) -> Void)?
    init(api: RemoteAPI) { self.api = api; super.init() }
    func start() {
        stop(); generation = UUID()
        let token = generation
        browser.delegate = self
        onState?(true, nil)
        browser.searchForServices(ofType: "_devialet-http._tcp.", inDomain: "local.")
        stopTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            guard let self, self.generation == token else { return }
            self.browser.stop(); self.onState?(false, nil)
        }
    }
    func stop() {
        generation = UUID(); stopTask?.cancel(); stopTask = nil
        browser.stop(); services.forEach { $0.stop() }; services.removeAll()
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service); service.delegate = self; service.resolve(withTimeout: 4)
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        onState?(false, String(localized: "mDNS-Suche fehlgeschlagen. Netzwerkzugriff in macOS prüfen oder IP-Adresse verwenden."))
    }
    func netServiceDidResolveAddress(_ service: NetService) {
        guard let host = service.hostName, let endpoint = try? Endpoint("\(host):\(service.port)") else { return }
        let token = generation
        Task { [weak self, api] in
            guard let found = try? await api.probe(endpoint), let self, self.generation == token else { return }
            self.onDevice?(found)
        }
    }
}
