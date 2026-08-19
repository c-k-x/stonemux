import AppKit

// 第三弹：先定石头。20 种手绘石头 × 2 种图标构图。
// 用法: swift scripts/make-stones.swift <输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-stones"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

typealias RGB = (CGFloat, CGFloat, CGFloat)
func color(_ c: RGB, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: a)
}

let cool: [RGB] = [(0.72,0.75,0.80), (0.50,0.54,0.60), (0.36,0.39,0.44), (0.23,0.25,0.28)]
let warm: [RGB] = [(0.78,0.71,0.62), (0.58,0.52,0.45), (0.42,0.37,0.31), (0.28,0.25,0.21)]
let moss: [RGB] = [(0.66,0.78,0.66), (0.47,0.59,0.47), (0.34,0.44,0.34), (0.22,0.29,0.22)]
let blue: [RGB] = [(0.66,0.77,0.90), (0.47,0.60,0.74), (0.34,0.44,0.56), (0.22,0.29,0.38)]
let palettes: [[RGB]] = [cool, warm, moss, blue]

let green: RGB = (0.30, 0.85, 0.40)
let dark: RGB = (0.11, 0.11, 0.13)

struct Ctx {
    let pal: [RGB]
    let box: CGRect
    func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: box.minX + x * box.width, y: box.minY + (1 - y) * box.height)
    }
    func poly(_ pts: [(CGFloat, CGFloat)], _ shade: Int, alpha: CGFloat = 1) {
        let path = NSBezierPath()
        path.move(to: pt(pts[0].0, pts[0].1))
        for p in pts.dropFirst() { path.line(to: pt(p.0, p.1)) }
        path.close()
        color(pal[shade], alpha).setFill()
        path.fill()
    }
    func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ shade: Int, alpha: CGFloat = 1) {
        let r = NSRect(x: box.minX + x * box.width, y: box.minY + (1 - y - h) * box.height,
                       width: w * box.width, height: h * box.height)
        NSBezierPath(ovalIn: r).fill()
        _ = shade
    }
    func ovalC(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: RGB, _ a: CGFloat) {
        let r = NSRect(x: box.minX + x * box.width, y: box.minY + (1 - y - h) * box.height,
                       width: w * box.width, height: h * box.height)
        color(c, a).setFill()
        NSBezierPath(ovalIn: r).fill()
    }
    func line(_ pts: [(CGFloat, CGFloat)], _ c: RGB, _ w: CGFloat) {
        let path = NSBezierPath()
        path.move(to: pt(pts[0].0, pts[0].1))
        for p in pts.dropFirst() { path.line(to: pt(p.0, p.1)) }
        path.lineWidth = w
        color(c).setStroke()
        path.stroke()
    }
}

