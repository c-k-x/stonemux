import AppKit

// Round 3（终稿候选）：固化两轮评审全部硬约束
// 无 glow / 无条纹 / 无像素 / 无全息；每款必含 ">"；端点内含；叠石实遮挡；
// 线系统严格参数；同族色保护；narrow 用 gtSmall
// 规模 = 20石 × 6风格 × 5配色 - arch 限制 ≈ 580
// 用法: swift scripts/make-r3.swift <输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-r3"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

typealias P = (CGFloat, CGFloat)
typealias RGB = (CGFloat, CGFloat, CGFloat)
func color(_ c: RGB, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: a)
}
func mix(_ a: RGB, _ b: RGB, _ t: CGFloat) -> RGB {
    (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
}

struct Art { let sil: [[P]]; let ovals: [(CGFloat, CGFloat, CGFloat, CGFloat)]; let inner: [[P]]; let cairn: Bool; let narrow: Bool }

let arts: [Art] = [
    Art(sil: [[(0.02,0.62),(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.24,0.98)]], ovals: [],
        inner: [[(0.50,0.52),(0.16,0.22)],[(0.50,0.52),(0.86,0.20)],[(0.50,0.52),(0.50,0.98)]], cairn: false, narrow: false),
    Art(sil: [], ovals: [(0.05,0.15,0.90,0.80)], inner: [], cairn: false, narrow: false),
    Art(sil: [[(0.28,0.0),(0.66,0.30),(0.78,1.0),(0.26,1.0),(0.14,0.42)]], ovals: [],
        inner: [[(0.28,0.0),(0.46,0.48),(0.30,1.0)],[(0.46,0.48),(0.66,0.30)]], cairn: false, narrow: true),
    Art(sil: [], ovals: [(0.10,0.62,0.80,0.36),(0.18,0.38,0.64,0.30),(0.28,0.12,0.44,0.28)], inner: [], cairn: true, narrow: false),
    Art(sil: [[(0.25,0.05),(0.75,0.05),(0.95,0.35),(0.5,0.95),(0.05,0.35)]], ovals: [],
        inner: [[(0.05,0.35),(0.95,0.35)],[(0.5,0.35),(0.5,0.95)]], cairn: false, narrow: false),
    Art(sil: [[(0.5,0.02),(0.93,0.26),(0.93,0.72),(0.5,0.98),(0.07,0.72),(0.07,0.26)]], ovals: [],
        inner: [[(0.07,0.26),(0.5,0.5),(0.93,0.26)],[(0.5,0.5),(0.5,0.98)]], cairn: false, narrow: false),
    Art(sil: [[(0.05,0.95),(0.30,0.15),(0.44,0.55),(0.68,0.05),(0.95,0.95)]], ovals: [],
        inner: [[(0.30,0.15),(0.36,0.95)],[(0.68,0.05),(0.62,0.95)]], cairn: false, narrow: false),
    Art(sil: [[(0.02,0.55),(0.20,0.25),(0.75,0.18),(0.98,0.50),(0.80,0.85),(0.15,0.85)]], ovals: [],
        inner: [[(0.20,0.25),(0.55,0.45),(0.75,0.18)]], cairn: false, narrow: false),
    Art(sil: [[(0.24,0.05),(0.72,0.02),(0.76,0.98),(0.22,0.98)]], ovals: [], inner: [[(0.42,0.03),(0.42,0.98)]], cairn: false, narrow: true),
    Art(sil: [[(0.15,0.95),(0.28,0.30),(0.38,0.60),(0.52,0.05),(0.66,0.55),(0.78,0.40),(0.90,0.95)]], ovals: [],
        inner: [[(0.52,0.05),(0.52,0.95)],[(0.28,0.30),(0.34,0.95)]], cairn: false, narrow: false),
    Art(sil: [], ovals: [(0.06,0.10,0.88,0.85)], inner: [[(0.35,0.45),(0.5,0.6),(0.45,0.8)]], cairn: false, narrow: false),
    Art(sil: [[(0.2,0.2),(0.8,0.2),(0.95,0.45),(0.5,0.98),(0.05,0.45)]], ovals: [],
        inner: [[(0.05,0.45),(0.95,0.45)],[(0.35,0.45),(0.5,0.98)],[(0.65,0.45),(0.5,0.98)]], cairn: false, narrow: false),
    Art(sil: [[(0.02,0.62),(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.24,0.98)]], ovals: [],
        inner: [[(0.10,0.35),(0.3,0.28),(0.5,0.34),(0.7,0.27),(0.9,0.34)]], cairn: false, narrow: false),
    Art(sil: [[(0.1,0.5),(0.3,0.1),(0.75,0.05),(0.92,0.55),(0.6,0.95),(0.2,0.9)]], ovals: [],
        inner: [[(0.3,0.1),(0.5,0.4),(0.6,0.95)]], cairn: false, narrow: false),
    Art(sil: [], ovals: [(0.08,0.55,0.84,0.40),(0.12,0.32,0.76,0.34),(0.20,0.10,0.60,0.30)], inner: [], cairn: true, narrow: false),
    Art(sil: [[(0.1,0.4),(0.3,0.08),(0.75,0.05),(0.95,0.5),(0.7,0.95),(0.25,0.9)]], ovals: [],
        inner: [[(0.28,0.42),(0.4,0.22),(0.68,0.2),(0.78,0.5),(0.6,0.75),(0.38,0.72),(0.28,0.42)]], cairn: false, narrow: false),
    Art(sil: [[(0.05,0.6),(0.2,0.2),(0.5,0.05),(0.85,0.2),(0.95,0.6),(0.75,0.95),(0.25,0.95)]], ovals: [],
        inner: [[(0.2,0.2),(0.5,0.5),(0.85,0.2)],[(0.5,0.5),(0.5,0.95)]], cairn: false, narrow: false),
    Art(sil: [[(0.5,0.02),(0.9,0.25),(0.95,0.7),(0.55,0.98),(0.45,0.98),(0.05,0.7),(0.1,0.25)]], ovals: [],
        inner: [[(0.1,0.25),(0.5,0.45),(0.9,0.25)],[(0.5,0.45),(0.5,0.98)]], cairn: false, narrow: false),
    Art(sil: [[(0.0,0.6),(0.12,0.25),(0.4,0.1),(0.62,0.3),(0.64,0.7),(0.48,0.95),(0.1,0.95)],
              [(0.76,0.72),(0.82,0.5),(0.97,0.55),(0.99,0.85),(0.88,0.98)]], ovals: [],
        inner: [[(0.12,0.25),(0.45,0.4),(0.62,0.3)]], cairn: false, narrow: false),
    Art(sil: [[(0.05,0.95),(0.1,0.2),(0.5,0.02),(0.9,0.2),(0.95,0.95),(0.68,0.95),(0.66,0.55),(0.5,0.4),(0.34,0.55),(0.32,0.95)]], ovals: [], inner: [], cairn: false, narrow: false),
]
let shapeNames = ["classic","pebble","shard","cairn","hexgem","isocube","twinpeaks","flatwide",
                  "monolith","crystals","boulder","brilliant","mossy","obsidian","strata","geode",
                  "lineart","sixfacet","pair","arch"]

let palettes: [(RGB, RGB, RGB)] = [
    ((0.05,0.07,0.09), (0.90,0.93,0.95), (0.25,0.73,0.31)),   // 终端绿
    ((0.02,0.08,0.10), (0.61,0.84,0.96), (0.13,0.83,0.93)),   // 赛博青
    ((0.09,0.06,0.02), (0.96,0.89,0.78), (0.96,0.62,0.04)),   // 琥珀
    ((0.06,0.06,0.08), (0.83,0.69,0.22), (0.96,0.94,0.90)),   // 优雅金
    ((0.07,0.07,0.08), (0.88,0.89,0.91), (0.25,0.73,0.31)),   // 石墨+绿
]
// 6 风格: 0 wire-accent | 1 wire-white | 2 facet-accent | 3 knock | 4 knock-deep | 5 facet-white
let styleNames = ["wireA", "wireW", "facetA", "knock", "knockD", "facetW"]

let gtBig: [P] = [(0.33,0.31),(0.63,0.50),(0.33,0.69)]
let gtSmall: [P] = [(0.37,0.35),(0.59,0.50),(0.37,0.65)]
let gtCairn: [P] = [(0.40,0.44),(0.60,0.53),(0.40,0.62)]

func ovalPoly(_ o: (CGFloat, CGFloat, CGFloat, CGFloat), _ n: Int = 24) -> [P] {
    var pts: [P] = []
    for i in 0..<n {
        let a = CGFloat(i) / CGFloat(n) * 2 * .pi
        pts.append((o.0 + o.2/2 + cos(a) * o.2/2, o.1 + o.3/2 + sin(a) * o.3/2))
    }
    return pts
}

/// 内线端点向质心内收 18%（端点 containment）
func shortened(_ lines: [[P]]) -> [[P]] {
    lines.map { line in
        let cx = line.reduce(0) { $0 + $1.0 } / CGFloat(line.count)
        let cy = line.reduce(0) { $0 + $1.1 } / CGFloat(line.count)
        return line.map { ($0.0 + (cx - $0.0) * 0.18, $0.1 + (cy - $0.1) * 0.18) }
    }
}

func draw(_ a: Art, shapeIdx: Int, style: Int, pal: (RGB, RGB, RGB), size: Int) -> NSImage {
    let S = CGFloat(size)
    let img = NSImage(size: NSSize(width: S, height: S))
    img.lockFocus()
    color(pal.0).setFill()
    NSRect(x: 0, y: 0, width: S, height: S).fill()

    let box = CGRect(x: S * 0.13, y: S * 0.13, width: S * 0.74, height: S * 0.74)
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

    let lw = S * 0.08        // 主轮廓 ≥0.07 硬下限之上
    let lwInner = S * 0.06
    let lwGT = S * 0.10
    let lwKnock = S * 0.13

    var sils = a.sil
    if !a.cairn { for o in a.ovals { sils.append(ovalPoly(o)) } }

    let gt: [P] = a.cairn ? gtCairn : (a.narrow ? gtSmall : gtBig)
    let white = pal.1
    let gtColor: RGB = (style == 1 || style == 5) ? white : pal.2
    let innerColor: RGB = (style == 5) ? white : pal.2
    let deep = mix(pal.2, (0, 0, 0), 0.62)

    // cairn 实遮挡：自底向上，上层先填背景再描边
    func cairnStroked(_ strokeC: RGB) {
        let ov = a.ovals
        for (i, o) in ov.enumerated() {
            if i > 0 {
                let p = path(ovalPoly(o), close: true)
                color(pal.0).setFill(); p.fill()   // 背景遮罩
            }
            let p = path(ovalPoly(o), close: true)
            color(strokeC).setStroke(); p.lineWidth = lw; p.stroke()
        }
    }
    func cairnFilled(_ fillC: RGB) {
        for o in a.ovals {
            let p = path(ovalPoly(o), close: true)
            color(fillC, 0.95).setFill(); p.fill()
        }
    }

    switch style {
    case 0, 1: // wire + 粗>
        if a.cairn { cairnStroked(pal.1) }
        else {
            color(pal.1).setStroke()
            for poly in sils { let p = path(poly, close: true); p.lineWidth = lw; p.stroke() }
        }
        color(gtColor).setStroke()
        let g = path(gt, close: false); g.lineWidth = lwGT; g.stroke()
    case 2, 5: // facet + >（内线内收、线宽 0.75×轮廓）
        if a.cairn { cairnStroked(pal.1) }
        else {
            color(pal.1).setStroke()
            for poly in sils { let p = path(poly, close: true); p.lineWidth = lw; p.stroke() }
            color(innerColor).setStroke()
            for line in shortened(a.inner) {
                let p = path(line, close: false); p.lineWidth = lwInner; p.stroke()
            }
        }
        color(gtColor).setStroke()
        let g = path(gt, close: false); g.lineWidth = lwGT; g.stroke()
    case 3: // knock 实心+镂空>
        if a.cairn { cairnFilled(pal.1) }
        else {
            for poly in sils { let p = path(poly, close: true); color(pal.1, 0.95).setFill(); p.fill() }
        }
        color(pal.0).setStroke()
        let g = path(gt, close: false); g.lineWidth = lwKnock; g.stroke()
    default: // knock-deep 深底+亮>
        if a.cairn { cairnFilled(deep) }
        else {
            for poly in sils { let p = path(poly, close: true); color(deep, 0.95).setFill(); p.fill() }
        }
        color(pal.1).setStroke()
        let g = path(gt, close: false); g.lineWidth = lwKnock; g.stroke()
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
var n = 0
for (si, a) in arts.enumerated() {
    for (sti, _) in styleNames.enumerated() {
        if si == 19 && !(sti == 3 || sti == 4) { continue }   // arch 只留 knock 两款
        for (pi, _) in palettes.enumerated() {
            n += 1
            let code = String(format: "%03d", n)
            png(draw(a, shapeIdx: si, style: sti, pal: palettes[pi], size: 512), "\(outDir)/\(code).png")
            htmlRows += "<div style=\"text-align:center\"><img src=\"\(code).png\" width=\"96\" style=\"border-radius:14px\"><p style=\"margin:2px 0 10px;color:#888;font-size:11px\">\(code) \(shapeNames[si])·\(styleNames[sti])·p\(pi)</p></div>\n"
        }
    }
}

let html = """
<html><head><meta charset="utf-8"><title>stonemux Round3 终稿候选</title></head>
<body style="background:#151517;color:#eee;font-family:-apple-system,sans-serif;padding:24px">
<h1>Round3 终稿候选（\(n) 个）</h1>
<div style="display:grid;grid-template-columns:repeat(10,1fr);gap:6px">
\(htmlRows)
</div></body></html>
"""
try? html.write(to: URL(fileURLWithPath: "\(outDir)/gallery.html"), atomically: true, encoding: .utf8)
print("done: \(n) icons")
