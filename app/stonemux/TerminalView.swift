import AppKit
import GhosttyKit

/// 承载一个 ghostty surface 的 NSView。
/// Ghostty 会在这个 view 上自行搭建 Metal 渲染管线；
/// 本类负责：尺寸/缩放同步、键盘鼠标事件转发、焦点管理、剪贴板粘贴。
final class TerminalView: NSView {
    private(set) var surface: ghostty_surface_t?
    private let runtime: StonemuxRuntime
    /// 注入到 shell 的环境变量（如 STONEMUX_SESSION_ID）
    private let envPairs: [(String, String)]
    /// P8：OSC 7 追踪的 shell cwd
    var workingDirectory: String?
    /// P8：cmd+click 解析出文件路径后的回调（store 挂上开 Dock 的动作）
    var onCommandClickPath: ((String) -> Void)?

    init(runtime: StonemuxRuntime, envPairs: [(String, String)] = []) {
        self.runtime = runtime
        self.envPairs = envPairs
        super.init(frame: NSRect(x: 0, y: 0, width: 900, height: 560))
        wantsLayer = true

        guard let app = runtime.app else { return }

        // surface 配置：platform=macOS，把本 view 交给 ghostty
        var cfg = ghostty_surface_config_new()
        cfg.platform_tag = GHOSTTY_PLATFORM_MACOS
        cfg.platform.macos.nsview = Unmanaged.passUnretained(self).toOpaque()
        cfg.userdata = Unmanaged.passUnretained(self).toOpaque()
        cfg.scale_factor = 2.0  // 挂到窗口后会按实际 backing 刷新
        cfg.font_size = 13
        cfg.context = GHOSTTY_SURFACE_CONTEXT_WINDOW
        // command / working_directory 不设置 → 使用配置里的默认 shell

        // 环境变量在 surface 创建期间保持 C 字符串有效
        withEnvVars(envPairs) { evs in
            var evs = evs
            cfg.env_vars = evs.isEmpty ? nil : evs.withUnsafeMutableBufferPointer { $0.baseAddress }
            cfg.env_var_count = evs.count
            surface = ghostty_surface_new(app, &cfg)
        }
    }

    /// 递归嵌套 withCString，保证 ghostty_surface_new 调用期间指针有效
    private func withEnvVars<T>(_ pairs: [(String, String)], _ body: ([ghostty_env_var_s]) -> T) -> T {
        func rec(_ i: Int, _ acc: [ghostty_env_var_s]) -> T {
            guard i < pairs.count else { return body(acc) }
            return pairs[i].0.withCString { k in
                pairs[i].1.withCString { v in
                    rec(i + 1, acc + [ghostty_env_var_s(key: k, value: v)])
                }
            }
        }
        return rec(0, [])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let surface { ghostty_surface_free(surface) }
    }

    /// 向终端注入一段文本（如同键入）。消息层投递的入口。
    func injectText(_ text: String) {
        guard let surface, !text.isEmpty else { return }
        text.withCString { ptr in
            ghostty_surface_text_input(surface, ptr, UInt(text.utf8.count))
        }
    }

