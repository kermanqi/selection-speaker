import Foundation

public struct TranslationCache {
    private struct Key: Hashable {
        let text: String
        let direction: TranslationDirection
    }

    private let limit: Int
    private var values: [Key: String] = [:]
    private var keys: [Key] = []

    public init(limit: Int) {
        self.limit = limit
    }

    public subscript(text: String, direction: TranslationDirection) -> String? {
        values[Key(text: text, direction: direction)]
    }

    public mutating func store(
        _ translation: String,
        for text: String,
        direction: TranslationDirection
    ) {
        let key = Key(text: text, direction: direction)
        if values[key] == nil {
            keys.append(key)
        }
        values[key] = translation

        while keys.count > limit {
            let oldest = keys.removeFirst()
            values.removeValue(forKey: oldest)
        }
    }
}
