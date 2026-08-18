import Foundation

struct SessionConfig {
    let agentId: String
    let name: String?
    /// P5：信任白名单——这些发送者的消息跳过人审自动投递
    var autoAcceptFrom: [String] = []
    /// P5：自动审批时是否自动回车提交
    var autoSubmit: Bool = false
}

/// stonemux 消息层配置。
/// 读取顺序：环境变量（单会话）> ~/.stonemux/config.json（sessions 数组，回退旧 agent_id 键）。
/// 没有配置时返回 nil，应用降级为纯终端（单本地会话、不轮询）。
struct StonemuxConfig {
    let sessions: [SessionConfig]
    let brokerURL: String
    let token: String

    var primaryAgentId: String { sessions.first?.agentId ?? "stonemux-local" }

    static func load() -> StonemuxConfig? {
        let env = ProcessInfo.processInfo.environment
        if let id = env["STONEMUX_AGENT_ID"],
           let url = env["STONEMUX_BROKER_URL"],
           let token = env["STONEMUX_TOKEN"] {
            return StonemuxConfig(
                sessions: [SessionConfig(agentId: id, name: nil, autoAcceptFrom: [], autoSubmit: false)],
                brokerURL: url, token: token)
        }

        let path = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".stonemux/config.json")
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let url = json["broker_url"] as? String,
              let token = json["token"] as? String else { return nil }

        var sessionConfigs: [SessionConfig] = []
        if let arr = json["sessions"] as? [[String: Any]] {
            sessionConfigs = arr.compactMap { d in
                guard let id = d["agent_id"] as? String else { return nil }
                return SessionConfig(
                    agentId: id,
                    name: d["name"] as? String,
                    autoAcceptFrom: d["auto_accept_from"] as? [String] ?? [],
                    autoSubmit: d["auto_submit"] as? Bool ?? false)
            }
        } else if let id = json["agent_id"] as? String {
            // 兼容旧单身份格式
            sessionConfigs = [SessionConfig(agentId: id, name: nil, autoAcceptFrom: [], autoSubmit: false)]
        }
        guard !sessionConfigs.isEmpty else { return nil }

        return StonemuxConfig(sessions: sessionConfigs, brokerURL: url, token: token)
    }
}
