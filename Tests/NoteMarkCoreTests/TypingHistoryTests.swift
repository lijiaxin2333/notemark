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
            XCTAssertTrue(history(markdown).looksLikeMarkdown(), markdown)
        }
        for prose in ["hello", "-a", "a/b", "1", "中文", ""] {
            XCTAssertFalse(history(prose).looksLikeMarkdown(), prose)
        }
    }

    func testSlashCommandAtParagraphStart() {
        XCTAssertTrue(history("/h2").containsSlashCommand)
        XCTAssertTrue(history("text\n/h2").containsSlashCommand)
        XCTAssertFalse(history("a/b").containsSlashCommand)
    }
}

final class TypingHistoryPunctuationTests: XCTestCase {
    private func history(_ text: String) -> TypingHistory {
        var history = TypingHistory()
        history.append(text)
        return history
    }

    func testSentencePunctuationIsNotMarkdown() {
        for prose in ["done.", "(a)", "a>", "x > y", "第1章。", "v1.2."] {
            XCTAssertFalse(history(prose).looksLikeMarkdown(), prose)
        }
        // A pasted or long URL leaves only the closing parenthesis in the history.
        for link in [")", "Started.md)", "[a](b)"] {
            XCTAssertTrue(history(link).looksLikeMarkdown(), link)
        }
        XCTAssertFalse(history("see (note)").looksLikeMarkdown())
        for marker in ["1.", "12.", "１．", "[a](b)", ">", "》", "text\n>", "text\n---", "——", "···swift", "｀｀｀", "＃"] {
            XCTAssertTrue(history(marker).looksLikeMarkdown(), marker)
        }
        // After Return, and with a backslash that keeps the marker as text.
        for marker in ["text\n-", "text\n[]", "\\>", "\\1.", "\\-", "\\---", "\\/h2", "text\n\\#"] {
            XCTAssertTrue(history(marker).looksLikeMarkdown(), marker)
        }
        // A smart-dash divider retyped after deleting an em dash.
        XCTAssertTrue(history("-----").looksLikeMarkdown())
        var noDividers = ConversionRules()
        noDividers.dividers = false
        XCTAssertFalse(history("-----").looksLikeMarkdown(rules: noDividers))
        for prose in ["\\hello", "a\\b", "\\a>", "\\v1.2.", "--", "-a-"] {
            XCTAssertFalse(history(prose).looksLikeMarkdown(), prose)
        }
    }
}
