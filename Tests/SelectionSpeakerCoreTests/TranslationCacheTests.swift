import Testing
@testable import SelectionSpeakerCore

@Test func cacheSeparatesTranslationsByDirection() {
    var cache = TranslationCache(limit: 2)
    cache.store("你好", for: "hello", direction: .englishToChinese)
    cache.store("hello", for: "hello", direction: .chineseToEnglish)

    #expect(cache["hello", .englishToChinese] == "你好")
    #expect(cache["hello", .chineseToEnglish] == "hello")
}
