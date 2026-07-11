import AppKit
import Testing
@testable import SelectionSpeakerCore

@MainActor
@Test func layoutKeepsMechanicalPartsWithinTheTextFrame() {
    let layout = PopoverTextLayout.layout(
        for: "Mechanical parts",
        font: .systemFont(ofSize: 14)
    )

    #expect(layout.requiredTextSize.width <= layout.textFrame.width)
    #expect(layout.requiredTextSize.height <= layout.textFrame.height)
}
