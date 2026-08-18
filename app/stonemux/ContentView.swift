import SwiftUI
import AppKit
import WebKit
import PDFKit
import MarkdownUI

/// 顶层 chrome：左侧边栏 + 主区 + 右侧 Dock。
/// 侧边栏宽度只被 SidebarContainer 观察，拖宽度不重算主区。
struct ContentView: View {
    let store: SessionStore
    @State private var widthModel = SidebarWidthModel()

    var body: some View {
        HStack(spacing: 0) {
            if store.sidebarVisible {
                SidebarContainer(store: store, widthModel: widthModel)
            }
            MainArea(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if store.dockVisible {
                Divider()
                DockView(store: store)
                    .frame(width: 320)
            } else {
                // 折叠态：右侧留细条，点击展开（修"折叠后找不到"）
                Divider()
                Button {
                    store.dockVisible = true
                } label: {
                    Image(systemName: "sidebar.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24)
                .help(NSLocalizedString("Toggle Dock", comment: ""))
            }
        }
        .background(Color.black)
    }
}

struct SidebarContainer: View {
    let store: SessionStore
    let widthModel: SidebarWidthModel
    @State private var dragStartWidth: CGFloat?

    var body: some View {
        SidebarView(store: store)
            .frame(width: widthModel.width)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .trailing) { dragHandle }
    }

    private var dragHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 5)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartWidth == nil { dragStartWidth = widthModel.width }
                        let base = dragStartWidth ?? widthModel.width
                        widthModel.width = min(max(140, base + value.translation.width), 400)
                    }
                    .onEnded { _ in dragStartWidth = nil }
            )
    }
}

struct MainArea: View {
    let store: SessionStore

    var body: some View {
        if let session = store.selectedSession {
            SessionLayoutView(store: store, session: session)
        } else {
            Text(NSLocalizedString("No sessions", comment: "")).foregroundStyle(.secondary)
        }
    }
}

struct SessionLayoutView: View {
    let store: SessionStore
    let session: Session

    var body: some View {
        switch session.layout {
        case .single(let pane):
            PaneView(store: store, session: session, pane: pane)
        case .split(let left, let right):
            HStack(spacing: 0) {
                PaneView(store: store, session: session, pane: left)
                Divider()
                PaneView(store: store, session: session, pane: right)
            }
        }
    }
}

/// P7：一个 pane = tab 条 + 当前选中面板
struct PaneView: View {
    let store: SessionStore
    let session: Session
    let pane: Pane

    var body: some View {
        VStack(spacing: 0) {
            if pane.panels.count > 1 {
                TabBar(store: store, session: session, pane: pane)
            }
            if let panel = pane.selectedPanel {
                PanelHost(store: store, session: session, panel: panel)
            }
        }
    }
}

struct TabBar: View {
    let store: SessionStore
    let session: Session
    let pane: Pane

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(pane.panels.enumerated()), id: \.element.id) { idx, panel in
                TabItem(store: store, session: session, pane: pane,
                        panel: panel, isSelected: idx == pane.selectedIndex)
            }
            Button {
                store.newTab(in: session)
            } label: {
                Image(systemName: "plus").imageScale(.small)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .help(NSLocalizedString("New Tab", comment: ""))
            Spacer()
        }
        .frame(height: 26)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct TabItem: View {
    let store: SessionStore
    let session: Session
    let pane: Pane
    let panel: Panel
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: panel.kind == .terminal ? "terminal.fill" : "globe")
                .imageScale(.small)
            Text(panel.title).lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            pane.selectedIndex = pane.panels.firstIndex { $0.id == panel.id } ?? 0
            store.focus(panel: panel, in: session)
        }
    }
}

struct PanelHost: View {
    let store: SessionStore
    let session: Session
    let panel: Panel

    var body: some View {
        Group {
            switch panel.kind {
            case .terminal:
                if let view = panel.terminalView {
                    TerminalHostView(view: view)
                }
            case .browser:
                if let browser = panel.browserPanel {
                    BrowserPanelView(panel: browser, browserPanel: panel, store: store, session: session)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { store.focus(panel: panel, in: session) }
    }
}

/// P7 右侧 Dock：P8 承载文件查看器
struct DockView: View {
    let store: SessionStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.dockFileURL?.lastPathComponent ?? "Dock")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if store.dockFileURL != nil {
                    Button {
                        store.dockFileURL = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    store.dockVisible = false
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            Divider()
            if let url = store.dockFileURL {
                if isMarkdownFile(url) {
                    MarkdownFileView(url: url)
                } else {
                    FilePreviewView(url: url)
                }
            } else {
                Spacer()
                Text(NSLocalizedString("⌘+Click a file in the terminal to preview it here", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                Spacer()
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// markdown 走 MarkdownUI 渲染（cmux 同款库）
struct MarkdownFileView: View {
    let url: URL
    @State private var text = ""

    var body: some View {
        ScrollView {
            Markdown(text)
                .markdownTheme(.gitHub)
                .textSelection(.enabled)
                .padding(12)
        }
        .onAppear { load() }
        .onChange(of: url) { _, _ in load() }
    }

    private func load() {
        text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}

func isMarkdownFile(_ url: URL) -> Bool {
    ["md", "markdown", "mdown"].contains(url.pathExtension.lowercased())
}

/// P8：按类型渲染的文件预览（对齐 cmux 的体验）：
/// markdown → NSAttributedString 渲染；html → WKWebView；
/// 图片 → NSImageView；pdf → PDFView；其余 → 等宽文本。
struct FilePreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        mount(container, url: url)
        context.coordinator.currentURL = url
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard context.coordinator.currentURL != url else { return }
        mount(container, url: url)
        context.coordinator.currentURL = url
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var currentURL: URL?
    }

    private func mount(_ container: NSView, url: URL) {
        container.subviews.forEach { $0.removeFromSuperview() }
        let view = makeContentView(url: url)
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
    }

    private func makeContentView(url: URL) -> NSView {
        switch kind(of: url) {
        case .image:
            let iv = NSImageView()
            iv.image = NSImage(contentsOf: url)
            iv.imageScaling = .scaleProportionallyUpOrDown
            return iv

        case .pdf:
            let pv = PDFView()
            pv.document = PDFDocument(url: url)
            pv.autoScales = true
            return pv

        case .html:
            let wv = WKWebView()
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            return wv

        case .text:
            let scroll = NSTextView.scrollableTextView()
            if let tv = scroll.documentView as? NSTextView {
                tv.isEditable = false
                tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                tv.string = plainText(url)
            }
            return scroll
        }
    }

    private func plainText(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? "<binary or unreadable>"
    }

    private enum Kind { case image, pdf, html, text }

    private func kind(of url: URL) -> Kind {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "bmp", "tiff":
            return .image
        case "pdf":
            return .pdf
        case "html", "htm", "xhtml":
            return .html
        default:
            return .text
        }
    }
}
