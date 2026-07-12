import AppKit
import CoreGraphics

@MainActor
final class ScreenTextCaptureOverlay {
    struct Selection {
        let screenRect: NSRect
        let resultLocation: NSPoint
    }

    private var panel: NSPanel?
    private var escapeMonitor: Any?
    private var onSelection: ((Selection) -> Void)?
    private var onCancel: (() -> Void)?

    var isCapturing: Bool {
        panel != nil
    }

    func begin(
        at location: NSPoint,
        onSelection: @escaping (Selection) -> Void,
        onCancel: @escaping () -> Void
    ) -> Bool {
        guard !isCapturing,
              Self.hasScreenRecordingAccess(),
              let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) ?? NSScreen.main else {
            return false
        }

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false

        let captureView = ScreenTextCaptureView(frame: NSRect(origin: .zero, size: screen.frame.size)) { [weak self, weak panel] rect in
            guard let self, let panel else {
                return
            }
            let screenRect = NSRect(
                x: panel.frame.minX + rect.minX,
                y: panel.frame.minY + rect.minY,
                width: rect.width,
                height: rect.height
            )
            self.finish(with: Selection(screenRect: screenRect, resultLocation: NSEvent.mouseLocation))
        } onCancel: { [weak self] in
            self?.cancel()
        }
        panel.contentView = captureView
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(captureView)

        self.panel = panel
        self.onSelection = onSelection
        self.onCancel = onCancel
        installEscapeMonitor()
        return true
    }

    func cancel() {
        guard isCapturing else {
            return
        }

        let onCancel = self.onCancel
        dismiss()
        onCancel?()
    }

    static func hasScreenRecordingAccess() -> Bool {
        CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess()
    }

    static func captureImage(in screenRect: NSRect) -> CGImage? {
        CGWindowListCreateImage(
            screenRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        )
    }

    private func finish(with selection: Selection) {
        guard isCapturing else {
            return
        }

        let onSelection = self.onSelection
        dismiss()
        onSelection?(selection)
    }

    private func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        onSelection = nil
        onCancel = nil

        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else {
                return
            }
            Task { @MainActor [weak self] in
                self?.cancel()
            }
        }
    }
}

@MainActor
private final class ScreenTextCaptureView: NSView {
    private let onSelection: (NSRect) -> Void
    private let onCancel: () -> Void
    private var startPoint: NSPoint?
    private var selectedRect: NSRect?

    init(
        frame frameRect: NSRect,
        onSelection: @escaping (NSRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSelection = onSelection
        self.onCancel = onCancel
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        let shade = NSColor.black.withAlphaComponent(0.26)
        shade.setFill()

        let path = NSBezierPath(rect: bounds)
        if let selectedRect {
            path.appendRect(selectedRect)
            path.windingRule = .evenOdd
        }
        path.fill()

        if let selectedRect {
            NSColor.white.withAlphaComponent(0.9).setStroke()
            let border = NSBezierPath(rect: selectedRect.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 1
            border.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectedRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        updateSelection(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        updateSelection(with: event)
        guard let selectedRect,
              selectedRect.width >= 4,
              selectedRect.height >= 4 else {
            onCancel()
            return
        }
        onSelection(selectedRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    private func updateSelection(with event: NSEvent) {
        guard let startPoint else {
            return
        }
        let currentPoint = convert(event.locationInWindow, from: nil)
        selectedRect = NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
        needsDisplay = true
    }
}
