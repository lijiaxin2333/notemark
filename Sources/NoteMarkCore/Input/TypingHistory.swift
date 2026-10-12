/// Characters typed since the caret last moved. Return reads the editor only
/// when this history could end a Markdown marker.
public struct TypingHistory: Equatable, Sendable {
    public static let capacity = 64

    public private(set) var text = ""

    public init() {}

    public mutating func clear() { text = "" }

    /// Start over after a trigger key: a Return begins a new paragraph.
    public mutating func reset(after trigger: Trigger) { text = trigger == .enter ? "\n" : "" }

    public mutating func append(_ typed: String) { text = String((text + typed).suffix(Self.capacity)) }

    public mutating func deleteBackward() {
        if !text.isEmpty { text.removeLast() }
    }

    /// A `/command` typed at a paragraph start.
    public var containsSlashCommand: Bool { text.hasPrefix("/") || text.contains("\n/") }

    /// Divider lines count only when `rules` would convert them.
    public func looksLikeMarkdown(rules: ConversionRules = .default) -> Bool {
        let marker = currentMarker
        return endsWithMarkdownDelimiter || containsSlashCommand || SlashQuery.startsWithSlash(marker) ||
            Self.codeFences.contains { text.contains($0) } || Self.paragraphMarkers.contains(marker) ||
            MarkdownRule.convertsDivider(marker, rules: rules) || (rules.dividers && MarkdownRule.isTypedDashRun(marker, rules: rules))
    }

    /// The typed text after the last Return.
    public var currentLine: String {
        text.split(separator: "\n", omittingEmptySubsequences: false).last.map(String.init) ?? text
    }

    /// The current line without a leading backslash: `\#` and Space also
    /// edit the note, by removing the backslash.
    private var currentMarker: String {
        let line = currentLine
        return line.hasPrefix("\\") ? String(line.dropFirst()) : line
    }

    /// Whether the last character can close a marker. Sentence punctuation
    /// counts only when it completes one, so prose such as `done.` is not held.
    private var endsWithMarkdownDelimiter: Bool {
        guard let last = text.last else { return false }
        let line = currentMarker
        switch last {
        case ".", "。", "．": return line.dropLast().allSatisfy(\.isNumber) && line.count > 1
        // A link's URL may have been pasted or scrolled out of the history.
        case ")": return line.contains("](") || !line.contains("(")
        case ">", "＞", "》": return line.count == 1
        default: return Self.closingDelimiters.contains(last)
        }
    }

    private static let closingDelimiters = "#*_`~]］】＃＊｀"
    private static let codeFences = ["```", "｀｀｀", "···"]
    private static let paragraphMarkers: Set<String> = ["-", "[]", "[ ]", "- [ ]", "1."]
}
