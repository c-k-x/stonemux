import AppKit

// 第二弹：手绘 low-poly 石头（告别 🪨 emoji）+ 少量纯文字极简款
// 用法: swift scripts/make-icons2.swift <输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-icons2"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

typealias RGB = (CGFloat, CGFloat, CGFloat)
func color(_ c: RGB) -> NSColor { NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: 1) }

// 石头色板：[顶面亮, 右面中, 左面中暗, 底面暗]
let cool:  [RGB] = [(0.65,0.68,0.72), (0.47,0.51,0.56), (0.34,0.37,0.41), (0.22,0.24,0.27)]
let warm:  [RGB] = [(0.72,0.66,0.58), (0.55,0.49,0.42), (0.40,0.35,0.30), (0.27,0.24,0.20)]
let moss:  [RGB] = [(0.60,0.72,0.60), (0.43,0.55,0.43), (0.31,0.40,0.31), (0.21,0.27,0.21)]
let blue:  [RGB] = [(0.60,0.71,0.84), (0.43,0.55,0.68), (0.31,0.40,0.51), (0.21,0.27,0.35)]

let green: RGB = (0.30, 0.85, 0.40)
let dark: RGB = (0.11, 0.11, 0.13)

struct Spec {
    let name: String
    let c1: RGB; let c2: RGB
    let dots: Bool
    let stone: [RGB]?          // nil = 不画石头
    let stoneSize: CGFloat     // 石头盒宽度
    let stoneDY: CGFloat
    let main: String?          // 无石头时的主文字
    let mainColor: RGB
    let mainSize: CGFloat
    let sub: String?
    let subColor: RGB
    let subSize: CGFloat
}

let specs: [Spec] = [
    Spec(name: "21-stone-green",   c1: dark, c2: dark, dots: false, stone: cool, stoneSize: 300, stoneDY: 40,  main: nil,  mainColor: (1,1,1), mainSize: 0,   sub: ">_", subColor: green, subSize: 105),
    Spec(name: "22-stone-window",  c1: (0.16,0.16,0.18), c2: (0.16,0.16,0.18), dots: true, stone: cool, stoneSize: 270, stoneDY: 10, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: green, subSize: 95),
    Spec(name: "23-stone-grad",    c1: (0.05,0.16,0.10), c2: (0.07,0.23,0.13), dots: false, stone: cool, stoneSize: 290, stoneDY: 40, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: (0.85,1,0.9), subSize: 100),
    Spec(name: "24-stone-blue",    c1: (0.04,0.07,0.13), c2: (0.04,0.07,0.13), dots: false, stone: cool, stoneSize: 300, stoneDY: 40, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: (0.04,0.52,1.0), subSize: 105),
    Spec(name: "25-stone-amber",   c1: (0.10,0.07,0.02), c2: (0.10,0.07,0.02), dots: false, stone: warm, stoneSize: 300, stoneDY: 40, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: (1.0,0.69,0.0), subSize: 105),
    Spec(name: "26-stone-only",    c1: dark, c2: dark, dots: false, stone: cool, stoneSize: 360, stoneDY: 0,  main: nil, mainColor: (1,1,1), mainSize: 0, sub: nil,  subColor: green, subSize: 0),
    Spec(name: "27-stone-paper",   c1: (0.95,0.94,0.92), c2: (0.95,0.94,0.92), dots: false, stone: cool, stoneSize: 290, stoneDY: 40, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: (0.1,0.1,0.1), subSize: 100),
    Spec(name: "28-stone-purple",  c1: (0.10,0.06,0.19), c2: (0.16,0.10,0.29), dots: false, stone: cool, stoneSize: 300, stoneDY: 40, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: (0.75,0.35,0.95), subSize: 105),
    Spec(name: "29-stone-teal",    c1: (0.02,0.16,0.18), c2: (0.02,0.16,0.18), dots: false, stone: moss, stoneSize: 300, stoneDY: 40, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: (0.39,0.82,0.80), subSize: 105),
    Spec(name: "30-stone-moss",    c1: (0.06,0.10,0.06), c2: (0.09,0.15,0.09), dots: false, stone: moss, stoneSize: 300, stoneDY: 40, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: (0.7,0.9,0.7), subSize: 105),
    Spec(name: "31-stone-warm",    c1: dark, c2: dark, dots: false, stone: warm, stoneSize: 300, stoneDY: 40, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: green, subSize: 105),
    Spec(name: "32-stone-blueton", c1: dark, c2: dark, dots: false, stone: blue, stoneSize: 300, stoneDY: 40, main: nil, mainColor: (1,1,1), mainSize: 0, sub: ">_", subColor: green, subSize: 105),
    Spec(name: "33-minimal-s",     c1: (0,0,0), c2: (0,0,0), dots: false, stone: nil, stoneSize: 0, stoneDY: 0, main: "S",  mainColor: (0.95,0.95,0.95), mainSize: 320, sub: nil, subColor: green, subSize: 0),
    Spec(name: "34-minimal-prompt",c1: (0,0,0), c2: (0,0,0), dots: false, stone: nil, stoneSize: 0, stoneDY: 0, main: ">_", mainColor: green, mainSize: 220, sub: nil, subColor: green, subSize: 0),
    Spec(name: "35-minimal-gray",  c1: (0.42,0.45,0.50), c2: (0.42,0.45,0.50), dots: false, stone: nil, stoneSize: 0, stoneDY: 0, main: ">_", mainColor: (0.07,0.07,0.07), mainSize: 200, sub: nil, subColor: green, subSize: 0),
    Spec(name: "36-minimal-green", c1: (0.12,0.54,0.24), c2: (0.12,0.54,0.24), dots: false, stone: nil, stoneSize: 0, stoneDY: 0, main: ">_", mainColor: (1,1,1), mainSize: 220, sub: nil, subColor: green, subSize: 0),
]

