import Foundation
import SelectionSpeakerCore

struct DeepSeekTranslationClient {
    let apiKey: String
    let modelName: String
    let promptConfiguration: TranslationPromptConfiguration

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    func translate(_ text: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 18

        let body = ChatCompletionRequest(
            model: modelName,
            messages: [
                .init(role: "system", content: promptConfiguration.systemPrompt),
                .init(
                    role: "user",
                    content: TranslationPromptBuilder.userPrompt(
                        for: text,
                        template: promptConfiguration.userPromptTemplate
                    )
                )
            ],
            temperature: 1.3,
            maxTokens: 420,
            stream: false,
            thinking: .init(type: "disabled")
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = try? JSONDecoder().decode(APIErrorResponse.self, from: data).error.message
            throw TranslationError.server(statusCode: httpResponse.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let content = decoded.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let content, !content.isEmpty else {
            throw TranslationError.emptyResult
        }

        return content
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool
    let thinking: ThinkingMode

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
        case thinking
    }
}

private struct ThinkingMode: Encodable {
    let type: String
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String?
    }
}

private struct APIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}

enum TranslationError: LocalizedError {
    case invalidResponse
    case server(statusCode: Int, message: String?)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "翻译服务没有返回有效响应"
        case .server(let statusCode, let message):
            return message.map { "翻译服务错误 \(statusCode)：\($0)" } ?? "翻译服务错误 \(statusCode)"
        case .emptyResult:
            return "翻译结果为空"
        }
    }
}
