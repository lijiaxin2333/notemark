import AppKit
import ApplicationServices
import NoteMarkCore

if CommandLine.arguments.contains("--self-check") {
    let title = MarkdownRule.plan(beforeCaret: "#", trigger: .space)
    let bold = MarkdownRule.plan(beforeCaret: "中文 **粗体**", trigger: .space)
    let slash = SlashQuery.parse(beforeCaret: "/h2")
    let cancelled = EmptyHeadingCancellation(style: .title, paragraphStart: 0)?.plan(
        beforeCaret: "", windowStart: 0, afterCaret: "", selection: NSRange(location: 0, length: 0))
    guard title?.conversion == .paragraph(.title), bold != nil,
          slash?.query == "h2", SlashCommand.matching("h2").first?.style == .heading,
          cancelled?.conversion == .paragraph(.body), cancelled?.range.length == 0 else { exit(1) }
    print("NoteMark self-check passed · \(ProcessInfo.processInfo.operatingSystemVersionString)")
    exit(0)
}
if CommandLine.arguments.contains("--diagnose") {
    print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
    print("Accessibility: \(AXIsProcessTrusted())")
    print("Input monitoring: \(CGPreflightListenEventAccess())")
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
