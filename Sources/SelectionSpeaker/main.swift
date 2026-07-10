import AppKit
import ApplicationServices
import AVFoundation
import SelectionSpeakerCore

@MainActor
final class SelectionSpeakerApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let speaker = AVSpeechSynthesizer()
    private let keychainStore = KeychainCredentialStore()
    private let translationPopover = TranslationPopover()
    private var globalMouseMonitor: Any?
    private var globalKeyMonitor: Any?
    private var isEnabled = true
    private var isTranslationEnabled = UserSettings.isTranslationEnabled
    private var lastSpokenText = ""
    private var lastSpokenAt = Date.distantPast
    private var lastMouseDownLocation: NSPoint?
    private var translationTask: Task<Void, Never>?
    private var translationGeneration = 0
    private var translationCache = TranslationCache(limit: 80)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        speaker.delegate = self
        configureStatusItem()
        requestAccessibilityPermissionIfNeeded()
        startMonitoringSelection()
        startMonitoringTranslationShortcut()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        translationTask?.cancel()
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

        let translationItem = NSMenuItem(
            title: "显示中文翻译",
            action: #selector(toggleTranslationEnabled),
            keyEquivalent: "t"
        )
        translationItem.target = self
        translationItem.keyEquivalentModifierMask = [.option]
        translationItem.state = isTranslationEnabled ? .on : .off
        menu.addItem(translationItem)

        let apiKeyItem = NSMenuItem(
            title: "设置 DeepSeek API Key...",
            action: #selector(setDeepSeekAPIKey),
            keyEquivalent: ""
        )
        apiKeyItem.target = self
        menu.addItem(apiKeyItem)

        let modelItem = NSMenuItem(
            title: "设置 DeepSeek 模型...",
            action: #selector(setDeepSeekModel),
            keyEquivalent: ""
        )
        modelItem.target = self
        menu.addItem(modelItem)

        menu.addItem(.separator())

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

    private func startMonitoringTranslationShortcut() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 17 else {
                return
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == .option else {
                return
            }

            Task { @MainActor [weak self] in
                self?.toggleTranslationEnabled()
            }
        }
    }

    private func handleGlobalMouseEvent(isMouseDown: Bool, clickCount: Int, location: NSPoint) {
        if isMouseDown {
            lastMouseDownLocation = location
            return
        }

        guard isEnabled || isTranslationEnabled else {
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

        if isEnabled {
            let now = Date()
            if text != lastSpokenText || now.timeIntervalSince(lastSpokenAt) > 1.2 {
                lastSpokenText = text
                lastSpokenAt = now
                speak(text)
            }
        }

        translateIfNeeded(text, near: NSEvent.mouseLocation)
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

    private func translateIfNeeded(_ text: String, near location: NSPoint) {
        guard isTranslationEnabled else {
            return
        }

        if let cached = translationCache[text] {
            translationPopover.show(text: cached, at: location)
            return
        }

        let apiKey: String
        do {
            guard let storedAPIKey = try keychainStore.apiKey(), !storedAPIKey.isEmpty else {
                isTranslationEnabled = false
                UserSettings.isTranslationEnabled = false
                refreshMenu()
                translationPopover.showError("请先设置 DeepSeek API Key", at: location)
                return
            }
            apiKey = storedAPIKey
        } catch {
            isTranslationEnabled = false
            UserSettings.isTranslationEnabled = false
            refreshMenu()
            translationPopover.showError(error.localizedDescription, at: location)
            return
        }

        translationTask?.cancel()
        translationGeneration += 1
        let generation = translationGeneration
        let modelName = UserSettings.modelName

        translationPopover.showLoading(at: location)
        translationTask = Task { @MainActor in
            do {
                let client = DeepSeekTranslationClient(apiKey: apiKey, modelName: modelName)
                let translation = try await client.translate(text)
                guard !Task.isCancelled, generation == translationGeneration else {
                    return
                }
                rememberTranslation(translation, for: text)
                translationPopover.show(text: translation, at: location)
            } catch {
                guard !Task.isCancelled, generation == translationGeneration else {
                    return
                }
                translationPopover.showError(error.localizedDescription, at: location)
            }
        }
    }

    private func rememberTranslation(_ translation: String, for text: String) {
        translationCache.store(translation, for: text)
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        if !isEnabled {
            speaker.stopSpeaking(at: .immediate)
        }
        refreshMenu()
    }

    @objc private func toggleTranslationEnabled() {
        if isTranslationEnabled {
            isTranslationEnabled = false
            UserSettings.isTranslationEnabled = false
            translationTask?.cancel()
            translationPopover.hide()
            refreshMenu()
            return
        }

        guard ensureAPIKeyIsConfigured() else {
            return
        }

        isTranslationEnabled = true
        UserSettings.isTranslationEnabled = true
        refreshMenu()
    }

    @objc private func setDeepSeekAPIKey() {
        _ = promptForAPIKey()
        refreshMenu()
    }

    @objc private func setDeepSeekModel() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.stringValue = UserSettings.modelName

        let alert = NSAlert()
        alert.messageText = "设置 DeepSeek 模型"
        alert.informativeText = "默认使用 \(UserSettings.defaultModelName)。如果 DeepSeek 更换模型名，可以在这里修改。"
        alert.accessoryView = field
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            UserSettings.modelName = field.stringValue
        }
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

    private func ensureAPIKeyIsConfigured() -> Bool {
        if keychainStore.hasAPIKey() {
            return true
        }

        return promptForAPIKey()
    }

    private func promptForAPIKey() -> Bool {
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.placeholderString = "sk-..."

        let alert = NSAlert()
        alert.messageText = "设置 DeepSeek API Key"
        alert.informativeText = "API Key 会保存到 macOS Keychain。开启中文翻译后，划选文本会发送到 DeepSeek API。"
        alert.accessoryView = field
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }

        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            showMessage("API Key 不能为空", informativeText: "请重新打开菜单设置 DeepSeek API Key。")
            return false
        }

        do {
            try keychainStore.saveAPIKey(key)
            return true
        } catch {
            showMessage("保存 API Key 失败", informativeText: error.localizedDescription)
            return false
        }
    }

    private func showMessage(_ messageText: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.addButton(withTitle: "好")
        alert.runModal()
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
