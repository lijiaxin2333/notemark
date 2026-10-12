import XCTest
@testable import NoteMarkCore

final class SlashCommandTests: XCTestCase {
    func testBareSlashShowsAllCommands() {
        XCTAssertEqual(SlashQuery.parse(beforeCaret: "/")?.query, "")
        XCTAssertEqual(SlashCommand.matching("").count, 12)
        XCTAssertEqual(Set(SlashCommand.all.map(\.id)).count, 12)
        XCTAssertEqual(Set(SlashCommand.all.compactMap(\.style)).count, 10)
    }

    func testExactAliasRanksFirstAndEnglishIsCaseInsensitive() {
        XCTAssertEqual(SlashCommand.matching("h2").first?.style, .heading)
        XCTAssertEqual(SlashCommand.matching("CODE").first?.style, .monostyled)
        XCTAssertEqual(SlashCommand.matching("body").first?.style, .body)
        XCTAssertEqual(SlashCommand.matching("todo").first?.style, .checklist)
    }

    func testChineseAndPartialSearch() {
        XCTAssertEqual(SlashCommand.matching("引用").first?.style, .quote)
        XCTAssertEqual(SlashCommand.matching("代码").first?.style, .monostyled)
        XCTAssertEqual(SlashCommand.matching("清单").first?.style, .checklist)
        XCTAssertEqual(SlashCommand.matching("h").prefix(3).map(\.style), [.title, .heading, .subheading])
        XCTAssertTrue(SlashCommand.matching("notacommand").isEmpty)
    }

    func testSearchIncludesEveryVisibleTitleAndDetail() {
        for command in SlashCommand.all {
            for term in [command.title, command.detail, command.englishTitle, command.englishDetail] {
                XCTAssertEqual(SlashCommand.matching(term).first?.id, command.id, term)
            }
        }
    }

    func testListSearchReturnsEveryListStyleInChineseAndEnglish() {
        let lists: Set<ParagraphStyle> = [.checklist, .bullets, .dashed, .numbered]
        XCTAssertEqual(Set(SlashCommand.matching("列表").map(\.style)), lists)
        XCTAssertEqual(Set(SlashCommand.matching("LIST").map(\.style)), lists)
        XCTAssertEqual(SlashCommand.matching("list").first?.style, .bullets)
        XCTAssertEqual(SlashCommand.matching("符号").first?.style, .bullets)
        XCTAssertEqual(SlashCommand.matching("任务列表").first?.style, .checklist)
        XCTAssertEqual(SlashCommand.matching("短横线列表").first?.style, .dashed)
    }

    func testNumberedListSynonymsAndExactOrdering() {
        for query in ["编号", "编号列表", "序号", "序号列表", "有序号列表", "数字", "数字列表", "有序列表", "ordered", "numbered"] {
            XCTAssertEqual(SlashCommand.matching(query).first?.style, .numbered, query)
        }
        XCTAssertEqual(SlashCommand.matching("无序列表").first?.style, .bullets)
        XCTAssertEqual(SlashCommand.matching("unordered").first?.style, .bullets)
        XCTAssertEqual(SlashCommand.matching("h1").first?.style, .title)
        XCTAssertEqual(SlashCommand.matching("h2").first?.style, .heading)
        XCTAssertTrue(SlashCommand.matching("不存在的命令").isEmpty)
    }

    func testChineseAndEnglishCommandsKeepTrailingSpacesInEditRange() throws {
        for (input, name, style) in [("/标题 ", "标题", ParagraphStyle.title),
                                     ("/title  ", "title", .title), ("/H2 ", "H2", .heading),
                                     ("／小标题　", "小标题", .heading), ("/代码\u{00a0}", "代码", .monostyled)] {
            let prefix = "👩🏽‍💻\n"
            let query = try XCTUnwrap(SlashQuery.parse(beforeCaret: prefix + input, windowStart: 20), input)
            XCTAssertEqual(query.query, name)
            XCTAssertEqual(query.original, input)
            XCTAssertEqual(query.range, NSRange(location: 20 + (prefix as NSString).length,
                                               length: (input as NSString).length))
            let command = try XCTUnwrap(SlashCommand.matching(query.query).first)
            XCTAssertEqual(command.style, style)
            XCTAssertEqual(query.plan(for: command).original, input)
        }
    }

    func testParserNormalizesWhitespaceSeparatelyFromMenuVisibility() throws {
        for input in ["/ ", "/　", "／", "／ "] {
            let query = try XCTUnwrap(SlashQuery.parse(beforeCaret: input), input)
            XCTAssertEqual(query.query, "")
            XCTAssertEqual(SlashCommand.matching(query.query), SlashCommand.all)
        }
        XCTAssertEqual(SlashCommand.matching(" TITLE　").first?.style, .title)
        XCTAssertEqual(SlashCommand.matching("标题 ").first?.style, .title)
    }

