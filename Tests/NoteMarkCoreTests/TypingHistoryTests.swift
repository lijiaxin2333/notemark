import XCTest
@testable import NoteMarkCore

final class TypingHistoryTests: XCTestCase {
    private func history(_ typed: String...) -> TypingHistory {
        var history = TypingHistory()
        typed.forEach { history.append($0) }
        return history
    }

    func testKeepsTheMostRecentCharacters() {
        let typed = history(String(repeating: "a", count: 70), "#")
        XCTAssertEqual(typed.text.count, TypingHistory.capacity)
        XCTAssertEqual(typed.text.last, "#")
    }

    func testResetsAfterTriggers() {
        var typed = history("abc")
        typed.reset(after: .enter)
        XCTAssertEqual(typed.text, "\n")
        typed.reset(after: .space)
        XCTAssertEqual(typed.text, "")
    }

    func testDeleteBackwardRemovesOneCharacter() {
        var typed = history("中文🌳")
        typed.deleteBackward()
        XCTAssertEqual(typed.text, "中文")
        var empty = TypingHistory()
        empty.deleteBackward()
        XCTAssertEqual(empty.text, "")
    }

    func testMarkdownEvidence() {
        for markdown in ["#", "**bold**", "_x_", "`code`", "~~s~~", "[]", "【】", "［］", "1.", ">", "[a](b)",
                         "-", "[ ]", "- [ ]", "```swift", "/h2", "text\n/h2"] {
            XCTAssertTrue(history(markdown).looksLikeMarkdown, markdown)
        }
        for prose in ["hello", "-a", "a/b", "1", "中文", ""] {
            XCTAssertFalse(history(prose).looksLikeMarkdown, prose)
        }
    }

    func testSlashCommandAtParagraphStart() {
        XCTAssertTrue(history("/h2").containsSlashCommand)
        XCTAssertTrue(history("text\n/h2").containsSlashCommand)
        XCTAssertFalse(history("a/b").containsSlashCommand)
    }
}
