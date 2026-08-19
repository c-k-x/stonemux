import AppKit

// 第四弹：线稿 wireframe 石头 ×20（用户选中风格）
// 用法: swift scripts/make-lineart.swift <输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-lineart"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

typealias P = (CGFloat, CGFloat)
let offwhite: (CGFloat, CGFloat, CGFloat) = (0.90, 0.91, 0.92)
let green: (CGFloat, CGFloat, CGFloat) = (0.30, 0.85, 0.40)
let dark: (CGFloat, CGFloat, CGFloat) = (0.16, 0.17, 0.19)

struct Art {
    let sil: [[P]]                    // 闭合轮廓（可多个）
    let ovals: [(CGFloat, CGFloat, CGFloat, CGFloat)]
    let inner: [[P]]                // 内部开放折线
}

let arts: [Art] = [
    Art(sil: [[(0.02,0.62),(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.24,0.98)]], ovals: [],
        inner: [[(0.50,0.52),(0.16,0.22)],[(0.50,0.52),(0.86,0.20)],[(0.50,0.52),(0.50,0.98)]]),
    Art(sil: [], ovals: [(0.05,0.15,0.90,0.80)],
        inner: [[(0.22,0.34),(0.40,0.26),(0.60,0.30)]]),
    Art(sil: [[(0.35,0.0),(0.62,0.35),(0.70,1.0),(0.30,1.0),(0.20,0.45)]], ovals: [],
        inner: [[(0.35,0.0),(0.45,0.5),(0.30,1.0)],[(0.45,0.5),(0.62,0.35)]]),
    Art(sil: [], ovals: [(0.10,0.62,0.80,0.36),(0.18,0.38,0.64,0.30),(0.28,0.12,0.44,0.28)],
        inner: []),
    Art(sil: [[(0.25,0.05),(0.75,0.05),(0.95,0.35),(0.5,0.95),(0.05,0.35)]], ovals: [],
        inner: [[(0.05,0.35),(0.95,0.35)],[(0.25,0.05),(0.5,0.35),(0.75,0.05)],[(0.5,0.35),(0.5,0.95)]]),
    Art(sil: [[(0.5,0.02),(0.93,0.26),(0.93,0.72),(0.5,0.98),(0.07,0.72),(0.07,0.26)]], ovals: [],
        inner: [[(0.07,0.26),(0.5,0.5),(0.93,0.26)],[(0.5,0.5),(0.5,0.98)]]),
    Art(sil: [[(0.05,0.95),(0.30,0.15),(0.44,0.55),(0.68,0.05),(0.95,0.95)]], ovals: [],
        inner: [[(0.30,0.15),(0.36,0.95)],[(0.68,0.05),(0.62,0.95)]]),
    Art(sil: [[(0.02,0.55),(0.20,0.25),(0.75,0.18),(0.98,0.50),(0.80,0.85),(0.15,0.85)]], ovals: [],
        inner: [[(0.20,0.25),(0.55,0.45),(0.75,0.18)],[(0.55,0.45),(0.5,0.85)]]),
    Art(sil: [[(0.30,0.05),(0.70,0.02),(0.72,0.98),(0.28,0.98)]], ovals: [],
        inner: [[(0.44,0.03),(0.44,0.98)]]),
    Art(sil: [[(0.15,0.95),(0.28,0.30),(0.38,0.60),(0.52,0.05),(0.66,0.55),(0.78,0.40),(0.90,0.95)]], ovals: [],
        inner: [[(0.28,0.30),(0.34,0.95)],[(0.52,0.05),(0.52,0.95)],[(0.78,0.40),(0.74,0.95)]]),
    Art(sil: [], ovals: [(0.06,0.10,0.88,0.85)],
        inner: [[(0.35,0.45),(0.5,0.6),(0.45,0.8)]]),
    Art(sil: [[(0.2,0.2),(0.8,0.2),(0.95,0.45),(0.5,0.98),(0.05,0.45)]], ovals: [],
        inner: [[(0.05,0.45),(0.95,0.45)],[(0.35,0.45),(0.5,0.98)],[(0.65,0.45),(0.5,0.98)],[(0.35,0.45),(0.2,0.2)],[(0.65,0.45),(0.8,0.2)]]),
    Art(sil: [[(0.02,0.62),(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.24,0.98)]], ovals: [],
        inner: [[(0.10,0.35),(0.3,0.28),(0.5,0.34),(0.7,0.27),(0.9,0.34)],[(0.5,0.55),(0.5,0.98)]]),
    Art(sil: [[(0.1,0.5),(0.3,0.1),(0.75,0.05),(0.92,0.55),(0.6,0.95),(0.2,0.9)]], ovals: [],
        inner: [[(0.3,0.1),(0.5,0.4),(0.6,0.95)],[(0.4,0.2),(0.62,0.16)]]),
    Art(sil: [], ovals: [(0.08,0.55,0.84,0.40),(0.12,0.32,0.76,0.34),(0.20,0.10,0.60,0.30)],
        inner: []),
    Art(sil: [[(0.1,0.4),(0.3,0.08),(0.75,0.05),(0.95,0.5),(0.7,0.95),(0.25,0.9)]], ovals: [(0.46,0.38,0.10,0.10)],
        inner: [[(0.28,0.42),(0.4,0.22),(0.68,0.2),(0.78,0.5),(0.6,0.75),(0.38,0.72),(0.28,0.42)]]),
    Art(sil: [[(0.05,0.6),(0.2,0.2),(0.5,0.05),(0.85,0.2),(0.95,0.6),(0.75,0.95),(0.25,0.95)]], ovals: [],
        inner: [[(0.2,0.2),(0.5,0.5),(0.85,0.2)],[(0.5,0.5),(0.5,0.95)]]),
    Art(sil: [[(0.5,0.02),(0.9,0.25),(0.95,0.7),(0.55,0.98),(0.45,0.98),(0.05,0.7),(0.1,0.25)]], ovals: [],
        inner: [[(0.1,0.25),(0.5,0.45),(0.9,0.25)],[(0.5,0.45),(0.45,0.98)],[(0.5,0.45),(0.55,0.98)]]),
    Art(sil: [[(0.0,0.6),(0.12,0.25),(0.4,0.1),(0.62,0.3),(0.68,0.7),(0.5,0.95),(0.1,0.95)],
              [(0.7,0.75),(0.78,0.5),(0.95,0.55),(0.98,0.85),(0.85,0.98)]], ovals: [],
        inner: [[(0.12,0.25),(0.45,0.4),(0.62,0.3)]]),
    Art(sil: [[(0.05,0.95),(0.1,0.2),(0.5,0.02),(0.9,0.2),(0.95,0.95),(0.68,0.95),(0.66,0.55),(0.5,0.4),(0.34,0.55),(0.32,0.95)]], ovals: [],
        inner: []),
]

