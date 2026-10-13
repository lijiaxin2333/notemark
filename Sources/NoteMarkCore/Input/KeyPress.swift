import Carbon.HIToolbox
import Foundation

public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let shift = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)
}

/// A key-down event classified for Markdown input. Physical keys such as
/// Return or Delete are identified by virtual key code; text shortcuts such as
/// Control-H are identified by the character the key types in the current
/// layout, as Cocoa's text system does.
public struct KeyPress: Equatable, Sendable {
    public let code: Int
    public let modifiers: KeyModifiers
    public let isAutorepeat: Bool
    /// What the key types in the current ASCII-capable layout with the current
    /// Shift state and no other modifiers. Nil when the layout is unavailable;
    /// ANSI key positions are assumed then.
    public let layoutCharacter: String?

    public init(code: Int, modifiers: KeyModifiers = [], isAutorepeat: Bool = false, layoutCharacter: String? = nil) {
        self.code = code
        self.modifiers = modifiers
        self.isAutorepeat = isAutorepeat
        self.layoutCharacter = layoutCharacter
    }

    public var isSpace: Bool { code == kVK_Space }
    public var isReturn: Bool { code == kVK_Return || code == kVK_ANSI_KeypadEnter }
    public var isTab: Bool { code == kVK_Tab }
    public var isEscape: Bool { code == kVK_Escape }
    public var isDeleteBackward: Bool { code == kVK_Delete }
    /// Any key that deletes text, with or without modifiers.
    public var isDeletion: Bool { [kVK_Delete, kVK_ForwardDelete].contains(code) || isControlDeletion }
    public var isUpArrow: Bool { code == kVK_UpArrow }
    public var isVerticalArrow: Bool { code == kVK_UpArrow || code == kVK_DownArrow }

    public var hasCommandControlOrOption: Bool { !modifiers.isDisjoint(with: [.command, .control, .option]) }

    /// Space and Return complete a Markdown marker.
    public var trigger: Trigger? {
        if isSpace { return .space }
        return isReturn ? .enter : nil
    }

    /// Command-Z.
    public var isUndo: Bool { modifiers == .command && letter == "z" }
    /// Command-V, which can paste images; other paste variants paste plain text.
    public var isPaste: Bool { modifiers == .command && letter == "v" }

    /// Shift-Command-Z.
    public var isRedo: Bool { modifiers == [.command, .shift] && letter == "z" }

    /// Control-D, Control-H, and Control-K delete text in Cocoa editors.
    public var isControlDeletion: Bool { modifiers == .control && ["d", "h", "k"].contains(letter) }

    /// Control-A/E/F/B/P/N move the caret in Cocoa editors.
    public var isControlNavigation: Bool { modifiers == .control && ["a", "e", "f", "b", "p", "n"].contains(letter) }

    /// Keys that may restore Body on an empty formatted paragraph.
    public var isCancellationKey: Bool {
        ([kVK_Delete, kVK_ForwardDelete, kVK_Escape].contains(code) && modifiers.isEmpty) || isControlDeletion
    }

    /// Direction of a cancellation key; meaningful when `isCancellationKey`.
    public var cancellationIntent: CodeBlockCancellationIntent {
        if isEscape { return .escape }
        return isDeleteBackward || (isControlDeletion && letter == "h") ? .backwardDeletion : .forwardDeletion
    }

    /// Caret and focus movement that ends the typed Markdown context.
    public var resetsTypingHistory: Bool {
        [kVK_LeftArrow, kVK_RightArrow, kVK_DownArrow, kVK_UpArrow, kVK_Home, kVK_End,
         kVK_PageUp, kVK_PageDown, kVK_Tab, kVK_Escape].contains(code)
    }

    /// Whether a main-keyboard key types `/`. Some input methods omit
    /// committed punctuation from the raw event string, so the layout decides.
    /// The numeric keypad is left to the raw event string, as it always was.
    public var typesSlash: Bool {
        guard !Self.keypadCodes.contains(code) else { return false }
        guard let layoutCharacter else { return code == kVK_ANSI_Slash && !modifiers.contains(.shift) }
        return layoutCharacter == "/"
    }

    /// The lowercase ASCII letter the key types, if any.
    var letter: String? {
        guard let layoutCharacter else { return Self.ansiLetters[code] }
        let lowercased = layoutCharacter.lowercased()
        guard lowercased.count == 1, let scalar = lowercased.unicodeScalars.first,
              scalar.isASCII, CharacterSet.lowercaseLetters.contains(scalar) else { return nil }
        return lowercased
    }

    private static let keypadCodes: Set<Int> = [
        kVK_ANSI_KeypadDecimal, kVK_ANSI_KeypadMultiply, kVK_ANSI_KeypadPlus, kVK_ANSI_KeypadClear,
        kVK_ANSI_KeypadDivide, kVK_ANSI_KeypadEnter, kVK_ANSI_KeypadMinus, kVK_ANSI_KeypadEquals,
        kVK_ANSI_Keypad0, kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3, kVK_ANSI_Keypad4,
        kVK_ANSI_Keypad5, kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8, kVK_ANSI_Keypad9
    ]

    private static let ansiLetters: [Int: String] = [
        kVK_ANSI_A: "a", kVK_ANSI_B: "b", kVK_ANSI_C: "c", kVK_ANSI_D: "d", kVK_ANSI_E: "e", kVK_ANSI_F: "f",
        kVK_ANSI_G: "g", kVK_ANSI_H: "h", kVK_ANSI_I: "i", kVK_ANSI_J: "j", kVK_ANSI_K: "k", kVK_ANSI_L: "l",
        kVK_ANSI_M: "m", kVK_ANSI_N: "n", kVK_ANSI_O: "o", kVK_ANSI_P: "p", kVK_ANSI_Q: "q", kVK_ANSI_R: "r",
        kVK_ANSI_S: "s", kVK_ANSI_T: "t", kVK_ANSI_U: "u", kVK_ANSI_V: "v", kVK_ANSI_W: "w", kVK_ANSI_X: "x",
        kVK_ANSI_Y: "y", kVK_ANSI_Z: "z"
    ]
}
