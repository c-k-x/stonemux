import AppKit
import Observation

enum PanelKind {
    case terminal
    case browser
}

/// 面板内容：模型持有重视图实例，SwiftUI 只负责停靠（reparent）。
enum PanelContent {
    case terminal(TerminalView)
    case browser(BrowserPanel)
}

@MainActor @Observable
final class Panel: Identifiable {
    let id: UUID
    let kind: PanelKind
    let content: PanelContent
    /// 终端标题或网页标题（运行时更新）
    var title: String

    init(content: PanelContent, title: String) {
        self.id = UUID()
        self.content = content
        self.title = title
        switch content {
        case .terminal:
            self.kind = .terminal
        case .browser:
            self.kind = .browser
        }
    }

    var terminalView: TerminalView? {
        if case .terminal(let v) = content { return v }
        return nil
    }

    var browserPanel: BrowserPanel? {
        if case .browser(let p) = content { return p }
        return nil
    }
}

/// P7：一个 pane = 一组 tab（[Panel]）+ 选中下标。
@MainActor @Observable
final class Pane: Identifiable {
    let id: UUID
    var panels: [Panel]
    var selectedIndex: Int

    init(panels: [Panel], selectedIndex: Int = 0) {
        self.id = UUID()
        self.panels = panels
        self.selectedIndex = selectedIndex
    }

    var selectedPanel: Panel? {
        panels.indices.contains(selectedIndex) ? panels[selectedIndex] : nil
    }
}

/// 2 路分屏模型（不嵌套），每路是一个 Pane（tab 组）
@MainActor
enum PaneLayout {
    case single(Pane)
    case split(left: Pane, right: Pane)

    var panes: [Pane] {
        switch self {
        case .single(let p):
            return [p]
        case .split(let l, let r):
            return [l, r]
        }
    }

    var panels: [Panel] { panes.flatMap { $0.panels } }

    func pane(id: UUID) -> Pane? {
        panes.first { $0.id == id }
    }

    func pane(containing panelId: UUID) -> Pane? {
        panes.first { p in p.panels.contains { $0.id == panelId } }
    }
}
