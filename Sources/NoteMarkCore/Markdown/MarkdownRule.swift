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
    /// Replace the marker with Notes' native divider line.
    case divider
    /// Replace the range with today's date, formatted by the app.
    case date
    /// Remove the escaping backslash in the range; the trigger key only confirms it.
    case unescape
}

extension Conversion {
    /// Inline styles change part of a paragraph; the others change or replace it.
    public var isInline: Bool {
        if case .inline = self { return true }
        return false
    }
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

    /// Lines that insert a divider. Smart Dashes turns `--` into `—`, so `--`
    /// and another `-` leave `—-`; Chinese input methods type `——` for
    /// Shift-hyphen, which counts as Chinese punctuation.
    public static let dividerMarkers: Set<String> = ["---", "***", "___", "—-", "——"]
    private static let chineseDividerMarker = "——"
    /// Smart Dashes replaces a typed `---` with one em dash, on Space or Return
    /// or after a short pause. Only the typed keys tell it from an em dash.
    private static let smartDashDivider = "—"

    /// Hyphens typed for a smart-dash divider. Deleting an em dash removes
    /// one typed hyphen from the history, so a retyped `---` can follow more.
    public static func isTypedDashRun(_ typed: String, rules: ConversionRules = .default) -> Bool {
        let marker = normalizedMarker(typed, rules: rules)
        return marker.count >= 3 && marker.allSatisfy { $0 == "-" }
    }

    /// Full-width and Chinese punctuation that stands for an ASCII marker
    /// character when a whole line is a marker, such as `＃` or `》`.
    private static let markerEquivalents: [Character: Character] = [
        "＃": "#", "＞": ">", "》": ">", "＊": "*", "－": "-", "｀": "`", "·": "`",
        "．": ".", "。": ".", "０": "0", "１": "1", "２": "2", "３": "3", "４": "4",
        "５": "5", "６": "6", "７": "7", "８": "8", "９": "9"
    ]

    private struct InlinePattern {
        let expression: NSRegularExpression
        let style: InlineStyle
        /// Underscore emphasis keeps the stricter boundary so identifiers such as `变量_名_` stay literal.
        var requiresSpacedBoundary: Bool { expression.pattern.hasPrefix("_") }
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

    /// ASCII characters that may precede an opening inline delimiter. Any
    /// non-ASCII character may too, so Chinese text needs no spaces.
    private static let inlineBoundaryCharacters = "([{，。；：、!?！？:;"

    /// Markers that may change the current paragraph without replacing its text.
    public static func isListMarker(_ line: String, rules: ConversionRules = .default) -> Bool {
        ["-", "*"].contains(normalizedMarker(line, rules: rules)) || checklistMarkers.contains(line)
    }

    /// Whether `line`, a whole paragraph, becomes a divider under `rules`.
    /// `typedLine` is what the user typed on it, when known.
    public static func convertsDivider(_ line: String, typedLine: String? = nil, rules: ConversionRules) -> Bool {
        guard rules.dividers else { return false }
        let marker = normalizedMarker(line, rules: rules)
        if marker == smartDashDivider { return typedLine.map { isTypedDashRun($0, rules: rules) } == true }
        return dividerMarkers.contains(marker) && (marker != chineseDividerMarker || rules.fullWidthMarkers)
    }

    /// The ASCII form of a line-start marker typed with full-width or Chinese
    /// punctuation; the line itself when those forms are disabled.
    static func normalizedMarker(_ line: String, rules: ConversionRules) -> String {
        guard rules.fullWidthMarkers else { return line }
        return String(line.map { markerEquivalents[$0] ?? $0 })
    }

