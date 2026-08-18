import Foundation

/// 控制面命令（NDJSON 行协议；Swift 5.9 关联值自动合成 Codable）。
/// panel=nil → 选中会话的 browser panel；session=nil → 当前选中会话。
enum ControlCommand: Codable {
    case sessions
    case open(url: String, session: String?)
    case navigate(url: String, panel: String?)
    case back(panel: String?)
    case forward(panel: String?)
    case reload(panel: String?)
    case url(panel: String?)
    case title(panel: String?)
    case eval(js: String, panel: String?)
    case snapshot(panel: String?)
    case click(selector: String, panel: String?)
    case type(selector: String, text: String, panel: String?)
    // 消息动词（P5）：agent 在终端内自主收发
    case send(from: String?, to: String, subject: String, body: String)
    case inbox(session: String?)
    case reply(id: String, from: String?, body: String)
    case ack(id: String, status: String)
}

struct ControlRequest: Codable {
    let token: String
    let command: ControlCommand
}

struct ControlResponse: Codable {
    let ok: Bool
    let result: String?
    let error: String?

    static func success(_ result: String?) -> ControlResponse {
        ControlResponse(ok: true, result: result, error: nil)
    }

    static func failure(_ error: String) -> ControlResponse {
        ControlResponse(ok: false, result: nil, error: error)
    }
}
