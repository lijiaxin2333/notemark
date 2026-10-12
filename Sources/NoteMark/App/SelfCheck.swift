import Foundation
import NoteMarkCore

/// Smoke test of the rules compiled into a release binary. The unit tests
/// cover the rules in depth; this confirms the shipped build links them.
enum SelfCheck {
    struct Check {
        let name: String
        let passed: Bool
    }

    static func run() -> [Check] {
        var slashSession = SlashMenuSession()
        slashSession.begin()
        let initialMenu = slashSession.update(beforeCaret: "/")
        let titleMenu = slashSession.update(beforeCaret: "/题")
        let deletedMenu = slashSession.update(beforeCaret: "/")
        let spaceMenu = slashSession.update(beforeCaret: "/ ")
        let unknownMenu = slashSession.update(beforeCaret: "/notacommand")
        let existingBullet = MarkdownRule.plan(beforeCaret: "-", trigger: .space, afterCaret: "你好")
        let checklist = MarkdownRule.plan(beforeCaret: "[]", trigger: .space, afterCaret: "待办事项")
        let codeWithEmptyLastLine = CodeBlockContext.read(text: "abc\n", windowStart: 0, documentLength: 4,
            caret: 4, currentLineIsCode: true, isCodeLine: { _ in true })
        let emptyCode = CodeBlockContext.read(text: "\n\n", windowStart: 0, documentLength: 2,
            caret: 2, currentLineIsCode: true, isCodeLine: { _ in true })
        let terminalEmptyCode = CodeBlockContext.read(text: "body\n\n", windowStart: 0, documentLength: 6,
            caret: 5, currentLineIsCode: true, isCodeLine: { line in
                CodeBlockContext.isCodeParagraph(line, fontIsCode: { $0 == 5 ? true : nil })
            })
        let chineseCode = CodeBlockContext.read(text: "body\n中文\n\n", windowStart: 0, documentLength: 9,
            caret: 8, currentLineIsCode: true, isCodeLine: { line in
                if line.location == 9 { return false }
                return CodeBlockContext.codeParagraphState(line, separatorIsCode: NSMaxRange(line) >= 5,
                                                           fontIsCode: { _ in nil })
            })
        let unknownCodeBoundary = CodeBlockContext.read(text: "中文\n\n", windowStart: 0, documentLength: 4,
            caret: 3, currentLineIsCode: true, isCodeLine: { _ in nil })
        let caret = { (location: Int) in NSRange(location: location, length: 0) }

        return [
            Check(name: "title marker", passed: MarkdownRule.plan(beforeCaret: "#", trigger: .space)?.conversion == .paragraph(.title)),
            Check(name: "inline bold after Chinese text", passed: MarkdownRule.plan(beforeCaret: "中文 **粗体**", trigger: .space) != nil),
            Check(name: "slash query", passed: SlashQuery.parse(beforeCaret: "/h2")?.query == "h2"),
            Check(name: "slash h2 search", passed: SlashCommand.matching("h2").first?.style == .heading),
            Check(name: "list search", passed: SlashCommand.matching("列表").count == 4),
            Check(name: "numbered list search", passed: SlashCommand.matching("序号列表").first?.style == .numbered),
            Check(name: "fresh slash opens menu", passed: initialMenu == .show("")),
            Check(name: "Chinese query shows menu", passed: titleMenu == .show("题")),
            Check(name: "deleting to slash hides menu", passed: deletedMenu == .hide),
            Check(name: "space query hides menu", passed: spaceMenu == .hide),
            Check(name: "unknown query hides menu", passed: unknownMenu == .hide),
            Check(name: "bullet before text", passed: existingBullet?.conversion == .paragraph(.bullets) &&
                  existingBullet?.range == NSRange(location: 0, length: 1)),
            Check(name: "checklist before text", passed: checklist?.conversion == .paragraph(.checklist) &&
                  checklist?.range == NSRange(location: 0, length: 2)),
            Check(name: "every format cancels to Body", passed: ParagraphStyle.allCases.filter { $0 != .body }.allSatisfy { style in
                let plan = EmptyParagraphCancellation(style: style, paragraphStart: 0)?.plan(
                    beforeCaret: "", windowStart: 0, afterCaret: "", selection: caret(0))
                return plan?.conversion == .paragraph(.body) && plan?.range.length == 0
            }),
            Check(name: "code with text is not empty",
                  passed: codeWithEmptyLastLine?.cancellationPlan(selection: caret(4)) == nil),
            Check(name: "empty code cancels with Esc",
                  passed: emptyCode?.cancellationPlan(selection: caret(2))?.original == "\n\n"),
            Check(name: "empty code keeps native Backspace inside the block",
                  passed: emptyCode?.cancellationPlan(selection: caret(2), intent: .backwardDeletion) == nil),
            Check(name: "Chinese code paragraph bounds", passed: chineseCode?.range == NSRange(location: 5, length: 3)),
            Check(name: "Chinese code keeps content above the caret",
                  passed: chineseCode?.cancellationPlan(selection: caret(8), intent: .backwardDeletion) == nil),
            Check(name: "unknown boundary is not an empty block", passed: unknownCodeBoundary == nil),
            Check(name: "terminal empty code cancels at its boundary",
                  passed: terminalEmptyCode?.cancellationPlan(selection: caret(5), intent: .backwardDeletion)?.range == caret(5))
        ]
    }
}
