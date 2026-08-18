import Foundation

/// 终端点击 token → 真实文件路径。
/// 借鉴 cmux TerminalPathResolver 的最小版：候选变形 → ~ 展开 → 拼 cwd → fileExists 探测。
enum PathResolver {
    static func resolve(_ token: String, cwd: String?) -> String? {
        let candidates = resolutionCandidates(token)
        for cand in candidates {
            var path = (cand as NSString).expandingTildeInPath
            if !(path as NSString).isAbsolutePath {
                guard let cwd else { continue }
                path = (cwd as NSString).appendingPathComponent(path)
            }
            path = (path as NSString).standardizingPath
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// 候选变形：原文 / 反斜杠解转义 / 去配对引号 / 去尾部标点
    private static func resolutionCandidates(_ token: String) -> [String] {
        var out: [String] = []
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return out }
        out.append(trimmed)

        // 反斜杠解转义：ls 输出里空格是 \  转义
        let unescaped = trimmed.replacingOccurrences(of: "\\ ", with: " ")
            .replacingOccurrences(of: "\\'", with: "'")
        if unescaped != trimmed { out.append(unescaped) }

        // 去配对引号
        for q in ["\"", "'"] {
            if trimmed.hasPrefix(q), trimmed.hasSuffix(q), trimmed.count >= 2 {
                out.append(String(trimmed.dropFirst().dropLast()))
            }
        }

        // 去尾部标点（, ; : 等）
        let trailing = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ",;:。，；："))
        if trailing != trimmed { out.append(trailing) }

        return out
    }
}
