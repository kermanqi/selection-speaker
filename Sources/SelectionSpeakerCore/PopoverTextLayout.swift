import AppKit

@MainActor
public struct PopoverTextLayout {
    public let windowSize: NSSize
    public let textFrame: NSRect
    public let requiredTextSize: NSSize

    public static func layout(for text: String, font: NSFont) -> PopoverTextLayout {
        let cell = textCell(text: text, font: font)
        let naturalSize = cell.cellSize(
            forBounds: NSRect(
                x: 0,
                y: 0,
                width: maxTextWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        let textWidth = min(
            maxTextWidth,
            max(minTextWidth, ceil(naturalSize.width) + textWidthSafetyMargin)
        )
        let requiredTextSize = cell.cellSize(
            forBounds: NSRect(
                x: 0,
                y: 0,
                width: textWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        let windowHeight = min(
            maxTextHeight + verticalPadding,
            max(minWindowHeight, ceil(requiredTextSize.height) + verticalPadding)
        )

        return PopoverTextLayout(
            windowSize: NSSize(width: textWidth + horizontalPadding, height: windowHeight),
            textFrame: NSRect(
                x: horizontalPadding / 2,
                y: verticalPadding / 2,
                width: textWidth,
                height: windowHeight - verticalPadding
            ),
            requiredTextSize: requiredTextSize
        )
    }

    private static func textCell(text: String, font: NSFont) -> NSTextFieldCell {
        let cell = NSTextFieldCell(textCell: text)
        cell.font = font
        cell.wraps = true
        cell.usesSingleLineMode = false
        cell.isScrollable = false
        cell.lineBreakMode = .byWordWrapping
        return cell
    }

    private static let maxTextWidth: CGFloat = 330
    private static let minTextWidth: CGFloat = 100
    private static let maxTextHeight: CGFloat = 280
    private static let horizontalPadding: CGFloat = 28
    private static let verticalPadding: CGFloat = 24
    private static let minWindowHeight: CGFloat = 44
    private static let textWidthSafetyMargin: CGFloat = 8
}
