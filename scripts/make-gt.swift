import AppKit

// 第六弹：石头里包含 ">" （参考 Ghostty）240 个，编号 501-740
// 20 石形 × 4 融合方式 × 3 配色(p0 终端绿 / p1 赛博青 / p4 优雅金)
// 用法: swift scripts/make-gt.swift <输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-500"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

typealias P = (CGFloat, CGFloat)
typealias RGB = (CGFloat, CGFloat, CGFloat)
func color(_ c: RGB, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: a)
}

struct Art { let sil: [[P]]; let ovals: [(CGFloat, CGFloat, CGFloat, CGFloat)]; let inner: [[P]] }

let arts: [Art] = [
    Art(sil: [[(0.02,0.62),(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.24,0.98)]], ovals: [],
        inner: [[(0.50,0.52),(0.16,0.22)],[(0.50,0.52),(0.86,0.20)],[(0.50,0.52),(0.50,0.98)]]),
    Art(sil: [], ovals: [(0.05,0.15,0.90,0.80)], inner: [[(0.22,0.34),(0.40,0.26),(0.60,0.30)]]),
    Art(sil: [[(0.35,0.0),(0.62,0.35),(0.70,1.0),(0.30,1.0),(0.20,0.45)]], ovals: [],
        inner: [[(0.35,0.0),(0.45,0.5),(0.30,1.0)],[(0.45,0.5),(0.62,0.35)]]),
    Art(sil: [], ovals: [(0.10,0.62,0.80,0.36),(0.18,0.38,0.64,0.30),(0.28,0.12,0.44,0.28)], inner: []),
    Art(sil: [[(0.25,0.05),(0.75,0.05),(0.95,0.35),(0.5,0.95),(0.05,0.35)]], ovals: [],
        inner: [[(0.05,0.35),(0.95,0.35)],[(0.25,0.05),(0.5,0.35),(0.75,0.05)],[(0.5,0.35),(0.5,0.95)]]),
    Art(sil: [[(0.5,0.02),(0.93,0.26),(0.93,0.72),(0.5,0.98),(0.07,0.72),(0.07,0.26)]], ovals: [],
        inner: [[(0.07,0.26),(0.5,0.5),(0.93,0.26)],[(0.5,0.5),(0.5,0.98)]]),
    Art(sil: [[(0.05,0.95),(0.30,0.15),(0.44,0.55),(0.68,0.05),(0.95,0.95)]], ovals: [],
        inner: [[(0.30,0.15),(0.36,0.95)],[(0.68,0.05),(0.62,0.95)]]),
    Art(sil: [[(0.02,0.55),(0.20,0.25),(0.75,0.18),(0.98,0.50),(0.80,0.85),(0.15,0.85)]], ovals: [],
        inner: [[(0.20,0.25),(0.55,0.45),(0.75,0.18)],[(0.55,0.45),(0.5,0.85)]]),
    Art(sil: [[(0.30,0.05),(0.70,0.02),(0.72,0.98),(0.28,0.98)]], ovals: [], inner: [[(0.44,0.03),(0.44,0.98)]]),
    Art(sil: [[(0.15,0.95),(0.28,0.30),(0.38,0.60),(0.52,0.05),(0.66,0.55),(0.78,0.40),(0.90,0.95)]], ovals: [],
        inner: [[(0.28,0.30),(0.34,0.95)],[(0.52,0.05),(0.52,0.95)],[(0.78,0.40),(0.74,0.95)]]),
    Art(sil: [], ovals: [(0.06,0.10,0.88,0.85)], inner: [[(0.35,0.45),(0.5,0.6),(0.45,0.8)]]),
    Art(sil: [[(0.2,0.2),(0.8,0.2),(0.95,0.45),(0.5,0.98),(0.05,0.45)]], ovals: [],
        inner: [[(0.05,0.45),(0.95,0.45)],[(0.35,0.45),(0.5,0.98)],[(0.65,0.45),(0.5,0.98)]]),
    Art(sil: [[(0.02,0.62),(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.24,0.98)]], ovals: [],
        inner: [[(0.10,0.35),(0.3,0.28),(0.5,0.34),(0.7,0.27),(0.9,0.34)],[(0.5,0.55),(0.5,0.98)]]),
    Art(sil: [[(0.1,0.5),(0.3,0.1),(0.75,0.05),(0.92,0.55),(0.6,0.95),(0.2,0.9)]], ovals: [],
        inner: [[(0.3,0.1),(0.5,0.4),(0.6,0.95)],[(0.4,0.2),(0.62,0.16)]]),
    Art(sil: [], ovals: [(0.08,0.55,0.84,0.40),(0.12,0.32,0.76,0.34),(0.20,0.10,0.60,0.30)], inner: []),
    Art(sil: [[(0.1,0.4),(0.3,0.08),(0.75,0.05),(0.95,0.5),(0.7,0.95),(0.25,0.9)]], ovals: [(0.46,0.38,0.10,0.10)],
        inner: [[(0.28,0.42),(0.4,0.22),(0.68,0.2),(0.78,0.5),(0.6,0.75),(0.38,0.72),(0.28,0.42)]]),
    Art(sil: [[(0.05,0.6),(0.2,0.2),(0.5,0.05),(0.85,0.2),(0.95,0.6),(0.75,0.95),(0.25,0.95)]], ovals: [],
        inner: [[(0.2,0.2),(0.5,0.5),(0.85,0.2)],[(0.5,0.5),(0.5,0.95)]]),
    Art(sil: [[(0.5,0.02),(0.9,0.25),(0.95,0.7),(0.55,0.98),(0.45,0.98),(0.05,0.7),(0.1,0.25)]], ovals: [],
        inner: [[(0.1,0.25),(0.5,0.45),(0.9,0.25)],[(0.5,0.45),(0.45,0.98)],[(0.5,0.45),(0.55,0.98)]]),
    Art(sil: [[(0.0,0.6),(0.12,0.25),(0.4,0.1),(0.62,0.3),(0.68,0.7),(0.5,0.95),(0.1,0.95)],
              [(0.7,0.75),(0.78,0.5),(0.95,0.55),(0.98,0.85),(0.85,0.98)]], ovals: [],
        inner: [[(0.12,0.25),(0.45,0.4),(0.62,0.3)]]),
    Art(sil: [[(0.05,0.95),(0.1,0.2),(0.5,0.02),(0.9,0.2),(0.95,0.95),(0.68,0.95),(0.66,0.55),(0.5,0.4),(0.34,0.55),(0.32,0.95)]], ovals: [], inner: []),
]
let shapeNames = ["classic","pebble","shard","cairn","hexgem","isocube","twinpeaks","flatwide",
                  "monolith","crystals","boulder","brilliant","mossy","obsidian","strata","geode",
                  "lineart","sixfacet","pair","arch"]

