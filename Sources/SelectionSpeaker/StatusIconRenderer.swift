import AppKit

@MainActor
enum StatusIconRenderer {
    static func image(readingEnabled: Bool, translationEnabled: Bool) -> NSImage {
        let size = NSSize(width: 28, height: 22)
        let image = NSImage(size: size, flipped: false) { _ in
            NSGraphicsContext.current?.imageInterpolation = .high

            drawTranslationMark(in: NSRect(x: 3, y: 4.5, width: 20, height: 16))
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

    private static func drawTranslationMark(in rect: NSRect) {
        let color = primaryIconColor
        let bubble = NSBezierPath(
            roundedRect: NSRect(x: rect.minX + 2, y: rect.minY + 3, width: 15, height: 11),
            xRadius: 3,
            yRadius: 3
        )
        color.setFill()
        bubble.fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: rect.minX + 8, y: rect.minY + 4))
        tail.line(to: NSPoint(x: rect.minX + 6, y: rect.minY + 1))
        tail.line(to: NSPoint(x: rect.minX + 12, y: rect.minY + 4))
        tail.close()
        color.setFill()
        tail.fill()

        let letter = NSAttributedString(
            string: "A",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 8.5),
                .foregroundColor: cutoutColor
            ]
        )
        letter.draw(at: NSPoint(x: rect.minX + 6.4, y: rect.minY + 4.1))

        color.withAlphaComponent(0.9).setStroke()
        let accent = NSBezierPath()
        accent.move(to: NSPoint(x: rect.minX + 17.2, y: rect.minY + 13.2))
        accent.line(to: NSPoint(x: rect.minX + 20.5, y: rect.minY + 13.2))
        accent.move(to: NSPoint(x: rect.minX + 18.8, y: rect.minY + 14.8))
        accent.line(to: NSPoint(x: rect.minX + 18.8, y: rect.minY + 10.4))
        accent.lineWidth = 1.6
        accent.lineCapStyle = .round
        accent.stroke()
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

    private static var primaryIconColor: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .labelColor
    }

    private static var cutoutColor: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .black : .windowBackgroundColor
    }
}
