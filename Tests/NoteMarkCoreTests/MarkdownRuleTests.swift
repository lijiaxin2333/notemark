import XCTest
@testable import NoteMarkCore

final class MarkdownRuleTests: XCTestCase {
    func testNativeParagraphStyles() {
        let examples: [(String, ParagraphStyle)] = [
            ("#", .title), ("##", .heading), ("###", .subheading),
            (">", .quote), ("[]", .checklist), ("[ ]", .checklist),
            ("- [ ]", .checklist), ("*", .bullets), ("-", .dashed), ("1.", .numbered)
        ]
        for (input, style) in examples {
            let result = MarkdownRule.plan(beforeCaret: input, trigger: .space)
            XCTAssertEqual(result?.conversion, .paragraph(style), input)
            XCTAssertEqual(result?.range, NSRange(location: 0, length: (input as NSString).length))
        }
    }
    func testPrefixMustBeEntireLine() {
        for input in ["### 标题", "hello #", " #", "####", "abc-", "1.2", "##\\"] {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: input, trigger: .space), input)
        }
    }
    func testCaretInMiddleOfLineDoesNotConvertParagraph() {
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "#", trigger: .space, afterCaret: "已有内容"))
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "#", trigger: .space, afterCaret: "\n")?.conversion, .paragraph(.title))
    }
    func testUnicodeParagraphOffsets() {
        let input = "🌳 算法\n##"
        let result = MarkdownRule.plan(beforeCaret: input, windowStart: 100, trigger: .space)
        XCTAssertEqual(result?.range, NSRange(location: 106, length: 2))
    }
    func testUnknownWindowBoundaryRejectsParagraph() {
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "#", windowStart: 22, trigger: .space))
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "文字\n#", windowStart: 22, trigger: .space)?.range, NSRange(location: 25, length: 1))
    }
    func testSelectionIsNeverReplaced() {
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "#", trigger: .space, selectionLength: 2))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "**bold**", trigger: .space, selectionLength: 1))
    }
    func testFenceEnterAndExit() {
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "```", trigger: .space)?.conversion, .paragraph(.monostyled))
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "```swift", trigger: .enter)?.conversion, .paragraph(.monostyled))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "```swift", trigger: .space))
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "```", trigger: .enter, isMonospaced: true)?.conversion, .paragraph(.body))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "```swift", trigger: .enter, isMonospaced: true))
    }
    func testCodeBlockRetainsMarkdownLookingCode() {
        for input in ["#", "**bold**", "*x*", "[]", "var a = `code`", "/h1", ">"] {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: input, trigger: .space, isMonospaced: true), input)
        }
    }
    func testBoldItalicAndStrikethrough() {
        let examples: [(String, InlineStyle, String)] = [
            ("**粗体**", .bold, "粗体"), ("__bold__", .bold, "bold"),
            ("*italic*", .italic, "italic"), ("_斜体_", .italic, "斜体"),
            ("***both***", .boldItalic, "both"), ("~~删除~~", .strike, "删除"),
            ("`let x = 1`", .code, "let x = 1")
        ]
        for (input, style, text) in examples {
            XCTAssertEqual(MarkdownRule.plan(beforeCaret: input, trigger: .space)?.conversion,
                           .inline(style, text: text, delimiter: " "), input)
        }
    }
    func testInlineEnterIsIncludedInReplacement() {
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "**粗体**", trigger: .enter)?.conversion,
                       .inline(.bold, text: "粗体", delimiter: "\n"))
    }
    func testInlineUnicodeUsesUTF16NotGraphemeCount() {
        let result = MarkdownRule.plan(beforeCaret: "👩🏽‍💻 这里 **🌳树**", windowStart: 42, trigger: .space)
        let prefix = "👩🏽‍💻 这里 " as NSString
        XCTAssertEqual(result?.range, NSRange(location: 42 + prefix.length, length: ("**🌳树**" as NSString).length))
        XCTAssertEqual(result?.original, "**🌳树**")
    }
    func testImagesOutsideEditedParagraphDoNotBlock() {
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "\u{fffc}\n##", trigger: .space)?.conversion, .paragraph(.heading))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "**图片\u{fffc}**", trigger: .space))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "\u{fffc} #", trigger: .space))
    }
    func testEscapedMarkersRetainLiteralText() {
        for input in ["\\**bold**", "**bold\\**", "\\_italic_", "\\`code`", "\\[link](https://example.com)"] {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: input, trigger: .space), input)
        }
    }
    func testUnfinishedNestedAndCodeIdentifiersAreRetained() {
        for input in ["**unfinished", "snake_case_", "name*value*", "** **", "**bold *italic***", "****"] {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: input, trigger: .space), input)
        }
    }
    func testNoInlineConversionAcrossParagraphs() {
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "**line one\nline two**", trigger: .space))
    }
    func testLinkAndUnsafeURLSchemes() {
        let result = MarkdownRule.plan(beforeCaret: "参考 [文档](https://example.com/page)", trigger: .space)
        XCTAssertEqual(result?.conversion, .inline(.link("https://example.com/page"), text: "文档", delimiter: " "))
        XCTAssertNotNil(MarkdownRule.plan(beforeCaret: "[邮箱](mailto:user@example.com)", trigger: .enter))
        for input in ["[x](javascript:alert)", "[x](file:///etc/passwd)", "[x](https:)", "![图片](https://example.com/a.png)"] {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: input, trigger: .space), input)
        }
    }
    func testSlashCommandsMapToNativeStyles() {
        for command in ["/h1", "/title"] {
            XCTAssertEqual(MarkdownRule.plan(beforeCaret: command, trigger: .space)?.conversion, .paragraph(.title))
        }
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "/body", trigger: .space)?.conversion, .paragraph(.body))
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "/code", trigger: .space)?.conversion, .paragraph(.monostyled))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "path/h1", trigger: .space))
    }
    func testShortcutMappingMatchesAppleNotes() {
        XCTAssertEqual(ParagraphStyle.title.shortcut, "t")
        XCTAssertEqual(ParagraphStyle.heading.shortcut, "h")
        XCTAssertEqual(ParagraphStyle.subheading.shortcut, "j")
        XCTAssertEqual(ParagraphStyle.monostyled.shortcut, "m")
        XCTAssertEqual(ParagraphStyle.quote.shortcut, "'")
        XCTAssertFalse(ParagraphStyle.quote.needsShift)
        XCTAssertTrue(ParagraphStyle.checklist.needsShift)
    }
}
