import XCTest
@testable import NoteMarkCore

/// Rules added for the 0.2 product pass: Chinese text, full-width markers,
/// deeper headings, dividers, dates, escapes, and per-group switches.
final class ProductRuleTests: XCTestCase {
    private func conversion(_ line: String, _ trigger: Trigger = .space, after: String? = "",
                            mono: Bool = false, rules: ConversionRules = .default) -> Conversion? {
        MarkdownRule.plan(beforeCaret: line, trigger: trigger, isMonospaced: mono, afterCaret: after, rules: rules)?.conversion
    }

    func testInlineStylesConvertInsideChineseText() {
        let plan = MarkdownRule.plan(beforeCaret: "这是**重点**", trigger: .space)
        XCTAssertEqual(plan?.conversion, .inline(.bold, text: "重点", delimiter: " "))
        XCTAssertEqual(plan?.range, NSRange(location: 2, length: 6))
        XCTAssertEqual(conversion("（**粗体**"), .inline(.bold, text: "粗体", delimiter: " "))
        XCTAssertEqual(conversion("代码`let x`"), .inline(.code, text: "let x", delimiter: " "))
        XCTAssertEqual(conversion("参考[文档](https://example.com)"),
                       .inline(.link("https://example.com"), text: "文档", delimiter: " "))
        // ASCII text and underscore identifiers stay literal.
        for literal in ["abc**x**", "name*value*", "2*3*", "变量_名_", "变量__名__"] {
            XCTAssertNil(conversion(literal), literal)
        }
    }

    func testDeeperHeadingsBecomeSubheadings() {
        for marker in ["####", "#####", "######"] {
            XCTAssertEqual(conversion(marker), .paragraph(.subheading), marker)
        }
        XCTAssertNil(conversion("#######"))
    }

    func testFullWidthAndChinesePunctuationMarkers() {
        let expected: [(String, Conversion)] = [
            ("＃", .paragraph(.title)), ("＃＃", .paragraph(.heading)), ("＃＃＃", .paragraph(.subheading)),
            ("＞", .paragraph(.quote)), ("》", .paragraph(.quote)), ("＊", .paragraph(.bullets)),
            ("－", .paragraph(.bullets)), ("１．", .paragraph(.numbered)), ("1。", .paragraph(.numbered)),
            ("···", .paragraph(.monostyled)), ("｀｀｀", .paragraph(.monostyled)), ("－－－", .divider)
        ]
        for (marker, result) in expected {
            XCTAssertEqual(conversion(marker), result, marker)
        }
        XCTAssertEqual(conversion("···swift", .enter), .paragraph(.monostyled))
        XCTAssertEqual(conversion("···", mono: true), .paragraph(.body))
        let plan = MarkdownRule.plan(beforeCaret: "＊", trigger: .space, afterCaret: "已有文字")
        XCTAssertEqual(plan?.conversion, .paragraph(.bullets))
        XCTAssertEqual(plan?.range, NSRange(location: 0, length: 1))
        var rules = ConversionRules()
        rules.fullWidthMarkers = false
        for marker in ["＃", "》", "＊", "1。", "···"] {
            XCTAssertNil(conversion(marker, rules: rules), marker)
        }
        // ASCII markers and existing full-width checklists are unaffected by the switch.
        XCTAssertEqual(conversion("#", rules: rules), .paragraph(.title))
        XCTAssertEqual(conversion("【】", rules: rules), .paragraph(.checklist))
    }

    func testDashListSetting() {
        var rules = ConversionRules()
        XCTAssertEqual(conversion("-", rules: rules), .paragraph(.bullets))
        rules.dashMakesDashedList = true
        XCTAssertEqual(conversion("-", rules: rules), .paragraph(.dashed))
        XCTAssertEqual(conversion("－", rules: rules), .paragraph(.dashed))
        XCTAssertEqual(conversion("*", rules: rules), .paragraph(.bullets))
        let plan = MarkdownRule.plan(beforeCaret: "-", trigger: .space, afterCaret: "text", rules: rules)
        XCTAssertEqual(plan?.conversion, .paragraph(.dashed))
    }

