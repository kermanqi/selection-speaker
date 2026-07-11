import Testing
@testable import SelectionSpeakerCore

@Test func prefersTheSettledSelectionWhenItExtendsTheInitialSelection() {
    #expect(
        SelectionTextStabilityResolver.preferredText(
            initial: "How divine and",
            settled: "How divine and holy"
        ) == "How divine and holy"
    )
}

@Test func keepsTheInitialSelectionWhenTheSettledReadIsItsPrefix() {
    #expect(
        SelectionTextStabilityResolver.preferredText(
            initial: "好神圣啊",
            settled: "好神圣"
        ) == "好神圣啊"
    )
}

@Test func usesTheMostRecentSelectionWhenTheReadsDescribeDifferentText() {
    #expect(
        SelectionTextStabilityResolver.preferredText(
            initial: "first selection",
            settled: "second selection"
        ) == "second selection"
    )
}
