import XCTest
@testable import NoteMarkCore

final class CodeBlockContextTests: XCTestCase {
    private func read(_ text: String, caret: Int, code: NSRange) -> CodeBlockContext? {
        CodeBlockContext.read(text: text, windowStart: 0, documentLength: (text as NSString).length,
            caret: caret, currentLineIsCode: true, isCodeLine: { line in
                line.location >= code.location && line.location <= NSMaxRange(code)
            })
    }

    func testEmptyLastLineDoesNotCancelCodeStillPresentAbove() {
        let text = "body\nabc\ndef\n"
        let context = read(text, caret: 13, code: NSRange(location: 5, length: 8))!
        XCTAssertEqual(context.text, "abc\ndef\n")
        XCTAssertNil(context.cancellationPlan(selection: NSRange(location: 13, length: 0)))
    }

    func testBackspacingEveryCharacterAndLineBreakOnlyCancelsAfterEntireBlockIsEmpty() {
        // Exercise the intermediate empty line which the old per-line plan cancelled too early.
        for code in ["abc\ndef", "abc\nde", "abc\nd", "abc\n", "abc", "ab", "a", ""] {
            let text = "body\n" + code
            let length = (text as NSString).length
            let context = read(text, caret: length, code: NSRange(location: 5, length: (code as NSString).length))!
            let plan = context.cancellationPlan(selection: NSRange(location: length, length: 0))
            XCTAssertEqual(plan != nil, code.isEmpty, code)
            if code.isEmpty { XCTAssertEqual(plan?.range, NSRange(location: 5, length: 0)) }
        }
    }

    func testUpwardDeletionKeepsNativeCaretUntilAllBlankLineBreaksAreDeleted() {
        // Enter created many empty lines. Backspace/Ctrl+K must not select or
        // reformat the whole block while any of those separators remain.
        for code in ["abc\n\ndef\n\n", "abc\n\n\n", "abc\n\n", "abc\n", "abc", "ab", "a"] +
                    (0...100).reversed().map({ String(repeating: "\n", count: $0) }) {
            let text = "body\n" + code
            let caret = (text as NSString).length
            let context = read(text, caret: caret,
                code: NSRange(location: 5, length: (code as NSString).length))!
            let plan = context.cancellationPlan(selection: NSRange(location: caret, length: 0), intent: .backwardDeletion)
            XCTAssertEqual(plan != nil, code.isEmpty)
            if let plan {
                XCTAssertEqual(plan.range, NSRange(location: caret, length: 0))
                XCTAssertEqual(CodeBlockContext.bodyFormattingSelections(for: plan), [NSRange(location: caret, length: 0)])
            }
        }
    }

    func testEscapeCanCancelAllBlankLinesButDeleteDoesNotSkipThem() {
        let context = read("body\n\n\n\n", caret: 6, code: NSRange(location: 5, length: 3))!
        let caret = NSRange(location: 6, length: 0)
        XCTAssertNil(context.cancellationPlan(selection: caret, intent: .backwardDeletion))
        XCTAssertEqual(context.cancellationPlan(selection: caret, intent: .escape)?.original, "\n\n\n")
    }

    func testLastEmptyCodeParagraphDoesNotIncludeUnknownTerminalBodyParagraph() {
        // The only code character is its trailing separator. The final empty
        // paragraph has no font and must not inherit the preceding code font.
        let text = "body\n\n"
        let codeFonts = [5: true]
        let context = CodeBlockContext.read(text: text, windowStart: 0, documentLength: 6,
            caret: 5, currentLineIsCode: true, isCodeLine: { line in
                CodeBlockContext.isCodeParagraph(line, fontIsCode: { codeFonts[$0] })
            })!
        XCTAssertEqual(context.range, NSRange(location: 5, length: 0))
        XCTAssertEqual(context.text, "")
        XCTAssertEqual(context.cancellationPlan(selection: NSRange(location: 5, length: 0),
            intent: .backwardDeletion)?.range, NSRange(location: 5, length: 0))
    }

    func testBoundaryDeletionCancelsAtCaretInsteadOfDraggingBlankCodeAcrossBody() {
        let context = read("body\n\n\n\nnext body", caret: 5, code: NSRange(location: 5, length: 2))!
        for (caret, intent) in [(5, CodeBlockCancellationIntent.backwardDeletion), (7, .forwardDeletion)] {
            let plan = context.cancellationPlan(selection: NSRange(location: caret, length: 0), intent: intent)
            XCTAssertEqual(plan?.range, NSRange(location: caret, length: 0))
            XCTAssertEqual(plan?.original, "")
            XCTAssertEqual(plan?.conversion, .paragraph(.body))
        }
        // Both directions still delete internal newlines, without formatting.
        for intent in [CodeBlockCancellationIntent.backwardDeletion, .forwardDeletion] {
            XCTAssertNil(context.cancellationPlan(selection: NSRange(location: 6, length: 0), intent: intent))
        }
        let nonempty = read("body\nabc\n", caret: 5, code: NSRange(location: 5, length: 4))!
        XCTAssertNil(nonempty.cancellationPlan(selection: NSRange(location: 5, length: 0), intent: .backwardDeletion))
    }

    func testForwardDeletionRemovesInternalNewlinesBeforeCancellingAtStart() {
        for count in (0...100).reversed() {
            let text = "body\n" + String(repeating: "\n", count: count)
            let context = read(text, caret: 5, code: NSRange(location: 5, length: count))!
            let plan = context.cancellationPlan(selection: NSRange(location: 5, length: 0), intent: .forwardDeletion)
            XCTAssertEqual(plan != nil, count == 0)
        }
    }