/// 20 种石头
func drawStone(_ v: Int, pal: [RGB], box: CGRect) {
    let c = Ctx(pal: pal, box: box)
    switch v {
    case 1: // 经典 4 切面
        c.poly([(0.02,0.62),(0.16,0.22),(0.52,0.52)], 2)
        c.poly([(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.52,0.52)], 0)
        c.poly([(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.52,0.52)], 1)
        c.poly([(0.52,0.52),(0.78,0.98),(0.24,0.98),(0.02,0.62)], 3)
        c.poly([(0.30,0.16),(0.46,0.10),(0.40,0.26)], 0, alpha: 0.5)
    case 2: // 圆润鹅卵石
        c.ovalC(0.05, 0.15, 0.90, 0.80, pal[2], 1)
        c.ovalC(0.10, 0.15, 0.80, 0.45, pal[0], 1)
        c.ovalC(0.22, 0.22, 0.28, 0.14, (1,1,1), 0.45)
    case 3: // 尖锐碎片
        c.poly([(0.35,0.0),(0.62,0.35),(0.45,0.5)], 0)
        c.poly([(0.35,0.0),(0.45,0.5),(0.20,0.45)], 2)
        c.poly([(0.20,0.45),(0.45,0.5),(0.62,0.35),(0.70,1.0),(0.30,1.0)], 3)
        c.poly([(0.62,0.35),(0.45,0.5),(0.70,1.0)], 1)
    case 4: // 叠石 cairn
        c.ovalC(0.10, 0.62, 0.80, 0.36, pal[3], 1)
        c.ovalC(0.18, 0.38, 0.64, 0.30, pal[1], 1)
        c.ovalC(0.28, 0.12, 0.44, 0.28, pal[0], 1)
        c.ovalC(0.34, 0.16, 0.16, 0.08, (1,1,1), 0.4)
    case 5: // 六方宝石切
        c.poly([(0.25,0.05),(0.75,0.05),(0.95,0.35),(0.5,0.35)], 0)
        c.poly([(0.05,0.35),(0.25,0.05),(0.5,0.35)], 1)
        c.poly([(0.95,0.35),(0.75,0.05),(0.5,0.35)], 1)
        c.poly([(0.05,0.35),(0.5,0.35),(0.5,0.95)], 2)
        c.poly([(0.5,0.35),(0.95,0.35),(0.5,0.95)], 3)
    case 6: // 等距立方
        c.poly([(0.5,0.02),(0.93,0.26),(0.5,0.50),(0.07,0.26)], 0)
        c.poly([(0.07,0.26),(0.5,0.50),(0.5,0.98),(0.07,0.72)], 2)
        c.poly([(0.5,0.50),(0.93,0.26),(0.93,0.72),(0.5,0.98)], 3)
    case 7: // 双峰
        c.poly([(0.05,0.95),(0.30,0.15),(0.48,0.95)], 1)
        c.poly([(0.30,0.15),(0.48,0.95),(0.38,0.95)], 3)
        c.poly([(0.40,0.95),(0.68,0.05),(0.95,0.95)], 0)
        c.poly([(0.68,0.05),(0.95,0.95),(0.80,0.95)], 2)
    case 8: // 扁宽石
        c.poly([(0.02,0.55),(0.20,0.25),(0.55,0.45)], 0)
        c.poly([(0.20,0.25),(0.75,0.18),(0.98,0.50),(0.55,0.45)], 0)
        c.poly([(0.02,0.55),(0.55,0.45),(0.98,0.50),(0.80,0.85),(0.15,0.85)], 3)
    case 9: // 独石 monolith
        c.poly([(0.30,0.05),(0.70,0.02),(0.72,0.98),(0.28,0.98)], 1)
        c.poly([(0.30,0.05),(0.45,0.03),(0.44,0.98),(0.28,0.98)], 0)
        c.poly([(0.70,0.02),(0.72,0.98),(0.60,0.98),(0.58,0.04)], 3)
    case 10: // 水晶簇
        c.poly([(0.15,0.95),(0.28,0.30),(0.40,0.95)], 2)
        c.poly([(0.35,0.95),(0.52,0.05),(0.68,0.95)], 0)
        c.poly([(0.52,0.05),(0.68,0.95),(0.58,0.95)], 1)
        c.poly([(0.62,0.95),(0.78,0.40),(0.90,0.95)], 1)
    case 11: // 圆石+裂纹
        c.ovalC(0.06, 0.10, 0.88, 0.85, pal[1], 1)
        c.ovalC(0.14, 0.14, 0.5, 0.3, pal[0], 1)
        c.line([(0.35,0.45),(0.5,0.6),(0.45,0.8)], pal[3], box.width * 0.03)
    case 12: // 明亮式切割
        c.poly([(0.2,0.2),(0.8,0.2),(0.95,0.45),(0.05,0.45)], 0)
        c.poly([(0.05,0.45),(0.95,0.45),(0.5,0.98)], 2)
        c.poly([(0.35,0.45),(0.65,0.45),(0.5,0.98)], 1)
        c.line([(0.2,0.2),(0.35,0.45)], (1,1,1), box.width * 0.02)
    case 13: // 苔藓顶
        c.poly([(0.02,0.62),(0.16,0.22),(0.52,0.52)], 2)
        c.poly([(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.52,0.52)], 1)
        c.poly([(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.52,0.52)], 2)
        c.poly([(0.52,0.52),(0.78,0.98),(0.24,0.98),(0.02,0.62)], 3)
        c.poly([(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.5,0.3)], 0) // 苔帽用亮色
    case 14: // 黑曜石
        c.poly([(0.1,0.5),(0.3,0.1),(0.75,0.05),(0.92,0.55),(0.6,0.95),(0.2,0.9)], 3)
        c.poly([(0.3,0.1),(0.75,0.05),(0.6,0.4),(0.35,0.4)], 1)
        c.line([(0.38,0.18),(0.66,0.14)], (1,1,1), box.width * 0.05)
    case 15: // 层岩 strata
        c.ovalC(0.08, 0.55, 0.84, 0.40, pal[3], 1)
        c.ovalC(0.12, 0.32, 0.76, 0.34, pal[1], 1)
        c.ovalC(0.20, 0.10, 0.60, 0.30, pal[0], 1)
    case 16: // 晶洞 geode
        c.poly([(0.1,0.4),(0.3,0.08),(0.75,0.05),(0.95,0.5),(0.7,0.95),(0.25,0.9)], 2)
        c.poly([(0.28,0.42),(0.4,0.22),(0.68,0.2),(0.78,0.5),(0.6,0.75),(0.38,0.72)], 0)
        c.ovalC(0.48, 0.35, 0.1, 0.1, (1,1,1), 0.8)
    case 17: // 线稿
        c.line([(0.05,0.6),(0.2,0.2),(0.5,0.05),(0.85,0.2),(0.95,0.6),(0.75,0.95),(0.25,0.95),(0.05,0.6)], (0.9,0.9,0.9), box.width * 0.04)
        c.line([(0.2,0.2),(0.5,0.5),(0.85,0.2)], (0.9,0.9,0.9), box.width * 0.03)
        c.line([(0.5,0.5),(0.5,0.95)], (0.9,0.9,0.9), box.width * 0.03)
    case 18: // 六面 low-poly
        c.poly([(0.5,0.02),(0.9,0.25),(0.5,0.45),(0.1,0.25)], 0)
        c.poly([(0.1,0.25),(0.5,0.45),(0.45,0.98),(0.05,0.7)], 2)
        c.poly([(0.5,0.45),(0.9,0.25),(0.95,0.7),(0.55,0.98)], 1)
        c.poly([(0.45,0.98),(0.5,0.45),(0.55,0.98)], 3)
    case 19: // 大石+小石
        c.poly([(0.0,0.6),(0.12,0.25),(0.4,0.1),(0.62,0.3),(0.68,0.7),(0.5,0.95),(0.1,0.95)], 1)
        c.poly([(0.12,0.25),(0.4,0.1),(0.45,0.4),(0.2,0.45)], 0)
        c.poly([(0.7,0.75),(0.78,0.5),(0.95,0.55),(0.98,0.85),(0.85,0.98)], 2)
    default: // 20 拱石
        let path = NSBezierPath()
        path.move(to: c.pt(0.05, 0.95)); path.line(to: c.pt(0.1, 0.2)); path.line(to: c.pt(0.5, 0.02))
        path.line(to: c.pt(0.9, 0.2)); path.line(to: c.pt(0.95, 0.95)); path.line(to: c.pt(0.68, 0.95))
        path.line(to: c.pt(0.66, 0.55)); path.line(to: c.pt(0.5, 0.4)); path.line(to: c.pt(0.34, 0.55))
        path.line(to: c.pt(0.32, 0.95)); path.close()
        color(pal[1]).setFill(); path.fill()
        c.poly([(0.1,0.2),(0.5,0.02),(0.5,0.25),(0.2,0.35)], 0)
    }
}

