import AppKit

// 生成 20 个 stonemux 候选图标（512px）+ 一个选择页 gallery.html
// 用法: swift scripts/make-icons.swift <输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-icons"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

typealias RGB = (CGFloat, CGFloat, CGFloat)

struct Spec {
    let name: String
    let c1: RGB; let c2: RGB          // 背景渐变（相同=纯色）
    let dots: Bool                    // 终端窗口红黄绿点
    let main: String                  // 主图形（emoji 或文本）
    let mainMono: Bool                // true=等宽文本（用 mainColor），false=emoji
    let mainColor: RGB
    let mainSize: CGFloat
    let mainDY: CGFloat
    let sub: String?                  // 底部 prompt 文本
    let subColor: RGB
    let subSize: CGFloat
    let subDY: CGFloat
}

let green: RGB = (0.30, 0.85, 0.40)
let dark: RGB = (0.11, 0.11, 0.13)

let specs: [Spec] = [
    Spec(name: "01-stone-prompt",  c1: dark, c2: dark, dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30,  sub: ">_", subColor: green, subSize: 110, subDY: -170),
    Spec(name: "02-stone-only",    c1: dark, c2: dark, dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 340, mainDY: 0,   sub: nil,   subColor: green, subSize: 110, subDY: 0),
    Spec(name: "03-green-grad",    c1: (0.05,0.16,0.10), c2: (0.07,0.23,0.13), dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30, sub: ">_", subColor: (0.85,1,0.9), subSize: 110, subDY: -170),
    Spec(name: "04-paper-light",   c1: (0.95,0.94,0.92), c2: (0.95,0.94,0.92), dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30, sub: ">_", subColor: (0.1,0.1,0.1), subSize: 110, subDY: -170),
    Spec(name: "05-mono-s",        c1: (0,0,0), c2: (0,0,0), dots: false, main: "S", mainMono: true, mainColor: (0.95,0.95,0.95), mainSize: 320, mainDY: 0, sub: nil, subColor: green, subSize: 110, subDY: 0),
    Spec(name: "06-prompt-only",   c1: (0,0,0), c2: (0,0,0), dots: false, main: ">_", mainMono: true, mainColor: green, mainSize: 220, mainDY: 0, sub: nil, subColor: green, subSize: 110, subDY: 0),
    Spec(name: "07-gray-stone",    c1: (0.42,0.45,0.50), c2: (0.42,0.45,0.50), dots: false, main: ">_", mainMono: true, mainColor: (0.07,0.07,0.07), mainSize: 200, mainDY: 0, sub: nil, subColor: green, subSize: 110, subDY: 0),
    Spec(name: "08-moai",          c1: dark, c2: dark, dots: false, main: "🗿", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30, sub: ">_", subColor: green, subSize: 110, subDY: -170),
    Spec(name: "09-mountain",      c1: (0.06,0.08,0.10), c2: (0.06,0.08,0.10), dots: false, main: "⛰️", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30, sub: ">_", subColor: green, subSize: 110, subDY: -170),
    Spec(name: "10-gem",           c1: (0.06,0.06,0.08), c2: (0.06,0.06,0.08), dots: false, main: "💎", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30, sub: ">_", subColor: (0.20,0.65,0.90), subSize: 110, subDY: -170),
    Spec(name: "11-blue-accent",   c1: (0.04,0.07,0.13), c2: (0.04,0.07,0.13), dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30, sub: ">_", subColor: (0.04,0.52,1.0), subSize: 110, subDY: -170),
    Spec(name: "12-amber",         c1: (0.10,0.07,0.02), c2: (0.10,0.07,0.02), dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30, sub: ">_", subColor: (1.0,0.69,0.0), subSize: 110, subDY: -170),
    Spec(name: "13-window-chrome", c1: (0.16,0.16,0.18), c2: (0.16,0.16,0.18), dots: true,  main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 250, mainDY: -10, sub: ">_", subColor: green, subSize: 100, subDY: -170),
    Spec(name: "14-green-bg",      c1: (0.12,0.54,0.24), c2: (0.12,0.54,0.24), dots: false, main: ">_", mainMono: true, mainColor: (1,1,1), mainSize: 220, mainDY: 0, sub: nil, subColor: green, subSize: 110, subDY: 0),
    Spec(name: "15-stone-bottom",  c1: (0.07,0.07,0.07), c2: (0.07,0.07,0.07), dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 230, mainDY: -120, sub: ">_", subColor: green, subSize: 110, subDY: 150),
    Spec(name: "16-split-grad",    c1: (0.23,0.25,0.28), c2: (0.07,0.07,0.07), dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 270, mainDY: 40, sub: ">_", subColor: green, subSize: 105, subDY: -165),
    Spec(name: "17-cursor-block",  c1: (0.07,0.07,0.07), c2: (0.07,0.07,0.07), dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 270, mainDY: 20, sub: "▍", subColor: green, subSize: 190, subDY: -160),
    Spec(name: "18-prompt-stone",  c1: (0.07,0.07,0.07), c2: (0.07,0.07,0.07), dots: false, main: ">🪨", mainMono: false, mainColor: green, mainSize: 220, mainDY: 0, sub: nil, subColor: green, subSize: 110, subDY: 0),
    Spec(name: "19-purple",        c1: (0.10,0.06,0.19), c2: (0.16,0.10,0.29), dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30, sub: ">_", subColor: (0.75,0.35,0.95), subSize: 110, subDY: -170),
    Spec(name: "20-teal",          c1: (0.02,0.16,0.18), c2: (0.02,0.16,0.18), dots: false, main: "🪨", mainMono: false, mainColor: (1,1,1), mainSize: 280, mainDY: 30, sub: ">_", subColor: (0.39,0.82,0.80), subSize: 110, subDY: -170),
]

