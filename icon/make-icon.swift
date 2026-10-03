// Draws Trading Clock's app icon at 1024 × 1024: a 24-hour dial whose rim is coloured by the New York sessions
// (pre-market, regular hours, after-hours, closed), with its hand at 09:30, the open, on the macOS icon grid.
// Usage: swift icon/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let cg = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func linear(_ colors: [NSColor], _ locations: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cgColor) as CFArray, locations: locations)!
    cg.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
func radial(_ colors: [NSColor], _ locations: [CGFloat], at c: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cgColor) as CFArray, locations: locations)!
    cg.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [.drawsAfterEndLocation])
}

// macOS grid: an 824-point body inset 100, corner radius about 22.5 %, with a soft drop shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
rgb(0x1c1d22).setFill(); shape.fill()
cg.restoreGState()
cg.saveGState()
shape.addClip()

// Graphite, the colour of the clock's own panel.
linear([rgb(0x3a3c44), rgb(0x1a1b20)], [0, 1], from: CGPoint(x: 0, y: body.maxY), to: CGPoint(x: 0, y: body.minY))

let c = CGPoint(x: 512, y: 512)
// A 24-hour dial with midnight at the top, running clockwise.
func angle(_ hour: CGFloat) -> CGFloat { 90 - hour / 24 * 360 }
func point(_ hour: CGFloat, _ r: CGFloat) -> CGPoint {
    let a = angle(hour) * .pi / 180
    return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
}

// The face.
let faceR: CGFloat = 330
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor.black.withAlphaComponent(0.55).cgColor)
rgb(0x121317).setFill(); NSBezierPath(ovalIn: CGRect(x: c.x - faceR - 22, y: c.y - faceR - 22, width: 2 * faceR + 44, height: 2 * faceR + 44)).fill()
cg.restoreGState()
cg.saveGState()
NSBezierPath(ovalIn: CGRect(x: c.x - faceR - 22, y: c.y - faceR - 22, width: 2 * faceR + 44, height: 2 * faceR + 44)).addClip()
linear([rgb(0x55575f), rgb(0x1e1f24)], [0, 1], from: CGPoint(x: 0, y: c.y + faceR), to: CGPoint(x: 0, y: c.y - faceR))
cg.restoreGState()
cg.saveGState()
NSBezierPath(ovalIn: CGRect(x: c.x - faceR, y: c.y - faceR, width: 2 * faceR, height: 2 * faceR)).addClip()
radial([rgb(0x2e3038), rgb(0x17181d)], [0, 1], at: CGPoint(x: c.x, y: c.y + 80), radius: faceR * 1.1)
cg.restoreGState()

// The session ring: pre-market slate blue, regular hours warm white, after-hours amber, closed grey.
let ringR: CGFloat = 282, ringW: CGFloat = 46
let sessions: [(CGFloat, CGFloat, UInt32)] = [(4, 9.5, 0x6f8fd6), (9.5, 16, 0xf1ece0), (16, 20, 0xf0a63a), (20, 28, 0x4a4c55)]
for (from, to, hex) in sessions {
    let arc = NSBezierPath()
    arc.appendArc(withCenter: c, radius: ringR, startAngle: angle(from) - 1.2, endAngle: angle(to) + 1.2, clockwise: true)
    arc.lineWidth = ringW
    arc.lineCapStyle = .butt
    rgb(hex).setStroke(); arc.stroke()
}
// Hour ticks inside the ring.
for h in 0..<24 {
    let major = h % 6 == 0
    let t = NSBezierPath()
    t.move(to: point(CGFloat(h), ringR - ringW / 2 - 18))
    t.line(to: point(CGFloat(h), ringR - ringW / 2 - (major ? 58 : 36)))
    t.lineWidth = major ? 12 : 6
    t.lineCapStyle = .round
    rgb(0xc9cbd2, major ? 0.85 : 0.4).setStroke(); t.stroke()
}

// The open: a soft glow on the ring where pre-market meets regular hours.
cg.saveGState()
radial([rgb(0xffffff, 0.55), rgb(0xffffff, 0)], [0, 1], at: point(9.5, ringR), radius: 80)
cg.restoreGState()

// One hand, as on a 24-hour watch, pointing at 09:30 New York: the open.
func hand(to p: CGPoint, width: CGFloat, color: NSColor, tail: CGFloat) {
    let dx = p.x - c.x, dy = p.y - c.y, len = hypot(dx, dy)
    let path = NSBezierPath()
    path.move(to: CGPoint(x: c.x - dx / len * tail, y: c.y - dy / len * tail))
    path.line(to: p)
    path.lineWidth = width
    path.lineCapStyle = .round
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    color.setStroke(); path.stroke()
    cg.restoreGState()
}
hand(to: point(9.5, 214), width: 30, color: rgb(0xf6f2e8), tail: 44)
// Centre cap in the opening-range colours' first stage.
rgb(0x4fb8a5).setFill(); NSBezierPath(ovalIn: CGRect(x: c.x - 28, y: c.y - 28, width: 56, height: 56)).fill()
rgb(0x17181d).setFill(); NSBezierPath(ovalIn: CGRect(x: c.x - 10, y: c.y - 10, width: 20, height: 20)).fill()

// A faint sheen across the top of the body, as on Apple's icons.
linear([NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)], [0, 1],
       from: CGPoint(x: 0, y: body.maxY), to: CGPoint(x: 0, y: body.maxY - 260))
cg.restoreGState()

// A hairline edge to keep the shape crisp on dark menus and docks.
shape.lineWidth = 2
NSColor.white.withAlphaComponent(0.08).setStroke(); shape.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