    func testRepeatedWhitespaceInsideCommandAndFullWidthPathsAreRejected() {
        for input in ["/ti  tle ", "/标　题", "／usr/bin", "／／", "/title\tmore"] {
            XCTAssertNil(SlashQuery.parse(beforeCaret: input), input)
        }
        // Single spaces separate words of English names; other text matches nothing.
        XCTAssertEqual(SlashQuery.parse(beforeCaret: "/code block ")?.query, "code block")
        for query in ["ti tle", "标 题", "hello world"] {
            XCTAssertEqual(SlashQuery.parse(beforeCaret: "/" + query)?.query, query)
            XCTAssertTrue(SlashCommand.matching(query).isEmpty, query)
        }
    }

    func testQueryRangeUsesUTF16AndLeavesPreviousParagraphsAlone() throws {
        let query = try XCTUnwrap(SlashQuery.parse(beforeCaret: "👩🏽‍💻 算法\n/代码", windowStart: 100))
        XCTAssertEqual(query.range.location, 100 + ("👩🏽‍💻 算法\n" as NSString).length)
        XCTAssertEqual(query.range.length, 3)
        let plan = query.plan(for: SlashCommand.matching("code")[0])
        XCTAssertEqual(plan.original, "/代码")
        XCTAssertEqual(plan.range, query.range)
        XCTAssertEqual(plan.conversion, .paragraph(.monostyled))
    }

    func testPathURLAndInlineSlashAreNeverCommands() {
        for input in ["https://example.com", "/usr/bin", "look /h1", " // comment", "//", " /h1", "/\\h1"] {
            XCTAssertNil(SlashQuery.parse(beforeCaret: input), input)
        }
    }

    func testCodeSelectionsImagesAndUnknownBoundariesAreIgnored() {
        XCTAssertNil(SlashQuery.parse(beforeCaret: "/h1", isMonospaced: true))
        XCTAssertNil(SlashQuery.parse(beforeCaret: "/h1", selectionLength: 1))
        XCTAssertNil(SlashQuery.parse(beforeCaret: "/h1", afterCaret: "文字"))
        XCTAssertNil(SlashQuery.parse(beforeCaret: "/h1", windowStart: 5))
        XCTAssertNil(SlashQuery.parse(beforeCaret: "/\u{fffc}"))
        XCTAssertNotNil(SlashQuery.parse(beforeCaret: "\u{fffc}\n/h1", windowStart: 5))
        XCTAssertNotNil(SlashQuery.parse(beforeCaret: "/h1", afterCaret: "\n"))
    }

    func testLongQueryDoesNotOpenMenu() {
        XCTAssertNil(SlashQuery.parse(beforeCaret: "/" + String(repeating: "a", count: 41)))
    }

    func testSelectionWrapsInBothDirections() {
        var selection = SlashSelection()
        selection.move(-1)
        XCTAssertEqual(selection.selected?.id, "date")
        selection.move(1)
        XCTAssertEqual(selection.selected?.style, .title)
        selection.move(13)
        XCTAssertEqual(selection.selected?.style, .heading)
    }

    func testSearchResetsSelectionAndEmptyResultsAreSafe() {
        var selection = SlashSelection()
        selection.move(3)
        selection.update(query: "quote")
        XCTAssertEqual(selection.index, 0)
        XCTAssertEqual(selection.selected?.style, .quote)
        selection.update(query: "missing")
        selection.move(-1)
        XCTAssertNil(selection.selected)
        XCTAssertEqual(selection.index, 0)
    }

    func testPopupClampsToRightAndBottomAndOpensAboveCaret() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frame = SlashPopupPlacement.frame(anchor: CGRect(x: 980, y: 20, width: 1, height: 18), visibleFrame: screen, size: CGSize(width: 340, height: 528))
        XCTAssertTrue(screen.contains(frame))
        XCTAssertEqual(frame.minX, 660)
        XCTAssertEqual(frame.minY, 44)
    }

    func testPopupSupportsDisplaysLeftOfMainAndSmallScreens() {
        let screen = CGRect(x: -600, y: 800, width: 500, height: 300)
        let frame = SlashPopupPlacement.frame(anchor: CGRect(x: -500, y: 1080, width: 1, height: 18), visibleFrame: screen, size: CGSize(width: 340, height: 528))
        XCTAssertTrue(screen.contains(frame))
        XCTAssertEqual(frame.height, 300)
        XCTAssertEqual(frame.minY, 800)
    }
}
