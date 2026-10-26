import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let viewModel: ServerMonitorViewModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ServerMonitorViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
        observeViewModel()
        updateStatusItem(servers: viewModel.servers, host: viewModel.menuBarHost)
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(
            systemSymbolName: "server.rack",
            accessibilityDescription: "Server Monitor"
        )
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(
            width: ServerDetailView.contentWidth,
            height: ServerDetailView.contentHeight
        )
        popover.contentViewController = NSHostingController(
            rootView: ServerDetailView(
                model: viewModel,
                onRefresh: { [weak viewModel] in
                    Task { @MainActor in await viewModel?.refresh() }
                },
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }

    private func observeViewModel() {
        viewModel.$servers
            .combineLatest(viewModel.$menuBarHost)
            .sink { [weak self] servers, host in
                self?.updateStatusItem(servers: servers, host: host)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem(servers: [ServerStatus], host: String) {
        guard let button = statusItem.button else { return }
        let server = servers.first { $0.host == host }
        let readings = server?.snapshot?.readings.sorted { $0.index < $1.index } ?? []
        let values = readings.map { String(Int($0.utilizationPercent.rounded())) }
        let title: String
        if values.isEmpty, let cpu = server?.snapshot?.cpuPercent {
            title = "CPU \(Int(cpu.rounded()))%"
        } else if values.isEmpty {
            title = "—"
        } else if values.count <= 8 {
            title = values.joined(separator: "·") + "%"
        } else {
            let mean = readings.reduce(0) { $0 + $1.utilizationPercent } / Double(readings.count)
            title = "\(readings.count) GPU · \(Int(mean.rounded()))%"
        }
        let stale = server?.state.isStale == true
        button.title = stale ? "\(title) ⏸" : title
        button.appearsDisabled = stale || server?.snapshot == nil
        var details = [server?.state.title ?? "等待连接"]
        if let cpu = server?.snapshot?.cpuPercent {
            details.append("CPU \(Int(cpu.rounded()))%")
        }
        if !readings.isEmpty {
            details.append(readings.map { "GPU \($0.index)：\(Int($0.utilizationPercent.rounded()))%" }.joined(separator: " · "))
        }
        button.toolTip = "\(host) · " + details.joined(separator: "\n")
        button.setAccessibilityLabel("Server Monitor · \(host)")
        button.setAccessibilityValue(button.title)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        showPopover()
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        viewModel.refreshIfStale(maxAge: 8)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
