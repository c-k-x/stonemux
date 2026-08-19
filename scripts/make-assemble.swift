import Foundation

// 组装最终 500：r3 survivors + topup survivors 重编号 001-500 + 终选页
// 用法: swift scripts/make-assemble.swift <输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-final500"
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func range(_ s: String) -> [Int] {
    // "011-015" -> [011...015]
    let parts = s.split(separator: "-").map { Int($0)! }
    return Array(parts[0]...parts[1])
}

var r3Culls: [Int] = []
for r in ["011-015","026-030","061-065","066-070","071-075","086-090","091-095","096-100","101-105","116-120","121-125",
          "191-210",
          "281-285","296-300","341-345","356-360",
          "401-405","416-420","461-465","476-480","491-495",
          "506-510","521-525","536-560","566-575"] {
    r3Culls += range(r)
}
// topup 淘汰（终检 agent 结论，组装前填入）
let TOPUP_CULL_RANGES: [String] = ["056-060", "071-075", "076-100", "146-150"]
var topupCulls: [Int] = []
for r in TOPUP_CULL_RANGES { topupCulls += range(r) }

let r3CullSet = Set(r3Culls)
let topupCullSet = Set(topupCulls)

var picked: [(String, String)] = []   // (srcPath, label)
for i in 1...580 {
    if !r3CullSet.contains(i) {
        picked.append(("/tmp/stonemux-r3/\(String(format: "%03d", i)).png", "r3-\(String(format: "%03d", i))"))
    }
}
for i in 1...150 {
    if !topupCullSet.contains(i) {
        picked.append(("/tmp/stonemux-topup/\(String(format: "%03d", i)).png", "topup-\(String(format: "%03d", i))"))
    }
}

// 取前 500
let final = Array(picked.prefix(500))
var htmlRows = ""
for (idx, item) in final.enumerated() {
    let code = String(format: "%03d", idx + 1)
    try? fm.copyItem(atPath: item.0, toPath: "\(outDir)/\(code).png")
    htmlRows += "<div style=\"text-align:center\"><img src=\"\(code).png\" width=\"96\" style=\"border-radius:14px\"><p style=\"margin:2px 0 10px;color:#888;font-size:11px\">\(code) <span style=\"color:#555\">\(item.1)</span></p></div>\n"
}

let html = """
<html><head><meta charset="utf-8"><title>stonemux 终选 500</title></head>
<body style="background:#151517;color:#eee;font-family:-apple-system,sans-serif;padding:24px">
<h1>stonemux 终选 \(final.count) 个（三轮评审后）</h1>
<p style="color:#888">灰字为来源（r3=第三轮池 / topup=补足微调）。挑一个编号告诉我做进 app。</p>
<div style="display:grid;grid-template-columns:repeat(10,1fr);gap:6px">
\(htmlRows)
</div></body></html>
"""
try? html.write(to: URL(fileURLWithPath: "\(outDir)/gallery.html"), atomically: true, encoding: .utf8)
print("final: \(final.count) (pool \(picked.count))")
