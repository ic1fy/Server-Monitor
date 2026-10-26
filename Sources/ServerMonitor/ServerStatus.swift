import ServerMonitorCore

enum ConnectionState: Equatable {
    case idle, connecting, connected
    case stale(String), failed(String)

    var title: String {
        switch self {
        case .idle: return "等待连接"
        case .connecting: return "正在连接"
        case .connected: return "连接成功"
        case .stale: return "数据已过期"
        case .failed: return "连接失败"
        }
    }
    var detail: String? {
        switch self {
        case let .stale(message), let .failed(message): return message
        default: return nil
        }
    }
    var isStale: Bool {
        if case .stale = self { return true }
        return false
    }
}

struct ServerStatus: Identifiable {
    let host: String
    var snapshot: ServerSnapshot?
    var state: ConnectionState = .idle
    var id: String { host }
}
