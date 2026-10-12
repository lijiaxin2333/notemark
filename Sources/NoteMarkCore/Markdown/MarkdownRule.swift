import Foundation

public enum ParagraphStyle: String, Equatable, CaseIterable, Sendable {
    case title, heading, subheading, body, monostyled, quote, checklist, bullets, dashed, numbered
}

public enum InlineStyle: Equatable, Sendable {
    case bold, italic, boldItalic, code, strike, link(String)
}

public enum Conversion: Equatable, Sendable {
    case paragraph(ParagraphStyle)
    case inline(InlineStyle, text: String, delimiter: String)
}

public struct EditPlan: Equatable, Sendable {
    public let range: NSRange
    public let original: String
    public let conversion: Conversion
}

public enum Trigger: Equatable, Sendable { case space, enter }

/// Pure rules. Positions use UTF-16, matching the Accessibility text APIs.
public enum MarkdownRule {
    public static let checklistMarkers = ["[]", "[ ]", "- [ ]", "［］", "［ ］", "【】", "【 】"]

    /// Notes stores an attachment such as an image as this placeholder character.
    public static let attachmentCharacter = "\u{fffc}"

    /// Line-start markers converted with Space. Slash names come from `SlashCommand`.
    private static let paragraphMarkers: [String: ParagraphStyle] = [
        "#": .title, "##": .heading, "###": .subheading,
        ">": .quote,
        "*": .bullets, "-": .bullets, "1.": .numbered
    ]

    private struct InlinePattern {
        let expression: NSRegularExpression
        let style: InlineStyle
    }

    // Checked in order: longer delimiters first so `***` is not read as `*`.
    private static let inlinePatterns: [InlinePattern] = [
        (#"\*\*\*([^*\r\n]+)\*\*\*$"#, InlineStyle.boldItalic),
        (#"\*\*([^*\r\n]+)\*\*$"#, .bold),
        (#"__([^_\r\n]+)__$"#, .bold),
        (#"\*([^*\r\n]+)\*$"#, .italic),
        (#"_([^_\r\n]+)_$"#, .italic),
        (#"`([^`\r\n]+)`$"#, .code),
        (#"~~([^~\r\n]+)~~$"#, .strike)
    ].map { InlinePattern(expression: compile($0.0), style: $0.1) }

    private static let linkPattern = compile(#"\[([^\[\]\r\n]+)\]\(([^\s()]+)\)$"#)
    private static let fencedCodeLanguagePattern = compile(#"^```[A-Za-z][A-Za-z0-9_+.-]{0,31}$"#)

    /// Characters that may precede an opening inline delimiter.
    private static let inlineBoundaryCharacters = "([{，。；：、!?！？:;"

    /// Markers that may change the current paragraph without replacing its text.
    public static func isListMarker(_ line: String) -> Bool {
        ["-", "*"].contains(line) || checklistMarkers.contains(line)
    }

    /// `afterCaret` is the rest of the caret paragraph, or nil when its right
    /// boundary is unknown; an unknown boundary never converts a paragraph.
    public static func plan(
        beforeCaret: String, windowStart: Int = 0,
        trigger: Trigger, isMonospaced: Bool = false,
        selectionLength: Int = 0, afterCaret: String? = ""
    ) -> EditPlan? {
        guard selectionLength == 0, windowStart >= 0 else { return nil }
        let caretLine = CaretLine(beforeCaret: beforeCaret, windowStart: windowStart)
        let line = caretLine.text
        guard !line.contains(attachmentCharacter) else { return nil }
        let rightIsEmpty = afterCaret?.startsAtParagraphEnd == true
        let listBeforeText = isListMarker(line) &&
            afterCaret.map { !$0.prefixBeforeLineBreak().text.contains(attachmentCharacter) } == true

        if caretLine.startIsKnown && (rightIsEmpty || listBeforeText),
           let style = paragraphStyle(for: line, trigger: trigger, isMonospaced: isMonospaced) {
            return EditPlan(range: NSRange(location: caretLine.documentStart, length: (line as NSString).length),
                            original: line, conversion: .paragraph(style))
        }
        // Code blocks must retain operators and Markdown-looking code literally.
        guard !isMonospaced else { return nil }
        let source = line as NSString
        let delimiter = trigger == .space ? " " : "\n"
        for pattern in inlinePatterns {
            guard let match = firstMatch(pattern.expression, in: line),
                  hasInlineBoundary(line, before: match.range.location),
                  containsNoEscapes(line, in: match.range) else { continue }
            let content = source.substring(with: match.range(at: 1))
            guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            return EditPlan(range: NSRange(location: caretLine.documentStart + match.range.location, length: match.range.length),
                            original: source.substring(with: match.range),
                            conversion: .inline(pattern.style, text: content, delimiter: delimiter))
        }
        if let match = firstMatch(linkPattern, in: line),
           hasInlineBoundary(line, before: match.range.location),
           match.range.location == 0 || source.substring(to: match.range.location).last != "!",
           containsNoEscapes(line, in: match.range) {
            let label = source.substring(with: match.range(at: 1))
            let url = source.substring(with: match.range(at: 2))
            if isAllowedLink(url) {
                return EditPlan(range: NSRange(location: caretLine.documentStart + match.range.location, length: match.range.length),
                                original: source.substring(with: match.range),
                                conversion: .inline(.link(url), text: label, delimiter: delimiter))
            }
        }
        return nil
    }

    private static func paragraphStyle(for line: String, trigger: Trigger, isMonospaced: Bool) -> ParagraphStyle? {
        if line == "```" { return isMonospaced ? .body : .monostyled }
        if !isMonospaced, trigger == .enter, firstMatch(fencedCodeLanguagePattern, in: line) != nil { return .monostyled }
        guard !isMonospaced, trigger == .space else { return nil }
        if checklistMarkers.contains(line) { return .checklist }
        return paragraphMarkers[line] ?? SlashCommand.command(typedAs: line)?.style
    }

    private static func isAllowedLink(_ url: String) -> Bool {
        guard let components = URLComponents(string: url),
              let scheme = components.scheme?.lowercased(),
              ["https", "http", "mailto"].contains(scheme) else { return false }
        return scheme == "mailto" ? !components.path.isEmpty : components.host?.isEmpty == false
    }

    private static func compile(_ pattern: String) -> NSRegularExpression {
        // The patterns are literals covered by tests; an invalid one is a programming error.
        try! NSRegularExpression(pattern: pattern)
    }

    private static func firstMatch(_ expression: NSRegularExpression, in text: String) -> NSTextCheckingResult? {
        expression.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    private static func hasInlineBoundary(_ line: String, before start: Int) -> Bool {
        guard start > 0, let character = (line as NSString).substring(to: start).last else { return true }
        return character.isWhitespace || inlineBoundaryCharacters.contains(character)
    }

    /// Escaped and nested Markdown is intentionally kept verbatim in this version.
    private static func containsNoEscapes(_ line: String, in range: NSRange) -> Bool {
        !(line as NSString).substring(with: range).contains("\\")
    }
}
