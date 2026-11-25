import AppKit

/// Status bar picture: one dot per running instance. The one in front is filled, the others are rings.
func badgeImage(_ badges: [(color: NSColor, front: Bool)]) -> NSImage {
    let dot: CGFloat = 10, gap: CGFloat = 4
    let width = CGFloat(badges.count) * dot + CGFloat(max(badges.count - 1, 0)) * gap
    let image = NSImage(size: NSSize(width: width, height: 18), flipped: false) { _ in
        for (i, badge) in badges.enumerated() {
            let rect = NSRect(x: CGFloat(i) * (dot + gap), y: 4, width: dot, height: dot)
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.9, dy: 0.9))
            path.lineWidth = 1.8
            badge.color.set()
            if badge.front { path.fill() }
            path.stroke()
        }
        return true
    }
    image.isTemplate = false  // keep the profile colors
    return image
}
