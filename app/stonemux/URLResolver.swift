import Foundation

/// 纯函数：omnibar 输入 → URL。
/// 带 scheme 直接用；像域名补 https；其余转搜索。
enum URLResolver {
    static func resolve(_ input: String) -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // 带 scheme（http://、https://、about: 等）直接用
        if trimmed.contains("://"), let url = URL(string: trimmed) {
            return url
        }
        // 像域名：无空格且含点（排除以点开头）
        if !trimmed.contains(" "), trimmed.contains("."), !trimmed.hasPrefix(".") {
            return URL(string: "https://\(trimmed)")!
        }
        // 其余走搜索
        let q = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://duckduckgo.com/?q=\(q)")!
    }
}
