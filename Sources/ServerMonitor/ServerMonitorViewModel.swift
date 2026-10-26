import Combine
import Foundation
import ServerMonitorCore

@MainActor
final class ServerMonitorViewModel: ObservableObject {
    static let defaultRefreshInterval: TimeInterval = 5
    static let refreshOptions: [TimeInterval] = [2, 5, 10, 30]
    typealias Fetch = @Sendable (String) async throws -> ServerSnapshot

    @Published private(set) var servers: [ServerStatus]
    @Published private(set) var menuBarHost: String
    @Published private(set) var expandedHosts: Set<String>
    @Published private(set) var now = Date()
    @Published var isShowingSettings = false
    private(set) var refreshInterval: TimeInterval

    var menuBarServer: ServerStatus? { servers.first { $0.host == menuBarHost } }
    private let defaults: UserDefaults
    private let fetch: Fetch
    private var pollingTasks: [String: Task<Void, Never>] = [:]
    private var requests: [String: Task<Void, Never>] = [:]
    private var generation = UUID()
    private var clockTimer: Timer?

    init(defaults: UserDefaults = .standard,
         fetch: @escaping Fetch = { try await RemoteServerService().fetch(host: $0) }) {
        self.defaults = defaults
        self.fetch = fetch
        let saved = defaults.stringArray(forKey: "serverHosts")
            ?? defaults.string(forKey: "sshHost").map { [$0] } ?? []
        let hosts = Self.normalizedHosts(saved)
        servers = hosts.map { ServerStatus(host: $0) }
        let selected = defaults.string(forKey: "menuBarHost") ?? ""
        let initialHost = hosts.contains(selected) ? selected : hosts.first ?? ""
        menuBarHost = initialHost
        expandedHosts = Set(defaults.stringArray(forKey: "expandedHosts") ?? [initialHost]).intersection(hosts)
        let interval = defaults.double(forKey: "refreshInterval")
        refreshInterval = Self.refreshOptions.contains(interval) ? interval : Self.defaultRefreshInterval
    }

    deinit {
        pollingTasks.values.forEach { $0.cancel() }
        requests.values.forEach { $0.cancel() }
        clockTimer?.invalidate()
    }

    func start() {
        stop()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        startPolling()
    }

    func stop() {
        generation = UUID()
        pollingTasks.values.forEach { $0.cancel() }
        requests.values.forEach { $0.cancel() }
        pollingTasks.removeAll()
        requests.removeAll()
        clockTimer?.invalidate()
        clockTimer = nil
    }

    func refresh() async {
        // Each request starts before awaiting results; a slow host cannot block the others.
        let pending = servers.map { request(host: $0.host) }
        for task in pending { await task.value }
    }

    func refreshIfStale(maxAge: TimeInterval) {
        for server in servers where now.timeIntervalSince(server.snapshot?.fetchedAt ?? .distantPast) > maxAge {
            _ = request(host: server.host)
        }
    }

    func toggleExpanded(_ host: String) {
        if expandedHosts.contains(host) { expandedHosts.remove(host) }
        else { expandedHosts.insert(host) }
        defaults.set(Array(expandedHosts), forKey: "expandedHosts")
    }

    func selectMenuBarHost(_ host: String) {
        guard servers.contains(where: { $0.host == host }) else { return }
        menuBarHost = host
        defaults.set(host, forKey: "menuBarHost")
    }

    func applySettings(hosts rawHosts: [String], refreshInterval newInterval: TimeInterval) {
        let hosts = Self.normalizedHosts(rawHosts)
        guard !hosts.isEmpty else { return }
        let previousHosts = Set(servers.map(\.host))
        let previous = Dictionary(uniqueKeysWithValues: servers.map { ($0.host, $0) })
        servers = hosts.map { previous[$0] ?? ServerStatus(host: $0) }
        if !hosts.contains(menuBarHost) { menuBarHost = hosts[0] }
        expandedHosts = expandedHosts.intersection(hosts).union(Set(hosts).subtracting(previousHosts))
        refreshInterval = Self.refreshOptions.contains(newInterval) ? newInterval : Self.defaultRefreshInterval
        defaults.set(hosts, forKey: "serverHosts")
        defaults.set(menuBarHost, forKey: "menuBarHost")
        defaults.set(Array(expandedHosts), forKey: "expandedHosts")
        defaults.set(refreshInterval, forKey: "refreshInterval")
        start()
    }

    private static func normalizedHosts(_ hosts: [String]) -> [String] {
        var seen = Set<String>()
        return hosts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { RemoteServerService.isValidHost($0) && seen.insert($0).inserted }
    }

    private func startPolling() {
        for server in servers {
            let host = server.host
            pollingTasks[host] = Task { [weak self] in
                while !Task.isCancelled {
                    guard let task = self?.request(host: host) else { return }
                    await task.value
                    guard !Task.isCancelled, let interval = self?.refreshInterval else { return }
                    do { try await Task.sleep(for: .seconds(interval)) }
                    catch { return }
                }
            }
        }
    }

    @discardableResult
    private func request(host: String) -> Task<Void, Never> {
        if let existing = requests[host] { return existing }
        let currentGeneration = generation
        let fetch = self.fetch
        if let index = servers.firstIndex(where: { $0.host == host }), servers[index].snapshot == nil {
            servers[index].state = .connecting
        }
        let task = Task { [weak self] in
            defer {
                if self?.generation == currentGeneration { self?.requests.removeValue(forKey: host) }
            }
            do {
                let snapshot = try await fetch(host)
                guard !Task.isCancelled, let self, self.generation == currentGeneration,
                      let index = self.servers.firstIndex(where: { $0.host == host }) else { return }
                self.servers[index].snapshot = snapshot
                self.servers[index].state = .connected
                self.now = Date()
            } catch {
                guard !Task.isCancelled, let self, self.generation == currentGeneration,
                      let index = self.servers.firstIndex(where: { $0.host == host }) else { return }
                let message = String(error.localizedDescription.replacingOccurrences(of: "\n", with: " ").prefix(180))
                self.servers[index].state = self.servers[index].snapshot == nil ? .failed(message) : .stale(message)
            }
        }
        requests[host] = task
        return task
    }
}
