import Foundation
import SelectionSpeakerCore

enum UserSettings {
    private static let translationEnabledKey = "translation.enabled"
    private static let modelNameKey = "translation.deepseek.modelName"
    private static let readingShortcutKey = "hotKey.reading"
    private static let translationShortcutKey = "hotKey.translation"
    private static let systemPromptKey = "translation.prompt.system"
    private static let userPromptTemplateKey = "translation.prompt.userTemplate"

    static let defaultModelName = "deepseek-v4-flash"

    static var isTranslationEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: translationEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: translationEnabledKey)
        }
    }

    static var modelName: String {
        get {
            let stored = UserDefaults.standard.string(forKey: modelNameKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stored?.isEmpty == false ? stored! : defaultModelName
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? defaultModelName : trimmed, forKey: modelNameKey)
        }
    }

    static var readingShortcut: HotKeyShortcut? {
        get {
            shortcut(forKey: readingShortcutKey)
        }
        set {
            setShortcut(newValue, forKey: readingShortcutKey)
        }
    }

    static var translationShortcut: HotKeyShortcut? {
        get {
            shortcut(forKey: translationShortcutKey)
        }
        set {
            setShortcut(newValue, forKey: translationShortcutKey)
        }
    }

    static var promptConfiguration: TranslationPromptConfiguration {
        TranslationPromptConfiguration(
            systemPrompt: systemPrompt,
            userPromptTemplate: userPromptTemplate
        )
    }

    static var systemPrompt: String {
        get {
            let stored = UserDefaults.standard.string(forKey: systemPromptKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stored?.isEmpty == false ? stored! : TranslationPromptBuilder.defaultSystemPrompt
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? TranslationPromptBuilder.defaultSystemPrompt : trimmed, forKey: systemPromptKey)
        }
    }

    static var userPromptTemplate: String {
        get {
            let stored = UserDefaults.standard.string(forKey: userPromptTemplateKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stored?.isEmpty == false ? stored! : TranslationPromptBuilder.defaultUserPromptTemplate
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? TranslationPromptBuilder.defaultUserPromptTemplate : trimmed, forKey: userPromptTemplateKey)
        }
    }

    static func restoreDefaultPrompts() {
        UserDefaults.standard.removeObject(forKey: systemPromptKey)
        UserDefaults.standard.removeObject(forKey: userPromptTemplateKey)
    }

    private static func shortcut(forKey key: String) -> HotKeyShortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(HotKeyShortcut.self, from: data)
    }

    private static func setShortcut(_ shortcut: HotKeyShortcut?, forKey key: String) {
        guard let shortcut else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
