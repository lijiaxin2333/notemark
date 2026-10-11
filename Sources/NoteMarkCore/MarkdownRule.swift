import Foundation

public enum ParagraphStyle: String, Equatable, CaseIterable {
    case title, heading, subheading, body, monostyled, quote, checklist, bullets, dashed, numbered

    /// Notes' built-in commands. No font sizes are supplied by NoteMark.
    public var shortcut: String {
        switch self {
        case .title: return "t"
        case .heading: return "h"
        case .subheading: return "j"
        case .body: return "b"
        case .monostyled: return "m"
        case .quote: return "'"
        case .checklist: return "l"
        case .bullets: return "7"
        case .dashed: return "8"
        case .numbered: return "9"
        }
    }
    public var needsShift: Bool { self != .quote }
}

public enum InlineStyle: Equatable {
    case bold, italic, boldItalic, code, strike, link(String)
}

public enum Conversion: Equatable {
    case paragraph(ParagraphStyle)
    case inline(InlineStyle, text: String, delimiter: String)
}

public struct EditPlan: Equatable {
    public let range: NSRange
    public let original: String
    public let conversion: Conversion
}

public enum Trigger: Equatable { case space, enter }

/// Pure rules. Positions use UTF-16, matching the Accessibility text APIs.
public enum MarkdownRule {
    public static func plan(
        beforeCaret: String, windowStart: Int = 0,
        trigger: Trigger, isMonospaced: Bool = false,
        selectionLength: Int = 0, afterCaret: String = "", rightBoundaryKnown: Bool = true
    ) -> EditPlan? {
        guard selectionLength == 0, windowStart >= 0 else { return nil }
        let ns = beforeCaret as NSString
        let lastNewline = ns.rangeOfCharacter(from: .newlines, options: .backwards)
        let lineStart = lastNewline.location == NSNotFound ? 0 : NSMaxRange(lastNewline)
        let line = ns.substring(from: lineStart)
        guard !line.contains("\u{fffc}") else { return nil }
        let atStartKnown = windowStart == 0 || lastNewline.location != NSNotFound
        let rightIsEmpty = rightBoundaryKnown && (afterCaret.isEmpty || afterCaret.first?.isNewline == true)
        let rightText = afterCaret as NSString
        let rightNewline = rightText.rangeOfCharacter(from: .newlines)
        let paragraphTail = rightNewline.location == NSNotFound ? afterCaret : rightText.substring(to: rightNewline.location)
        let listBeforeText = rightBoundaryKnown && ["-", "*"].contains(line) && !paragraphTail.contains("\u{fffc}")

        if atStartKnown && (rightIsEmpty || listBeforeText),
           let style = paragraphStyle(for: line, trigger: trigger, isMonospaced: isMonospaced) {
            return EditPlan(range: NSRange(location: windowStart + lineStart, length: (line as NSString).length),
                            original: line, conversion: .paragraph(style))
        }
        // Code blocks must retain operators and Markdown-looking code literally.
        guard !isMonospaced else { return nil }
        let patterns: [(String, InlineStyle)] = [
            (#"\*\*\*([^*\r\n]+)\*\*\*$"#, .boldItalic),
            (#"\*\*([^*\r\n]+)\*\*$"#, .bold),
            (#"__([^_\r\n]+)__$"#, .bold),
            (#"\*([^*\r\n]+)\*$"#, .italic),
            (#"_([^_\r\n]+)_$"#, .italic),
            (#"`([^`\r\n]+)`$"#, .code),
            (#"~~([^~\r\n]+)~~$"#, .strike)
        ]
        for (pattern, style) in patterns {
            guard let match = match(pattern, in: line),
                  validBoundary(line, start: match.range.location),
                  unescapedClosingDelimiter(line, range: match.range) else { continue }
            let content = (line as NSString).substring(with: match.range(at: 1))
            guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            return EditPlan(range: NSRange(location: windowStart + lineStart + match.range.location, length: match.range.length),
                            original: (line as NSString).substring(with: match.range),
                            conversion: .inline(style, text: content, delimiter: trigger == .space ? " " : "\n"))
        }
        if let match = match(#"\[([^\[\]\r\n]+)\]\(([^\s()]+)\)$"#, in: line),
           validBoundary(line, start: match.range.location),
           match.range.location == 0 || (line as NSString).substring(to: match.range.location).last != "!",
           unescapedClosingDelimiter(line, range: match.range) {
            let label = (line as NSString).substring(with: match.range(at: 1))
            let url = (line as NSString).substring(with: match.range(at: 2))
            if let components = URLComponents(string: url),
               let scheme = components.scheme?.lowercased(),
               ["https", "http", "mailto"].contains(scheme),
               scheme == "mailto" ? !components.path.isEmpty : components.host?.isEmpty == false {
                return EditPlan(range: NSRange(location: windowStart + lineStart + match.range.location, length: match.range.length),
                                original: (line as NSString).substring(with: match.range),
                                conversion: .inline(.link(url), text: label, delimiter: trigger == .space ? " " : "\n"))
            }
        }
        return nil
    }

    private static func paragraphStyle(for line: String, trigger: Trigger, isMonospaced: Bool) -> ParagraphStyle? {
        if line == "```" { return isMonospaced ? .body : .monostyled }
        if !isMonospaced, trigger == .enter,
           match(#"^```[A-Za-z][A-Za-z0-9_+.-]{0,31}$"#, in: line) != nil { return .monostyled }
        guard !isMonospaced, trigger == .space else { return nil }
        let prefixes: [String: ParagraphStyle] = [
            "#": .title, "##": .heading, "###": .subheading,
            ">": .quote, "[]": .checklist, "[ ]": .checklist, "- [ ]": .checklist,
            "*": .bullets, "-": .bullets, "1.": .numbered,
            "/title": .title, "/h1": .title,
            "/heading": .heading, "/h2": .heading,
            "/subheading": .subheading, "/h3": .subheading,
            "/body": .body, "/code": .monostyled, "/quote": .quote,
            "/checklist": .checklist, "/bullets": .bullets, "/numbered": .numbered
        ]
        return prefixes[line]
    }

    private static func match(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        try? NSRegularExpression(pattern: pattern).firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    private static func validBoundary(_ line: String, start: Int) -> Bool {
        guard start > 0 else { return true }
        let prefix = (line as NSString).substring(to: start)
        guard let char = prefix.last else { return true }
        return char.isWhitespace || "([{，。；：、!?，！？:;".contains(char)
    }

    private static func unescapedClosingDelimiter(_ line: String, range: NSRange) -> Bool {
        let source = (line as NSString).substring(with: range)
        // Escaped/nested Markdown is intentionally kept verbatim in this first version.
        return !source.contains("\\")
    }
}
