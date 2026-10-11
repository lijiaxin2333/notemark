import XCTest
@testable import NoteMarkCore

final class EmptyHeadingCancellationTests: XCTestCase {
    func testOnlyHeadingStylesCanBeArmed() {
        for style in ParagraphStyle.allCases {
            XCTAssertEqual(EmptyHeadingCancellation(style: style, paragraphStart: 0) != nil,
                           [.title, .heading, .subheading].contains(style), style.rawValue)
        }
        XCTAssertNil(EmptyHeadingCancellation(style: .title, paragraphStart: -1))
    }

    func testEmptyFirstLineRestoresBodyWithoutDeletingText() {
        let plan = EmptyHeadingCancellation(style: .title, paragraphStart: 0)?.plan(
            beforeCaret: "", windowStart: 0, afterCaret: "", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(plan?.conversion, .paragraph(.body))
        XCTAssertEqual(plan?.range, NSRange(location: 0, length: 0))
        XCTAssertEqual(plan?.original, "")
    }

    func testPreviousTextAndImageStayOutsideTheEdit() {
        let before = "🌳\u{fffc}\n"
        let start = (before as NSString).length
        let plan = EmptyHeadingCancellation(style: .heading, paragraphStart: start)?.plan(
            beforeCaret: before, windowStart: 0, afterCaret: "\n", selection: NSRange(location: start, length: 0))
        XCTAssertEqual(plan?.range, NSRange(location: start, length: 0))
    }

    func testKnownWindowBoundaryIsRequired() {
        let cancellation = EmptyHeadingCancellation(style: .title, paragraphStart: 10)!
        XCTAssertNil(cancellation.plan(beforeCaret: "", windowStart: 10, afterCaret: "",
                                        selection: NSRange(location: 10, length: 0)))
        XCTAssertNotNil(cancellation.plan(beforeCaret: "x\n", windowStart: 8, afterCaret: "",
                                           selection: NSRange(location: 10, length: 0)))
    }

    func testContentAndWhitespaceAreNotEmpty() {
        for content in ["a", " ", "\t", "中文", "🌳", "\u{fffc}"] {
            XCTAssertNil(EmptyHeadingCancellation(style: .title, paragraphStart: 0)?.plan(
                beforeCaret: content, windowStart: 0, afterCaret: "",
                selection: NSRange(location: (content as NSString).length, length: 0)), content)
        }
    }

    func testContentAfterCaretAndUnknownBoundaryAreRejected() {
        for after in ["text", " ", "\u{fffc}", "?"] {
            XCTAssertNil(EmptyHeadingCancellation(style: .title, paragraphStart: 0)?.plan(
                beforeCaret: "", windowStart: 0, afterCaret: after,
                selection: NSRange(location: 0, length: 0)), after)
        }
    }

    func testSelectionAndAnotherParagraphAreRejected() {
        let cancellation = EmptyHeadingCancellation(style: .title, paragraphStart: 0)!
        XCTAssertNil(cancellation.plan(beforeCaret: "", windowStart: 0, afterCaret: "",
                                        selection: NSRange(location: 0, length: 1)))
        XCTAssertNil(cancellation.plan(beforeCaret: "\n", windowStart: 0, afterCaret: "",
                                        selection: NSRange(location: 1, length: 0)))
    }

    func testInconsistentSnapshotIsRejected() {
        let cancellation = EmptyHeadingCancellation(style: .title, paragraphStart: 0)!
        XCTAssertNil(cancellation.plan(beforeCaret: "", windowStart: -1, afterCaret: "",
                                        selection: NSRange(location: 0, length: 0)))
        XCTAssertNil(cancellation.plan(beforeCaret: "x\n", windowStart: 0, afterCaret: "",
                                        selection: NSRange(location: 0, length: 0)))
    }
}
