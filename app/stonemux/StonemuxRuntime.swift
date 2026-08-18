import AppKit
import GhosttyKit

// MARK: - C 回调跳板
// libghostty 的回调是 C 函数指针，不能捕获 Swift 上下文，
// 只能通过 userdata / app 句柄取回 Swift 对象。

private func stonemuxWakeupCallback(_ userdata: UnsafeMutableRawPointer?) {
    // 唤醒 = 请驱动一次事件循环（在主线程序列化执行）
    StonemuxRuntime.fromUserdata(userdata)?.scheduleTick()
}

private func stonemuxActionCallback(
    _ app: ghostty_app_t?,
    _ target: ghostty_target_s,
    _ action: ghostty_action_s
) -> Bool {
    guard let app else { return false }
    return StonemuxRuntime.fromApp(app)?.handleAction(target: target, action: action) ?? false
}

private func stonemuxReadClipboardCallback(
    _ userdata: UnsafeMutableRawPointer?,
    _ location: ghostty_clipboard_e,
    _ state: UnsafeMutableRawPointer?
) -> Bool {
    // walking-skeleton：拒绝终端侧读剪贴板（OSC 52），把攻击面压到最小
    return false
}

private func stonemuxConfirmReadClipboardCallback(
    _ userdata: UnsafeMutableRawPointer?,
    _ message: UnsafePointer<CChar>?,
    _ state: UnsafeMutableRawPointer?,
    _ request: ghostty_clipboard_request_e
) {
    // walking-skeleton：不做确认弹窗
}

private func stonemuxWriteClipboardCallback(
    _ userdata: UnsafeMutableRawPointer?,
    _ location: ghostty_clipboard_e,
    _ content: UnsafePointer<ghostty_clipboard_content_s>?,
    _ len: Int,
    _ confirm: Bool
) {
    // 终端请求写剪贴板（如 Cmd-C 复制选区）：只接收 text/plain
    guard let content, len > 0 else { return }
    for i in 0..<len {
        let item = content[i]
        guard let mimePtr = item.mime, let dataPtr = item.data else { continue }
        guard String(cString: mimePtr) == "text/plain" else { continue }
        let value = String(cString: dataPtr)
        DispatchQueue.main.async {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(value, forType: .string)
        }
        return
    }
}

private func stonemuxCloseSurfaceCallback(_ userdata: UnsafeMutableRawPointer?, _ processAlive: Bool) {
    // close_surface_cb 的 userdata 即 surface config 的 userdata（TerminalView）
    let view = userdata.map { Unmanaged<TerminalView>.fromOpaque($0).takeUnretainedValue() }
    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: StonemuxRuntime.surfaceDidClose,
            object: view,
            userInfo: ["processAlive": processAlive])
    }
}

// MARK: - StonemuxRuntime

/// libghostty 生命周期封装：init → config → app_new → tick。
/// 进程级单实例，由 AppDelegate 持有（userdata 是 unretained 引用，必须保活）。
final class StonemuxRuntime {
    /// 终端标题变化（userInfo: title + surface）
    static let titleDidChange = Notification.Name("stonemux.titleDidChange")
    /// surface 请求关闭（shell 退出）
    static let surfaceDidClose = Notification.Name("stonemux.surfaceDidClose")

    enum RuntimeError: Error, LocalizedError {
        case backendInitFailed(code: Int32)
        case appCreationFailed

        var errorDescription: String? {
            switch self {
            case .backendInitFailed(let code):
                return "libghostty 初始化失败（错误码 \(code)）"
            case .appCreationFailed:
                return "libghostty app 创建失败"
            }
        }
    }

    private(set) var app: ghostty_app_t?
    private(set) var config: ghostty_config_t?

    private init() throws {
        // 1) 后端初始化（一次性）
        let rc = ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv)
        guard rc == GHOSTTY_SUCCESS else {
            throw RuntimeError.backendInitFailed(code: rc)
        }