    /// `afterCaret` is the rest of the caret paragraph, or nil when its right
    /// boundary is unknown; an unknown boundary never converts a paragraph.
    /// `typedLine` is the text typed on the caret line, when known, which
    /// identifies markers that text substitution has already replaced.
    public static func plan(
        beforeCaret: String, windowStart: Int = 0,
        trigger: Trigger, isMonospaced: Bool = false,
        selectionLength: Int = 0, afterCaret: String? = "", rules: ConversionRules = .default,
        typedLine: String? = nil
    ) -> EditPlan? {
        guard selectionLength == 0, windowStart >= 0 else { return nil }
        let caretLine = CaretLine(beforeCaret: beforeCaret, windowStart: windowStart)
        let line = caretLine.text
        guard !line.contains(attachmentCharacter) else { return nil }
        let rightIsEmpty = afterCaret?.startsAtParagraphEnd == true
        let listBeforeText = isListMarker(line, rules: rules) &&
            afterCaret.map { !$0.prefixBeforeLineBreak().text.contains(attachmentCharacter) } == true

        if caretLine.startIsKnown && (rightIsEmpty || listBeforeText) {
            if let conversion = paragraphConversion(for: line, trigger: trigger, isMonospaced: isMonospaced, rules: rules,
                                                    typedLine: typedLine) {
                return EditPlan(range: NSRange(location: caretLine.documentStart, length: (line as NSString).length),
                                original: line, conversion: conversion)
            }
            // `\#` and Space leave a literal `#`: drop the backslash; Space only confirms.
            // Code keeps backslashes, as in Markdown code blocks.
            if rightIsEmpty, trigger == .space, !isMonospaced, line.hasPrefix("\\"),
               paragraphConversion(for: String(line.dropFirst()), trigger: trigger, isMonospaced: isMonospaced, rules: rules,
                                   typedLine: typedLine.map { $0.hasPrefix("\\") ? String($0.dropFirst()) : $0 }) != nil {
                return EditPlan(range: NSRange(location: caretLine.documentStart, length: 1), original: "\\",
                                conversion: .unescape)
            }
        }
        // Code blocks must retain operators and Markdown-looking code literally.
        guard !isMonospaced else { return nil }
        let source = line as NSString
        let delimiter = trigger == .space ? " " : "\n"
        for pattern in inlinePatterns where rules.inlineStyles {
            guard let match = firstMatch(pattern.expression, in: line),
                  hasInlineBoundary(line, before: match.range.location, strict: pattern.requiresSpacedBoundary),
                  containsNoEscapes(line, in: match.range) else { continue }
            let content = source.substring(with: match.range(at: 1))
            guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            return EditPlan(range: NSRange(location: caretLine.documentStart + match.range.location, length: match.range.length),
                            original: source.substring(with: match.range),
                            conversion: .inline(pattern.style, text: content, delimiter: delimiter))
        }
        if rules.links, let match = firstMatch(linkPattern, in: line),
           hasInlineBoundary(line, before: match.range.location, strict: false),
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

    private static func paragraphConversion(for line: String, trigger: Trigger, isMonospaced: Bool,
                                            rules: ConversionRules, typedLine: String? = nil) -> Conversion? {
        let marker = normalizedMarker(line, rules: rules)
        if marker == "```" { return rules.codeBlocks ? .paragraph(isMonospaced ? .body : .monostyled) : nil }
        if !isMonospaced, trigger == .enter, rules.codeBlocks,
           firstMatch(fencedCodeLanguagePattern, in: marker) != nil { return .paragraph(.monostyled) }
        guard !isMonospaced else { return nil }
        if convertsDivider(line, typedLine: typedLine, rules: rules) { return .divider }
        guard trigger == .space else { return nil }
        if checklistMarkers.contains(line) { return rules.checklists ? .paragraph(.checklist) : nil }
        if let style = paragraphStyle(forMarker: marker, rules: rules) { return .paragraph(style) }
        guard rules.slashCommands, let command = SlashCommand.command(typedAs: line),
              command.isAvailable(under: rules) else { return nil }
        return command.action.conversion
    }

    private static func paragraphStyle(forMarker marker: String, rules: ConversionRules) -> ParagraphStyle? {
        switch marker {
        case "#": return rules.headings ? .title : nil
        case "##": return rules.headings ? .heading : nil
        // Notes has three heading levels; its Markdown importer also maps deeper ones to Subheading.
        case "###", "####", "#####", "######": return rules.headings ? .subheading : nil
        case ">": return rules.quotes ? .quote : nil
        case "-": return rules.lists ? (rules.dashMakesDashedList ? .dashed : .bullets) : nil
        case "*": return rules.lists ? .bullets : nil
        case "1.": return rules.lists ? .numbered : nil
        default: return nil
        }
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

    private static func hasInlineBoundary(_ line: String, before start: Int, strict: Bool) -> Bool {
        guard start > 0, let character = (line as NSString).substring(to: start).last else { return true }
        if character.isWhitespace || inlineBoundaryCharacters.contains(character) { return true }
        // ASCII letters, digits, and symbols keep `snake_case` and `2*3*` literal.
        return !strict && !character.isASCII
    }

    /// Escaped and nested Markdown is intentionally kept verbatim in this version.
    private static func containsNoEscapes(_ line: String, in range: NSRange) -> Bool {
        !(line as NSString).substring(with: range).contains("\\")
    }
}
