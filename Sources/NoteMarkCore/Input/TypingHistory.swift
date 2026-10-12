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

    public var looksLikeMarkdown: Bool {
        endsWithMarkdownDelimiter || containsSlashCommand || text.contains("```") || Self.paragraphMarkers.contains(text)
    }

    private var endsWithMarkdownDelimiter: Bool {
        text.last.map { Self.closingDelimiters.contains($0) } ?? false
    }

    private static let closingDelimiters = "#*_`~]］】.>)"
    private static let paragraphMarkers: Set<String> = ["-", "[]", "[ ]", "- [ ]", "1."]
}
