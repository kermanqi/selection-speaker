import Testing
@testable import SelectionSpeakerCore

@Test func promptAsksForLearningStyleWordTranslations() {
    #expect(TranslationPromptBuilder.systemPrompt.contains("核心义"))
    #expect(TranslationPromptBuilder.systemPrompt.contains("基本意象"))
    #expect(TranslationPromptBuilder.systemPrompt.contains("不确定词源时不要编造词源"))
}

@Test func promptAsksForNaturalSentenceTranslations() {
    #expect(TranslationPromptBuilder.systemPrompt.contains("自然、接地气、现实中文"))
    #expect(TranslationPromptBuilder.systemPrompt.contains("只输出译文"))
}
