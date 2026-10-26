import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: ServerMonitorViewModel?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = ServerMonitorViewModel()
        self.viewModel = viewModel
        menuBarController = MenuBarController(viewModel: viewModel)
        viewModel.start()
        if viewModel.servers.isEmpty {
            viewModel.isShowingSettings = true
            menuBarController?.showPopover()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBarController?.showPopover()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stop()
    }
}
