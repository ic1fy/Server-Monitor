import SwiftUI

private struct HostDraft: Identifiable {
    let id = UUID()
    var host: String
}

struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [HostDraft]
    @State private var refreshInterval: TimeInterval
    let onSave: ([String], TimeInterval) -> Void

    init(hosts: [String], currentRefreshInterval: TimeInterval, onSave: @escaping ([String], TimeInterval) -> Void) {
        _drafts = State(initialValue: (hosts.isEmpty ? [""] : hosts).map { HostDraft(host: $0) })
        _refreshInterval = State(initialValue: currentRefreshInterval)
        self.onSave = onSave
    }

    private var hosts: [String] { drafts.map { $0.host.trimmingCharacters(in: .whitespacesAndNewlines) } }
    private var validation: String? {
        if hosts.isEmpty || hosts.contains(where: { !RemoteServerService.isValidHost($0) }) { return "请填写有效的 SSH Host 别名或 IP 地址。" }
        if Set(hosts).count != hosts.count { return "同一台服务器只需添加一次。" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("服务器设置").font(.system(size: 18, weight: .semibold))
            Text("填写 ~/.ssh/config 中的 Host 别名。每台服务器独立刷新。")
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($drafts) { $draft in
                        HStack {
                            Image(systemName: "server.rack").foregroundStyle(.secondary)
                            TextField("例如 my-server", text: $draft.host)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                            Button {
                                drafts.removeAll { $0.id == draft.id }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).disabled(drafts.count == 1)
                            .accessibilityLabel("移除 \(draft.host)")
                        }
                    }
                }.padding(2)
            }.frame(height: min(180, CGFloat(drafts.count) * 36))
            Button { drafts.append(HostDraft(host: "")) } label: { Label("添加服务器", systemImage: "plus") }
            if let validation {
                Text(validation).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("刷新间隔").font(.system(size: 12)).foregroundStyle(.secondary)
                Picker("刷新间隔", selection: $refreshInterval) {
                    ForEach(ServerMonitorViewModel.refreshOptions, id: \.self) { interval in
                        Text("\(Int(interval)) 秒").tag(interval)
                    }
                }.labelsHidden().pickerStyle(.segmented)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") { onSave(hosts, refreshInterval); dismiss() }
                    .keyboardShortcut(.defaultAction).disabled(validation != nil)
            }
        }.padding(22).frame(width: 390)
    }
}