    func testDividers() {
        for marker in ["---", "***", "___", "—-", "——"] {
            XCTAssertEqual(conversion(marker), .divider, marker)
            XCTAssertEqual(conversion(marker, .enter), .divider, marker)
            XCTAssertNil(conversion(marker, mono: true), marker)
            XCTAssertNil(conversion(marker, after: "text"), marker)
        }
        let plan = MarkdownRule.plan(beforeCaret: "前一段\n---", windowStart: 10, trigger: .space)
        XCTAssertEqual(plan?.range, NSRange(location: 14, length: 3))
        var rules = ConversionRules()
        rules.dividers = false
        XCTAssertNil(conversion("---", rules: rules))
        XCTAssertNil(conversion("/divider", rules: rules))
        XCTAssertFalse(SlashCommand.matching("", rules: rules).contains { $0.id == "divider" })
        XCTAssertTrue(SlashCommand.matching("divider", rules: rules).isEmpty)
        XCTAssertNil(conversion("—"))
        XCTAssertNil(conversion("--"))
        // Smart Dashes turns a typed `---` into one em dash after a pause.
        for trigger in [Trigger.space, .enter] {
            let smart = MarkdownRule.plan(beforeCaret: "前一段\n—", windowStart: 10, trigger: trigger, typedLine: "---")
            XCTAssertEqual(smart?.conversion, .divider)
            XCTAssertEqual(smart?.range, NSRange(location: 14, length: 1))
            XCTAssertEqual(smart?.original, "—")
        }
        for typed in ["--", "—", "-", "***", "-a-"] {
            XCTAssertNil(MarkdownRule.plan(beforeCaret: "—", trigger: .space, typedLine: typed), typed)
        }
        // Deleting an em dash removes one typed hyphen, so `---` typed again follows more.
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "—", trigger: .space, typedLine: "-----")?.conversion, .divider)
        // `\---` turned into `\—` keeps the dash as text.
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "\\—", trigger: .space, typedLine: "\\---")?.conversion, .unescape)
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "\\—", trigger: .space))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "—", trigger: .space, rules: rules, typedLine: "---"))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "—", trigger: .space, afterCaret: "x", typedLine: "---"))
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "—", trigger: .space, isMonospaced: true, typedLine: "---"))
        // The Chinese dash form follows the full-width switch.
        var noFullWidth = ConversionRules()
        noFullWidth.fullWidthMarkers = false
        XCTAssertNil(conversion("——", rules: noFullWidth))
        XCTAssertEqual(conversion("—-", rules: noFullWidth), .divider)
    }

    func testTypedSlashActions() {
        XCTAssertEqual(conversion("/divider"), .divider)
        XCTAssertEqual(conversion("/hr"), .divider)
        XCTAssertEqual(conversion("/date"), .date)
        let query = SlashQuery.parse(beforeCaret: "/日期")
        XCTAssertEqual(query.map { $0.plan(for: SlashCommand.matching("日期")[0]).conversion }, .date)
    }

    func testEscapedMarkersKeepTheirText() {
        for marker in ["#", "##", ">", "-", "*", "1.", "[]", "---", "```", "/h2", "＃"] {
            let plan = MarkdownRule.plan(beforeCaret: "前一段\n\\" + marker, windowStart: 0, trigger: .space)
            XCTAssertEqual(plan?.conversion, .unescape, marker)
            XCTAssertEqual(plan?.range, NSRange(location: 4, length: 1), marker)
            XCTAssertEqual(plan?.original, "\\", marker)
        }
        XCTAssertNil(conversion("\\#", .enter))
        XCTAssertNil(conversion("\\#", after: "text"))
        XCTAssertNil(conversion("\\hello"))
        XCTAssertNil(conversion("\\\\#"))
        var rules = ConversionRules()
        rules.headings = false
        XCTAssertNil(conversion("\\#", rules: rules))
    }

    func testEscapedParagraphKeepsLaterMarkersAsText() throws {
        // `\-` and Space leave "-"; a Space or `[ ]` typed after it stays text.
        XCTAssertEqual(conversion("\\-"), .unescape)
        let escaped = try XCTUnwrap(EscapedMarker(escaping: "\\-"))
        let bullet = try XCTUnwrap(MarkdownRule.plan(beforeCaret: "-", trigger: .space))
        XCTAssertTrue(escaped.keepsLiteral(bullet, line: "-"))
        let checklist = try XCTUnwrap(MarkdownRule.plan(beforeCaret: "- [ ]", trigger: .space))
        XCTAssertEqual(checklist.conversion, .paragraph(.checklist))
        XCTAssertTrue(escaped.keepsLiteral(checklist, line: "- [ ]"))
        // Inline styles still convert, and another marker is not affected.
        let bold = try XCTUnwrap(MarkdownRule.plan(beforeCaret: "- **a**", trigger: .space))
        XCTAssertFalse(escaped.keepsLiteral(bold, line: "- **a**"))
        let heading = try XCTUnwrap(MarkdownRule.plan(beforeCaret: "#", trigger: .space))
        XCTAssertFalse(escaped.keepsLiteral(heading, line: "#"))
        let hash = try XCTUnwrap(EscapedMarker(escaping: "\\#"))
        XCTAssertTrue(hash.keepsLiteral(heading, line: "#"))
        let date = try XCTUnwrap(EscapedMarker(escaping: "\\/date"))
        let typedDate = try XCTUnwrap(MarkdownRule.plan(beforeCaret: "/date", trigger: .space))
        XCTAssertTrue(date.keepsLiteral(typedDate, line: "/date"))
        let fence = try XCTUnwrap(EscapedMarker(escaping: "\\```"))
        let code = try XCTUnwrap(MarkdownRule.plan(beforeCaret: "```", trigger: .enter))
        XCTAssertTrue(fence.keepsLiteral(code, line: "```"))
        XCTAssertNil(EscapedMarker(escaping: "\\"))
        XCTAssertNil(EscapedMarker(escaping: "-"))
    }

    func testRuleGroupsCanBeDisabled() {
        let cases: [(WritableKeyPath<ConversionRules, Bool>, String, Trigger)] = [
            (\.headings, "#", .space), (\.lists, "-", .space), (\.lists, "1.", .space),
            (\.checklists, "[]", .space), (\.quotes, ">", .space), (\.codeBlocks, "```", .space),
            (\.codeBlocks, "```swift", .enter), (\.inlineStyles, "**bold**", .space),
            (\.links, "[a](https://example.com)", .space), (\.dividers, "---", .space),
            (\.slashCommands, "/h2", .space), (\.slashCommands, "/date", .space)
        ]
        for (keyPath, line, trigger) in cases {
            XCTAssertNotNil(conversion(line, trigger), line)
            var rules = ConversionRules()
            rules[keyPath: keyPath] = false
            XCTAssertNil(conversion(line, trigger, rules: rules), line)
        }
        var noLists = ConversionRules()
        noLists.lists = false
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "-", trigger: .space, afterCaret: "text", rules: noLists))
    }

    func testRulesDecodeOlderSettingsWithDefaults() throws {
        let decoded = try JSONDecoder().decode(ConversionRules.self, from: Data(#"{"headings": false}"#.utf8))
        var expected = ConversionRules()
        expected.headings = false
        XCTAssertEqual(decoded, expected)
        var rules = ConversionRules()
        rules.dashMakesDashedList = true
        rules.links = false
        XCTAssertEqual(try JSONDecoder().decode(ConversionRules.self, from: JSONEncoder().encode(rules)), rules)
    }

    func testSlashSearchUsesNotesNamesEnglishAndPinyin() {
        let expected: [String: String] = [
            "副标题": "subheading", "核对清单": "checklist", "块引用": "quote", "等宽样式": "monostyled",
            "短划线列表": "dashed", "blockquote": "quote", "monostyled": "monostyled", "ul": "bullets", "ol": "numbered",
            "code block": "monostyled", "bulleted": "bullets", "divider": "divider", "分隔线": "divider", "日期": "date",
            "bt": "title", "biaoti": "title", "xbt": "heading", "dm": "monostyled", "db": "checklist",
            "fgx": "divider", "rq": "date", "zw": "body",
            "大標題": "title", "標題": "heading", "子標題": "subheading", "檢查表": "checklist", "破折號": "dashed",
            "程式碼": "monostyled", "區塊引言": "quote"
        ]
        for (query, id) in expected {
            XCTAssertEqual(SlashCommand.matching(query).first?.id, id, query)
        }
        // Pinyin ranks after real names, and needs two letters.
        XCTAssertEqual(SlashCommand.matching("h").prefix(3).compactMap(\.style), [.title, .heading, .subheading])
        XCTAssertEqual(Set(SlashCommand.matching("列表").compactMap(\.style)), [.checklist, .bullets, .dashed, .numbered])
        XCTAssertEqual(SlashCommand.matching("列表").count, 4)
        // Names outrank description words.
        XCTAssertEqual(SlashCommand.matching("to").first?.id, "checklist")
        XCTAssertEqual(SlashCommand.matching("short").first?.id ?? "none", "none")
        XCTAssertEqual(SlashCommand.matching("Top-level heading").first?.id, "title")
    }
}