let palettes: [(RGB, RGB, RGB)] = [
    ((0.05,0.07,0.09), (0.90,0.93,0.95), (0.25,0.73,0.31)),   // p0 终端绿
    ((0.02,0.08,0.10), (0.61,0.84,0.96), (0.13,0.83,0.93)),   // p1 赛博青
    ((0.06,0.06,0.08), (0.83,0.69,0.22), (0.96,0.94,0.90)),   // p4 优雅金
]
let treatNames = ["gtwire", "gtaccent", "gtknock", "gtfacet"]

// ">" 形（盒子内坐标）
let gt: [P] = [(0.34,0.30),(0.62,0.50),(0.34,0.70)]

func ovalPoly(_ o: (CGFloat, CGFloat, CGFloat, CGFloat), _ n: Int = 20) -> [P] {
    var pts: [P] = []
    for i in 0..<n {
        let a = CGFloat(i) / CGFloat(n) * 2 * .pi
        pts.append((o.0 + o.2/2 + cos(a) * o.2/2, o.1 + o.3/2 + sin(a) * o.3/2))
    }
    return pts
}

func draw(_ a: Art, treat: Int, pal: (RGB, RGB, RGB), size: Int) -> NSImage {
    let S = CGFloat(size)
    let img = NSImage(size: NSSize(width: S, height: S))
    img.lockFocus()
    color(pal.0).setFill()
    NSRect(x: 0, y: 0, width: S, height: S).fill()

    let box = CGRect(x: S * 0.14, y: S * 0.14, width: S * 0.72, height: S * 0.72)
    func pt(_ p: P) -> NSPoint {
        NSPoint(x: box.minX + p.0 * box.width, y: box.minY + (1 - p.1) * box.height)
    }
    func path(_ poly: [P], close: Bool) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: pt(poly[0]))
        for q in poly.dropFirst() { p.line(to: pt(q)) }
        if close { p.close() }
        p.lineJoinStyle = .round; p.lineCapStyle = .round
        return p
    }
    var sils = a.sil
    for o in a.ovals { sils.append(ovalPoly(o)) }
    let lw = S * 0.045

    switch treat {
    case 0: // gtwire：线稿 + 线色 >
        color(pal.1).setStroke()
        for poly in sils { let p = path(poly, close: true); p.lineWidth = lw; p.stroke() }
        for line in a.inner { let p = path(line, close: false); p.lineWidth = lw * 0.7; p.stroke() }
        let g = path(gt, close: false); g.lineWidth = lw * 1.1; g.stroke()
    case 1: // gtaccent：纯轮廓 + 强调色粗 >
        color(pal.1).setStroke()
        for poly in sils { let p = path(poly, close: true); p.lineWidth = lw; p.stroke() }
        color(pal.2).setStroke()
        let g = path(gt, close: false); g.lineWidth = lw * 1.6; g.stroke()
    case 2: // gtknock：实心亮石 + 镂空白底 >
        for poly in sils {
            let p = path(poly, close: true)
            color(pal.1, 0.92).setFill(); p.fill()
        }
        color(pal.0).setStroke()
        let g = path(gt, close: false); g.lineWidth = lw * 1.7; g.stroke()
    default: // gtfacet：> 当切面线
        color(pal.1).setStroke()
        for poly in sils { let p = path(poly, close: true); p.lineWidth = lw; p.stroke() }
        let g = path(gt, close: false); g.lineWidth = lw; g.stroke()
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
var n = 500
for (si, a) in arts.enumerated() {
    for (ti, _) in treatNames.enumerated() {
        for (pi, _) in palettes.enumerated() {
            n += 1
            let code = String(format: "%03d", n)
            png(draw(a, treat: ti, pal: palettes[pi], size: 512), "\(outDir)/\(code).png")
            htmlRows += "<div style=\"text-align:center\"><img src=\"\(code).png\" width=\"96\" style=\"border-radius:14px\"><p style=\"margin:2px 0 10px;color:#888;font-size:11px\">\(code) \(shapeNames[si])·\(treatNames[ti])·p\(pi)</p></div>\n"
        }
    }
}

let html = """
<html><head><meta charset="utf-8"><title>stonemux 石头含&gt; 候选</title></head>
<body style="background:#151517;color:#eee;font-family:-apple-system,sans-serif;padding:24px">
<h1>501-740：石头里含 "&gt;"（参考 Ghostty）</h1>
<p style="color:#888">gtwire 线稿+线色&gt; / gtaccent 轮廓+强调粗&gt; / gtknock 实心镂空&gt; / gtfacet &gt;当切面 · p0 绿 p1 青 p4 金</p>
<div style="display:grid;grid-template-columns:repeat(10,1fr);gap:6px">
\(htmlRows)
</div></body></html>
"""
try? html.write(to: URL(fileURLWithPath: "\(outDir)/gallery-gt.html"), atomically: true, encoding: .utf8)
print("done: \(n - 500) gt icons -> \(outDir)/gallery-gt.html")
