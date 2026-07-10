import AppKit
import SelectionSpeakerCore

@MainActor
final class PreferencesWindowController: NSWindowController {
    private let onShortcutsChanged: @MainActor () -> Void
    private let readingButton = NSButton()
    private let translationButton = NSButton()
    private let systemPromptTextView = NSTextView()
    private let userPromptTemplateTextView = NSTextView()

    init(onShortcutsChanged: @escaping @MainActor () -> Void) {
        self.onShortcutsChanged = onShortcutsChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 720),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "偏好设置"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.contentView = makeContentView()
        refreshControls()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        guard let window else {
            return
        }

        refreshShortcutButtons()
        refreshPromptTextViews()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeContentView() -> NSView {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 720))

        let title = NSTextField(labelWithString: "快捷键")
        title.font = .boldSystemFont(ofSize: 18)
        title.frame = NSRect(x: 34, y: 672, width: 240, height: 24)
        content.addSubview(title)

        let note = NSTextField(labelWithString: "点击“录制快捷键”后，直接按下你想用的组合。建议至少两个修饰键，避免和浏览器、输入法或系统快捷键冲突。")
        note.font = .systemFont(ofSize: 13)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 34, y: 626, width: 572, height: 40)
        note.lineBreakMode = .byWordWrapping
        note.maximumNumberOfLines = 2
        content.addSubview(note)

        let shortcutSeparator = NSBox(frame: NSRect(x: 34, y: 608, width: 572, height: 1))
        shortcutSeparator.boxType = .separator
        content.addSubview(shortcutSeparator)

        addShortcutRow(
            to: content,
            y: 556,
            title: "划词后自动朗读",
            button: readingButton,
            recordAction: #selector(recordReadingShortcut),
            clearAction: #selector(clearReadingShortcut)
        )

        addShortcutRow(
            to: content,
            y: 508,
            title: "显示中文翻译",
            button: translationButton,
            recordAction: #selector(recordTranslationShortcut),
            clearAction: #selector(clearTranslationShortcut)
        )

        let footer = NSTextField(labelWithString: "如果保存后提示快捷键不可用，通常说明这个组合已被其他 App 或系统占用。")
        footer.font = .systemFont(ofSize: 12)
        footer.textColor = .secondaryLabelColor
        footer.frame = NSRect(x: 34, y: 470, width: 572, height: 20)
        content.addSubview(footer)

        let promptTitle = NSTextField(labelWithString: "翻译提示词")
        promptTitle.font = .boldSystemFont(ofSize: 18)
        promptTitle.frame = NSRect(x: 34, y: 432, width: 240, height: 24)
        content.addSubview(promptTitle)

        let promptNote = NSTextField(labelWithString: "你可以把这里的提示词复制给其他 AI 修改。用户提示词模板必须保留 {selectedText}，App 会把划选文本填进去。")
        promptNote.font = .systemFont(ofSize: 13)
        promptNote.textColor = .secondaryLabelColor
        promptNote.frame = NSRect(x: 34, y: 388, width: 572, height: 36)
        promptNote.lineBreakMode = .byWordWrapping
        promptNote.maximumNumberOfLines = 2
        content.addSubview(promptNote)

        addPromptEditor(
            to: content,
            title: "系统提示词",
            textView: systemPromptTextView,
            frame: NSRect(x: 34, y: 142, width: 572, height: 230)
        )

        addPromptEditor(
            to: content,
            title: "用户提示词模板",
            textView: userPromptTemplateTextView,
            frame: NSRect(x: 34, y: 50, width: 572, height: 70)
        )

        let restoreButton = NSButton(title: "恢复默认提示词", target: self, action: #selector(restoreDefaultPrompts))
        restoreButton.bezelStyle = .rounded
        restoreButton.frame = NSRect(x: 34, y: 12, width: 128, height: 28)
        content.addSubview(restoreButton)

        let saveButton = NSButton(title: "保存提示词", target: self, action: #selector(savePrompts))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: 478, y: 12, width: 128, height: 28)
        content.addSubview(saveButton)

        return content
    }

    private func addShortcutRow(
        to content: NSView,
        y: CGFloat,
        title: String,
        button: NSButton,
        recordAction: Selector,
        clearAction: Selector
    ) {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.frame = NSRect(x: 34, y: y + 6, width: 170, height: 20)
        content.addSubview(label)

        button.bezelStyle = .rounded
        button.target = self
        button.action = recordAction
        button.frame = NSRect(x: 224, y: y, width: 160, height: 32)
        content.addSubview(button)

        let clearButton = NSButton(title: "清空", target: self, action: clearAction)
        clearButton.bezelStyle = .rounded
        clearButton.frame = NSRect(x: 394, y: y + 2, width: 58, height: 28)
        content.addSubview(clearButton)
    }

    private func addPromptEditor(
        to content: NSView,
        title: String,
        textView: NSTextView,
        frame: NSRect
    ) {
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: frame.minX, y: frame.maxY + 6, width: frame.width, height: 18)
        content.addSubview(label)

        let scrollView = NSScrollView(frame: frame)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .bezelBorder

        textView.frame = scrollView.contentView.bounds
        textView.autoresizingMask = [.width]
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.minSize = NSSize(width: 0, height: frame.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: frame.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 8, height: 8)

        scrollView.documentView = textView
        content.addSubview(scrollView)
    }

    private func refreshControls() {
        refreshShortcutButtons()
        refreshPromptTextViews()
    }

    private func refreshShortcutButtons() {
        readingButton.title = UserSettings.readingShortcut?.displayString ?? "录制快捷键"
        translationButton.title = UserSettings.translationShortcut?.displayString ?? "录制快捷键"
    }

    private func refreshPromptTextViews() {
        systemPromptTextView.string = UserSettings.systemPrompt
        userPromptTemplateTextView.string = UserSettings.userPromptTemplate
        scrollToBeginning(systemPromptTextView)
        scrollToBeginning(userPromptTemplateTextView)
    }

    private func scrollToBeginning(_ textView: NSTextView) {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    @objc private func recordReadingShortcut() {
        recordShortcut(title: "设置朗读快捷键") { shortcut in
            guard shortcut != UserSettings.translationShortcut else {
                throw HotKeyShortcutError.duplicatedShortcut
            }
            UserSettings.readingShortcut = shortcut
        }
    }

    @objc private func recordTranslationShortcut() {
        recordShortcut(title: "设置翻译快捷键") { shortcut in
            guard shortcut != UserSettings.readingShortcut else {
                throw HotKeyShortcutError.duplicatedShortcut
            }
            UserSettings.translationShortcut = shortcut
        }
    }

    @objc private func clearReadingShortcut() {
        UserSettings.readingShortcut = nil
        shortcutSettingsChanged()
    }

    @objc private func clearTranslationShortcut() {
        UserSettings.translationShortcut = nil
        shortcutSettingsChanged()
    }

    @objc private func savePrompts() {
        let template = userPromptTemplateTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard template.contains(TranslationPromptBuilder.selectedTextPlaceholder) else {
            showMessage("用户提示词模板缺少占位符", informativeText: "请保留 {selectedText}，App 会把划选文本填到这个位置。")
            return
        }

        UserSettings.systemPrompt = systemPromptTextView.string
        UserSettings.userPromptTemplate = template
        showMessage("提示词已保存", informativeText: "下一次翻译会使用新的提示词。")
    }

    @objc private func restoreDefaultPrompts() {
        UserSettings.restoreDefaultPrompts()
        refreshPromptTextViews()
        showMessage("已恢复默认提示词", informativeText: "文本框里现在就是内置默认提示词，可以直接复制。")
    }

    private func recordShortcut(
        title: String,
        save: (HotKeyShortcut) throws -> Void
    ) {
        guard let shortcut = ShortcutRecorderPanel(title: title).recordShortcut() else {
            return
        }

        do {
            try save(shortcut)
            shortcutSettingsChanged()
        } catch {
            showMessage("快捷键不可用", informativeText: error.localizedDescription)
        }
    }

    private func shortcutSettingsChanged() {
        refreshShortcutButtons()
        onShortcutsChanged()
    }

    private func showMessage(_ messageText: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.addButton(withTitle: "好")
        if let window {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }
}

@MainActor
private final class ShortcutRecorderPanel {
    private let title: String

    init(title: String) {
        self.title = title
    }

    func recordShortcut() -> HotKeyShortcut? {
        var capturedShortcut: HotKeyShortcut?

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 180),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.isReleasedWhenClosed = false
        panel.center()

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 180))
        let titleLabel = NSTextField(labelWithString: "请按下新的快捷键")
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 30, y: 128, width: 360, height: 24)
        content.addSubview(titleLabel)

        let statusLabel = NSTextField(labelWithString: "至少包含两个修饰键，例如 Control + Shift + R。")
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 30, y: 92, width: 360, height: 20)
        content.addSubview(statusLabel)

        let captureView = ShortcutCaptureView(frame: NSRect(x: 94, y: 48, width: 232, height: 36)) { result in
            switch result {
            case .success(let shortcut):
                capturedShortcut = shortcut
                NSApp.stopModal(withCode: .OK)
            case .failure(let error):
                statusLabel.stringValue = error.localizedDescription
                NSSound.beep()
            }
        }
        content.addSubview(captureView)

        let cancelTarget = ModalButtonTarget {
            NSApp.stopModal(withCode: .cancel)
        }
        let cancelButton = NSButton(title: "取消", target: cancelTarget, action: #selector(ModalButtonTarget.runAction))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 170, y: 12, width: 80, height: 28)
        content.addSubview(cancelButton)

        panel.contentView = content
        panel.makeFirstResponder(captureView)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let response = NSApp.runModal(for: panel)
        panel.close()

        guard response == .OK else {
            return nil
        }
        return capturedShortcut
    }
}

@MainActor
private final class ModalButtonTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func runAction() {
        action()
    }
}

@MainActor
private final class ShortcutCaptureView: NSView {
    private let onShortcut: (Result<HotKeyShortcut, Error>) -> Void
    private let label = NSTextField(labelWithString: "Record Shortcut")

    init(
        frame frameRect: NSRect,
        onShortcut: @escaping (Result<HotKeyShortcut, Error>) -> Void
    ) {
        self.onShortcut = onShortcut
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.frame = bounds.insetBy(dx: 10, dy: 8)
        label.autoresizingMask = [.width, .height]
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        do {
            let shortcut = try HotKeyShortcut.from(event: event)
            label.stringValue = shortcut.displayString
            onShortcut(.success(shortcut))
        } catch {
            onShortcut(.failure(error))
        }
    }
}
