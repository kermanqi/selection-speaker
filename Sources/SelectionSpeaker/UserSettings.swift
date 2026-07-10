import Foundation

enum UserSettings {
    private static let translationEnabledKey = "translation.enabled"
    private static let modelNameKey = "translation.deepseek.modelName"

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
}
