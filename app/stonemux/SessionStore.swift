import AppKit
import Observation

/// 全局 store：会话列表 + 选中 + 布局操作（分屏/tab）+ 焦点移交 + runtime 回调路由。
/// 焦点唯一入口：所有 firstResponder 移交都从这里发起。
@MainActor @Observable
final class SessionStore {
    let runtime: StonemuxRuntime
    private(set) var sessions: [Session]
    var selectedSessionId: String?
    /// P7：右侧边栏（Dock）可见性
    var dockVisible: Bool = false
    /// P8：Dock 正在预览的文件
    var dockFileURL: URL?
    /// 会话被选中时的回调（消息层用来投递 pending）
    var onSessionSelected: ((Session) -> Void)?
    /// 左侧边栏可见性
    var sidebarVisible: Bool = true

    weak var window: NSWindow?

    init(runtime: StonemuxRuntime, config: StonemuxConfig?) {
        self.runtime = runtime
        self.sessions = []
        self.selectedSessionId = nil

        // 无配置时降级为单本地会话（纯终端模式）
        let cfgs = config?.sessions ?? [SessionConfig(agentId: "stonemux-local", name: nil)]
        self.sessions = cfgs.map { cfg in
            Session(agentId: cfg.agentId, name: cfg.name,
                    layout: .single(Pane(panels: [Self.makeTerminalPanel(runtime, agentId: cfg.agentId)])),
                    autoAcceptFrom: cfg.autoAcceptFrom, autoSubmit: cfg.autoSubmit)
        }
        self.selectedSessionId = sessions.first?.id

        // cmd+click 开文件回调挂到初始面板
        for s in sessions { s.panels.forEach { wire($0) } }

        // runtime 回调路由（通知 object = TerminalView）
        NotificationCenter.default.addObserver(
            forName: StonemuxRuntime.titleDidChange, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self,
                      let view = note.object as? TerminalView,
                      let title = note.userInfo?["title"] as? String else { return }
                self.handleTitleChanged(view, title)
            }
        }
        NotificationCenter.default.addObserver(
            forName: StonemuxRuntime.surfaceDidClose, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self, let view = note.object as? TerminalView else { return }
                self.handleSurfaceClosed(view)
            }
        }
    }

    /// 唯一创建终端面板的工厂。
    /// 会话 shell 自动带 STONEMUX_SESSION_ID，终端内 agent 由此得知自己的身份。
    static func makeTerminalPanel(_ runtime: StonemuxRuntime, agentId: String) -> Panel {
        var env: [(String, String)] = [("STONEMUX_SESSION_ID", agentId)]
        // ghostty shell-integration 资源目录（OSC 7 cwd 追踪的前提）
        if let res = Bundle.main.resourcePath {
            env.append(("GHOSTTY_RESOURCES_DIR", res))
        }
        return Panel(content: .terminal(TerminalView(runtime: runtime, envPairs: env)), title: "shell")
    }

    static func makeBrowserPanel() -> Panel {
        Panel(content: .browser(BrowserPanel()), title: "browser")
    }

    var selectedSession: Session? {
        sessions.first { $0.id == selectedSessionId }
    }

    // MARK: 选中与焦点

    /// File > New Session：动态新建会话（自动 id）
    func addSession() {
        var id = "stonemux-\(sessions.count + 1)"
        while session(agentId: id) != nil { id += "x" }
        let s = Session(agentId: id, name: nil,
                        layout: .single(Pane(panels: [Self.makeTerminalPanel(runtime, agentId: id)])))
        s.panels.forEach { wire($0) }
        sessions.append(s)
        select(s)
    }

    func select(_ session: Session) {
        selectedSessionId = session.id
        session.unread = 0
        onSessionSelected?(session)
        focusCurrent()
    }

    func focus(panel: Panel, in session: Session) {
        session.focusedPanelId = panel.id
        if let view = panel.terminalView {
            window?.makeFirstResponder(view)
        }
    }

    func focusCurrent() {
        guard let s = selectedSession, let p = s.focusedPanel else { return }
        focus(panel: p, in: s)
    }

    // MARK: P8 cmd+click 开文件

    /// 终端面板挂上 cmd+click 回调
    private func wire(_ panel: Panel) {
        panel.terminalView?.onCommandClickPath = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.openFileInDock(path)
            }
        }
    }

    func openFileInDock(_ path: String) {
        dockFileURL = URL(fileURLWithPath: path)
        dockVisible = true
    }

    // MARK: 分屏

    /// ⌘D：旁加一个新终端 pane（2 路封顶）
    func splitTerminal(in session: Session) {
        guard case .single(let pane) = session.layout else { return }
        let panel = Self.makeTerminalPanel(runtime, agentId: session.agentId)
        wire(panel)
        let newPane = Pane(panels: [panel])
        session.layout = .split(left: pane, right: newPane)
        if let p = newPane.selectedPanel { focus(panel: p, in: session) }
    }

    // MARK: P7 tab 操作

    /// ⌘T：焦点 pane 加一个终端 tab
    func newTab(in session: Session) {
        guard let pane = session.focusedPane else { return }
        let panel = Self.makeTerminalPanel(runtime, agentId: session.agentId)
        wire(panel)
        pane.panels.append(panel)
        pane.selectedIndex = pane.panels.count - 1
        focus(panel: panel, in: session)
    }

    /// ⌘⇧[/]：焦点 pane 内切换 tab
    func switchTab(in session: Session, delta: Int) {
        guard let pane = session.focusedPane, !pane.panels.isEmpty else { return }
        let n = pane.panels.count
        pane.selectedIndex = ((pane.selectedIndex + delta) % n + n) % n
        if let p = pane.selectedPanel { focus(panel: p, in: session) }
    }

    // MARK: 关闭

    /// ⌘W / 浏览器 X：移除面板；pane 空了折叠分屏；会话最后一个终端 respawn
    func close(panel: Panel, in session: Session) {
        guard let pane = session.layout.pane(containing: panel.id) else { return }
        removePanel(panel, from: pane, in: session)
    }

    func closeFocusedPanel() {
        guard let s = selectedSession, let p = s.focusedPanel else { return }
        close(panel: p, in: s)
    }

    private func removePanel(_ panel: Panel, from pane: Pane, in session: Session) {
        pane.panels.removeAll { $0.id == panel.id }
        pane.selectedIndex = min(pane.selectedIndex, max(0, pane.panels.count - 1))

        if !pane.panels.isEmpty {
            if let p = pane.selectedPanel { focus(panel: p, in: session) }
            return
        }

        // pane 空了
        switch session.layout {
        case .split(let l, let r):
            let other = (l.id == pane.id) ? r : l
            session.layout = .single(other)
            if let p = other.selectedPanel { focus(panel: p, in: session) }
        case .single:
            // 会话最后一个面板：终端则 respawn 新 shell；浏览器直接补一个终端
            let fresh = Self.makeTerminalPanel(runtime, agentId: session.agentId)
            wire(fresh)
            session.layout = .single(Pane(panels: [fresh]))
            focus(panel: fresh, in: session)
        }
    }

    // MARK: P3 浏览器

    /// ⌘⇧B 语义：已有浏览器 → 选中并 navigate；single → split 出浏览器 pane；
    /// split 无浏览器 → 在焦点 pane 加浏览器 tab
    func openBrowser(in session: Session, url: String? = nil) {
        if let existing = session.panels.compactMap({ $0.browserPanel }).first,
           let panel = session.panels.first(where: { $0.browserPanel === existing }) {
            if let pane = session.layout.pane(containing: panel.id) {
                pane.selectedIndex = pane.panels.firstIndex { $0.id == panel.id } ?? 0
            }
            if let url { existing.navigate(to: url) }
            focus(panel: panel, in: session)
            return
        }

        let bp = Self.makeBrowserPanel()
        switch session.layout {
        case .single(let pane):
            session.layout = .split(left: pane, right: Pane(panels: [bp]))
        case .split(let l, let r):
            // 在焦点 pane 加一个浏览器 tab
            if let pane = session.focusedPane {
                pane.panels.append(bp)
                pane.selectedIndex = pane.panels.count - 1
            } else {
                r.panels.append(bp)
                r.selectedIndex = r.panels.count - 1
            }
        }
        if let url { bp.browserPanel?.navigate(to: url) }
        focus(panel: bp, in: session)
    }

    // MARK: 消息层接口

    func session(agentId: String) -> Session? {
        sessions.first { $0.agentId == agentId }
    }

    func session(containing view: TerminalView) -> Session? {
        sessions.first { s in s.panels.contains { $0.terminalView === view } }
    }

    func bumpUnread(_ session: Session) { session.unread += 1 }
    func clearUnread(_ session: Session) { session.unread = 0 }

    /// 投递到会话的焦点终端，兜底首个终端
    func inject(_ text: String, into session: Session) {
        (session.focusedTerminalView ?? session.firstTerminalView)?.injectText(text)
    }

    // MARK: runtime 回调路由

    private func handleTitleChanged(_ view: TerminalView, _ title: String) {
        guard let s = session(containing: view) else { return }
        s.panels.first { $0.terminalView === view }?.title = title
    }

    private func handleSurfaceClosed(_ view: TerminalView) {
        // P1 验证点：确认 close_surface_cb 的 userdata 能还原出 TerminalView
        NSLog("[stonemux] surface closed, view resolved=\(session(containing: view) != nil)")
        guard let s = session(containing: view),
              let panel = s.panels.first(where: { $0.terminalView === view }),
              let pane = s.layout.pane(containing: panel.id) else { return }
        removePanel(panel, from: pane, in: s)
    }
}
