import AppKit

enum StatusIconRenderer {
    static func image(readingEnabled: Bool, translationEnabled: Bool) -> NSImage {
        let size = NSSize(width: 28, height: 22)
        let image = NSImage(size: size, flipped: false) { _ in
            NSGraphicsContext.current?.imageInterpolation = .high

            drawSpeaker(in: NSRect(x: 3, y: 4, width: 19, height: 16))
            drawStatusDot(
                center: NSPoint(x: 7, y: 4.5),
                color: readingEnabled ? .systemYellow : offColor
            )
            drawStatusDot(
                center: NSPoint(x: 21, y: 4.5),
                color: translationEnabled ? .systemGreen : offColor
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawSpeaker(in rect: NSRect) {
        guard let symbol = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold)) else {
            return
        }

        NSColor.labelColor.set()
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.92)
    }

    private static func drawStatusDot(center: NSPoint, color: NSColor) {
        let radius: CGFloat = 3.8
        let rect = NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let path = NSBezierPath(ovalIn: rect)

        NSColor.windowBackgroundColor.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1.4
        path.stroke()

        color.setFill()
        path.fill()
    }

    private static var offColor: NSColor {
        NSColor.secondaryLabelColor.withAlphaComponent(0.55)
    }
}
