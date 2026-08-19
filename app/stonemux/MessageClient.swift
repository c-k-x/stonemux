import Foundation

/// 信封（与 broker 的线上格式一致）
struct Envelope: Codable {
    let id: String
    let from: String
    let to: String
    let content_type: String
    let subject: String
    let body: String
    let reply_to: String?
    let created_at: String
    let status: String
}

enum MessagingError: Error, LocalizedError {
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .http(let code): return "broker 返回 HTTP \(code)"
        }
    }
}

/// broker HTTP 客户端：send / inbox / ack / reply 四个动作
final class MessageClient {
    private let base: String
    private let token: String
    private let session = URLSession(configuration: .ephemeral)

    init(brokerURL: String, token: String) {
        self.base = brokerURL.hasSuffix("/") ? String(brokerURL.dropLast()) : brokerURL
        self.token = token
    }

    private func call(
        _ method: String,
        _ path: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let url = URL(string: base + path) else { throw MessagingError.http(-1) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else { throw MessagingError.http(code) }
        return data
    }

    /// 拉取发给某 agent 的 pending 消息
    func inbox(to: String) async throws -> [Envelope] {
        let path = "/msg?to=\(to.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? to)&status=pending"
        let data = try await call("GET", path)
        return try JSONDecoder().decode([Envelope].self, from: data)
    }

    /// 更新状态（delivered/read）
    func ack(id: String, status: String) async throws {
        _ = try await call("POST", "/msg/\(id)/ack", body: ["status": status])
    }

    /// 发送消息，返回新消息 id
    func send(from: String, to: String, type: String, subject: String, body: String) async throws -> String {
        let data = try await call("POST", "/msg", body: [
            "from": from, "to": to,
            "content_type": type, "subject": subject, "body": body,
        ])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? String ?? ""
    }

    /// 回复，返回回复消息 id
    func reply(id: String, from: String, body: String) async throws -> String {
        let data = try await call("POST", "/msg/\(id)/reply", body: ["from": from, "body": body])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? String ?? ""
    }

    // MARK: P9 presence

    /// 心跳上报
    func beat(agentId: String, name: String) async throws {
        _ = try await call("POST", "/presence", body: ["agent_id": agentId, "name": name])
    }

    /// 在线 agent 目录
    func agents() async throws -> [Peer] {
        struct AgentDTO: Codable {
            let agent_id: String
            let name: String
        }
        let data = try await call("GET", "/agents")
        return try JSONDecoder().decode([AgentDTO].self, from: data)
            .map { Peer(agentId: $0.agent_id, name: $0.name) }
    }
}
