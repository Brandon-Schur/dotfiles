// deckart — renders dynamic Stream Deck key images and prints them as a PNG data URI.
//   deckart badge <bundle id> <big text> <small text> <accent hex> [<pill2 text> <pill2 hex>]   app icon + counts
//   deckart art <image file> <quadrant 0-3> [caption]                one quarter of album art (2x2 block)
//   deckart text <line1> <line2> <bg hex>                            two-line text key
import AppKit

let S: CGFloat = 144

func color(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                   blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

func canvas(_ draw: () -> Void) -> String {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor(srgbRed: 0.12, green: 0.16, blue: 0.2, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: S, height: S).fill()
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return "data:image/png;base64," + rep.representation(using: .png, properties: [:])!.base64EncodedString()
}

func text(_ s: String, size: CGFloat, weight: NSFont.Weight = .semibold, color c: NSColor = .white,
          in rect: NSRect, shadow: Bool = false) {
    let p = NSMutableParagraphStyle()
    p.alignment = .center
    p.lineBreakMode = .byTruncatingTail
    var attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                .foregroundColor: c, .paragraphStyle: p]
    if shadow {
        let sh = NSShadow()
        sh.shadowColor = .black
        sh.shadowBlurRadius = 4
        attrs[.shadow] = sh
    }
    NSAttributedString(string: s, attributes: attrs).draw(in: rect)
}

let a = CommandLine.arguments
switch a.count > 1 ? a[1] : "" {
case "badge" where a.count >= 6:
    print(canvas {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: a[2]) {
            NSWorkspace.shared.icon(forFile: url.path).draw(in: NSRect(x: 8, y: 52, width: 84, height: 84))
        }
        let big = a[3], small = a[4]
        if !big.isEmpty {
            let pill = NSRect(x: 62, y: 74, width: 76, height: 56)
            color(a[5]).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 28, yRadius: 28).fill()
            text(big, size: big.count > 3 ? 26 : 34, weight: .bold, in: pill.offsetBy(dx: 0, dy: big.count > 3 ? -12 : -6))
        }
        if a.count >= 8, !a[6].isEmpty { // second pill, e.g. DM count
            let pill = NSRect(x: 62, y: 44, width: 76, height: 34)
            color(a[7]).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 17, yRadius: 17).fill()
            text(a[6], size: 21, weight: .bold, in: pill.offsetBy(dx: 0, dy: -5))
        }
        text(small, size: 22, color: NSColor(white: 0.85, alpha: 1), in: NSRect(x: 2, y: 8, width: S - 4, height: 32))
    })
case "art" where a.count >= 4:
    let q = Int(a[3]) ?? 0
    print(canvas {
        if let img = NSImage(contentsOfFile: a[2]) {
            // Draw the full art at 2x key size, offset so this key shows its quarter.
            let col = CGFloat(q % 2), row = CGFloat(q / 2)
            img.draw(in: NSRect(x: -col * S, y: -(1 - row) * S, width: 2 * S, height: 2 * S))
        }
        if a.count >= 5, !a[4].isEmpty {
            NSColor(white: 0, alpha: 0.55).setFill()
            NSRect(x: 0, y: 0, width: S, height: 40).fill()
            text(a[4], size: 20, in: NSRect(x: 4, y: 6, width: S - 8, height: 28), shadow: true)
        }
    })
case "cover" where a.count >= 3: // full-key cover image with optional caption
    print(canvas {
        if let img = NSImage(contentsOfFile: a[2]) { img.draw(in: NSRect(x: 0, y: 0, width: S, height: S)) }
        if a.count >= 4, !a[3].isEmpty {
            NSColor(white: 0, alpha: 0.6).setFill()
            NSRect(x: 0, y: 0, width: S, height: 40).fill()
            text(a[3], size: 19, in: NSRect(x: 4, y: 7, width: S - 8, height: 28), shadow: true)
        }
    })
case "text" where a.count >= 5:
    print(canvas {
        color(a[4]).setFill()
        NSRect(x: 0, y: 0, width: S, height: S).fill()
        text(a[2], size: 34, weight: .bold, in: NSRect(x: 2, y: 78, width: S - 4, height: 44))
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        p.lineBreakMode = .byWordWrapping
        let body = NSAttributedString(string: a[3], attributes: [
            .font: NSFont.systemFont(ofSize: 19, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: p])
        body.draw(with: NSRect(x: 6, y: 8, width: S - 12, height: 68), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    })
default:
    FileHandle.standardError.write("usage: deckart badge|art|text ...\n".data(using: .utf8)!)
    exit(2)
}
