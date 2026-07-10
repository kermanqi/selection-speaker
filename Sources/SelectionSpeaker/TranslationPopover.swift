import AppKit

@MainActor
final class TranslationPopover {
    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?

    func showLoading(at location: NSPoint) {
        show("翻译中...", at: location, autoDismissAfter: nil)
    }

    func show(text: String, at location: NSPoint, autoDismissAfter seconds: TimeInterval? = nil) {
        show(text, at: location, autoDismissAfter: seconds)
    }

    func showError(_ message: String, at location: NSPoint) {
        show(message, at: location, autoDismissAfter: 4)
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        window?.orderOut(nil)
    }

    private func show(_ text: String, at location: NSPoint, autoDismissAfter seconds: TimeInterval?) {
        dismissTask?.cancel()

        let font = NSFont.systemFont(ofSize: 14)
        let size = Self.windowSize(for: text, font: font)
        let panel = window ?? makeWindow()
        panel.setContentSize(size)
        panel.contentView = makeContentView(text: text, size: size, font: font)
        panel.setFrameOrigin(Self.origin(near: location, size: size))
        panel.orderFrontRegardless()
        window = panel

        if let seconds {
            dismissTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
                hide()
            }
        }
    }

    private func makeWindow() -> NSWindow {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }

    private func makeContentView(text: String, size: NSSize, font: NSFont) -> NSView {
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor

        let container = NSView(frame: root.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let effectView = NSVisualEffectView(frame: container.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        container.addSubview(effectView)

        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: 14, y: 12, width: size.width - 28, height: size.height - 24)
        label.font = font
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 12
        label.cell?.wraps = true
        label.cell?.isScrollable = false

        container.addSubview(label)
        root.addSubview(container)
        return root
    }

    private static func windowSize(for text: String, font: NSFont) -> NSSize {
        let maxTextWidth: CGFloat = 330
        let minTextWidth: CGFloat = 120
        let maxTextHeight: CGFloat = 280
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let bounds = attributed.boundingRect(
            with: NSSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let width = min(360, max(minTextWidth, ceil(bounds.width) + 28))
        let height = min(maxTextHeight + 24, max(44, ceil(bounds.height) + 24))
        return NSSize(width: width, height: height)
    }

    private static func origin(near location: NSPoint, size: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 10

        var x = location.x + 14
        var y = location.y - size.height - 14

        if x + size.width > visibleFrame.maxX - margin {
            x = visibleFrame.maxX - size.width - margin
        }
        if x < visibleFrame.minX + margin {
            x = visibleFrame.minX + margin
        }
        if y < visibleFrame.minY + margin {
            y = location.y + 18
        }
        if y + size.height > visibleFrame.maxY - margin {
            y = visibleFrame.maxY - size.height - margin
        }

        return NSPoint(x: x, y: y)
    }
}
