import XCTest
@testable import NoteMarkCore

final class MarkdownRuleTests: XCTestCase {
    func testNativeParagraphStyles() {
        let examples: [(String, ParagraphStyle)] = [
            ("#", .title), ("##", .heading), ("###", .subheading),
            (">", .quote), ("[]", .checklist), ("[ ]", .checklist),
            ("- [ ]", .checklist), ("*", .bullets), ("-", .bullets), ("1.", .numbered)
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
    func testChecklistBeforeExistingTextPreservesTheParagraph() {
        for marker in MarkdownRule.checklistMarkers {
            for tail in ["", "你好", "🌳 task", "task\nnext paragraph"] {
                let before = "🌳 前一段\n" + marker
                let plan = MarkdownRule.plan(beforeCaret: before, windowStart: 100, trigger: .space, afterCaret: tail)
                XCTAssertEqual(plan?.conversion, .paragraph(.checklist), marker)
                XCTAssertEqual(plan?.original, marker)
                XCTAssertEqual(plan?.range, NSRange(location: 107, length: (marker as NSString).length))
                if let plan {
                    XCTAssertEqual(((before + tail) as NSString).replacingCharacters(
                        in: NSRange(location: plan.range.location - 100, length: plan.range.length), with: ""),
                                   "🌳 前一段\n" + tail)
                }
            }
        }
    }
    func testChecklistRejectsUnsafeParagraphs() {
        for marker in MarkdownRule.checklistMarkers {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: marker, trigger: .space, isMonospaced: true))
            XCTAssertNil(MarkdownRule.plan(beforeCaret: marker, trigger: .space, selectionLength: 1))
            XCTAssertNil(MarkdownRule.plan(beforeCaret: marker, trigger: .enter))
            XCTAssertNil(MarkdownRule.plan(beforeCaret: marker, trigger: .space, afterCaret: "task\u{fffc}"))
            XCTAssertNil(MarkdownRule.plan(beforeCaret: marker, trigger: .space, afterCaret: nil))
            XCTAssertNil(MarkdownRule.plan(beforeCaret: marker, windowStart: 10, trigger: .space, afterCaret: "task"))
            XCTAssertNil(MarkdownRule.plan(beforeCaret: "text " + marker, trigger: .space))
            XCTAssertNil(MarkdownRule.plan(beforeCaret: "\\" + marker, trigger: .space))
        }
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "[]", trigger: .space, afterCaret: "task\n\u{fffc}")?.conversion,
                       .paragraph(.checklist))
    }
    func testListMarkerDetectionMatchesRules() {
        for marker in MarkdownRule.checklistMarkers + ["-", "*"] {
            XCTAssertTrue(MarkdownRule.isListMarker(marker))
        }
        for text in ["[x]", "[task]", "【任务】", "hello []", "1.", "#", "/checklist"] {
            XCTAssertFalse(MarkdownRule.isListMarker(text))
        }
    }
    func testCaretInMiddleOfLineDoesNotConvertParagraph() {
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "#", trigger: .space, afterCaret: "已有内容"))
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "#", trigger: .space, afterCaret: "\n")?.conversion, .paragraph(.title))
    }
    func testBulletPrefixBeforeExistingTextOnlyRemovesTheMarker() {
        for marker in ["-", "*"] {
            for text in ["你好", "🌳 Hello", "? question", " already indented"] {
                let plan = MarkdownRule.plan(beforeCaret: marker, trigger: .space, afterCaret: text)
                XCTAssertEqual(plan?.conversion, .paragraph(.bullets))
                XCTAssertEqual(plan?.range, NSRange(location: 0, length: 1))
                XCTAssertEqual(plan?.original, marker)
                let original = marker + text
                if let plan {
                    XCTAssertEqual((original as NSString).replacingCharacters(in: plan.range, with: ""), text)
                }
            }
        }
    }
    func testExistingTextBulletPrefixUsesUTF16ParagraphStart() {
        let before = "🌳 前一段\n-"
        let plan = MarkdownRule.plan(beforeCaret: before, windowStart: 100, trigger: .space, afterCaret: "你好")
        XCTAssertEqual(plan?.range, NSRange(location: 100 + (before as NSString).length - 1, length: 1))
        XCTAssertEqual(plan?.conversion, .paragraph(.bullets))
    }
    func testExistingTextConversionRequiresOnlyABulletAtLineStart() {
        for before in ["你好-", " -", "\\-", "#", "##", "1.", ">", "/bullets"] {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: before, trigger: .space, afterCaret: "你好"), before)
        }
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "-", windowStart: 10, trigger: .space, afterCaret: "你好"))
    }
    func testExistingTextBulletDoesNotConvertCodeOrSelections() {
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "-", trigger: .space, isMonospaced: true, afterCaret: "你好"))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "-", trigger: .space, selectionLength: 1, afterCaret: "你好"))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "-", trigger: .enter, afterCaret: "你好"))
    }
    func testExistingTextBulletRejectsImagesInCurrentParagraphOnly() {
        for tail in ["\u{fffc}", "你好\u{fffc}", "你好 \u{fffc} 后面的文字"] {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: "-", trigger: .space, afterCaret: tail), tail)
        }
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "-", trigger: .space, afterCaret: "你好\n\u{fffc}")?.conversion,
                       .paragraph(.bullets))
    }
    func testBulletRejectsUnknownOrTruncatedRightBoundary() {
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "-", trigger: .space, afterCaret: nil))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "#", trigger: .space, afterCaret: nil))
        // Inline Markdown does not depend on the right boundary.
        XCTAssertNotNil(MarkdownRule.plan(beforeCaret: "**bold**", trigger: .space, afterCaret: nil))
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
        XCTAssertEqual(MenuShortcut.format(.title).key, "t")
        XCTAssertEqual(MenuShortcut.format(.heading).key, "h")
        XCTAssertEqual(MenuShortcut.format(.subheading).key, "j")
        XCTAssertEqual(MenuShortcut.format(.monostyled).key, "m")
        XCTAssertEqual(MenuShortcut.format(.quote).key, "'")
        XCTAssertFalse(MenuShortcut.format(.quote).requiresShift)
        XCTAssertTrue(MenuShortcut.format(.checklist).requiresShift)
        let expected: [ParagraphStyle: String] = [.title: "t", .heading: "h", .subheading: "j", .body: "b",
            .monostyled: "m", .quote: "'", .checklist: "l", .bullets: "7", .dashed: "8", .numbered: "9"]
        for style in ParagraphStyle.allCases {
            XCTAssertEqual(MenuShortcut.format(style).key, expected[style], style.rawValue)
            XCTAssertEqual(MenuShortcut.format(style).requiresShift, style != .quote, style.rawValue)
        }
    }

    func testTypedSlashNamesMatchTheMenuCommands() {
        let expected: [String: ParagraphStyle] = [
            "/title": .title, "/h1": .title, "/heading": .heading, "/h2": .heading,
            "/subheading": .subheading, "/h3": .subheading, "/body": .body, "/code": .monostyled,
            "/quote": .quote, "/checklist": .checklist, "/bullets": .bullets, "/dashed": .dashed,
            "/numbered": .numbered
        ]
        for (line, style) in expected {
            XCTAssertEqual(MarkdownRule.plan(beforeCaret: line, trigger: .space)?.conversion, .paragraph(style), line)
        }
        // Search aliases open the menu but are not typed shortcuts.
        for line in ["/todo", "/list", "/text", "/mono", "/H1", "／h1", "/h2 ", "/标题"] {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: line, trigger: .space), line)
        }
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "/h2", trigger: .enter))
    }
}
