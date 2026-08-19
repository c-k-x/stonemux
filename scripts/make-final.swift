import AppKit

// Round 2 生成器：落实评审意见
// 修: 砍点线/细扫描线 | glow 仅简单几何+硬约束 | cairn 遮挡堆叠 | 窄长加宽 |
//     ">" 分离+内含+粗线 | 线宽上调 | 配色收敛 5 套(砍 lavender/灰fill) | arch 只留实心>款 | pair 留 gap
// 规模 ≈ 580: (20石×6风格 - arch限制4) × 5配色
// 用法: swift scripts/make-final.swift <输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-final"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

typealias P = (CGFloat, CGFloat)
typealias RGB = (CGFloat, CGFloat, CGFloat)
func color(_ c: RGB, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: a)
}

struct Art { let sil: [[P]]; let ovals: [(CGFloat, CGFloat, CGFloat, CGFloat)]; let inner: [[P]]; let cairn: Bool; let narrow: Bool }

let arts: [Art] = [
    Art(sil: [[(0.02,0.62),(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.24,0.98)]], ovals: [],
        inner: [[(0.50,0.52),(0.16,0.22)],[(0.50,0.52),(0.86,0.20)],[(0.50,0.52),(0.50,0.98)]], cairn: false, narrow: false),          // classic
    Art(sil: [], ovals: [(0.05,0.15,0.90,0.80)], inner: [], cairn: false, narrow: false),                                                              // pebble
    Art(sil: [[(0.28,0.0),(0.66,0.30),(0.78,1.0),(0.26,1.0),(0.14,0.42)]], ovals: [],
        inner: [[(0.28,0.0),(0.46,0.48),(0.30,1.0)],[(0.46,0.48),(0.66,0.30)]], cairn: false, narrow: true),                                  // shard(加宽)
    Art(sil: [], ovals: [(0.10,0.62,0.80,0.36),(0.18,0.38,0.64,0.30),(0.28,0.12,0.44,0.28)], inner: [], cairn: true, narrow: false),                       // cairn(遮挡)
    Art(sil: [[(0.25,0.05),(0.75,0.05),(0.95,0.35),(0.5,0.95),(0.05,0.35)]], ovals: [],
        inner: [[(0.05,0.35),(0.95,0.35)],[(0.5,0.35),(0.5,0.95)]], cairn: false, narrow: false),                                                        // hexgem(减线)
    Art(sil: [[(0.5,0.02),(0.93,0.26),(0.93,0.72),(0.5,0.98),(0.07,0.72),(0.07,0.26)]], ovals: [],
        inner: [[(0.07,0.26),(0.5,0.5),(0.93,0.26)],[(0.5,0.5),(0.5,0.98)]], cairn: false, narrow: false),                                            // isocube
    Art(sil: [[(0.05,0.95),(0.30,0.15),(0.44,0.55),(0.68,0.05),(0.95,0.95)]], ovals: [],
        inner: [[(0.30,0.15),(0.36,0.95)],[(0.68,0.05),(0.62,0.95)]], cairn: false, narrow: false),                                                    // twinpeaks
    Art(sil: [[(0.02,0.55),(0.20,0.25),(0.75,0.18),(0.98,0.50),(0.80,0.85),(0.15,0.85)]], ovals: [],
        inner: [[(0.20,0.25),(0.55,0.45),(0.75,0.18)]], cairn: false, narrow: false),                                                                                // flatwide(减线)
    Art(sil: [[(0.24,0.05),(0.72,0.02),(0.76,0.98),(0.22,0.98)]], ovals: [], inner: [[(0.42,0.03),(0.42,0.98)]], cairn: false, narrow: true),                       // monolith(加宽)
    Art(sil: [[(0.15,0.95),(0.28,0.30),(0.38,0.60),(0.52,0.05),(0.66,0.55),(0.78,0.40),(0.90,0.95)]], ovals: [],
        inner: [[(0.52,0.05),(0.52,0.95)],[(0.28,0.30),(0.34,0.95)]], cairn: false, narrow: false),                                                            // crystals(减线)
    Art(sil: [], ovals: [(0.06,0.10,0.88,0.85)], inner: [[(0.35,0.45),(0.5,0.6),(0.45,0.8)]], cairn: false, narrow: false),                                  // boulder
    Art(sil: [[(0.2,0.2),(0.8,0.2),(0.95,0.45),(0.5,0.98),(0.05,0.45)]], ovals: [],
        inner: [[(0.05,0.45),(0.95,0.45)],[(0.35,0.45),(0.5,0.98)],[(0.65,0.45),(0.5,0.98)]], cairn: false, narrow: false),                    // brilliant
    Art(sil: [[(0.02,0.62),(0.16,0.22),(0.48,0.02),(0.86,0.20),(0.98,0.60),(0.78,0.98),(0.24,0.98)]], ovals: [],
        inner: [[(0.10,0.35),(0.3,0.28),(0.5,0.34),(0.7,0.27),(0.9,0.34)]], cairn: false, narrow: false),                                                    // mossy
    Art(sil: [[(0.1,0.5),(0.3,0.1),(0.75,0.05),(0.92,0.55),(0.6,0.95),(0.2,0.9)]], ovals: [],
        inner: [[(0.3,0.1),(0.5,0.4),(0.6,0.95)]], cairn: false, narrow: false),                                                                                                            // obsidian(减线)
    Art(sil: [], ovals: [(0.08,0.55,0.84,0.40),(0.12,0.32,0.76,0.34),(0.20,0.10,0.60,0.30)], inner: [], cairn: true, narrow: false),                       // strata(遮挡)
    Art(sil: [[(0.1,0.4),(0.3,0.08),(0.75,0.05),(0.95,0.5),(0.7,0.95),(0.25,0.9)]], ovals: [],
        inner: [[(0.28,0.42),(0.4,0.22),(0.68,0.2),(0.78,0.5),(0.6,0.75),(0.38,0.72),(0.28,0.42)]], cairn: false, narrow: false),          // geode
    Art(sil: [[(0.05,0.6),(0.2,0.2),(0.5,0.05),(0.85,0.2),(0.95,0.6),(0.75,0.95),(0.25,0.95)]], ovals: [],
        inner: [[(0.2,0.2),(0.5,0.5),(0.85,0.2)],[(0.5,0.5),(0.5,0.95)]], cairn: false, narrow: false),                                                    // lineart
    Art(sil: [[(0.5,0.02),(0.9,0.25),(0.95,0.7),(0.55,0.98),(0.45,0.98),(0.05,0.7),(0.1,0.25)]], ovals: [],
        inner: [[(0.1,0.25),(0.5,0.45),(0.9,0.25)],[(0.5,0.45),(0.5,0.98)]], cairn: false, narrow: false),                                                    // sixfacet
    Art(sil: [[(0.0,0.6),(0.12,0.25),(0.4,0.1),(0.62,0.3),(0.64,0.7),(0.48,0.95),(0.1,0.95)],
              [(0.76,0.72),(0.82,0.5),(0.97,0.55),(0.99,0.85),(0.88,0.98)]], ovals: [],
        inner: [[(0.12,0.25),(0.45,0.4),(0.62,0.3)]], cairn: false, narrow: false),                                                                                        // pair(留gap)
    Art(sil: [[(0.05,0.95),(0.1,0.2),(0.5,0.02),(0.9,0.2),(0.95,0.95),(0.68,0.95),(0.66,0.55),(0.5,0.4),(0.34,0.55),(0.32,0.95)]], ovals: [], inner: [], cairn: false, narrow: false), // arch
]
let shapeNames = ["classic","pebble","shard","cairn","hexgem","isocube","twinpeaks","flatwide",
                  "monolith","crystals","boulder","brilliant","mossy","obsidian","strata","geode",
                  "lineart","sixfacet","pair","arch"]

