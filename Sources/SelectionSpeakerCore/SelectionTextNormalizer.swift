import Foundation

public enum SelectionTextNormalizer {
    private static let zeroWidthCharacters = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
    private static let englishLetterPattern = try! NSRegularExpression(pattern: #"[A-Za-z]"#)
    private static let whitespacePattern = try! NSRegularExpression(pattern: #"\s+"#)

    public static func normalizedText(from selectedText: String, maxCharacters: Int = 500) -> String? {
        let withoutZeroWidth = selectedText
            .components(separatedBy: zeroWidthCharacters)
            .joined()

        let trimmed = withoutZeroWidth.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard englishLetterPattern.firstMatch(in: trimmed, range: range) != nil else {
            return nil
        }

        let collapsed = whitespacePattern.stringByReplacingMatches(
            in: trimmed,
            range: range,
            withTemplate: " "
        )

        if collapsed.count <= maxCharacters {
            return collapsed
        }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: maxCharacters)
        return String(collapsed[..<endIndex])
    }
}
