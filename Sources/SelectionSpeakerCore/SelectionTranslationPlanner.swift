import Foundation

public enum TranslationDirection: String, Codable, Hashable, Sendable {
    case englishToChinese
    case chineseToEnglish
}

public enum SelectionTranslationPlan: Equatable, Sendable {
    case speakOriginalAndTranslateToChinese(text: String)
    case translateToEnglishAndSpeakResult(text: String)
}

public enum SelectionTranslationPlanner {
    public static func plan(
        from rawText: String,
        direction: TranslationDirection,
        maxCharacters: Int = 500
    ) -> SelectionTranslationPlan? {
        let allowsChinese = direction == .chineseToEnglish
        guard let text = SelectionTextNormalizer.normalizedText(
            from: rawText,
            allowsChinese: allowsChinese,
            maxCharacters: maxCharacters
        ) else {
            return nil
        }

        guard direction == .chineseToEnglish,
              SelectionTextNormalizer.containsCJKIdeograph(in: text) else {
            return .speakOriginalAndTranslateToChinese(text: text)
        }

        return .translateToEnglishAndSpeakResult(text: text)
    }
}
