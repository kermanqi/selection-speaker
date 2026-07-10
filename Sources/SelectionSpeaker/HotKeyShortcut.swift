import AppKit
import Carbon
import Foundation

struct HotKeyShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyEquivalent: String
    let keyDisplay: String

    var displayString: String {
        modifierDisplay + keyDisplay
    }

    var menuModifierMask: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }
        if modifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if modifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }
        if modifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }
        return flags
    }

    static func from(event: NSEvent) throws -> HotKeyShortcut {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiers = carbonModifiers(from: modifierFlags)
        guard modifierCount(in: modifiers) >= 2 else {
            throw HotKeyShortcutError.needsMoreModifiers
        }

        guard let keyEquivalent = keyEquivalent(from: event),
              let keyDisplay = keyDisplay(from: event, keyEquivalent: keyEquivalent) else {
            throw HotKeyShortcutError.unsupportedKey
        }

        return HotKeyShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyEquivalent: keyEquivalent,
            keyDisplay: keyDisplay
        )
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        return modifiers
    }

    static func modifierCount(in modifiers: UInt32) -> Int {
        [controlKey, optionKey, cmdKey, shiftKey].filter { modifiers & UInt32($0) != 0 }.count
    }

    private var modifierDisplay: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }
        return result
    }

    private static func keyEquivalent(from event: NSEvent) -> String? {
        if event.keyCode == UInt16(kVK_Space) {
            return " "
        }
        if event.keyCode == UInt16(kVK_Return) {
            return "\r"
        }
        if event.keyCode == UInt16(kVK_Escape) {
            return "\u{1b}"
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return nil
        }

        let first = String(characters.prefix(1)).lowercased()
        guard first.rangeOfCharacter(from: .alphanumerics) != nil else {
            return nil
        }

        return first
    }

    private static func keyDisplay(from event: NSEvent, keyEquivalent: String) -> String? {
        switch event.keyCode {
        case UInt16(kVK_Space):
            return "Space"
        case UInt16(kVK_Return):
            return "Return"
        case UInt16(kVK_Escape):
            return "Esc"
        default:
            return keyEquivalent.uppercased()
        }
    }
}

enum HotKeyShortcutError: LocalizedError {
    case needsMoreModifiers
    case unsupportedKey
    case duplicatedShortcut

    var errorDescription: String? {
        switch self {
        case .needsMoreModifiers:
            return "请至少同时按下两个修饰键，比如 Control、Option、Command 或 Shift 中的任意两个。"
        case .unsupportedKey:
            return "这个按键暂不支持作为快捷键，请换一个字母、数字、Space、Return 或 Esc。"
        case .duplicatedShortcut:
            return "这个快捷键已经用于另一个功能，请换一个组合。"
        }
    }
}
