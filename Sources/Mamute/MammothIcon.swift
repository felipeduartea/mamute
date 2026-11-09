import AppKit

/// Mamute's mammoth, drawn as a template image so it follows the menu bar's light/dark tint.
func mammothIcon(muted: Bool, size: CGFloat = 18) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        ctx.scaleBy(x: rect.width / 18, y: rect.height / 18) // drawn on an 18×18 grid
        NSColor.black.set()

        NSBezierPath(ovalIn: NSRect(x: 5, y: 4.5, width: 12, height: 7.5)).fill()     // body, back sloping down to the tail
        NSBezierPath(ovalIn: NSRect(x: 6.5, y: 8.5, width: 7, height: 6.5)).fill()    // shoulder hump
        NSBezierPath(ovalIn: NSRect(x: 2.5, y: 9, width: 7, height: 7)).fill()        // domed head
        let fur = NSBezierPath() // shaggy fringe under the belly
        fur.move(to: NSPoint(x: 8.4, y: 5.5))
        for i in 0..<4 {
            let x = 8.4 + CGFloat(i) * 1.05
            fur.line(to: NSPoint(x: x + 0.5, y: 3.6))
            fur.line(to: NSPoint(x: x + 1.05, y: 5.5))
        }
        fur.close()
        fur.fill()
        NSBezierPath(roundedRect: NSRect(x: 6, y: 1, width: 2.6, height: 6), xRadius: 1, yRadius: 1).fill()    // front leg
        NSBezierPath(roundedRect: NSRect(x: 12.6, y: 1, width: 2.6, height: 6), xRadius: 1, yRadius: 1).fill() // back leg

        let trunk = NSBezierPath()
        trunk.move(to: NSPoint(x: 4, y: 11))
        trunk.curve(to: NSPoint(x: 2.2, y: 3.2), controlPoint1: NSPoint(x: 2, y: 8.5), controlPoint2: NSPoint(x: 1.6, y: 5))
        trunk.curve(to: NSPoint(x: 4.2, y: 3.4), controlPoint1: NSPoint(x: 2.6, y: 2.2), controlPoint2: NSPoint(x: 3.8, y: 2.4))
        trunk.lineWidth = 2.2
        trunk.lineCapStyle = .round
        trunk.stroke()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 16.2, y: 10))
        tail.line(to: NSPoint(x: 17.2, y: 7.5))
        tail.lineWidth = 1
        tail.lineCapStyle = .round
        tail.stroke()

        // Long tusk sweeping forward and up, with a clear gap so it reads against the trunk.
        let tusk = NSBezierPath()
        tusk.move(to: NSPoint(x: 5.8, y: 8.6))
        tusk.curve(to: NSPoint(x: 0.9, y: 7.4), controlPoint1: NSPoint(x: 5.2, y: 5), controlPoint2: NSPoint(x: 1.2, y: 4.6))
        tusk.lineCapStyle = .round
        ctx.setBlendMode(.clear)
        tusk.lineWidth = 3
        tusk.stroke()
        NSBezierPath(ovalIn: NSRect(x: 6.1, y: 12.4, width: 1.3, height: 1.3)).fill() // eye
        ctx.setBlendMode(.normal)
        tusk.lineWidth = 1.4
        tusk.stroke()

        if muted {
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 1, y: 17))
            slash.line(to: NSPoint(x: 17, y: 1))
            slash.lineCapStyle = .round
            ctx.setBlendMode(.clear) // gap around the slash
            slash.lineWidth = 3.4
            slash.stroke()
            ctx.setBlendMode(.normal)
            slash.lineWidth = 1.5
            slash.stroke()
        }
        return true
    }
    image.isTemplate = true
    image.accessibilityDescription = muted ? "Mamute, some apps muted" : "Mamute"
    return image
}