/// low-poly 石头：4 个切面 + 高光
func drawStone(_ pal: [RGB], box: CGRect) {
    func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: box.minX + x * box.width, y: box.minY + (1 - y) * box.height)
    }
    let p0 = pt(0.02, 0.62), p1 = pt(0.16, 0.22), p2 = pt(0.48, 0.02)
    let p3 = pt(0.86, 0.20), p4 = pt(0.98, 0.60), p5 = pt(0.78, 0.98)
    let p6 = pt(0.24, 0.98), c  = pt(0.52, 0.52)

    func fill(_ pts: [NSPoint], _ col: RGB) {
        let path = NSBezierPath()
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.line(to: p) }
        path.close()
        color(col).setFill()
        path.fill()
    }

    fill([p1, p2, p3, c], pal[0])       // 顶面（亮）
    fill([p3, p4, p5, c], pal[1])       // 右面（中）
    fill([p0, p1, c],     pal[2])       // 左面（中暗）
    fill([c, p5, p6, p0], pal[3])       // 底面（暗）

    // 顶面高光
    let h = NSBezierPath()
    h.move(to: pt(0.30, 0.16)); h.line(to: pt(0.46, 0.10)); h.line(to: pt(0.40, 0.26)); h.close()
    NSColor.white.withAlphaComponent(0.35).setFill()
    h.fill()
}

func draw(_ s: Spec) -> NSImage {
    let size = 512
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    let g = NSGradient(starting: color(s.c1), ending: color(s.c2))!
    g.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: 90)

    if s.dots {
        let cols: [RGB] = [(1.0,0.37,0.34), (1.0,0.74,0.18), (0.20,0.78,0.35)]
        for (i, c) in cols.enumerated() {
            color(c).setFill()
            NSBezierPath(ovalIn: NSRect(x: 44 + CGFloat(i) * 52, y: CGFloat(size) - 76, width: 34, height: 34)).fill()
        }
    }

    if let pal = s.stone {
        let w = s.stoneSize
        let h = w * 0.85
        drawStone(pal, box: CGRect(x: (512 - w) / 2, y: (512 - h) / 2 + s.stoneDY, width: w, height: h))
    }

    if let main = s.main {
        let str = NSAttributedString(
            string: main,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: s.mainSize, weight: .bold),
                         .foregroundColor: color(s.mainColor)])
        let b = str.size()
        str.draw(at: NSPoint(x: (512 - b.width) / 2, y: (512 - b.height) / 2))
    }

    if let sub = s.sub {
        let str = NSAttributedString(
            string: sub,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: s.subSize, weight: .bold),
                         .foregroundColor: color(s.subColor)])
        let b = str.size()
        str.draw(at: NSPoint(x: (512 - b.width) / 2, y: 70))
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
<html><head><meta charset="utf-8"><title>stonemux icon 候选 v2</title></head>
<body style="background:#151517;color:#eee;font-family:-apple-system,sans-serif;padding:32px">
<h1>stonemux icon v2 —— 手绘 low-poly 石头（选编号）</h1>
<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:20px;max-width:900px">
\(htmlRows)
</div></body></html>
"""
try? html.write(to: URL(fileURLWithPath: "\(outDir)/gallery.html"), atomically: true, encoding: .utf8)
print("done: \(outDir)/gallery.html")
