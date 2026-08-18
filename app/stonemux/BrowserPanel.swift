import AppKit
import WebKit
import Combine
import Observation

/// 浏览器面板：模型拥有 WKWebView（inline hosting，不用 portal）。
/// 导航状态经 KVO 写回 @Observable；脚本能力（eval/snapshot/click/type）
/// 的 selector/text 一律 JSON 编码内嵌，杜绝引号注入。
@MainActor @Observable
final class BrowserPanel: NSObject, WKNavigationDelegate {
    let webView: WKWebView

    var currentURL: URL?
    var currentTitle: String = ""
    var canGoBack = false
    var canGoForward = false
    var isLoading = false

    private var cancellables = Set<AnyCancellable>()

    override init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.navigationDelegate = self

        // KVO → @Observable
        webView.publisher(for: \.canGoBack)
            .sink { [weak self] in self?.canGoBack = $0 }
            .store(in: &cancellables)
        webView.publisher(for: \.canGoForward)
            .sink { [weak self] in self?.canGoForward = $0 }
            .store(in: &cancellables)
        webView.publisher(for: \.isLoading)
            .sink { [weak self] in self?.isLoading = $0 }
            .store(in: &cancellables)
        webView.publisher(for: \.title)
            .sink { [weak self] in self?.currentTitle = $0 ?? "" }
            .store(in: &cancellables)
        webView.publisher(for: \.url)
            .sink { [weak self] in self?.currentURL = $0 }
            .store(in: &cancellables)
    }

    // MARK: 导航

    func navigate(to input: String) {
        webView.load(URLRequest(url: URLResolver.resolve(input)))
    }

    func back() { webView.goBack() }
    func forward() { webView.goForward() }
    func reload() { webView.reload() }

    // MARK: 脚本能力（P4 经 socket 暴露）

    func evaluate(_ js: String) async throws -> String {
        let value = try await webView.evaluateJavaScript(js)
        if let s = value as? String { return s }
        if let value,
           let data = try? JSONSerialization.data(withJSONObject: value),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return value.map { String(describing: $0) } ?? ""
    }

    func snapshotText() async throws -> String {
        try await evaluate("document.body ? document.body.innerText : ''")
    }

    func click(selector: String) async throws {
        let js = """
        (() => {
            const el = document.querySelector(\(jsonLiteral(selector)));
            if (!el) throw new Error('selector not found');
            el.click();
            return 'ok';
        })()
        """
        _ = try await evaluate(js)
    }

    func typeText(selector: String, text: String) async throws {
        let js = """
        (() => {
            const el = document.querySelector(\(jsonLiteral(selector)));
            if (!el) throw new Error('selector not found');
            el.focus();
            el.value = \(jsonLiteral(text));
            el.dispatchEvent(new Event('input', { bubbles: true }));
            return 'ok';
        })()
        """
        _ = try await evaluate(js)
    }

    /// 把字符串编码成 JS 字符串字面量（含引号转义）
    private func jsonLiteral(_ s: String) -> String {
        if let data = try? JSONEncoder().encode(s), let lit = String(data: data, encoding: .utf8) {
            return lit
        }
        return "\"\""
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        currentURL = webView.url
        currentTitle = webView.title ?? ""
    }
}
