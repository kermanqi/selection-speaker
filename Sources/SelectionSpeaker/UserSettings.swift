import Foundation

enum UserSettings {
    private static let translationEnabledKey = "translation.enabled"
    private static let modelNameKey = "translation.deepseek.modelName"
    private static let readingShortcutKey = "hotKey.reading"
    private static let translationShortcutKey = "hotKey.translation"

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
