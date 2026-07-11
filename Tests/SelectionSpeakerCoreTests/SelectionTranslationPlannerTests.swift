import Testing
@testable import SelectionSpeakerCore

@Test func englishToChinesePlansOriginalSpeechAndChineseTranslation() {
    #expect(
        SelectionTranslationPlanner.plan(
            from: " hello world ",
            direction: .englishToChinese
        ) == .speakOriginalAndTranslateToChinese(text: "hello world")
    )
}

@Test func chineseToEnglishAcceptsPureChineseAndSpeaksTranslation() {
    #expect(
        SelectionTranslationPlanner.plan(
            from: "你好，世界",
            direction: .chineseToEnglish
        ) == .translateToEnglishAndSpeakResult(text: "你好，世界")
    )
}

@Test func chineseToEnglishAcceptsMixedTextAndSpeaksTranslation() {
    #expect(
        SelectionTranslationPlanner.plan(
            from: "请 open the door",
            direction: .chineseToEnglish
        ) == .translateToEnglishAndSpeakResult(text: "请 open the door")
    )
}

@Test func chineseToEnglishKeepsPureEnglishSpeechAndRequestsChinese() {
    #expect(
        SelectionTranslationPlanner.plan(
            from: "good morning",
            direction: .chineseToEnglish
        ) == .speakOriginalAndTranslateToChinese(text: "good morning")
    )
}

@Test func englishToChineseRejectsChineseAndMixedText() {
    #expect(
        SelectionTranslationPlanner.plan(
            from: "请 open the door",
            direction: .englishToChinese
        ) == nil
    )
}

@Test func plannerPreservesSelectionLimit() {
    let source = String(repeating: "中文 ", count: 100)
    let plan = SelectionTranslationPlanner.plan(
        from: source,
        direction: .chineseToEnglish,
        maxCharacters: 11
    )

    #expect(plan == .translateToEnglishAndSpeakResult(text: "中文 中文 中文 中文"))
}
