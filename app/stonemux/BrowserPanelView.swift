import SwiftUI
import WebKit

/// 浏览器面板 UI：顶部工具条（后退/前进/刷新/omnibar）+ inline hosting 的 webview。
struct BrowserPanelView: View {
    let panel: BrowserPanel
    let browserPanel: Panel
    let store: SessionStore
    let session: Session
    @State private var omnibarText = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            WebViewHost(webView: panel.webView)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                panel.back()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!panel.canGoBack)

            Button {
                panel.forward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!panel.canGoForward)

            Button {
                panel.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }

            OmnibarField(
                text: $omnibarText,
                onReturn: { panel.navigate(to: omnibarText) },
                onEscape: { store.focusCurrent() }  // Esc 焦点回终端
            )
            .frame(maxWidth: .infinity)

            if panel.isLoading {
                ProgressView().controlSize(.small)
            }

            Button {
                store.close(panel: browserPanel, in: session)
            } label: {
                Image(systemName: "xmark")
            }
            .help(NSLocalizedString("Close browser panel (⌘W)", comment: ""))
        }
        .padding(6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// WKWebView 的 inline hosting 容器：幂等 reparent，与 TerminalHostView 同款约定。
struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView

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
        guard webView.superview !== container else { return }
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
    }
}
