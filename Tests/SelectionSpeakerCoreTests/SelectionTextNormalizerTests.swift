import Testing
@testable import SelectionSpeakerCore

@Test func normalizesWhitespaceAroundEnglishText() {
    #expect(SelectionTextNormalizer.normalizedText(from: "  hello\nworld\t ") == "hello world")
}

@Test func ignoresBlankSelection() {
    #expect(SelectionTextNormalizer.normalizedText(from: " \n\t ") == nil)
}

@Test func ignoresSelectionWithoutEnglishLetters() {
    #expect(SelectionTextNormalizer.normalizedText(from: "你好，世界") == nil)
}

@Test func ignoresSelectionContainingChineseEvenWhenEnglishIsPresent() {
    #expect(SelectionTextNormalizer.normalizedText(from: "这个词是 pronunciation") == nil)
}

@Test func acceptsPureChineseWhenChineseIsAllowed() {
    #expect(
        SelectionTextNormalizer.normalizedText(from: "  你好，世界  ", allowsChinese: true) == "你好，世界"
    )
}

@Test func acceptsMixedChineseAndEnglishWhenChineseIsAllowed() {
    #expect(
        SelectionTextNormalizer.normalizedText(from: "请 open the door", allowsChinese: true) == "请 open the door"
    )
}

@Test func stillRejectsPunctuationOnlyWhenChineseIsAllowed() {
    #expect(SelectionTextNormalizer.normalizedText(from: "，。！？", allowsChinese: true) == nil)
}

@Test func limitsVeryLongSelections() {
    let source = String(repeating: "word ", count: 200)
    #expect(SelectionTextNormalizer.normalizedText(from: source, maxCharacters: 12) == "word word wo")
}