func makeImage(size: Int, bg1: RGB, bg2: RGB, dots: Bool, stone: Int, pal: [RGB],
               stoneW: CGFloat, stoneDY: CGFloat, prompt: String?, promptColor: RGB) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let g = NSGradient(starting: color(bg1), ending: color(bg2))!
    g.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: 90)
    if dots {
        let cols: [RGB] = [(1.0,0.37,0.34), (1.0,0.74,0.18), (0.20,0.78,0.35)]
        for (i, cc) in cols.enumerated() {
            color(cc).setFill()
            NSBezierPath(ovalIn: NSRect(x: CGFloat(size) * 0.09 + CGFloat(i) * CGFloat(size) * 0.10,
                                        y: CGFloat(size) * 0.85,
                                        width: CGFloat(size) * 0.065, height: CGFloat(size) * 0.065)).fill()
        }
    }
    let w = stoneW * CGFloat(size)
    let h = w * 0.9
    drawStone(stone, pal: pal,
              box: CGRect(x: (CGFloat(size) - w) / 2,
                          y: (CGFloat(size) - h) / 2 + stoneDY * CGFloat(size),
                          width: w, height: h))
    if let prompt {
        let str = NSAttributedString(
            string: prompt,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: CGFloat(size) * 0.21, weight: .bold),
                         .foregroundColor: color(promptColor)])
        let b = str.size()
        str.draw(at: NSPoint(x: (CGFloat(size) - b.width) / 2, y: CGFloat(size) * 0.12))
    }
    img.unlockFocus()
    return img
}

