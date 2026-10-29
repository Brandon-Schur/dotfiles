// Renders Stream Deck key/action icons (emoji glyph + optional caption) to PNG.
// Usage: swift make-icons.swift <outdir> < spec.tsv
//   spec.tsv lines: <filename-stem>\t<size px>\t<glyph>\t<caption or empty>\t<bg hex or empty>
import AppKit

let outDir = CommandLine.arguments[1]

func color(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                   blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

func render(stem: String, size: Int, glyph: String, caption: String, bg: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size)
    if !bg.isEmpty {
        color(bg).setFill()
        NSRect(x: 0, y: 0, width: s, height: s).fill()
    }
    let hasCaption = !caption.isEmpty
    let glyphSize = s * (hasCaption ? 0.50 : 0.62)
    let g = NSAttributedString(string: glyph, attributes: [.font: NSFont.systemFont(ofSize: glyphSize)])
    let gs = g.size()
    let gy = hasCaption ? s * 0.36 : (s - gs.height) / 2
    g.draw(at: NSPoint(x: (s - gs.width) / 2, y: gy))
    if hasCaption {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        let c = NSAttributedString(string: caption, attributes: [
            .font: NSFont.systemFont(ofSize: s * 0.17, weight: .semibold),
            .foregroundColor: NSColor.white, .paragraphStyle: p,
        ])
        c.draw(in: NSRect(x: 0, y: s * 0.08, width: s, height: s * 0.24))
    }
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(stem).png"))
}

while let line = readLine() {
    let f = line.components(separatedBy: "\t")
    guard f.count >= 3, let size = Int(f[1]) else { continue }
    render(stem: f[0], size: size, glyph: f[2], caption: f.count > 3 ? f[3] : "", bg: f.count > 4 ? f[4] : "")
}
