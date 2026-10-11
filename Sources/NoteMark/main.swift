import AppKit
import ApplicationServices
import NoteMarkCore

if CommandLine.arguments.contains("--self-check") {
    let title = MarkdownRule.plan(beforeCaret: "#", trigger: .space)
    let bold = MarkdownRule.plan(beforeCaret: "中文 **粗体**", trigger: .space)
    let slash = SlashQuery.parse(beforeCaret: "/h2")
    var slashSession = SlashMenuSession()
    slashSession.begin()
    let initialMenu = slashSession.update(beforeCaret: "/")
    let titleMenu = slashSession.update(beforeCaret: "/题")
    let deletedMenu = slashSession.update(beforeCaret: "/")
    let spaceMenu = slashSession.update(beforeCaret: "/ ")
    let unknownMenu = slashSession.update(beforeCaret: "/notacommand")
    let existingBullet = MarkdownRule.plan(beforeCaret: "-", trigger: .space, afterCaret: "你好")
    let checklist = MarkdownRule.plan(beforeCaret: "[]", trigger: .space, afterCaret: "待办事项")
    let cancelled = ParagraphStyle.allCases.filter { $0 != .body }.allSatisfy { style in
        let plan = EmptyParagraphCancellation(style: style, paragraphStart: 0)?.plan(
            beforeCaret: "", windowStart: 0, afterCaret: "", selection: NSRange(location: 0, length: 0))
        return plan?.conversion == .paragraph(.body) && plan?.range.length == 0
    }
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
    guard title?.conversion == .paragraph(.title), bold != nil,
          slash?.query == "h2", SlashCommand.matching("h2").first?.style == .heading,
          SlashCommand.matching("列表").count == 4, SlashCommand.matching("序号列表").first?.style == .numbered,
          initialMenu == .show(""), titleMenu == .show("题"), deletedMenu == .hide,
          spaceMenu == .hide, unknownMenu == .hide,
          existingBullet?.conversion == .paragraph(.bullets), existingBullet?.range == NSRange(location: 0, length: 1),
          checklist?.conversion == .paragraph(.checklist), checklist?.range == NSRange(location: 0, length: 2),
          cancelled,
          codeWithEmptyLastLine?.cancellationPlan(selection: NSRange(location: 4, length: 0)) == nil,
          emptyCode?.cancellationPlan(selection: NSRange(location: 2, length: 0))?.original == "\n\n",
          emptyCode?.cancellationPlan(selection: NSRange(location: 2, length: 0), intent: .backwardDeletion) == nil,
          chineseCode?.range == NSRange(location: 5, length: 3),
          chineseCode?.cancellationPlan(selection: NSRange(location: 8, length: 0), intent: .backwardDeletion) == nil,
          unknownCodeBoundary == nil,
          terminalEmptyCode?.cancellationPlan(selection: NSRange(location: 5, length: 0), intent: .backwardDeletion)?.range == NSRange(location: 5, length: 0) else { exit(1) }
    print("NoteMark self-check passed · \(ProcessInfo.processInfo.operatingSystemVersionString)")
    exit(0)
}
if CommandLine.arguments.contains("--diagnose") {
    print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
    print("Accessibility: \(AXIsProcessTrusted())")
    print("Input monitoring: \(CGPreflightListenEventAccess())")
    print("Input method candidate window: \(NotesAccessibility.inputMethodHasCandidates())")
    RuntimeStatus.printLastReport()
    print("No Notes content was read or changed.")
    exit(0)
}
let application = NSApplication.shared
let delegate = AppDelegate()
if let index = CommandLine.arguments.firstIndex(of: "--render-slash"), CommandLine.arguments.count > index + 1 {
    do {
        try SlashCommandPanel().renderPreview(to: CommandLine.arguments[index + 1])
        print("Rendered NoteMark slash menu offscreen.")
        exit(0)
    } catch { print("Render failed: \(error)"); exit(1) }
}
if let index = CommandLine.arguments.firstIndex(of: "--render-setup"), CommandLine.arguments.count > index + 1 {
    do {
        try delegate.renderSetup(to: CommandLine.arguments[index + 1])
        print("Rendered NoteMark setup view offscreen.")
        exit(0)
    } catch { print("Render failed: \(error)"); exit(1) }
}
application.delegate = delegate
application.run()
