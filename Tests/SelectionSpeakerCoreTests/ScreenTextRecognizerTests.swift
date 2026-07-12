import AppKit
import Testing
@testable import SelectionSpeakerCore

@MainActor
@Test func recognizesChineseTextFromAnInMemoryImage() throws {
    let recognized = try ScreenTextRecognizer().recognizeText(in: image(with: "机械零件"))
    #expect(recognized == "机械零件")
}

@MainActor
@Test func recognizesEnglishTextFromAnInMemoryImage() throws {
    let recognized = try ScreenTextRecognizer().recognizeText(in: image(with: "Mechanical parts"))
    #expect(recognized == "Mechanical parts")
}

@MainActor
private func image(with text: String) -> CGImage {
    let image = NSImage(size: NSSize(width: 480, height: 100))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: 480, height: 100).fill()

    let attributed = NSAttributedString(
        string: text,
        attributes: [
            .font: NSFont.systemFont(ofSize: 40),
            .foregroundColor: NSColor.black
        ]
    )
    attributed.draw(at: NSPoint(x: 16, y: 26))
    image.unlockFocus()

    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