        // 2) 配置：加载默认配置文件（如 ~/.config/ghostty/config），没有则用内置默认
        let config = ghostty_config_new()
        ghostty_config_load_default_files(config)
        ghostty_config_finalize(config)

        // 3) 运行时回调
        var rt = ghostty_runtime_config_s()
        rt.userdata = Unmanaged.passUnretained(self).toOpaque()
        rt.supports_selection_clipboard = false
        rt.wakeup_cb = stonemuxWakeupCallback
        rt.action_cb = stonemuxActionCallback
        rt.read_clipboard_cb = stonemuxReadClipboardCallback
        rt.confirm_read_clipboard_cb = stonemuxConfirmReadClipboardCallback
        rt.write_clipboard_cb = stonemuxWriteClipboardCallback
        rt.close_surface_cb = stonemuxCloseSurfaceCallback

        // 4) 创建 app
        guard let app = ghostty_app_new(&rt, config) else {
            ghostty_config_free(config)
            throw RuntimeError.appCreationFailed
        }
        self.app = app
        self.config = config
    }

    deinit {
        if let app { ghostty_app_free(app) }
        if let config { ghostty_config_free(config) }
    }

    /// 进程级启动入口（失败抛错，由调用方决定如何展示）
    static func bootstrap() throws -> StonemuxRuntime {
        try StonemuxRuntime()
    }

    /// 驱动 libghostty 事件循环（由 wakeup 回调触发）
    func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    func scheduleTick() {
        DispatchQueue.main.async { [weak self] in self?.tick() }
    }

    // MARK: userdata 还原

    static func fromUserdata(_ userdata: UnsafeMutableRawPointer?) -> StonemuxRuntime? {
        guard let userdata else { return nil }
        return Unmanaged<StonemuxRuntime>.fromOpaque(userdata).takeUnretainedValue()
    }

    static func fromApp(_ app: ghostty_app_t) -> StonemuxRuntime? {
        fromUserdata(ghostty_app_userdata(app))
    }

    // MARK: action 分发（walking-skeleton 只处理必要的几个）

    func handleAction(target: ghostty_target_s, action: ghostty_action_s) -> Bool {
        switch action.tag {
        case GHOSTTY_ACTION_SET_TITLE:
            guard target.tag == GHOSTTY_TARGET_SURFACE,
                  let surface = target.target.surface,
                  let titlePtr = action.action.set_title.title else { return false }
            let title = String(cString: titlePtr)
            // 经 ghostty_surface_userdata 还原出该 surface 的 TerminalView
            let view = ghostty_surface_userdata(surface)
                .map { Unmanaged<TerminalView>.fromOpaque($0).takeUnretainedValue() }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: StonemuxRuntime.titleDidChange,
                    object: view,
                    userInfo: ["title": title])
            }
            return true

        case GHOSTTY_ACTION_PWD:
            // OSC 7：shell-integration 报告的 cwd，按 surface 存
            guard target.tag == GHOSTTY_TARGET_SURFACE,
                  let surface = target.target.surface,
                  let pwdPtr = action.action.pwd.pwd else { return false }
            let pwd = String(cString: pwdPtr)
            let view = ghostty_surface_userdata(surface)
                .map { Unmanaged<TerminalView>.fromOpaque($0).takeUnretainedValue() }
            DispatchQueue.main.async {
                view?.workingDirectory = pwd
            }
            return true

        case GHOSTTY_ACTION_OPEN_URL:
            let payload = action.action.open_url
            guard let urlPtr = payload.url else { return false }
            let data = Data(bytes: urlPtr, count: Int(payload.len))
            guard let s = String(data: data, encoding: .utf8),
                  let url = URL(string: s) else { return false }
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
            return true

        default:
            // 其余 action（分屏、滚动条、提示符检测等）walking-skeleton 不处理
            return false
        }
    }
}
