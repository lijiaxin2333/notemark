import XCTest
@testable import NoteMarkCore

final class CaretLineTests: XCTestCase {
    func testParagraphAfterTheLastLineBreak() {
        let line = CaretLine(beforeCaret: "🌳 前一段\n##", windowStart: 100)
        XCTAssertEqual(line.text, "##")
        XCTAssertEqual(line.start, ("🌳 前一段\n" as NSString).length)
        XCTAssertEqual(line.documentStart, 100 + line.start)
        XCTAssertTrue(line.startIsKnown)
        XCTAssertFalse(line.caretIsAtStart)
    }

    func testTruncatedWindowWithoutLineBreakHasUnknownStart() {
        XCTAssertFalse(CaretLine(beforeCaret: "abc", windowStart: 10).startIsKnown)
        XCTAssertTrue(CaretLine(beforeCaret: "abc", windowStart: 0).startIsKnown)
        XCTAssertTrue(CaretLine(beforeCaret: "x\nabc", windowStart: 10).startIsKnown)
    }

    func testEmptyParagraphs() {
        XCTAssertTrue(CaretLine(beforeCaret: "", windowStart: 0).caretIsAtStart)
        let afterBreak = CaretLine(beforeCaret: "text\r\n", windowStart: 0)
        XCTAssertTrue(afterBreak.caretIsAtStart)
        XCTAssertEqual(afterBreak.text, "")
        XCTAssertEqual(CaretLine(beforeCaret: "a\u{2029}b", windowStart: 0).text, "b")
    }

    func testTextHelpers() {
        XCTAssertTrue("".consistsOfLineBreaks)
        XCTAssertTrue("\n\r\n\u{2028}".consistsOfLineBreaks)
        XCTAssertFalse("\n \n".consistsOfLineBreaks)
        XCTAssertTrue("".startsAtParagraphEnd)
        XCTAssertTrue("\nnext".startsAtParagraphEnd)
        XCTAssertFalse("?".startsAtParagraphEnd)
        XCTAssertEqual("task\nnext".prefixBeforeLineBreak().text, "task")
        XCTAssertTrue("task\nnext".prefixBeforeLineBreak().foundLineBreak)
        XCTAssertEqual("task".prefixBeforeLineBreak().text, "task")
        XCTAssertFalse("task".prefixBeforeLineBreak().foundLineBreak)
        let source = "a\nb" as NSString
        XCTAssertFalse(source.isLineBreak(at: 0))
        XCTAssertTrue(source.isLineBreak(at: 1))
    }
}
