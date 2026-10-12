import Carbon.HIToolbox
import XCTest
@testable import NoteMarkCore

final class KeyPressTests: XCTestCase {
    // US-layout characters for the keys these tests use.
    private let usCharacters: [Int: String] = [
        kVK_ANSI_A: "a", kVK_ANSI_B: "b", kVK_ANSI_D: "d", kVK_ANSI_E: "e", kVK_ANSI_F: "f", kVK_ANSI_H: "h",
        kVK_ANSI_K: "k", kVK_ANSI_N: "n", kVK_ANSI_P: "p", kVK_ANSI_V: "v", kVK_ANSI_Slash: "/"
    ]

    func testTriggersAndNamedKeys() {
        XCTAssertEqual(KeyPress(code: kVK_Space).trigger, .space)
        XCTAssertEqual(KeyPress(code: kVK_Return).trigger, .enter)
        XCTAssertEqual(KeyPress(code: kVK_ANSI_KeypadEnter).trigger, .enter)
        XCTAssertNil(KeyPress(code: kVK_Tab).trigger)
        XCTAssertTrue(KeyPress(code: kVK_UpArrow).isVerticalArrow)
        XCTAssertTrue(KeyPress(code: kVK_DownArrow).isVerticalArrow)
        XCTAssertFalse(KeyPress(code: kVK_LeftArrow).isVerticalArrow)
        XCTAssertTrue(KeyPress(code: kVK_UpArrow).isUpArrow)
        XCTAssertFalse(KeyPress(code: kVK_DownArrow).isUpArrow)
    }

    func testCancellationKeysMatchThePreviousKeyCodeSets() {
        // Unmodified Delete, Forward Delete, and Esc, or Control-D/H/K.
        for code in 0..<128 {
            for modifiers: KeyModifiers in [[], .control, .shift, .command, .option, [.control, .shift]] {
                for layout in [nil, usCharacters[code] ?? ""] as [String?] {
                    let press = KeyPress(code: code, modifiers: modifiers, layoutCharacter: layout)
                    let expected = ([51, 117, 53].contains(code) && modifiers.isEmpty) ||
                        ([2, 4, 40].contains(code) && modifiers == .control)
                    XCTAssertEqual(press.isCancellationKey, expected, "\(code) \(modifiers)")
                    let navigation = [0, 14, 3, 11, 35, 45].contains(code) && modifiers == .control
                    XCTAssertEqual(press.isControlNavigation, navigation, "\(code) \(modifiers)")
                    if expected {
                        let intent: CodeBlockCancellationIntent = code == 53 ? .escape :
                            [51, 4].contains(code) ? .backwardDeletion : .forwardDeletion
                        XCTAssertEqual(press.cancellationIntent, intent, "\(code)")
                    }
                }
            }
        }
    }

    func testControlShortcutsFollowTheLayoutCharacter() {
        // Dvorak: the ANSI H position types "d", and "h" is on the ANSI J position.
        let dvorakD = KeyPress(code: kVK_ANSI_H, modifiers: .control, layoutCharacter: "d")
        XCTAssertTrue(dvorakD.isControlDeletion)
        XCTAssertEqual(dvorakD.cancellationIntent, .forwardDeletion)
        let dvorakH = KeyPress(code: kVK_ANSI_J, modifiers: .control, layoutCharacter: "h")
        XCTAssertTrue(dvorakH.isCancellationKey)
        XCTAssertEqual(dvorakH.cancellationIntent, .backwardDeletion)
        // A key typing punctuation in the layout is not a letter shortcut.
        XCTAssertFalse(KeyPress(code: kVK_ANSI_E, modifiers: .control, layoutCharacter: ".").isControlNavigation)
        XCTAssertFalse(KeyPress(code: kVK_ANSI_H, modifiers: .control, layoutCharacter: "").isControlDeletion)
    }

    func testTypingHistoryResetKeys() {
        let resetting = [123, 124, 125, 126, 115, 119, 116, 121, 48, 53]
        for code in 0..<128 {
            XCTAssertEqual(KeyPress(code: code).resetsTypingHistory, resetting.contains(code), "\(code)")
        }
    }

    func testSlashFollowsTheLayout() {
        XCTAssertTrue(KeyPress(code: kVK_ANSI_Slash).typesSlash)
        XCTAssertFalse(KeyPress(code: kVK_ANSI_Slash, modifiers: .shift).typesSlash)
        XCTAssertTrue(KeyPress(code: kVK_ANSI_Slash, layoutCharacter: "/").typesSlash)
        XCTAssertFalse(KeyPress(code: kVK_ANSI_Slash, modifiers: .shift, layoutCharacter: "?").typesSlash)
        // German: the ANSI slash position types "-", and Shift-7 types "/".
        XCTAssertFalse(KeyPress(code: kVK_ANSI_Slash, layoutCharacter: "-").typesSlash)
        XCTAssertTrue(KeyPress(code: kVK_ANSI_7, modifiers: .shift, layoutCharacter: "/").typesSlash)
        // The keypad slash relies on the raw event string, as before.
        for modifiers: KeyModifiers in [[], .shift] {
            XCTAssertFalse(KeyPress(code: kVK_ANSI_KeypadDivide, modifiers: modifiers, layoutCharacter: "/").typesSlash)
            XCTAssertFalse(KeyPress(code: kVK_ANSI_KeypadDivide, modifiers: modifiers).typesSlash)
        }
    }

    func testCommandControlOrOption() {
        XCTAssertFalse(KeyPress(code: kVK_ANSI_A).hasCommandControlOrOption)
        XCTAssertFalse(KeyPress(code: kVK_ANSI_A, modifiers: .shift).hasCommandControlOrOption)
        for modifier: KeyModifiers in [.command, .control, .option, [.shift, .command]] {
            XCTAssertTrue(KeyPress(code: kVK_ANSI_A, modifiers: modifier).hasCommandControlOrOption)
        }
    }
}
