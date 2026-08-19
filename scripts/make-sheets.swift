import AppKit

// 把 <目录>/NNN.png 拼成 5×5 联络表 sheet-NN.png（每格 200px + 代码标签）
// 用法: swift scripts/make-sheets.swift <图标目录> <输出目录>

let srcDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/stonemux-500"
let outDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/stonemux-sheets"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let codes = (try? FileManager.default.contentsOfDirectory(atPath: srcDir))?
    .filter { $0.hasSuffix(".png") && $0.count == 7 }   // NNN.png
    .compactMap { $0.split(separator: ".").first.map(String.init) }
    .filter { Int($0) != nil }
    .sorted() ?? []

let cell = 200
let cols = 5, rows = 5
let perSheet = cols * rows
let sheetCount = Int(ceil(CGFloat(codes.count) / CGFloat(perSheet)))

for s in 0..<sheetCount {
    let size = NSSize(width: cols * cell, height: rows * (cell + 24))
    let img = NSImage(size: size)
    img.lockFocus()
    NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()

    for i in 0..<perSheet {
        let idx = s * perSheet + i
        guard idx < codes.count else { break }
        let code = codes[idx]
        let cx = CGFloat((i % cols) * cell)
        let cy = CGFloat((i / cols) * (cell + 24))

        if let icon = NSImage(contentsOfFile: "\(srcDir)/\(code).png") {
            icon.draw(in: NSRect(x: cx + 8, y: size.height - cy - CGFloat(cell) + 16,
                                 width: CGFloat(cell) - 16, height: CGFloat(cell) - 16))
        }
        let label = NSAttributedString(
            string: code,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                         .foregroundColor: NSColor(calibratedWhite: 0.7, alpha: 1)])
        label.draw(at: NSPoint(x: cx + 10, y: size.height - cy - 20))
    }
    img.unlockFocus()

    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let p = rep.representation(using: .png, properties: [:]) else { continue }
    try? p.write(to: URL(fileURLWithPath: String(format: "\(outDir)/sheet-%02d.png", s + 1)))
}
print("sheets: \(sheetCount) for \(codes.count) icons")
