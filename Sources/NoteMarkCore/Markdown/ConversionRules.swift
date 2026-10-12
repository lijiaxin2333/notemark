/// Which conversions are enabled. Every group is on by default.
public struct ConversionRules: Codable, Equatable, Sendable {
    /// `#` to `######` at a paragraph start.
    public var headings = true
    /// `-`, `*` and `1.` lists, including before existing text.
    public var lists = true
    /// `[]`, `[ ]` and `- [ ]` checklists.
    public var checklists = true
    /// `>` quotes.
    public var quotes = true
    /// Three backticks for monospaced code paragraphs.
    public var codeBlocks = true
    /// `**bold**`, `*italic*`, `` `code` ``, `~~strike~~` and their variants.
    public var inlineStyles = true
    /// `[text](url)` links.
    public var links = true
    /// `---`, `***` and `___` dividers.
    public var dividers = true
    /// The `/` menu and typed `/name` commands.
    public var slashCommands = true
    /// Full-width and Chinese punctuation forms of the line-start markers, such as `＃` and `》`.
    public var fullWidthMarkers = true
    /// `-` makes a dashed list instead of a bulleted list.
    public var dashMakesDashedList = false

    public init() {}

    public static let `default` = ConversionRules()

    public init(from decoder: Decoder) throws {
        // Settings saved by an older version may lack newer keys; those keep their defaults.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ConversionRules()
        headings = try container.decodeIfPresent(Bool.self, forKey: .headings) ?? defaults.headings
        lists = try container.decodeIfPresent(Bool.self, forKey: .lists) ?? defaults.lists
        checklists = try container.decodeIfPresent(Bool.self, forKey: .checklists) ?? defaults.checklists
        quotes = try container.decodeIfPresent(Bool.self, forKey: .quotes) ?? defaults.quotes
        codeBlocks = try container.decodeIfPresent(Bool.self, forKey: .codeBlocks) ?? defaults.codeBlocks
        inlineStyles = try container.decodeIfPresent(Bool.self, forKey: .inlineStyles) ?? defaults.inlineStyles
        links = try container.decodeIfPresent(Bool.self, forKey: .links) ?? defaults.links
        dividers = try container.decodeIfPresent(Bool.self, forKey: .dividers) ?? defaults.dividers
        slashCommands = try container.decodeIfPresent(Bool.self, forKey: .slashCommands) ?? defaults.slashCommands
        fullWidthMarkers = try container.decodeIfPresent(Bool.self, forKey: .fullWidthMarkers) ?? defaults.fullWidthMarkers
        dashMakesDashedList = try container.decodeIfPresent(Bool.self, forKey: .dashMakesDashedList) ?? defaults.dashMakesDashedList
    }
}
