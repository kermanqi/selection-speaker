import AppKit
import ApplicationServices
import AVFoundation
import SelectionSpeakerCore

@MainActor
final class SelectionSpeakerApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let speaker = AVSpeechSynthesizer()
    private var globalMouseMonitor: Any?
    private var isEnabled = true
    private var lastSpokenText = ""
    private var lastSpokenAt = Date.distantPast
    private var lastMouseDownLocation: NSPoint?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        speaker.delegate = self
        configureStatusItem()
        requestAccessibilityPermissionIfNeeded()
        startMonitoringSelection()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "speaker.wave.2.fill",
                accessibilityDescription: "Selection Speaker"
            )
            button.toolTip = "划词朗读器"
        }

        refreshMenu()
    }

    private func refreshMenu() {
        let menu = NSMenu()

        let enabledItem = NSMenuItem(
            title: "划词后自动朗读",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let stopItem = NSMenuItem(
            title: "停止朗读",
            action: #selector(stopSpeaking),
            keyEquivalent: ""
        )
        stopItem.target = self
        menu.addItem(stopItem)

        menu.addItem(.separator())

        let permissionItem = NSMenuItem(
            title: "打开辅助功能设置...",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func startMonitoringSelection() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            let isMouseDown = event.type == .leftMouseDown
            let clickCount = event.clickCount
            let location = NSEvent.mouseLocation

            Task { @MainActor [weak self] in
                self?.handleGlobalMouseEvent(
                    isMouseDown: isMouseDown,
                    clickCount: clickCount,
                    location: location
                )
            }
        }
    }

    private func handleGlobalMouseEvent(isMouseDown: Bool, clickCount: Int, location: NSPoint) {
        if isMouseDown {
            lastMouseDownLocation = location
            return
        }

        guard isEnabled else {
            return
        }

        let distance = lastMouseDownLocation.map { hypot(location.x - $0.x, location.y - $0.y) } ?? 0
        guard distance > 4 || clickCount >= 2 else {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            await speakCurrentSelectionIfNeeded()
        }
    }

    private func speakCurrentSelectionIfNeeded() async {
        guard AXIsProcessTrusted() else {
            return
        }

        var rawText = selectedTextFromFocusedElement()
        if rawText == nil {
            rawText = await copiedSelectedText()
        }

        guard let rawText,
              let text = SelectionTextNormalizer.normalizedText(from: rawText) else {
            return
        }

        let now = Date()
        guard text != lastSpokenText || now.timeIntervalSince(lastSpokenAt) > 1.2 else {
            return
        }

        lastSpokenText = text
        lastSpokenAt = now
        speak(text)
    }

    private func selectedTextFromFocusedElement() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedObject: AnyObject?

        let focusedResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard focusedResult == .success,
              let focusedElement = focusedObject else {
            return nil
        }

        var selectedTextObject: AnyObject?
        let selectedTextResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextObject
        )

        guard selectedTextResult == .success else {
            return nil
        }

        return selectedTextObject as? String
    }

    private func copiedSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        let previousChangeCount = pasteboard.changeCount

        postCommandC()
        try? await Task.sleep(for: .milliseconds(90))

        defer {
            snapshot.restore(to: pasteboard)
        }

        guard pasteboard.changeCount != previousChangeCount else {
            return nil
        }

        return pasteboard.string(forType: .string)
    }

    private func postCommandC() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func speak(_ text: String) {
        if speaker.isSpeaking {
            speaker.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.47
        speaker.speak(utterance)
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        if !isEnabled {
            speaker.stopSpeaking(at: .immediate)
        }
        refreshMenu()
    }

    @objc private func stopSpeaking() {
        speaker.stopSpeaking(at: .immediate)
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension SelectionSpeakerApp: AVSpeechSynthesizerDelegate {}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            Dictionary(
                uniqueKeysWithValues: item.types.compactMap { type in
                    item.data(forType: type).map { (type, $0) }
                }
            )
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        let restoredItems = items.map { storedTypes in
            let item = NSPasteboardItem()
            for (type, data) in storedTypes {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }
}

let app = NSApplication.shared
let delegate = SelectionSpeakerApp()
app.delegate = delegate
app.run()
