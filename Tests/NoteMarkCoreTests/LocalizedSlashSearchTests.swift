import XCTest
@testable import NoteMarkCore

/// Every slash title and description shown in a translation must find its
/// own command, or typing what the menu shows would hide the menu.
final class LocalizedSlashSearchTests: XCTestCase {
    private var resources: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Packaging/Resources")
    }

    func testShownTitlesAndDescriptionsFindTheirCommands() throws {
        let languages = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        var checked = 0
        for language in languages {
            let table = resources.appendingPathComponent(language).appendingPathComponent("Localizable.strings")
            guard let strings = NSDictionary(contentsOf: table) as? [String: String] else { continue }
            for command in SlashCommand.all {
                for field in ["title", "detail"] {
                    guard let shown = strings["slash.\(command.id).\(field)"] else { continue }
                    XCTAssertEqual(SlashCommand.matching(shown).first?.id, command.id, "\(language) \(field): \(shown)")
                    XCTAssertNotNil(SlashQuery.parse(beforeCaret: "/" + shown), "\(language) \(field): \(shown)")
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 48)
        // English text lives in code.
        for command in SlashCommand.all {
            XCTAssertEqual(SlashCommand.matching(command.englishTitle).first?.id, command.id)
            XCTAssertEqual(SlashCommand.matching(command.englishDetail).first?.id, command.id, command.englishDetail)
            for shown in [command.englishTitle, command.englishDetail] {
                XCTAssertEqual(SlashQuery.parse(beforeCaret: "/" + shown)?.query, shown)
            }
        }
    }

    func testDividerEvidenceFollowsTheRules() {
        var history = TypingHistory()
        history.append("---")
        XCTAssertTrue(history.looksLikeMarkdown())
        var noDividers = ConversionRules()
        noDividers.dividers = false
        XCTAssertFalse(history.looksLikeMarkdown(rules: noDividers))
        var chinese = TypingHistory()
        chinese.append("——")
        var noFullWidth = ConversionRules()
        noFullWidth.fullWidthMarkers = false
        XCTAssertFalse(chinese.looksLikeMarkdown(rules: noFullWidth))
    }

    func testPunctuationDoesNotSearchDescriptions() {
        XCTAssertTrue(SlashCommand.matching("-").isEmpty)
        XCTAssertEqual(SlashCommand.matching("虚线列表").first?.id, "dashed")
    }

    func testCodeKeepsItsBackslashes() {
        XCTAssertNil(MarkdownRule.plan(beforeCaret: "\\```", trigger: .space, isMonospaced: true))
        XCTAssertEqual(MarkdownRule.plan(beforeCaret: "\\```", trigger: .space)?.conversion, .unescape)
    }
}
