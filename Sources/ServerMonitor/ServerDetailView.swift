import AppKit
import ServerMonitorCore
import SwiftUI

struct ServerDetailView: View {
    static let contentWidth: CGFloat = 500
    static let contentHeight: CGFloat = 584
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: ServerMonitorViewModel
    let onRefresh: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.servers) { server in
                        serverSection(server)
                    }
                }
            }
            .scrollIndicators(.never)
            HStack {
                Text("通过系统 SSH 配置连接")
                Spacer()
                Text("每 \(Int(model.refreshInterval)) 秒")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Color.primary.opacity(0.43))
            .frame(height: 26)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: Self.contentWidth, height: Self.contentHeight)
        .background {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                Color.white.opacity(colorScheme == .dark ? 0.025 : 0.10)
            }
        }
        .sheet(isPresented: $model.isShowingSettings) {
            ServerSettingsView(hosts: model.servers.map(\.host), currentRefreshInterval: model.refreshInterval) { hosts, interval in
                model.applySettings(hosts: hosts, refreshInterval: interval)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor(model.menuBarServer?.state ?? .idle))
                .frame(width: 8, height: 8)
            Text(model.menuBarServer?.state.title ?? "等待连接")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.62))
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.70))
                    .frame(width: 28, height: 28).contentShape(Rectangle())
            }.buttonStyle(.plain).help("立即刷新").accessibilityLabel("立即刷新")
            Menu {
                Button("服务器设置…") { model.isShowingSettings = true }
                Divider()
                Button("退出 Server Monitor", action: onQuit)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.70))
                    .frame(width: 28, height: 28).contentShape(Rectangle())
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("更多")
        }.frame(height: 32)
    }

    private func serverSection(_ server: ServerStatus) -> some View {
        let expanded = model.expandedHosts.contains(server.host)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { model.toggleExpanded(server.host) } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.10))
                            Image(systemName: "server.rack")
                                .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.accentColor)
                        }.frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.host).font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(0.88))
                            Text(subtitle(server)).font(.system(size: 10.5))
                                .foregroundStyle(Color.primary.opacity(0.47)).lineLimit(1)
                        }
                        Spacer()
                        if model.servers.count > 1 {
                            Circle().fill(statusColor(server.state)).frame(width: 6, height: 6)
                        }
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("\(expanded ? "折叠" : "展开") \(server.host)")
                if model.servers.count > 1 {
                    Button { model.selectMenuBarHost(server.host) } label: {
                        Image(systemName: model.menuBarHost == server.host ? "pin.fill" : "pin")
                            .font(.system(size: 11))
                            .foregroundStyle(model.menuBarHost == server.host ? Color.accentColor : .secondary)
                            .frame(width: 24, height: 28)
                    }.buttonStyle(.plain).help("在菜单栏显示这台服务器")
                        .accessibilityLabel("在菜单栏显示 \(server.host)")
                }
            }.padding(.vertical, 8)
            if expanded {
                if let snapshot = server.snapshot {
                    ServerResourcesView(snapshot: snapshot)
                } else {
                    HStack(spacing: 8) {
                        if server.state == .connecting { ProgressView().controlSize(.small) }
                        Text(server.state.title).font(.system(size: 12)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 70)
                }
                HStack(alignment: .top) {
                    Text(updatedText(server))
                    Spacer(minLength: 8)
                    if let detail = server.state.detail {
                        Text(detail).lineLimit(2).help(detail).multilineTextAlignment(.trailing)
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(server.state.isStale ? Color.orange : Color.primary.opacity(0.43))
                .padding(.vertical, 5)
            }
            if model.servers.count > 1 { Divider().opacity(0.4) }
        }
    }

    private func subtitle(_ server: ServerStatus) -> String {
        guard server.state == .connected, let snapshot = server.snapshot else {
            return server.state.title
        }

        var parts: [String] = []
        if !snapshot.readings.isEmpty {
            parts.append("\(snapshot.readings.count) GPU")
        }
        if let memory = snapshot.memory {
            parts.append("\(capacity(memory.totalKiB)) 内存")
        }
        if !snapshot.disks.isEmpty {
            parts.append("\(capacity(snapshot.totalDiskKiB)) 磁盘")
        }
        return parts.isEmpty ? server.state.title : parts.joined(separator: " · ")
    }

    private func updatedText(_ server: ServerStatus) -> String {
        guard let date = server.snapshot?.fetchedAt else { return "尚未更新" }
        let seconds = max(0, Int(model.now.timeIntervalSince(date)))
        let age = seconds < 2 ? "刚刚更新" : seconds < 60 ? "\(seconds) 秒前更新" : "\(seconds / 60) 分钟前更新"
        return server.state.isStale ? "已过期 · \(age)" : age
    }

    private func statusColor(_ state: ConnectionState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting, .stale: return .orange
        case .failed: return .red
        case .idle: return .gray
        }
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}
