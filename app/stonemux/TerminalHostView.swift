import SwiftUI
import AppKit

/// 把模型持有的 TerminalView 停靠进 SwiftUI 视图树。
/// 关键约定：updateNSView 幂等、只 reparent、绝不重建——
/// SwiftUI 反复重建视图树时，PTY/ghostty surface 身份不变。
struct TerminalHostView: NSViewRepresentable {
    let view: TerminalView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        mount(into: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        mount(into: container)
    }

    private func mount(into container: NSView) {
        guard view.superview !== container else { return }
        view.removeFromSuperview()
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
    }
}
