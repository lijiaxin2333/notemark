import XCTest
@testable import NoteMarkCore

final class CodeParagraphMetadataTests: XCTestCase {
    func testParagraphSeparatorRecognizesChineseWithUnknownGlyphFonts() {
        let paragraph = NSRange(location: 44, length: 13)
        XCTAssertEqual(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: true,
            fontIsCode: { _ in nil }), true)
        // Fallback glyph fonts may report proportional traits inside a native
        // code paragraph. Its separator still carries the paragraph format.
        XCTAssertEqual(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: true,
            fontIsCode: { _ in false }), true)
    }

    func testBodySeparatorStopsChineseAndInlineCodeParagraphsJoiningCodeBlock() {
        let paragraph = NSRange(location: 5, length: 8)
        XCTAssertEqual(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: false,
            fontIsCode: { _ in nil }), false)
        XCTAssertEqual(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: false,
            fontIsCode: { _ in true }), false)
    }

    func testUnterminatedParagraphNeedsKnownFirstAndLastFonts() {
        let paragraph = NSRange(location: 5, length: 4)
        for fonts in [[5: true, 8: true], [5: false, 8: true], [5: true, 8: false]] {
            let expected = fonts[5] == true && fonts[8] == true
            XCTAssertEqual(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: nil,
                fontIsCode: { fonts[$0] }), expected)
        }
        for fonts in [[Int: Bool](), [5: true], [8: true]] {
            XCTAssertNil(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: nil,
                fontIsCode: { fonts[$0] }))
        }
        // A known Body glyph is a boundary even if the opposite glyph is absent.
        for fonts in [[5: false], [8: false]] {
            XCTAssertEqual(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: nil,
                fontIsCode: { fonts[$0] }), false)
        }
    }

    func testEmptyParagraphUsesOnlyItsOwnFont() {
        let paragraph = NSRange(location: 59, length: 0)
        XCTAssertNil(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: nil,
            fontIsCode: { $0 == 58 ? true : nil }))
        XCTAssertEqual(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: nil,
            fontIsCode: { $0 == 59 ? true : nil }), true)
        XCTAssertEqual(CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: nil,
            fontIsCode: { $0 == 59 ? false : nil }), false)
    }

    func testCapturedChineseMetadataKeepsContentAboveEmptyCodeCaret() {
        // Observed ranges: Chinese content 44..<57, code separator at 57,
        // current empty code paragraph at 58, terminal document position 59.
        let prefix = String(repeating: "t", count: 43) + "\n"
        let chinese = "中文代码段落待删除内容测试"
        XCTAssertEqual((chinese as NSString).length, 13)
        let text = prefix + chinese + "\n\n"
        let source = text as NSString
        XCTAssertEqual(source.length, 59)
        let context = CodeBlockContext.read(text: text, windowStart: 0,
            documentLength: source.length, caret: 58, currentLineIsCode: true,
            isCodeLine: { paragraph in
                // EOF is a separately established boundary, not an inferred
                // copy of the font on the separator before it.
                if paragraph.location == source.length { return false }
                let separator = NSMaxRange(paragraph)
                let separatorIsCode: Bool? = separator == 43 ? false :
                    [57, 58].contains(separator) ? true : nil
                return CodeBlockContext.codeParagraphState(paragraph,
                    separatorIsCode: separatorIsCode,
                    fontIsCode: { [57, 58].contains($0) ? true : nil })
            })
        XCTAssertEqual(context?.range, NSRange(location: 44, length: 14))
        XCTAssertEqual(context?.text, chinese + "\n")
        for intent in [CodeBlockCancellationIntent.backwardDeletion, .forwardDeletion, .escape] {
            XCTAssertNil(context?.cancellationPlan(selection: NSRange(location: 58, length: 0), intent: intent))
        }
    }

    func testChineseBodySeparatorBoundsTheEmptyCodeParagraph() {
        let chinese = "正文中文🌳"
        let text = chinese + "\n\nbody"
        let source = text as NSString
        let emptyStart = (chinese as NSString).length + 1
        let context = CodeBlockContext.read(text: text, windowStart: 0,
            documentLength: source.length, caret: emptyStart, currentLineIsCode: true,
            isCodeLine: { paragraph in
                CodeBlockContext.codeParagraphState(paragraph,
                    separatorIsCode: paragraph.location == 0 ? false : nil,
                    fontIsCode: { $0 == emptyStart })
            })
        XCTAssertEqual(context?.range, NSRange(location: emptyStart, length: 0))
        XCTAssertEqual(context?.cancellationPlan(selection: NSRange(location: emptyStart, length: 0),
            intent: .backwardDeletion)?.range, NSRange(location: emptyStart, length: 0))
    }

    func testUnknownAdjacentParagraphsCannotProveAnEmptyBlock() {
        let text = "中文🌳\n\nbody"
        let caret = ("中文🌳\n" as NSString).length
        for unknownBefore in [true, false] {
            let context = CodeBlockContext.read(text: text, windowStart: 0,
                documentLength: (text as NSString).length, caret: caret, currentLineIsCode: true,
                isCodeLine: { paragraph in
                    if (unknownBefore && paragraph.location < caret) ||
                       (!unknownBefore && paragraph.location > caret) {
                        return CodeBlockContext.codeParagraphState(paragraph, separatorIsCode: nil,
                            fontIsCode: { _ in nil })
                    }
                    return false
                })
            XCTAssertNil(context, "Unknown \(unknownBefore ? "preceding" : "following") paragraph")
        }
    }

    func testWindowEndingAfterLineBreakCannotTreatItsUnknownTailAsDocumentEOF() {
        let text = "body\n\n"
        let source = text as NSString
        let documentLength = ("body\n\ncode" as NSString).length
        var inspectedWindowTail = false
        let context = CodeBlockContext.read(text: text, windowStart: 0,
            documentLength: documentLength, caret: 5, currentLineIsCode: true,
            isCodeLine: { paragraph in
                // The sample ended immediately after the code separator. The
                // document continues, so this fontless position is unknown.
                if paragraph.length == 0 && paragraph.location == source.length {
                    inspectedWindowTail = true
                    XCTAssertLessThan(paragraph.location, documentLength)
                }
                let end = NSMaxRange(paragraph)
                let separatorIsCode: Bool? = end < source.length ? end == 5 : nil
                return CodeBlockContext.codeParagraphState(paragraph,
                    separatorIsCode: separatorIsCode,
                    fontIsCode: { $0 < source.length ? $0 == 5 : nil })
            })
        XCTAssertTrue(inspectedWindowTail)
        XCTAssertNil(context)
    }

    func testDeletingASCIIAndRepeatedBlankLinesNeverCancelsContentAboveCaret() {
        let stages = ["abc\n\ndef\n\n", "abc\n\ndef\n", "abc\n\ndef", "abc\n\nde",
                      "abc\n\nd", "abc\n\n", "abc\n", "abc", "ab", "a", ""] +
                     (0...50).reversed().map { String(repeating: "\n", count: $0) }
        for code in stages {
            let text = "body\n" + code + "\nnext body"
            let source = text as NSString
            let codeEnd = 5 + (code as NSString).length
            let context = CodeBlockContext.read(text: text, windowStart: 0,
                documentLength: source.length, caret: codeEnd, currentLineIsCode: true,
                isCodeLine: { paragraph in
                    let end = NSMaxRange(paragraph)
                    let hasSeparator = end < source.length && source.character(at: end) == 10
                    return CodeBlockContext.codeParagraphState(paragraph,
                        separatorIsCode: hasSeparator ? (end >= 5 && end <= codeEnd) : nil,
                        fontIsCode: { $0 >= 5 && $0 <= codeEnd })
                })
            XCTAssertEqual(context?.range, NSRange(location: 5, length: (code as NSString).length), code)
            let plan = context?.cancellationPlan(selection: NSRange(location: codeEnd, length: 0),
                intent: .backwardDeletion)
            XCTAssertEqual(plan != nil, code.isEmpty, code)
            if let plan { XCTAssertEqual(plan.range, NSRange(location: 5, length: 0)) }
        }
    }
}
