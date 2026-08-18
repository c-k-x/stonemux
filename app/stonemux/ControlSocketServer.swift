import Foundation
import Security

/// app 内 Unix socket 控制服务（NDJSON 行协议）。
/// 凭据：~/.stonemux/ctl.json（socket_path + 每启动随机 token，0600）。
/// 不复用 broker token——那是跨机器网络凭据，信任域不同。
@MainActor
final class ControlSocketServer {
    private let store: SessionStore
    /// P5：消息动词经 MessagingController 走 broker
    weak var messaging: MessagingController?
    private let socketPath: String
    private let token: String
    private var serverFD: Int32 = -1
    private var acceptTask: Task<Void, Never>?

    init(store: SessionStore) {
        self.store = store
        let dir = (NSHomeDirectory() as NSString).appendingPathComponent(".stonemux")
        self.socketPath = (dir as NSString).appendingPathComponent("stonemux.sock")
        self.token = Self.randomToken()
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    func start() throws {
        let dir = (socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // 写凭据 ctl.json（0600）
        let ctl = ["socket_path": socketPath, "token": token]
        let data = try JSONSerialization.data(withJSONObject: ctl, options: [.prettyPrinted])
        let ctlPath = (dir as NSString).appendingPathComponent("ctl.json")
        try data.write(to: URL(fileURLWithPath: ctlPath))
        chmod(ctlPath, 0o600)

        // bind 前 unlink 旧 socket 防 EADDRINUSE
        unlink(socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ControlError.socketFailed }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathSize = MemoryLayout.size(ofValue: addr.sun_path)
        guard socketPath.utf8.count < pathSize else {
            close(fd)
            throw ControlError.pathTooLong
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let buf = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            strcpy(buf, socketPath)
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw ControlError.socketFailed
        }
        guard listen(fd, 8) == 0 else {
            close(fd)
            throw ControlError.socketFailed
        }

        serverFD = fd
        let listenFD = fd  // 捕获局部值，避免 detached task 碰 MainActor 属性
        acceptTask = Task.detached { [weak self] in
            guard let self else { return }
            while true {
                let client = accept(listenFD, nil, nil)
                if client < 0 { break }
                Task.detached { [weak self] in
                    self?.serve(client)
                }
            }
        }
    }

    func stop() {
        acceptTask?.cancel()
        if serverFD >= 0 { close(serverFD) }
        unlink(socketPath)
    }

    // MARK: 连接服务：按行读 → 验 token → 主线程执行 → 写回一行

    private nonisolated func serve(_ client: Int32) {
        defer { close(client) }
        var buffer = [UInt8](repeating: 0, count: 65536)
        var pending = Data()

        while true {
            let n = read(client, &buffer, buffer.count)
            if n <= 0 { break }
            pending.append(contentsOf: buffer[0..<n])

            while let range = pending.range(of: Data("\n".utf8)) {
                let line = pending.subdata(in: pending.startIndex..<range.lowerBound)
                pending.removeSubrange(pending.startIndex..<range.upperBound)
                guard line.count > 0, line.count < 1_000_000 else { continue }

                let response = handleLine(line)
                if var out = try? JSONEncoder().encode(response) {
                    out.append(contentsOf: "\n".utf8)
                    out.withUnsafeBytes { raw in
                        _ = write(client, raw.baseAddress, raw.count)
                    }
                }
            }
        }
    }

    private nonisolated func handleLine(_ line: Data) -> ControlResponse {
        guard let req = try? JSONDecoder().decode(ControlRequest.self, from: line) else {
            return .failure("bad request")
        }
        guard req.token == token else {
            return .failure("unauthorized")
        }
        // 主线程执行（半同步：阻塞等主线程结果）
        let sem = DispatchSemaphore(value: 0)
        var result = ControlResponse.failure("internal")
        Task { @MainActor [weak self] in
            guard let self else { sem.signal(); return }
            result = await self.execute(req.command)
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 30)
        return result
    }

    // MARK: 命令分发

    private func execute(_ cmd: ControlCommand) async -> ControlResponse {
        do {
            switch cmd {
            case .sessions:
                return .success(sessionsJSON())

            case .open(let url, let session):
                let s = try targetSession(session)
                store.openBrowser(in: s, url: url)
                return .success("opened")

            case .navigate(let url, let panel):
                let bp = try targetBrowser(panel)
                bp.navigate(to: url)
                return .success("navigating")

            case .back(let panel):
                try targetBrowser(panel).back()
                return .success("ok")

            case .forward(let panel):
                try targetBrowser(panel).forward()
                return .success("ok")

            case .reload(let panel):
                try targetBrowser(panel).reload()
                return .success("ok")

            case .url(let panel):
                return .success(try targetBrowser(panel).currentURL?.absoluteString ?? "")

            case .title(let panel):
                return .success(try targetBrowser(panel).currentTitle)

            case .eval(let js, let panel):
                return .success(try await targetBrowser(panel).evaluate(js))

            case .snapshot(let panel):
                return .success(try await targetBrowser(panel).snapshotText())

            case .click(let selector, let panel):
                try await targetBrowser(panel).click(selector: selector)
                return .success("ok")

            case .type(let selector, let text, let panel):
                try await targetBrowser(panel).typeText(selector: selector, text: text)
                return .success("ok")

            // MARK: P5 消息动词
            case .send(let from, let to, let subject, let body):
                guard let from, !from.isEmpty else {
                    return .failure("from 为空（终端内应有 STONEMUX_SESSION_ID，或 --from 指定）")
                }
                guard let messaging else { return .failure("broker 未配置") }
                let id = try await messaging.sendForCtl(from: from, to: to, subject: subject, body: body)
                return .success(id)

            case .inbox(let session):
                guard let messaging else { return .failure("broker 未配置") }
                let sid = session ?? store.selectedSession?.agentId ?? ""
                return .success(try await messaging.inboxForCtl(session: sid))

            case .reply(let id, let from, let body):
                guard let messaging else { return .failure("broker 未配置") }
                let sender = (from?.isEmpty == false) ? from! : (store.selectedSession?.agentId ?? "")
                return .success(try await messaging.replyForCtl(id: id, from: sender, body: body))

            case .ack(let id, let status):
                guard let messaging else { return .failure("broker 未配置") }
                try await messaging.ackForCtl(id: id, status: status)
                return .success("ok")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func sessionsJSON() -> String {
        var rows: [[String: Any]] = []
        for s in store.sessions {
            let panels: [[String: Any]] = s.panels.map { p in
                ["id": p.id.uuidString,
                 "kind": p.kind == .terminal ? "terminal" : "browser",
                 "title": p.title]
            }
            rows.append(["agent_id": s.agentId,
                         "name": s.displayName,
                         "unread": s.unread,
                         "selected": s.id == store.selectedSessionId,
                         "panels": panels])
        }
        let data = (try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func targetSession(_ id: String?) throws -> Session {
        if let id {
            guard let s = store.session(agentId: id) else { throw ControlError.noSession }
            return s
        }
        guard let s = store.selectedSession else { throw ControlError.noSession }
        return s
    }

    private func targetBrowser(_ panelId: String?) throws -> BrowserPanel {
        let session = store.selectedSession
        guard let session else { throw ControlError.noSession }
        if let panelId {
            let uuid = UUID(uuidString: panelId)
            for s in store.sessions {
                if let p = s.panels.first(where: { $0.id == uuid }), let bp = p.browserPanel {
                    return bp
                }
            }
            throw ControlError.noBrowser
        }
        guard let bp = session.panels.compactMap({ $0.browserPanel }).first else {
            throw ControlError.noBrowser
        }
        return bp
    }

    enum ControlError: Error, LocalizedError {
        case socketFailed
        case pathTooLong
        case noSession
        case noBrowser

        var errorDescription: String? {
            switch self {
            case .socketFailed: return "socket 创建/绑定失败"
            case .pathTooLong: return "socket 路径过长"
            case .noSession: return "会话不存在"
            case .noBrowser: return "当前会话没有浏览器面板（先 ⌘⇧B 或 ctl open）"
            }
        }
    }
}
