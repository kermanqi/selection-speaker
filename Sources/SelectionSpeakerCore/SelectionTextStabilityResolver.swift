import Foundation

public enum SelectionTextStabilityResolver {
    public static func preferredText(initial: String?, settled: String?) -> String? {
        let initial = nonEmptyText(from: initial)
        let settled = nonEmptyText(from: settled)

        switch (initial, settled) {
        case (nil, nil):
            return nil
        case (let text?, nil), (nil, let text?):
            return text
        case (let initial?, let settled?):
            if settled.hasPrefix(initial) {
                return settled
            }
            if initial.hasPrefix(settled) {
                return initial
            }
            return settled
        }
    }

    private static func nonEmptyText(from text: String?) -> String? {
        guard let text, !text.isEmpty else {
            return nil
        }
        return text
    }
}
