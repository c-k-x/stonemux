import SwiftUI
import AppKit

/// omnibar 文本框：Return 触发导航、Esc 归还焦点给终端。
/// 用 NSTextField 子类自管按键语义（SwiftUI TextField 拿不到 Return/Esc 的干净时机）。
final class OmnibarTextField: NSTextField {
    var onReturn: (() -> Void)?
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:  // Return / 小键盘 Return
            onReturn?()
        case 53:      // Esc
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }
}

struct OmnibarField: NSViewRepresentable {
    @Binding var text: String
    var onReturn: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> OmnibarTextField {
        let field = OmnibarTextField()
        field.placeholderString = NSLocalizedString("Enter URL or search term", comment: "")
        field.delegate = context.coordinator
        field.onReturn = { [weak field] in
            if let field { self.text = field.stringValue }
            self.onReturn()
        }
        field.onEscape = { self.onEscape() }
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: OmnibarTextField, context: Context) {
        // 外部文本变化（v0.5 暂无）才回写；避免打字时光标跳动
        if !field.isFieldEditorActive, field.stringValue != text {
            field.stringValue = text
        }
        field.onReturn = { [weak field] in
            if let field { self.text = field.stringValue }
            self.onReturn()
        }
        field.onEscape = { self.onEscape() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: OmnibarField
        init(_ parent: OmnibarField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

private extension NSTextField {
    /// 焦点编辑器是否激活（正在打字）——避免 updateNSView 打断输入
    var isFieldEditorActive: Bool {
        window?.firstResponder is NSText
    }
}
