// Draws the app icon: two profile cards (private = blue, work = orange) with swap arrows.
// Usage: swift icon.swift <output.png>
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
}

func withShadow(_ blur: CGFloat, _ dy: CGFloat, _ alpha: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: -dy)
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

// Background tile on the macOS icon grid (824 pt inside 1024 pt).
let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
withShadow(30, 14, 0.3) { rgb(43, 39, 36).setFill(); tile.fill() }
NSGradient(starting: rgb(66, 59, 54), ending: rgb(35, 31, 29))!.draw(in: tile, angle: -90)

func card(_ rect: NSRect, top: NSColor, bottom: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 70, yRadius: 70)
    withShadow(40, 18, 0.45) { bottom.setFill(); path.fill() }
    NSGradient(starting: top, ending: bottom)!.draw(in: path, angle: -90)
    // Person symbol
    NSColor.white.setFill()
    let cx = rect.midX
    NSBezierPath(ovalIn: NSRect(x: cx - 55, y: rect.midY + 5, width: 110, height: 110)).fill()
    let body = NSBezierPath()
    body.move(to: NSPoint(x: cx - 100, y: rect.midY - 110))
    body.curve(to: NSPoint(x: cx, y: rect.midY - 15),
               controlPoint1: NSPoint(x: cx - 100, y: rect.midY - 50),
               controlPoint2: NSPoint(x: cx - 55, y: rect.midY - 15))
    body.curve(to: NSPoint(x: cx + 100, y: rect.midY - 110),
               controlPoint1: NSPoint(x: cx + 55, y: rect.midY - 15),
               controlPoint2: NSPoint(x: cx + 100, y: rect.midY - 50))
    body.close()
    body.fill()
}

card(NSRect(x: 200, y: 450, width: 360, height: 340), top: rgb(92, 160, 245), bottom: rgb(45, 108, 214))
card(NSRect(x: 464, y: 234, width: 360, height: 340), top: rgb(240, 145, 95), bottom: rgb(210, 95, 55))

// Two curved arrows: top right and bottom left.
func arrow(from: NSPoint, control: NSPoint, to: NSPoint) {
    let cream = rgb(245, 237, 225)
    cream.setStroke()
    cream.setFill()
    let angle = atan2(to.y - control.y, to.x - control.x)
    let line = NSBezierPath()
    line.lineWidth = 36
    line.lineCapStyle = .round
    line.move(to: from)
    line.curve(to: to, controlPoint1: control, controlPoint2: control)
    line.stroke()
    func point(_ distance: CGFloat, _ offset: CGFloat) -> NSPoint {
        NSPoint(x: to.x + cos(angle) * distance - sin(angle) * offset,
                y: to.y + sin(angle) * distance + cos(angle) * offset)
    }
    let head = NSBezierPath()
    head.move(to: point(58, 0))
    head.line(to: point(-14, 55))
    head.line(to: point(-14, -55))
    head.close()
    head.fill()
}

arrow(from: NSPoint(x: 630, y: 746), control: NSPoint(x: 758, y: 750), to: NSPoint(x: 754, y: 660))
arrow(from: NSPoint(x: 394, y: 278), control: NSPoint(x: 266, y: 274), to: NSPoint(x: 270, y: 364))

try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
