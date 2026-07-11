import AppKit
import ApplicationServices
import AVFoundation
import SelectionSpeakerCore

private enum TranslationResultSpeechPolicy {
    case never
    case whenTranslationArrives
}

@MainActor
final class SelectionSpeakerApp: NSObject, NSApplicationDelegate {
    private static let selectionSettleDelay = Duration.milliseconds(80)
    private static let clipboardCopyDelay = Duration.milliseconds(120)

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let speaker = AVSpeechSynthesizer()
    private let keychainStore = KeychainCredentialStore()
    private let translationPopover = TranslationPopover()
    private lazy var preferencesWindowController = PreferencesWindowController { [weak self] in
        self?.restartGlobalShortcuts()
        self?.refreshMenu()
    }
    private var globalMouseMonitor: Any?
    private var globalHotKeyMonitor: GlobalHotKeyMonitor?
    private var globalPopoverDismissMonitor: Any?
    private var localPopoverDismissMonitor: Any?
    private var isEnabled = true
    private var isTranslationEnabled = UserSettings.isTranslationEnabled
    private var translationDirection = UserSettings.translationDirection
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
        restartGlobalShortcuts()
        startMonitoringPopoverDismissal()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        globalHotKeyMonitor?.stop()
        if let globalPopoverDismissMonitor {
            NSEvent.removeMonitor(globalPopoverDismissMonitor)
        }
        if let localPopoverDismissMonitor {
            NSEvent.removeMonitor(localPopoverDismissMonitor)
        }
        translationTask?.cancel()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.toolTip = "划词朗读器"
        }

        refreshMenu()
    }

    private func refreshMenu() {
        refreshStatusItemIcon()

        let menu = NSMenu()

        let enabledItem = NSMenuItem(
            title: "划词后自动朗读",
            action: #selector(toggleEnabled),
            keyEquivalent: UserSettings.readingShortcut?.keyEquivalent ?? ""
        )
        enabledItem.target = self
        enabledItem.keyEquivalentModifierMask = UserSettings.readingShortcut?.menuModifierMask ?? []
        enabledItem.state = isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let translationItem = NSMenuItem(
            title: "开启/关闭翻译",
            action: #selector(toggleTranslationEnabled),
            keyEquivalent: UserSettings.translationShortcut?.keyEquivalent ?? ""
        )
        translationItem.target = self
        translationItem.keyEquivalentModifierMask = UserSettings.translationShortcut?.menuModifierMask ?? []
        translationItem.state = isTranslationEnabled ? .on : .off
        menu.addItem(translationItem)

        let directionItem = NSMenuItem(
            title: "切换为\(translationDirection == .englishToChinese ? "中译英" : "英译中")模式",
            action: #selector(toggleTranslationDirection),
            keyEquivalent: UserSettings.translationDirectionShortcut?.keyEquivalent ?? ""
        )
        directionItem.target = self
        directionItem.keyEquivalentModifierMask = UserSettings.translationDirectionShortcut?.menuModifierMask ?? []
        menu.addItem(directionItem)

        let preferencesItem = NSMenuItem(
            title: "偏好设置...",
            action: #selector(showPreferences),
            keyEquivalent: ""
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

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

    private func refreshStatusItemIcon() {
        guard let button = statusItem.button else {
            return
        }

        button.image = StatusIconRenderer.image(
            readingEnabled: isEnabled,
            translationEnabled: isTranslationEnabled,
            translationDirection: translationDirection
        )
        let directionName = translationDirection == .englishToChinese ? "英译中" : "中译英"
        button.toolTip = "划词朗读器：朗读\(isEnabled ? "开" : "关")，翻译\(isTranslationEnabled ? "开" : "关")（\(directionName)）"
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

    private func restartGlobalShortcuts() {
        globalHotKeyMonitor?.stop()
        globalHotKeyMonitor = nil

        let registrations = configuredHotKeyRegistrations()
        guard !registrations.isEmpty else {
            return
        }

        let monitor = GlobalHotKeyMonitor(registrations: registrations) { [weak self] in
            self?.toggleEnabled()
        } onTranslationToggle: { [weak self] in
            self?.toggleTranslationEnabled()
        } onTranslationDirectionToggle: { [weak self] in
            self?.toggleTranslationDirection()
        }

        do {
            try monitor.start()
            globalHotKeyMonitor = monitor
        } catch {
            showMessage("全局快捷键不可用", informativeText: error.localizedDescription)
        }
    }

    private func configuredHotKeyRegistrations() -> [GlobalHotKeyMonitor.Registration] {
        var registrations: [GlobalHotKeyMonitor.Registration] = []

        if let shortcut = UserSettings.readingShortcut {
            registrations.append(.init(action: .toggleReading, shortcut: shortcut))
        }

        if let shortcut = UserSettings.translationShortcut {
            registrations.append(.init(action: .toggleTranslation, shortcut: shortcut))
        }

        if let shortcut = UserSettings.translationDirectionShortcut {
            registrations.append(.init(action: .toggleTranslationDirection, shortcut: shortcut))
        }

        return registrations
    }

    private func startMonitoringPopoverDismissal() {
        let mouseDownEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        globalPopoverDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseDownEvents) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.translationPopover.hide()
            }
        }

        localPopoverDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseDownEvents) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.translationPopover.hide()
            }
            return event
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

        var rawText = await settledSelectedTextFromFocusedElement()
        if rawText == nil {
            rawText = await copiedSelectedText()
        }

        guard let rawText else {
            return
        }

        guard isTranslationEnabled else {
            guard let text = SelectionTextNormalizer.normalizedText(from: rawText) else {
                return
            }
            speakIfNeeded(text)
            return
        }

        guard let plan = SelectionTranslationPlanner.plan(
            from: rawText,
            direction: translationDirection
        ) else {
            return
        }

        switch plan {
        case .speakOriginalAndTranslateToChinese(let text):
            speakIfNeeded(text)
            translateIfNeeded(
                text,
                direction: .englishToChinese,
                speechPolicy: .never,
                near: NSEvent.mouseLocation
            )
        case .translateToEnglishAndSpeakResult(let text):
            translateIfNeeded(
                text,
                direction: .chineseToEnglish,
                speechPolicy: .whenTranslationArrives,
                near: NSEvent.mouseLocation
            )
        }
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

    private func settledSelectedTextFromFocusedElement() async -> String? {
        let initial = selectedTextFromFocusedElement()
        try? await Task.sleep(for: Self.selectionSettleDelay)
        let settled = selectedTextFromFocusedElement()
        return SelectionTextStabilityResolver.preferredText(initial: initial, settled: settled)
    }

    private func copiedSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        let previousChangeCount = pasteboard.changeCount

        postCommandC()
        try? await Task.sleep(for: Self.clipboardCopyDelay)

        defer {
            snapshot.restore(to: pasteboard)
        }

        guard pasteboard.changeCount != previousChangeCount else {
            return nil
        }

        let initial = pasteboard.string(forType: .string)
        try? await Task.sleep(for: Self.selectionSettleDelay)
        let settled = pasteboard.string(forType: .string)
        return SelectionTextStabilityResolver.preferredText(initial: initial, settled: settled)
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

    private func speakIfNeeded(_ text: String) {
        guard isEnabled else {
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

    private func speak(_ text: String) {
        if speaker.isSpeaking {
            speaker.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.47
        speaker.speak(utterance)
    }

    private func translateIfNeeded(
        _ text: String,
        direction: TranslationDirection,
        speechPolicy: TranslationResultSpeechPolicy,
        near location: NSPoint
    ) {
        guard isTranslationEnabled else {
            return
        }

        if let cached = translationCache[text, direction] {
            translationPopover.show(text: cached, at: location)
            if speechPolicy == .whenTranslationArrives {
                speakIfNeeded(cached)
            }
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
        let promptConfiguration: TranslationPromptConfiguration
        if direction == .chineseToEnglish {
            promptConfiguration = TranslationPromptConfiguration(
                systemPrompt: TranslationPromptBuilder.chineseToEnglishSystemPrompt,
                userPromptTemplate: TranslationPromptBuilder.chineseToEnglishUserPromptTemplate
            )
        } else {
            promptConfiguration = UserSettings.promptConfiguration
        }

        translationPopover.showLoading(at: location)
        translationTask = Task { @MainActor in
            do {
                let client = DeepSeekTranslationClient(
                    apiKey: apiKey,
                    modelName: modelName,
                    promptConfiguration: promptConfiguration
                )
                let translation = try await client.translate(text)
                guard !Task.isCancelled, generation == translationGeneration else {
                    return
                }
                rememberTranslation(translation, for: text, direction: direction)
                translationPopover.show(text: translation, at: location)
                if speechPolicy == .whenTranslationArrives {
                    self.speakIfNeeded(translation)
                }
            } catch {
                guard !Task.isCancelled, generation == translationGeneration else {
                    return
                }
                translationPopover.showError(error.localizedDescription, at: location)
            }
        }
    }

    private func rememberTranslation(
        _ translation: String,
        for text: String,
        direction: TranslationDirection
    ) {
        translationCache.store(translation, for: text, direction: direction)
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
            translationGeneration += 1
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

    @objc private func toggleTranslationDirection() {
        translationDirection = translationDirection == .englishToChinese
            ? .chineseToEnglish
            : .englishToChinese
        UserSettings.translationDirection = translationDirection
        translationTask?.cancel()
        translationGeneration += 1
        speaker.stopSpeaking(at: .immediate)
        translationPopover.hide()
        refreshMenu()
    }

    @objc private func setDeepSeekAPIKey() {
        _ = promptForAPIKey()
        refreshMenu()
    }

    @objc private func showPreferences() {
        preferencesWindowController.show()
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
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
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