    func testParagraphFontRecognitionNeverBorrowsPreviousCharacter() {
        let fonts = [2: false, 3: true, 4: true]
        XCTAssertTrue(CodeBlockContext.isCodeParagraph(NSRange(location: 3, length: 2), fontIsCode: { fonts[$0] }))
        XCTAssertFalse(CodeBlockContext.isCodeParagraph(NSRange(location: 2, length: 2), fontIsCode: { fonts[$0] }))
        XCTAssertFalse(CodeBlockContext.isCodeParagraph(NSRange(location: 5, length: 0), fontIsCode: { fonts[$0] }))
        XCTAssertTrue(CodeBlockContext.isCodeParagraph(NSRange(location: 3, length: 0), fontIsCode: { fonts[$0] }))
    }

    func testRemainingCodeBelowCaretPreventsCancellation() {
        let text = "body\n\nabc\nnext body"
        let context = read(text, caret: 5, code: NSRange(location: 5, length: 4))!
        XCTAssertEqual(context.text, "\nabc")
        XCTAssertNil(context.cancellationPlan(selection: NSRange(location: 5, length: 0)))
    }

    func testEntireEmptyBlockRestyledWithoutDeletingLineBreaksOrSurroundingBody() {
        let text = "body\n\n\n\nnext body"
        let context = read(text, caret: 6, code: NSRange(location: 5, length: 2))!
        let plan = context.cancellationPlan(selection: NSRange(location: 6, length: 0))
        XCTAssertEqual(plan?.conversion, .paragraph(.body))
        XCTAssertEqual(plan?.range, NSRange(location: 5, length: 2))
        XCTAssertEqual(plan?.original, "\n\n")
    }

    func testBodyFormattingCoversTerminalEmptyParagraphWithHalfOpenNativeSelection() {
        for blankLines in [1, 2, 10, 100] {
            let blankText = String(repeating: "\n", count: blankLines)
            let text = "body\n" + blankText + "\nnext body"
            let context = read(text, caret: 5 + blankLines,
                code: NSRange(location: 5, length: blankLines))!
            let plan = context.cancellationPlan(selection: NSRange(location: 5, length: 0))!
            let selections = CodeBlockContext.bodyFormattingSelections(for: plan)
            // Native selections are half-open: a paragraph at their end is
            // excluded unless Body is also applied with the caret inside it.
            let codeParagraphs = Array(5...5 + blankLines)
            for start in codeParagraphs {
                XCTAssertTrue(selections.contains { range in
                    range.length == 0 ? range.location == start :
                        range.location <= start && start < NSMaxRange(range)
                }, "Unformatted paragraph at \(start)")
            }
            XCTAssertFalse(selections.contains { $0.location < 5 || NSMaxRange($0) > 5 + blankLines })
            XCTAssertEqual(plan.original, blankText)
        }
    }

    func testSingleEmptyParagraphNeedsOnlyOneBodyCommand() {
        let plan = read("body\n", caret: 5, code: NSRange(location: 5, length: 0))!
            .cancellationPlan(selection: NSRange(location: 5, length: 0))!
        XCTAssertEqual(CodeBlockContext.bodyFormattingSelections(for: plan), [NSRange(location: 5, length: 0)])
    }

    func testWhitespaceAndAttachmentsAreContent() {
        for content in [" ", "\t", "\u{fffc}", "中文🌳"] {
            let text = "body\n" + content + "\n"
            let count = (text as NSString).length
            let context = read(text, caret: count, code: NSRange(location: 5, length: count - 5))!
            XCTAssertNil(context.cancellationPlan(selection: NSRange(location: count, length: 0)))
        }
    }

    func testTruncatedCodeBoundariesCannotBeTreatedAsEmpty() {
        XCTAssertNil(CodeBlockContext.read(text: "\n", windowStart: 10, documentLength: 11, caret: 11,
            currentLineIsCode: true, isCodeLine: { _ in true }))
        XCTAssertNil(CodeBlockContext.read(text: "\n", windowStart: 0, documentLength: 10, caret: 0,
            currentLineIsCode: true, isCodeLine: { _ in true }))
    }

    func testUnicodeAndCRLFRangesStayInUTF16() {
        let text = "🌳\r\n\r\n\r\n正文"
        let context = read(text, caret: 6, code: NSRange(location: 4, length: 2))!
        XCTAssertEqual(context.range, NSRange(location: 4, length: 2))
        XCTAssertEqual(context.text, "\r\n")
        XCTAssertEqual(context.cancellationPlan(selection: NSRange(location: 6, length: 0))?.original, "\r\n")
    }

    func testSelectionsBodyAndInconsistentSnapshotsAreRejected() {
        let context = read("\n", caret: 0, code: NSRange(location: 0, length: 1))!
        XCTAssertNil(context.cancellationPlan(selection: NSRange(location: 0, length: 1)))
        XCTAssertNil(context.cancellationPlan(selection: NSRange(location: 2, length: 0)))
        XCTAssertNil(CodeBlockContext.read(text: "", windowStart: 0, documentLength: 0, caret: 0,
            currentLineIsCode: false, isCodeLine: { _ in false }))
        XCTAssertNil(CodeBlockContext.read(text: "abc", windowStart: 0, documentLength: 2, caret: 0,
            currentLineIsCode: true, isCodeLine: { _ in true }))
    }
}
