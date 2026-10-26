import Foundation
import ServerMonitorCore

actor Calls {
    var counts: [String: Int] = [:]
    func increment(_ host: String) { counts[host, default: 0] += 1 }
    func count(_ host: String) -> Int { counts[host, default: 0] }
}

@main
struct ModelVerification {
    @MainActor
    static func main() async throws {
        let suite = "ServerMonitor.Verification.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fresh = ServerMonitorViewModel(defaults: defaults) { _ in
            fatalError("Fresh install must not connect to a hardcoded host")
        }
        precondition(fresh.servers.isEmpty && fresh.menuBarHost.isEmpty && fresh.expandedHosts.isEmpty)
        await fresh.refresh()
        fresh.applySettings(hosts: ["", "-oProxyCommand=bad"], refreshInterval: 30)
        precondition(fresh.servers.isEmpty, "Reject invalid settings")
        for host in ["", "-flag", "user@host", "host;id", "host name"] {
            precondition(!RemoteServerService.isValidHost(host), "Reject unsafe SSH destinations")
        }
        for host in ["my-server", "127.0.0.1", "::1"] {
            precondition(RemoteServerService.isValidHost(host))
        }
        defaults.set("legacy", forKey: "sshHost")
        let calls = Calls()
        let model = ServerMonitorViewModel(defaults: defaults) { host in
            await calls.increment(host)
            if host == "broken" { throw RemoteServerError.sshFailed("synthetic failure") }
            // Deliberately ignore cancellation to prove stale responses cannot be accepted.
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + (host == "slow" ? 0.3 : 0.02)) {
                    continuation.resume()
                }
            }
            return ServerSnapshot(host: host, readings: [])
        }
        precondition(model.servers.map(\.host) == ["legacy"], "Migrate old settings")
        model.applySettings(hosts: ["fast", "slow", "broken"], refreshInterval: 30)
        try await Task.sleep(for: .milliseconds(100))
        precondition(model.servers[0].snapshot?.host == "fast", "Slow host must not block fast host")
        precondition(model.servers[1].snapshot == nil, "Slow request still pending")
        if case .failed = model.servers[2].state {} else { fatalError("Host failure not isolated") }
        model.selectMenuBarHost("slow")
        model.toggleExpanded("fast")
        model.applySettings(hosts: ["fast", "new"], refreshInterval: 30)
        try await Task.sleep(for: .milliseconds(350))
        precondition(model.servers.map(\.host) == ["fast", "new"], "Removed host must stay removed")
        precondition(model.servers.allSatisfy { $0.snapshot?.host == $0.host }, "Responses must match the host")
        precondition(model.menuBarHost == "fast", "Removed menu host falls back")
        model.selectMenuBarHost("new")
        model.stop()
        let restored = ServerMonitorViewModel(defaults: defaults)
        precondition(restored.servers.map(\.host) == ["fast", "new"] && restored.menuBarHost == "new", "Persist host list and menu host")
        precondition(!restored.expandedHosts.contains("fast"), "Persist collapsed state")
        let before = await calls.count("fast")
        async let first: Void = model.refresh()
        async let second: Void = model.refresh()
        _ = await (first, second)
        let after = await calls.count("fast")
        precondition(after == before + 1, "Coalesce concurrent refresh requests per host")
        model.stop()
        print("Model verification passed: migration, independent hosts, removed requests, persistence and concurrent refresh")
    }
}
