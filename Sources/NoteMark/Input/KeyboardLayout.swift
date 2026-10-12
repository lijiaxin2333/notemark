import AppKit
import Carbon.HIToolbox

/// Characters typed by physical keys in the current ASCII-capable keyboard
/// layout. Shortcuts follow these characters, not ANSI key positions: on
/// Dvorak, Command-V is a different key than on QWERTY.
///
/// The character table is rebuilt whenever the selected layout differs from
/// the one it was built for. Input-source notifications are not used: macOS
/// holds them while NoteMark is in the background, which is exactly when the
/// user types in Notes.
@MainActor final class KeyboardLayout {
    private struct Key {
        let plain: String
        let shifted: String
        let command: String
    }

    private struct Table {
        let sourceID: String
        /// Nil when the layout provides no key layout data.
        let keys: [Int: Key]?
    }

    private var table: Table?

    /// What `keyCode` types with the given Shift state and no other modifiers;
    /// nil when the layout is unavailable.
    func character(for keyCode: Int, shift: Bool) -> String? {
        guard let keys = currentKeys() else { return nil }
        guard let key = keys[keyCode] else { return "" }
        return shift ? key.shifted : key.plain
    }

    /// The key that types `character` while Command is held, as used for menu
    /// key equivalents.
    func keyCode(typingWithCommand character: String) -> CGKeyCode? {
        guard let keys = currentKeys() else { return nil }
        return keys.filter { $0.value.command == character }.keys.min().map { CGKeyCode($0) }
    }

    private func currentKeys() -> [Int: Key]? {
        guard let source = Self.asciiCapableLayout(), let sourceID = Self.identifier(of: source) else { return nil }
        if let table, table.sourceID == sourceID { return table.keys }
        let keys = Self.readKeys(from: source)
        table = Table(sourceID: sourceID, keys: keys)
        return keys
    }

    /// The current keyboard layout, or the ASCII-capable layout macOS uses for
    /// shortcuts while a non-Latin layout such as Russian is selected. Input
    /// methods report their underlying layout, such as ABC for Pinyin.
    private static func asciiCapableLayout() -> TISInputSource? {
        if let current = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(), isASCIICapable(current) {
            return current
        }
        return TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
    }

    private static func identifier(of source: TISInputSource) -> String? {
        guard let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
    }

    private static func isASCIICapable(_ source: TISInputSource) -> Bool {
        guard let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(property).takeUnretainedValue())
    }

    private static func readKeys(from source: TISInputSource) -> [Int: Key]? {
        guard let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        // The layout data belongs to `source`, which the caller keeps alive.
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var keys: [Int: Key] = [:]
        for code in 0..<128 {
            keys[code] = Key(plain: translate(code, modifiers: 0, layout: layout),
                             shifted: translate(code, modifiers: shiftKey, layout: layout),
                             command: translate(code, modifiers: cmdKey, layout: layout))
        }
        return keys
    }

    private static func translate(_ code: Int, modifiers: Int, layout: UnsafePointer<UCKeyboardLayout>) -> String {
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDown), UInt32((modifiers >> 8) & 0xFF),
                                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                    &deadKeyState, characters.count, &length, &characters)
        guard status == noErr else { return "" }
        return String(utf16CodeUnits: characters, count: length)
    }
}