func color(_ c: RGB) -> NSColor { NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: 1) }

func draw(_ s: Spec) -> NSImage {
    let size = 512
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    // 背景渐变
    let g = NSGradient(starting: color(s.c1), ending: color(s.c2))!
    g.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: 90)

    // 终端窗口红黄绿点
    if s.dots {
        let cols: [RGB] = [(1.0,0.37,0.34), (1.0,0.74,0.18), (0.20,0.78,0.35)]
        for (i, c) in cols.enumerated() {
            color(c).setFill()
            let x = 44 + CGFloat(i) * 52
            NSBezierPath(ovalIn: NSRect(x: x, y: CGFloat(size) - 76, width: 34, height: 34)).fill()
        }
    }

    // 主图形
    let mainFont: NSFont = s.mainMono
        ? NSFont.monospacedSystemFont(ofSize: s.mainSize, weight: .bold)
        : NSFont.systemFont(ofSize: s.mainSize)
    var attrs: [NSAttributedString.Key: Any] = [.font: mainFont]
    if s.mainMono { attrs[.foregroundColor] = color(s.mainColor) }
    let mainStr = NSAttributedString(string: s.main, attributes: attrs)
    let mb = mainStr.size()
    mainStr.draw(at: NSPoint(x: (CGFloat(size) - mb.width) / 2,
                             y: (CGFloat(size) - mb.height) / 2 + s.mainDY))

    // 底部 prompt
    if let sub = s.sub {
        let subStr = NSAttributedString(
            string: sub,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: s.subSize, weight: .bold),
                         .foregroundColor: color(s.subColor)])
        let sb = subStr.size()
        subStr.draw(at: NSPoint(x: (CGFloat(size) - sb.width) / 2,
                                y: (CGFloat(size) - sb.height) / 2 + s.subDY))
    }

    img.unlockFocus()
    return img
}

var htmlRows = ""
for s in specs {
    let img = draw(s)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    let file = "\(s.name).png"
    try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(file)"))
    htmlRows += "<div style=\"text-align:center\"><img src=\"\(file)\" width=\"160\" style=\"border-radius:24px\"><p style=\"margin:6px 0 20px\">\(s.name)</p></div>\n"
}

let html = """
<html><head><meta charset="utf-8"><title>stonemux icon 候选</title></head>
<body style="background:#151517;color:#eee;font-family:-apple-system,sans-serif;padding:32px">
<h1>stonemux icon 候选（选个编号告诉我）</h1>
<div style="display:grid;grid-template-columns:repeat(5,1fr);gap:20px;max-width:1000px">
\(htmlRows)
</div></body></html>
"""
try? html.write(to: URL(fileURLWithPath: "\(outDir)/gallery.html"), atomically: true, encoding: .utf8)
print("done: \(outDir)/gallery.html")
