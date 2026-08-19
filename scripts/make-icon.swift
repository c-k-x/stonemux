import AppKit

// 生成 stonemux 图标：深色终端底 + 🪨 + 绿色 prompt
let size = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// 深色底
NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// 石头 emoji 居中偏上
let emoji = NSAttributedString(
    string: "🪨",
    attributes: [.font: NSFont.systemFont(ofSize: 560)])
let emojiBounds = emoji.size()
emoji.draw(at: NSPoint(
    x: (CGFloat(size) - emojiBounds.width) / 2,
    y: (CGFloat(size) - emojiBounds.height) / 2 + 60))

// 绿色 prompt ">_" 在下部
let prompt = NSAttributedString(
    string: ">_",
    attributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 220, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.30, green: 0.85, blue: 0.40, alpha: 1),
    ])
let promptBounds = prompt.size()
prompt.draw(at: NSPoint(
    x: (CGFloat(size) - promptBounds.width) / 2,
    y: 110))

img.unlockFocus()

// 存 PNG
guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-icon.png"
try! png.write(to: URL(fileURLWithPath: out))
print("written \(out)")
