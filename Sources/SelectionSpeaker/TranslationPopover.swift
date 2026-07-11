import AppKit
import SelectionSpeakerCore

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
        let layout = PopoverTextLayout.layout(for: text, font: font)
        let panel = window ?? makeWindow()
        panel.setContentSize(layout.windowSize)
        panel.contentView = makeContentView(text: text, layout: layout, font: font)
        panel.setFrameOrigin(Self.origin(near: location, size: layout.windowSize))
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

    private func makeContentView(text: String, layout: PopoverTextLayout, font: NSFont) -> NSView {
        let root = NSView(frame: NSRect(origin: .zero, size: layout.windowSize))
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
        label.frame = layout.textFrame
        label.font = font
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 12
        label.cell?.wraps = true
        label.cell?.usesSingleLineMode = false
        label.cell?.isScrollable = false

        container.addSubview(label)
        root.addSubview(container)
        return root
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
