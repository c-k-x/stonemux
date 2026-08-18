import AppKit

// main.swift 顶层代码非 MainActor 隔离，用 assumeIsolated 声明主线程事实
//（NSApplication 顶层代码必然跑在主线程）
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