let names = ["classic","pebble","shard","cairn","hexgem","isocube","twinpeaks","flatwide",
             "monolith","crystals","boulder","brilliant","mossy","obsidian","strata","geode",
             "lineart","sixfacet","pair","arch"]

func drawArt(_ a: Art, size: Int, lineColor: (CGFloat, CGFloat, CGFloat),
             bg: (CGFloat, CGFloat, CGFloat), dots: Bool, prompt: String?) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    NSColor(calibratedRed: bg.0, green: bg.1, blue: bg.2, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    if dots {
        let cols: [(CGFloat,CGFloat,CGFloat)] = [(1.0,0.37,0.34), (1.0,0.74,0.18), (0.20,0.78,0.35)]
        for (i, cc) in cols.enumerated() {
            NSColor(calibratedRed: cc.0, green: cc.1, blue: cc.2, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: CGFloat(size) * 0.09 + CGFloat(i) * CGFloat(size) * 0.10,
                                        y: CGFloat(size) * 0.85,
                                        width: CGFloat(size) * 0.065, height: CGFloat(size) * 0.065)).fill()
        }
    }

    let S = CGFloat(size)
    let box = CGRect(x: S * 0.14, y: S * 0.14, width: S * 0.72, height: S * 0.72)
    func pt(_ p: P) -> NSPoint {
        NSPoint(x: box.minX + p.0 * box.width, y: box.minY + (1 - p.1) * box.height)
    }
    let lc = NSColor(calibratedRed: lineColor.0, green: lineColor.1, blue: lineColor.2, alpha: 1)
    lc.setStroke()
    let lw = S * 0.045

    for poly in a.sil {
        let path = NSBezierPath()
        path.move(to: pt(poly[0]))
        for p in poly.dropFirst() { path.line(to: pt(p)) }
        path.close()
        path.lineWidth = lw
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }
    for (x, y, w, h) in a.ovals {
        let r = NSRect(x: box.minX + x * box.width, y: box.minY + (1 - y - h) * box.height,
                       width: w * box.width, height: h * box.height)
        let path = NSBezierPath(ovalIn: r)
        path.lineWidth = lw
        path.stroke()
    }
    for poly in a.inner {
        let path = NSBezierPath()
        path.move(to: pt(poly[0]))
        for p in poly.dropFirst() { path.line(to: pt(p)) }
        path.lineWidth = lw
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }

    if let prompt {
        let str = NSAttributedString(
            string: prompt,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: S * 0.16, weight: .bold),
                         .foregroundColor: NSColor(calibratedRed: green.0, green: green.1, blue: green.2, alpha: 1)])
        let b = str.size()
        str.draw(at: NSPoint(x: (S - b.width) / 2, y: S * 0.06))
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

var htmlRows = ""
for i in 0..<20 {
    let a = arts[i]
    png(drawArt(a, size: 512, lineColor: offwhite, bg: dark, dots: false, prompt: nil), "\(outDir)/\(i+1)-stone.png")
    png(drawArt(a, size: 512, lineColor: offwhite, bg: (0.11,0.11,0.13), dots: false, prompt: ">_"), "\(outDir)/\(i+1)-A.png")
    png(drawArt(a, size: 512, lineColor: green, bg: dark, dots: true, prompt: nil), "\(outDir)/\(i+1)-B.png")
    htmlRows += """
    <div style="text-align:center">
      <p style="margin:14px 0 8px;font-weight:600">\(String(format: "%02d", i+1)) \(names[i])</p>
      <img src="\(i+1)-stone.png" width="130" style="border-radius:20px">
      <img src="\(i+1)-A.png" width="130" style="border-radius:20px">
      <img src="\(i+1)-B.png" width="130" style="border-radius:20px">
      <p style="margin:6px 0 18px;color:#888">线稿 / A +prompt / B 绿线+窗口</p>
    </div>
    """
}

let html = """
<html><head><meta charset="utf-8"><title>stonemux 线稿石头选型</title></head>
<body style="background:#151517;color:#eee;font-family:-apple-system,sans-serif;padding:32px">
<h1>线稿风格 ×20 —— 选编号 + 变体（stone/A/B）</h1>
<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px;max-width:1100px">
\(htmlRows)
</div></body></html>
"""
try? html.write(to: URL(fileURLWithPath: "\(outDir)/gallery.html"), atomically: true, encoding: .utf8)
print("done: \(outDir)/gallery.html")
