import AppKit

enum MenuBarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let scale = NSAffineTransform()
        scale.translateX(by: size.width / 2, yBy: size.height / 2)
        scale.scaleX(by: 1.155, yBy: 1.155)
        scale.translateX(by: -size.width / 2, yBy: -size.height / 2)
        scale.concat()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let face = NSBezierPath(ovalIn: NSRect(x: 1.7, y: 3.7, width: 11, height: 11))
        face.lineWidth = 1.05
        face.stroke()

        let eyeWidth: CGFloat = 1.5
        let eyeHeight: CGFloat = 2.5
        for centerX in [5.85, 8.55] {
            NSBezierPath(
                roundedRect: NSRect(
                    x: centerX - eyeWidth / 2,
                    y: 10.5 - eyeHeight / 2,
                    width: eyeWidth,
                    height: eyeHeight
                ),
                xRadius: eyeWidth / 2,
                yRadius: eyeWidth / 2
            ).fill()
        }

        let smile = NSBezierPath()
        smile.lineWidth = 1.05
        smile.lineCapStyle = .round
        smile.move(to: NSPoint(x: 5.35, y: 7.75))
        smile.curve(
            to: NSPoint(x: 9.05, y: 7.75),
            controlPoint1: NSPoint(x: 6.15, y: 6),
            controlPoint2: NSPoint(x: 8.25, y: 6)
        )
        smile.stroke()

        for (y, endX) in [(11.1, 16.2), (9.2, 15.5), (7.3, 16.2)] as [(CGFloat, CGFloat)] {
            let arm = NSBezierPath()
            arm.lineWidth = 0.8625
            arm.lineCapStyle = .round
            arm.move(to: NSPoint(x: 12.9, y: y))
            arm.line(to: NSPoint(x: endX, y: y))
            arm.stroke()
        }

        let tail = NSBezierPath()
        tail.lineWidth = 1.0875
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 11.6, y: 5.2))
        tail.line(to: NSPoint(x: 13.9, y: 3.1))
        tail.stroke()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "QuickEmoji"
        return image
    }
}
