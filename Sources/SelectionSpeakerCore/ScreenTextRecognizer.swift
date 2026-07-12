import CoreGraphics
import Foundation
import Vision

public struct ScreenTextRecognizer {
    public init() {}

    public func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let observations = (request.results ?? []).sorted { lhs, rhs in
            let verticalDistance = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            if verticalDistance > 0.025 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw ScreenTextRecognitionError.noRecognizedText
        }
        return text
    }
}

enum ScreenTextRecognitionError: LocalizedError {
    case noRecognizedText

    var errorDescription: String? {
        switch self {
        case .noRecognizedText:
            return "没有识别到中英文文字，请重新框选字幕或单词。"
        }
    }
}
