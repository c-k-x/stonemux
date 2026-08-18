import AppKit

/// 消息层控制器（store 驱动）：
/// 轮询所有会话的收件 → 未读角标 → 人审弹窗（标注会话）→ 投递到该会话终端；
/// 发送/回复的 from 固定为当前选中会话。
@MainActor
final class MessagingController {
    private let config: StonemuxConfig
    private let store: SessionStore
    private let client: MessageClient
    private var pollTask: Task<Void, Never>?
    /// seen 按 agent_id 分桶
    private var seen: [String: Set<String>] = [:]
    /// 每个会话最近一条收件（用于回复）
    private var lastReceived: [String: Envelope] = [:]
    /// 非白名单待投递消息（左栏角标提示，点击会话时投递）
    private var pendingBySession: [String: [Envelope]] = [:]

    init(config: StonemuxConfig, store: SessionStore) {
        self.config = config
        self.store = store
        self.client = MessageClient(brokerURL: config.brokerURL, token: config.token)
        // 点击会话 → 投递该会话的 pending（不打断终端使用）
        store.onSessionSelected = { [weak self] session in
            self?.flushPending(in: session)
        }
    }

    func start() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.pollOnce()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func stop() { pollTask?.cancel() }

    private func pollOnce() {
        let sessions = store.sessions
        Task { [weak self] in
            guard let self else { return }
            // 顺序轮询各会话（N 很小，2s 一轮足够）
            for session in sessions {
                guard let msgs = try? await self.client.inbox(to: session.agentId) else { continue }
                for m in msgs where !(self.seen[session.agentId] ?? []).contains(m.id) {
                    self.seen[session.agentId, default: []].insert(m.id)
                    self.present(m, in: session)
                }
            }
        }
    }

    // MARK: 收件人审

    private func present(_ m: Envelope, in session: Session) {
        lastReceived[session.agentId] = m

        // P5：信任白名单发送者 → 自动审批（用户已确认该策略，config 显式 opt-in）
        if session.autoAcceptFrom.contains(m.from) {
            store.inject(m.body + (session.autoSubmit ? "\n" : ""), into: session)
            Task { [weak self] in try? await self?.client.ack(id: m.id, status: "read") }
            return
        }

        // 非白名单：不弹窗（避免打断终端），左栏角标提示，点击会话时投递
        store.bumpUnread(session)
        pendingBySession[session.agentId, default: []].append(m)
    }

    /// 会话被选中：按序投递 pending + ack read
    private func flushPending(in session: Session) {
        guard let msgs = pendingBySession[session.agentId], !msgs.isEmpty else { return }
        pendingBySession[session.agentId] = []
        for m in msgs {
            store.inject(m.body + (session.autoSubmit ? "\n" : ""), into: session)
            Task { [weak self] in try? await self?.client.ack(id: m.id, status: "read") }
        }
    }

    // MARK: 发送（from = 选中会话）

    func showSendSheet() {
        guard let from = store.selectedSession, let window = store.window else { return }
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Send stonemux message (from: %@)", comment: ""), from.agentId)
        alert.addButton(withTitle: NSLocalizedString("Send", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

        // 固定尺寸容器 + 绝对定位（NSStackView 无约束时高度为 0）
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 104))
        let toField = NSTextField(frame: NSRect(x: 0, y: 76, width: 380, height: 24))
        toField.placeholderString = NSLocalizedString("to (recipient agent_id, e.g. bob-claude)", comment: "")
        let subjectField = NSTextField(frame: NSRect(x: 0, y: 42, width: 380, height: 24))
        subjectField.placeholderString = NSLocalizedString("subject", comment: "")
        let bodyField = NSTextField(frame: NSRect(x: 0, y: 8, width: 380, height: 24))
        bodyField.placeholderString = NSLocalizedString("body", comment: "")
        box.addSubview(toField)
        box.addSubview(subjectField)
        box.addSubview(bodyField)
        alert.accessoryView = box

        alert.beginSheetModal(for: window) { [weak self] resp in
            Task { @MainActor [weak self] in
                guard let self, resp == .alertFirstButtonReturn else { return }
                let to = toField.stringValue.trimmingCharacters(in: .whitespaces)
                guard !to.isEmpty else { return }
                do {
                    _ = try await self.client.send(
                        from: from.agentId, to: to, type: "message",
                        subject: subjectField.stringValue, body: bodyField.stringValue)
                } catch {
                    self.showError(String(format: NSLocalizedString("Send failed: %@", comment: ""), error.localizedDescription))
                }
            }
        }
    }

    // MARK: 回复选中会话的最近一条

    func showReplySheet() {
        guard let session = store.selectedSession,
              let m = lastReceived[session.agentId],
              let window = store.window else {
            showError(NSLocalizedString("Current session has not received any message yet", comment: ""))
            return
        }
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Reply to %@", comment: ""), m.from)
        alert.informativeText = m.subject.isEmpty
            ? NSLocalizedString("(original had no subject)", comment: "")
            : String(format: NSLocalizedString("Original subject: %@", comment: ""), m.subject)
        alert.addButton(withTitle: NSLocalizedString("Send", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.placeholderString = NSLocalizedString("Reply content", comment: "")
        alert.accessoryView = field

        alert.beginSheetModal(for: window) { [weak self] resp in
            Task { @MainActor [weak self] in
                guard let self, resp == .alertFirstButtonReturn else { return }
                do {
                    _ = try await self.client.reply(
                        id: m.id, from: session.agentId, body: field.stringValue)
                } catch {
                    self.showError(String(format: NSLocalizedString("Reply failed: %@", comment: ""), error.localizedDescription))
                }
            }
        }
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        if let window = store.window {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }

    // MARK: P5 ctl 消息动词（agent 自主收发）

    func sendForCtl(from: String, to: String, subject: String, body: String) async throws -> String {
        try await client.send(from: from, to: to, type: "message", subject: subject, body: body)
    }

    func inboxForCtl(session: String) async throws -> String {
        let msgs = try await client.inbox(to: session)
        let data = try JSONEncoder().encode(msgs)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    func replyForCtl(id: String, from: String, body: String) async throws -> String {
        try await client.reply(id: id, from: from, body: body)
    }

    func ackForCtl(id: String, status: String) async throws {
        try await client.ack(id: id, status: status)
    }
}