    // MARK: 焦点

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        updateScaleAndSize()
        // v0.5：焦点由 SessionStore 统一指派，视图不再自抢 firstResponder
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if let surface {
            ghostty_surface_set_focus(surface, true)
            if let app = runtime.app { ghostty_app_set_focus(app, true) }
        }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if let surface { ghostty_surface_set_focus(surface, false) }
        return ok
    }

    // MARK: 尺寸与缩放

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        // 同步 layer 的 contentsScale，避免跨 DPI 屏幕时被合成器二次缩放
        if let window {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer?.contentsScale = window.backingScaleFactor
            CATransaction.commit()
        }
        updateScaleAndSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateScaleAndSize()
    }

    private func updateScaleAndSize() {
        guard let surface else { return }
        let fb = convertToBacking(bounds)
        let xScale = fb.width / bounds.width
        let yScale = fb.height / bounds.height
        ghostty_surface_set_content_scale(surface, xScale, yScale)
        ghostty_surface_set_size(surface, UInt32(fb.width), UInt32(fb.height))
    }

    // MARK: 键盘

    override func keyDown(with event: NSEvent) {
        // walking-skeleton 粘贴：Cmd-V 直接注入剪贴板文本
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            if let text = NSPasteboard.general.string(forType: .string) {
                injectText(text)
            }
            return
        }
        sendKey(event, action: event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS)
    }

    override func keyUp(with event: NSEvent) {
        sendKey(event, action: GHOSTTY_ACTION_RELEASE)
    }

    private func sendKey(_ event: NSEvent, action: ghostty_input_action_e) {
        guard let surface else { return }
        var key = ghostty_input_key_s()
        key.action = action
        // macOS 原生 keyCode 直传，ghostty 核心负责映射（与官方 app 同款做法）
        key.keycode = UInt32(event.keyCode)
        key.mods = Self.ghosttyMods(event.modifierFlags)
        // 官方同款启发式：control/command 不参与文本翻译
        key.consumed_mods = Self.ghosttyMods(event.modifierFlags.subtracting([.control, .command]))
        key.composing = false
        key.unshifted_codepoint = 0
        if let chars = event.characters(byApplyingModifiers: []),
           let cp = chars.unicodeScalars.first {
            key.unshifted_codepoint = cp.value
        }

        if action != GHOSTTY_ACTION_RELEASE, let text = Self.terminalText(for: event) {
            text.withCString { ptr in
                key.text = ptr
                _ = ghostty_surface_key(surface, key)
            }
        } else {
            key.text = nil
            _ = ghostty_surface_key(surface, key)
        }
    }

    /// 键文本翻译（简化自 Ghostty 官方 ghosttyCharacters）：
    /// - 单个控制字符 → 还原成未按 control 的字符，由 ghostty 核心编码
    /// - 私用区码点（功能键）→ 不发送
    private static func terminalText(for event: NSEvent) -> String? {
        guard let characters = event.characters else { return nil }
        if characters.count == 1, let scalar = characters.unicodeScalars.first {
            if scalar.value < 0x20 {
                return event.characters(byApplyingModifiers: event.modifierFlags.subtracting(.control))
            }
            if scalar.value >= 0xF700 && scalar.value <= 0xF8FF { return nil }
        }
        return characters
    }

    static func ghosttyMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var raw: UInt32 = 0
        if flags.contains(.shift) { raw |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { raw |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { raw |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { raw |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { raw |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(rawValue: raw) ?? GHOSTTY_MODS_NONE
    }

    // MARK: 鼠标（最小实现）

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil))
    }

    override func mouseDown(with event: NSEvent) {
        guard let surface else { return }
        window?.makeFirstResponder(self)
        sendMousePos(event)
        _ = ghostty_surface_mouse_button(
            surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, Self.ghosttyMods(event.modifierFlags))
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface else { return }
        sendMousePos(event)
        let consumed = ghostty_surface_mouse_button(
            surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, Self.ghosttyMods(event.modifierFlags))

        // P8：cmd+click 且 ghostty 没当链接消费 → 尝试解析裸文件路径
        guard event.modifierFlags.contains(.command), !consumed else { return }
        handleCommandClick()
    }

    /// 补坐标 → 取光标下的词 → 解析路径 → 回调
    private func handleCommandClick() {
        guard let surface else { return }
        var text = ghostty_text_s()
        guard ghostty_surface_quicklook_word(surface, &text),
              let ptr = text.text else { return }
        let word = String(cString: ptr)
        ghostty_surface_free_text(surface, &text)
        guard !word.isEmpty else { return }

        if let path = PathResolver.resolve(word, cwd: workingDirectory) {
            onCommandClickPath?(path)
        }
    }

    override func mouseMoved(with event: NSEvent) { sendMousePos(event) }
    override func mouseDragged(with event: NSEvent) { sendMousePos(event) }

    private func sendMousePos(_ event: NSEvent) {
        guard let surface else { return }
        // 终端坐标原点在左上角；AppKit 在左下角，翻转 y
        let p = convert(event.locationInWindow, from: nil)
        let y = bounds.height - p.y
        ghostty_surface_mouse_pos(surface, p.x, y, Self.ghosttyMods(event.modifierFlags))
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        // scroll_mods 是打包位域；walking-skeleton 只传修饰键，动量信息省略
        let mods = Int32(Self.ghosttyMods(event.modifierFlags).rawValue)
        ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, mods)
    }
}
