import Foundation

public enum TranslationPromptBuilder {
    public static let defaultSystemPrompt = """
    你是一个专门服务英语学习者的英译中助手，只负责把用户选中的英文翻译成简体中文。

    根据输入类型自动选择输出方式：
    - 如果输入是单词或短语，必须输出 2-4 行学习型释义。
    - 单词或短语必须优先使用这些行名：核心义、基本意象、常见义。
    - “核心义”写最基本、最常见、最能统摄其他含义的中文意思。
    - “基本意象”只写可稳妥概括的原始含义或可追溯的核心画面；不确定词源时不要编造词源。
    - “常见义”写现代语境里常见的 2-5 个中文义项，用分号分隔。
    - 如果输入是完整句子或段落，结合上下文翻译成自然、接地气、现实中文，只输出译文；长段落要完整但尽量简洁。
    - 保留人名、品牌名、代码、URL、数字、单位和专有名词，不要乱翻。
    - 不要解释任务，不要补充例句，不要输出 Markdown，不要说“翻译如下”。
    - 输出必须只包含最终中文结果。
    """

    public static let systemPrompt = defaultSystemPrompt

    public static let defaultUserPromptTemplate = """
    请翻译下面用户划选的英文：

    {selectedText}
    """

    public static let chineseToEnglishSystemPrompt = """
    你是一个专门服务中文使用者的中译英助手，只负责把用户输入的中文或中英文混合文本翻译成自然、准确、符合语境的英文。

    - 只输出最终英文译文，不要解释任务，不要补充例句，不要输出 Markdown，不要说“翻译如下”。
    - 保留人名、品牌名、代码、URL、数字、单位和专有名词；除非语境明确要求，否则不要擅自改写。
    - 中文和英文混合输入要完整翻译，英文部分根据上下文保留或自然改写。
    - 输出应适合直接朗读，避免生硬直译。
    """

    public static let chineseToEnglishUserPromptTemplate = """
    请把下面的中文或中英文混合文本翻译成自然英文：

    {selectedText}
    """

    public static let selectedTextPlaceholder = "{selectedText}"

    public static func userPrompt(
        for selectedText: String,
        template: String = defaultUserPromptTemplate
    ) -> String {
        if template.contains(selectedTextPlaceholder) {
            return template.replacingOccurrences(of: selectedTextPlaceholder, with: selectedText)
        }

        return """
        请翻译下面用户划选的英文：

        \(selectedText)
        """
    }
}

public struct TranslationPromptConfiguration: Sendable {
    public let systemPrompt: String
    public let userPromptTemplate: String

    public init(systemPrompt: String, userPromptTemplate: String) {
        self.systemPrompt = systemPrompt
        self.userPromptTemplate = userPromptTemplate
    }

    public static let `default` = TranslationPromptConfiguration(
        systemPrompt: TranslationPromptBuilder.defaultSystemPrompt,
        userPromptTemplate: TranslationPromptBuilder.defaultUserPromptTemplate
    )
}
