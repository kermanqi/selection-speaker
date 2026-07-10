import Foundation

struct TranslationCache {
    private let limit: Int
    private var values: [String: String] = [:]
    private var keys: [String] = []

    init(limit: Int) {
        self.limit = limit
    }

    subscript(text: String) -> String? {
        values[text]
    }

    mutating func store(_ translation: String, for text: String) {
        if values[text] == nil {
            keys.append(text)
        }
        values[text] = translation

        while keys.count > limit {
            let oldest = keys.removeFirst()
            values.removeValue(forKey: oldest)
        }
    }
}
