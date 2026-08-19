import AppKit
import SwiftUI
import GhosttyKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// runtime 必须与进程同生命周期：libghostty 持有它的 unretained userdata 指针
    private var runtime: StonemuxRuntime?
    private var window: NSWindow?
    private var store: SessionStore?
    private var messaging: MessagingController?
    private var controlServer: ControlSocketServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let runtime = try StonemuxRuntime.bootstrap()
            self.runtime = runtime

            let config = StonemuxConfig.load()
            let store = SessionStore(runtime: runtime, config: config)
            self.store = store

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1100, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false)
            window.title = "stonemux"
            window.contentView = NSHostingView(rootView: ContentView(store: store))
            window.center()
            window.makeKeyAndOrderFront(nil)
            self.window = window

            store.window = window
            store.focusCurrent()

            NSApp.activate(ignoringOtherApps: true)

            buildMenu()
            if let config {
                let controller = MessagingController(config: config, store: store)
                self.messaging = controller
                controller.start()
            }

            // 控制面：Unix socket + ctl.json 凭据
            let server = ControlSocketServer(store: store)
            server.messaging = messaging
            try? server.start()
            self.controlServer = server

            // 终端标题变化 → 窗口标题 =「会话名 · 终端标题」
            NotificationCenter.default.addObserver(
                forName: StonemuxRuntime.titleDidChange,
                object: nil,
                queue: .main
            ) { [weak self] note in
                Task { @MainActor [weak self] in
                    guard let self,
                          let view = note.object as? TerminalView,
                          let title = note.userInfo?["title"] as? String else { return }
                    self.updateWindowTitle(terminalTitle: title, for: view)
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("stonemux failed to start", comment: "")
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func updateWindowTitle(terminalTitle: String, for view: TerminalView) {
        guard let store,
              let session = store.session(containing: view),
              session.id == store.selectedSessionId else { return }
        window?.title = "\(session.displayName) · \(terminalTitle)"
    }

    // MARK: 菜单（参考 cmux + macOS 惯例补全）

    private func buildMenu() {
        let mainMenu = NSMenu()

        // MARK: stonemux（应用菜单）
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "stonemux")
        appMenu.addItem(menuItem(NSLocalizedString("About stonemux", comment: ""), "", #selector(aboutAction(_:))))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(menuItem(NSLocalizedString("Settings…", comment: ""), ",", #selector(settingsAction(_:))))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Hide stonemux", comment: ""),
            action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(
            title: NSLocalizedString("Hide Others", comment: ""),
            action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Show All", comment: ""),
            action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Quit stonemux", comment: ""),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // MARK: File
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: NSLocalizedString("File", comment: ""))
        fileMenu.addItem(menuItem(NSLocalizedString("New Session", comment: ""), "n", #selector(newSessionAction(_:))))
        fileMenu.addItem(menuItem(NSLocalizedString("New Tab", comment: ""), "t", #selector(newTabAction(_:))))
        fileMenu.addItem(menuItem(NSLocalizedString("Split", comment: ""), "d", #selector(splitAction(_:))))
        fileMenu.addItem(menuItem(NSLocalizedString("Open Browser", comment: ""), "B", #selector(openBrowserAction(_:))))
        fileMenu.addItem(menuItem(NSLocalizedString("Open Location…", comment: ""), "l", #selector(openLocationAction(_:))))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(menuItem(NSLocalizedString("Close Panel", comment: ""), "w", #selector(closePanelAction(_:))))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // MARK: Edit（标准响应链动作；终端内 copy/paste 由 ghostty 键位处理）
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: NSLocalizedString("Edit", comment: ""))
        editMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Undo", comment: ""),
            action: #selector(UndoManager.undo), keyEquivalent: "z"))
        let redoItem = NSMenuItem(
            title: NSLocalizedString("Redo", comment: ""),
            action: #selector(UndoManager.redo), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Cut", comment: ""),
            action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Copy", comment: ""),
            action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Paste", comment: ""),
            action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Select All", comment: ""),
            action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // MARK: View
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: NSLocalizedString("View", comment: ""))
        viewMenu.addItem(menuItem(NSLocalizedString("Previous Tab", comment: ""), "{", #selector(prevTabAction(_:))))
        viewMenu.addItem(menuItem(NSLocalizedString("Next Tab", comment: ""), "}", #selector(nextTabAction(_:))))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(menuItem(NSLocalizedString("Toggle Sidebar", comment: ""), "S", #selector(toggleSidebarAction(_:))))
        viewMenu.addItem(menuItem(NSLocalizedString("Toggle Dock", comment: ""), "D", #selector(toggleDockAction(_:))))
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // MARK: Messages
        let msgMenuItem = NSMenuItem()
        let msgMenu = NSMenu(title: NSLocalizedString("Messages", comment: ""))
        msgMenu.addItem(menuItem(NSLocalizedString("Send Message…", comment: ""), "s", #selector(sendMessageAction(_:))))
        let replyItem2 = menuItem(NSLocalizedString("Reply to Last…", comment: ""), "r", #selector(replyAction(_:)))
        replyItem2.keyEquivalentModifierMask = [.command, .shift]
        msgMenu.addItem(replyItem2)
        msgMenuItem.submenu = msgMenu
        mainMenu.addItem(msgMenuItem)

        // MARK: Window（标准）
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: NSLocalizedString("Window", comment: ""))
        windowMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Minimize", comment: ""),
            action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Zoom", comment: ""),
            action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(
            title: NSLocalizedString("Bring All to Front", comment: ""),
            action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // MARK: Help
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: NSLocalizedString("Help", comment: ""))
        helpMenu.addItem(menuItem(NSLocalizedString("stonemux on GitHub", comment: ""), "", #selector(helpGitHubAction(_:))))
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func menuItem(_ title: String, _ key: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: 动作

    @objc private func aboutAction(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "stonemux"
        alert.informativeText = NSLocalizedString("A Ghostty-based terminal for AI coding agents", comment: "")
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }

    @objc private func settingsAction(_ sender: Any?) {
        // 设置 = 在 Dock 里打开 config.json（不存在则生成模板）
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".stonemux/config.json")
        if !FileManager.default.fileExists(atPath: path) {
            let template = """
            {
              "sessions": [
                { "agent_id": "alice-codex", "name": "alice" }
              ],
              "broker_url": "http://127.0.0.1:8765",
              "token": "change-me"
            }
            """
            try? template.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        }
        store?.openFileInDock(path)
    }

    @objc private func newSessionAction(_ sender: Any?) {
        store?.addSession()
    }

    @objc private func openLocationAction(_ sender: Any?) {
        guard let store, let session = store.selectedSession, let window = store.window else { return }
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Open Location…", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Open", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.placeholderString = NSLocalizedString("Enter URL or search term", comment: "")
        alert.accessoryView = field
        alert.beginSheetModal(for: window) { resp in
            guard resp == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return }
            Task { @MainActor in
                store.openBrowser(in: session, url: field.stringValue)
            }
        }
    }

    @objc private func toggleSidebarAction(_ sender: Any?) {
        store?.sidebarVisible.toggle()
    }

    @objc private func helpGitHubAction(_ sender: Any?) {
        if let url = URL(string: "https://github.com/c-k-x/stonemux") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func splitAction(_ sender: Any?) {
        guard let store, let session = store.selectedSession else { return }
        store.splitTerminal(in: session)
    }

    @objc private func closePanelAction(_ sender: Any?) {
        store?.closeFocusedPanel()
    }

    @objc private func newTabAction(_ sender: Any?) {
        guard let store, let session = store.selectedSession else { return }
        store.newTab(in: session)
    }

    @objc private func prevTabAction(_ sender: Any?) {
        guard let store, let session = store.selectedSession else { return }
        store.switchTab(in: session, delta: -1)
    }

    @objc private func nextTabAction(_ sender: Any?) {
        guard let store, let session = store.selectedSession else { return }
        store.switchTab(in: session, delta: 1)
    }

    @objc private func toggleDockAction(_ sender: Any?) {
        store?.dockVisible.toggle()
    }

    @objc private func openBrowserAction(_ sender: Any?) {
        guard let store, let session = store.selectedSession else { return }
        store.openBrowser(in: session)
    }

    @objc private func sendMessageAction(_ sender: Any?) {
        messaging?.showSendSheet()
    }

    @objc private func replyAction(_ sender: Any?) {
        messaging?.showReplySheet()
    }
}
