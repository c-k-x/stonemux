import Foundation
import Observation

/// 会话 = 一个 agent 身份（broker 地址化）+ 它的分屏布局 + 未读状态。
/// sidebar 一行 = 一个 Session。
@MainActor @Observable
final class Session: Identifiable {
    let agentId: String
    var displayName: String
    var layout: PaneLayout
    var focusedPanelId: UUID?
    var unread: Int = 0
    /// P5：信任白名单——这些发送者的消息跳过人审自动投递
    let autoAcceptFrom: [String]
    /// P5：自动审批时是否自动回车提交
    let autoSubmit: Bool

    init(agentId: String, name: String?, layout: PaneLayout,
         autoAcceptFrom: [String] = [], autoSubmit: Bool = false) {
        self.agentId = agentId
        self.displayName = name ?? agentId
        self.layout = layout
        self.focusedPanelId = layout.panels.first?.id
        self.autoAcceptFrom = autoAcceptFrom
        self.autoSubmit = autoSubmit
    }

    var id: String { agentId }

    var panels: [Panel] { layout.panels }

    func panel(id: UUID) -> Panel? {
        layout.panels.first { $0.id == id }
    }

    var focusedPanel: Panel? {
        focusedPanelId.flatMap(panel(id:)) ?? layout.panels.first
    }

    /// P7：焦点面板所在的 pane（tab 操作要用）
    var focusedPane: Pane? {
        focusedPanel.flatMap { layout.pane(containing: $0.id) }
    }

    var firstTerminalView: TerminalView? {
        panels.compactMap { $0.terminalView }.first
    }

    var focusedTerminalView: TerminalView? {
        focusedPanel?.terminalView ?? firstTerminalView
    }
}
