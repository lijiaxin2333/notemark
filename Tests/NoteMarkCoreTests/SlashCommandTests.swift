import XCTest
@testable import NoteMarkCore

final class SlashCommandTests: XCTestCase {
    func testBareSlashShowsAllCommands() {
        XCTAssertEqual(SlashQuery.parse(beforeCaret: "/")?.query, "")
        XCTAssertEqual(SlashCommand.matching("").count, 10)
        XCTAssertEqual(Set(SlashCommand.all.map(\.style)).count, 10)
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
        for input in ["https://example.com", "/usr/bin", "look /h1", " // comment", "//", " /h1", "/hello world", "/\\h1"] {
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
        XCTAssertEqual(selection.selected?.style, .numbered)
        selection.move(1)
        XCTAssertEqual(selection.selected?.style, .title)
        selection.move(11)
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