// 5 配色（砍 lavender / 灰 fill）
let palettes: [(RGB, RGB, RGB)] = [
    ((0.05,0.07,0.09), (0.90,0.93,0.95), (0.25,0.73,0.31)),   // 终端绿
    ((0.02,0.08,0.10), (0.61,0.84,0.96), (0.13,0.83,0.93)),   // 赛博青
    ((0.09,0.06,0.02), (0.96,0.89,0.78), (0.96,0.62,0.04)),   // 琥珀
    ((0.06,0.06,0.08), (0.83,0.69,0.22), (0.96,0.94,0.90)),   // 优雅金
    ((0.07,0.07,0.08), (0.88,0.89,0.91), (0.25,0.73,0.31)),   // 石墨+绿
]
// 6 风格: 0 wire粗 | 1 facet | 2 knock镂空 | 3 gt粗 | 4 neon(仅简单几何) | 5 holo粗
let styleNames = ["wire", "facet", "knock", "gt", "neon", "holo"]
let neonOK: Set<Int> = [0, 1, 4, 5, 10, 15]

let gtBig: [P] = [(0.32,0.30),(0.64,0.50),(0.32,0.70)]
let gtSmall: [P] = [(0.36,0.34),(0.60,0.50),(0.36,0.66)]

func ovalPoly(_ o: (CGFloat, CGFloat, CGFloat, CGFloat), _ n: Int = 24) -> [P] {
    var pts: [P] = []
    for i in 0..<n {
        let a = CGFloat(i) / CGFloat(n) * 2 * .pi
        pts.append((o.0 + o.2/2 + cos(a) * o.2/2, o.1 + o.3/2 + sin(a) * o.3/2))
    }
    return pts
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

    let lw = S * 0.07          // 主轮廓（评审: 6-8%）
    let lwInner = S * 0.055
    let lwGT = S * 0.10
    let lwKnock = S * 0.13

    var sils = a.sil
    if !a.cairn { for o in a.ovals { sils.append(ovalPoly(o)) } }

    let gt = a.narrow ? gtSmall : gtBig

    // cairn 遮挡堆叠：自底向上，上层 fill 遮下层轮廓
    func drawCairnStroked(_ strokeC: RGB, fillC: RGB?) {
        let ov = a.ovals
        for (i, o) in ov.enumerated() {
            if i > 0, let fc = fillC {   // 遮罩
                let r = ovalPoly(ov[i])
                let p = path(r, close: true)
                color(fc).setFill(); p.fill()
            }
            let p = path(ovalPoly(o), close: true)
            color(strokeC).setStroke(); p.lineWidth = lw; p.stroke()
        }
    }

    switch style {
    case 0: // wire 粗
        if a.cairn { drawCairnStroked(pal.1, fillC: pal.0) }
        else {
            color(pal.1).setStroke()
            for poly in sils { let p = path(poly, close: true); p.lineWidth = lw; p.stroke() }
            for line in a.inner { let p = path(line, close: false); p.lineWidth = lwInner; p.stroke() }
        }
    case 1: // facet
        if a.cairn {
            for o in a.ovals { let p = path(ovalPoly(o), close: true); color(pal.2, 0.2).setFill(); p.fill() }
            drawCairnStroked(pal.1, fillC: nil)
        } else {
            for poly in sils { let p = path(poly, close: true); color(pal.2, 0.18).setFill(); p.fill() }
            color(pal.1).setStroke()
            for poly in sils { let p = path(poly, close: true); p.lineWidth = lw; p.stroke() }
            color(pal.2).setStroke()
            for line in a.inner { let p = path(line, close: false); p.lineWidth = lwInner; p.stroke() }
        }
    case 2: // knock 实心+镂空>
        if a.cairn {
            for o in a.ovals { let p = path(ovalPoly(o), close: true); color(pal.1, 0.92).setFill(); p.fill() }
        } else {
            for poly in sils { let p = path(poly, close: true); color(pal.1, 0.92).setFill(); p.fill() }
        }
        color(pal.0).setStroke()
        let g = path(gt, close: false); g.lineWidth = lwKnock; g.stroke()
    case 3: // gt 粗彩色>
        if a.cairn { drawCairnStroked(pal.1, fillC: pal.0) }
        else {
            color(pal.1).setStroke()
            for poly in sils { let p = path(poly, close: true); p.lineWidth = lw; p.stroke() }
        }
        color(pal.2).setStroke()
        let g = path(gt, close: false); g.lineWidth = lwGT; g.stroke()
    case 4: // neon（仅简单几何，halo 收紧）
        let allowed = neonOK.contains(shapeIdx)
        let passes: [(CGFloat, CGFloat)] = allowed
            ? [(lw * 1.5, 0.12), (lw * 0.9, 0.3), (lw * 0.55, 1.0)]
            : [(lw * 0.9, 0.25), (lw * 0.55, 1.0)]
        for (w, al) in passes {
            color(pal.2, al).setStroke()
            if a.cairn {
                for o in a.ovals { let p = path(ovalPoly(o), close: true); p.lineWidth = w; p.stroke() }
            } else {
                for poly in sils { let p = path(poly, close: true); p.lineWidth = w; p.stroke() }
            }
        }
        color(pal.1).setStroke()
        let g = path(gt, close: false); g.lineWidth = lwGT * 0.8; g.stroke()
    default: // holo 粗扫描线
        NSGraphicsContext.saveGraphicsState()
        let clip = NSBezierPath()
        if a.cairn { for o in a.ovals { clip.append(path(ovalPoly(o), close: true)) } }
        else { for poly in sils { clip.append(path(poly, close: true)) } }
        clip.addClip()
        color(pal.1, 0.5).setFill()
        var y: CGFloat = 0
        while y < S {
            NSRect(x: 0, y: y, width: S, height: S * 0.03).fill()
            y += S * 0.075
        }
        NSGraphicsContext.restoreGraphicsState()
        color(pal.2).setStroke()
        if a.cairn {
            for o in a.ovals { let p = path(ovalPoly(o), close: true); p.lineWidth = lw * 0.85; p.stroke() }
        } else {
            for poly in sils { let p = path(poly, close: true); p.lineWidth = lw * 0.85; p.stroke() }
        }
        color(pal.1).setStroke()
        let g = path(gt, close: false); g.lineWidth = lwGT * 0.8; g.stroke()
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
        // arch 只留 knock / gt 两款
        if si == 19 && !(sti == 2 || sti == 3) { continue }
        for (pi, _) in palettes.enumerated() {
            n += 1
            let code = String(format: "%03d", n)
            png(draw(a, shapeIdx: si, style: sti, pal: palettes[pi], size: 512), "\(outDir)/\(code).png")
            htmlRows += "<div style=\"text-align:center\"><img src=\"\(code).png\" width=\"96\" style=\"border-radius:14px\"><p style=\"margin:2px 0 10px;color:#888;font-size:11px\">\(code) \(shapeNames[si])·\(styleNames[sti])·p\(pi)</p></div>\n"
        }
    }
}

let html = """
<html><head><meta charset="utf-8"><title>stonemux Round2 候选</title></head>
<body style="background:#151517;color:#eee;font-family:-apple-system,sans-serif;padding:24px">
<h1>Round2 改进候选（\(n) 个）</h1>
<div style="display:grid;grid-template-columns:repeat(10,1fr);gap:6px">
\(htmlRows)
</div></body></html>
"""
try? html.write(to: URL(fileURLWithPath: "\(outDir)/gallery.html"), atomically: true, encoding: .utf8)
print("done: \(n) icons")