func png(_ img: NSImage, _ path: String) {
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let p = rep.representation(using: .png, properties: [:]) else { return }
    try? p.write(to: URL(fileURLWithPath: path))
}

let names = ["classic","pebble","shard","cairn","hexgem","isocube","twinpeaks","flatwide",
             "monolith","crystals","boulder","brilliant","mossy","obsidian","strata","geode",
             "lineart","sixfacet","pair","arch"]

var htmlRows = ""
for i in 1...20 {
    let pal = palettes[(i - 1) % 4]
    // 石头单看（中性深底）
    png(makeImage(size: 512, bg1: (0.16,0.16,0.18), bg2: (0.16,0.16,0.18), dots: false,
                  stone: i, pal: pal, stoneW: 0.62, stoneDY: 0, prompt: nil, promptColor: green),
        "\(outDir)/\(i)-stone.png")
    // 构图 A：深底 + 绿 prompt
    png(makeImage(size: 512, bg1: dark, bg2: dark, dots: false,
                  stone: i, pal: pal, stoneW: 0.56, stoneDY: 0.06, prompt: ">_", promptColor: green),
        "\(outDir)/\(i)-A.png")
    // 构图 B：终端窗口框 + 渐变底
    png(makeImage(size: 512, bg1: (0.13,0.20,0.15), bg2: (0.07,0.10,0.08), dots: true,
                  stone: i, pal: pal, stoneW: 0.52, stoneDY: 0.02, prompt: ">_", promptColor: (0.85,1,0.9)),
        "\(outDir)/\(i)-B.png")
    htmlRows += """
    <div style="text-align:center">
      <p style="margin:14px 0 8px;font-weight:600">\(String(format: "%02d", i)) \(names[i-1])</p>
      <img src="\(i)-stone.png" width="130" style="border-radius:20px">
      <img src="\(i)-A.png" width="130" style="border-radius:20px">
      <img src="\(i)-B.png" width="130" style="border-radius:20px">
      <p style="margin:6px 0 18px;color:#888">stone / A 深底 / B 窗口</p>
    </div>
    """
}

let html = """
<html><head><meta charset="utf-8"><title>stonemux 石头选型</title></head>
<body style="background:#151517;color:#eee;font-family:-apple-system,sans-serif;padding:32px">
<h1>20 种石头 × 2 种构图 —— 先选石头编号，再选构图 A/B</h1>
<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px;max-width:1100px">
\(htmlRows)
</div></body></html>
"""
try? html.write(to: URL(fileURLWithPath: "\(outDir)/gallery.html"), atomically: true, encoding: .utf8)
print("done: \(outDir)/gallery.html")
