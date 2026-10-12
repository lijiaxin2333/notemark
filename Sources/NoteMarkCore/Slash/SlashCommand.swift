import Foundation

/// What a slash command does.
public enum SlashAction: Equatable, Sendable {
    /// Apply a native Notes paragraph style.
    case paragraph(ParagraphStyle)
    /// Insert Notes' native divider line.
    case divider
    /// Insert today's date.
    case date

    var conversion: Conversion {
        switch self {
        case .paragraph(let style): return .paragraph(style)
        case .divider: return .divider
        case .date: return .date
        }
    }
}

public struct SlashCommand: Equatable, Identifiable, Sendable {
    public let id: String
    public let action: SlashAction
    /// Chinese menu title and description. The app localizes the displayed
    /// text by `id`; these and the English names below are always searchable.
    public let title: String
    public let detail: String
    public let englishTitle: String
    public let englishDetail: String
    public let symbol: String
    /// Search terms. The first one is shown in the menu as `/alias`.
    public let aliases: [String]
    /// Exact names that convert as `/name` followed by Space outside the menu.
    public let typedNames: [String]

    public var style: ParagraphStyle? {
        if case .paragraph(let style) = action { return style }
        return nil
    }

    public static let all: [SlashCommand] = [
        .init(id: "title", action: .paragraph(.title), title: "标题", detail: "一级标题",
              englishTitle: "Title", englishDetail: "Top-level heading", symbol: "textformat.size.larger",
              aliases: ["h1", "title", "标题", "一级", "大標題", "一級", "一級標題"], typedNames: ["title", "h1"]),
        .init(id: "heading", action: .paragraph(.heading), title: "小标题", detail: "二级标题",
              englishTitle: "Heading", englishDetail: "Second-level heading", symbol: "textformat.size",
              aliases: ["h2", "heading", "小标题", "二级", "標題", "二級", "二級標題"], typedNames: ["heading", "h2"]),
        .init(id: "subheading", action: .paragraph(.subheading), title: "次级标题", detail: "三级标题",
              englishTitle: "Subheading", englishDetail: "Third-level heading", symbol: "textformat.size.smaller",
              aliases: ["h3", "subheading", "次级标题", "三级", "副标题", "子標題", "三級", "三級標題"], typedNames: ["subheading", "h3"]),
        .init(id: "body", action: .paragraph(.body), title: "正文", detail: "默认段落格式",
              englishTitle: "Body", englishDetail: "Default paragraph style", symbol: "text.alignleft",
              aliases: ["body", "text", "正文", "段落", "內文", "預設段落格式"], typedNames: ["body"]),
        .init(id: "monostyled", action: .paragraph(.monostyled), title: "代码块", detail: "等宽代码段落",
              englishTitle: "Code Block", englishDetail: "Monospaced code paragraph",
              symbol: "chevron.left.forwardslash.chevron.right",
              aliases: ["code", "mono", "代码", "等宽", "等宽样式", "monostyled", "codeblock", "程式碼", "等寬樣式", "程式碼區塊", "等寬", "等寬程式碼段落"], typedNames: ["code"]),
        .init(id: "quote", action: .paragraph(.quote), title: "引用", detail: "引用段落",
              englishTitle: "Quote", englishDetail: "Block quote paragraph", symbol: "text.quote",
              aliases: ["quote", "引用", "块引用", "blockquote", "引言", "區塊引言", "區塊引言段落"], typedNames: ["quote"]),
        .init(id: "checklist", action: .paragraph(.checklist), title: "待办清单", detail: "可勾选的任务列表",
              englishTitle: "Checklist", englishDetail: "Tasks you can check off", symbol: "checklist",
              aliases: ["checklist", "todo", "待办", "清单", "任务", "核对清单", "task", "檢查表", "待辦", "可勾選的待辦事項"], typedNames: ["checklist"]),
        .init(id: "bullets", action: .paragraph(.bullets), title: "项目符号列表", detail: "无序列表",
              englishTitle: "Bulleted List", englishDetail: "Unordered list", symbol: "list.bullet",
              aliases: ["bullets", "bullet", "list", "unordered", "unorderedlist", "无序", "项目", "圆点", "符号",
                        "bulletedlist", "ul", "項目符號", "項目符號列表", "無序", "無序列表"], typedNames: ["bullets"]),
        .init(id: "dashed", action: .paragraph(.dashed), title: "短划线列表", detail: "短横线列表",
              englishTitle: "Dashed List", englishDetail: "List with dashes", symbol: "list.dash",
              aliases: ["dashed", "dash", "dashlist", "虚线", "短横线", "短划线", "短划线列表", "dashedlist", "破折號", "破折號列表", "破折號項目列表", "虚线列表"],
              typedNames: ["dashed"]),
        .init(id: "numbered", action: .paragraph(.numbered), title: "编号列表", detail: "有序列表",
              englishTitle: "Numbered List", englishDetail: "Ordered list", symbol: "list.number",
              aliases: ["numbered", "number", "ordered", "numberedlist", "orderedlist", "编号", "有序", "序号", "序号列表",
                        "有序号列表", "数字", "数字列表", "ol", "編號", "編號列表"], typedNames: ["numbered"]),
        .init(id: "divider", action: .divider, title: "分隔线", detail: "插入原生分隔线",
              englishTitle: "Divider", englishDetail: "Insert a divider line", symbol: "minus",
              aliases: ["divider", "hr", "line", "分隔线", "分割线", "横线", "分隔線", "插入原生分隔線"], typedNames: ["divider", "hr"]),
        .init(id: "date", action: .date, title: "日期", detail: "插入今天的日期",
              englishTitle: "Date", englishDetail: "Insert the current date", symbol: "calendar",
              aliases: ["date", "today", "日期", "今天"], typedNames: ["date"])
    ]

    /// The command for an exact `/name` line, such as `/h2`.
    public static func command(typedAs line: String) -> SlashCommand? {
        guard line.hasPrefix("/") else { return nil }
        let name = String(line.dropFirst())
        return all.first { $0.typedNames.contains(name) }
    }

    /// Commands ranked by how well a term matches: any term exactly, then a
    /// name (alias or title) by prefix, then by substring, then a description,
    /// then the pinyin or pinyin initials of Chinese terms (`bt` finds 标题),
    /// exactly before by prefix.
    /// Menu order breaks ties. Commands the rules turn off are left out.
    public static func matching(_ query: String, rules: ConversionRules = .default) -> [SlashCommand] {
        let available = all.filter { $0.isAvailable(under: rules) }
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return available }
        // Description words are searched only with a letter or ideograph, so
        // punctuation such as "-" does not match "Top-level heading".
        let searchesDescriptions = query.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        let searchesPinyin = query.count >= 2 && query.unicodeScalars.allSatisfy { $0.isASCII && CharacterSet.lowercaseLetters.contains($0) }
        return available.enumerated().compactMap { index, command -> (Int, Int, SlashCommand)? in
            let names = command.nameTerms
            let descriptions = command.descriptionTerms
            let rank: Int
            if names.contains(query) || descriptions.contains(query) { rank = 0 }
            else if names.contains(where: { $0.hasPrefix(query) }) { rank = 1 }
            else if names.contains(where: { $0.contains(query) }) { rank = 2 }
            else if searchesDescriptions, descriptions.contains(where: { $0.contains(query) }) { rank = 3 }
            else if searchesPinyin, pinyinIndex[command.id, default: []].contains(query) { rank = 4 }
            else if searchesPinyin, pinyinIndex[command.id, default: []].contains(where: { $0.hasPrefix(query) }) { rank = 5 }
            else { return nil }
            return (rank, index, command)
        }.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map { $0.2 }
    }

    /// Dividers follow the divider switch, which the app also turns off where
    /// Notes has no divider command.
    public func isAvailable(under rules: ConversionRules) -> Bool {
        action != .divider || rules.dividers
    }

    private var nameTerms: [String] { (aliases + [title, englishTitle]).map { $0.lowercased() } }
    private var descriptionTerms: [String] { [detail, englishDetail].map { $0.lowercased() } }

    /// Full pinyin and initials of each command's Chinese terms, for example
    /// "biaoti" and "bt" for 标题. Built once, outside the event tap.
    private static let pinyinIndex: [String: [String]] = Dictionary(uniqueKeysWithValues: all.map { command in
        let chinese = (command.aliases + [command.title, command.detail]).filter { term in
            term.unicodeScalars.contains { $0.properties.isIdeographic }
        }
        return (command.id, chinese.flatMap(pinyinForms))
    })

    private static func pinyinForms(_ text: String) -> [String] {
        let latin = NSMutableString(string: text)
        CFStringTransform(latin, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(latin, nil, kCFStringTransformStripDiacritics, false)
        let syllables = (latin as String).lowercased().split(separator: " ")
        guard !syllables.isEmpty else { return [] }
        return [syllables.joined(), String(syllables.compactMap(\.first))]
    }
}

public struct SlashQuery: Equatable, Sendable {
    /// ASCII and full-width slashes both open a command.
    public static let slashCharacters = ["/", "／"]
    private static let queryCharacters = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "-_"))

    public let query: String
    public let range: NSRange
    public let original: String

    /// `afterCaret` is nil when the paragraph's right boundary is unknown.
    public static func parse(beforeCaret: String, windowStart: Int = 0, afterCaret: String? = "",
                             isMonospaced: Bool = false, selectionLength: Int = 0) -> SlashQuery? {
        guard !isMonospaced, selectionLength == 0, windowStart >= 0,
              afterCaret?.startsAtParagraphEnd == true else { return nil }
        let caretLine = CaretLine(beforeCaret: beforeCaret, windowStart: windowStart)
        guard caretLine.startIsKnown else { return nil }
        let line = caretLine.text
        guard startsWithSlash(line), line.count <= 41 else { return nil }
        // Spaces used to confirm an IME candidate may remain after the command.
        // Search the trimmed name, but remove the entire original range on execution.
        let query = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        // Names such as "Code Block" have single spaces between words.
        let words = query.split(separator: " ", omittingEmptySubsequences: false)
        guard query.isEmpty || words.allSatisfy({ !$0.isEmpty && $0.unicodeScalars.allSatisfy(queryCharacters.contains) })
        else { return nil }
        return SlashQuery(query: query, range: NSRange(location: caretLine.documentStart, length: (line as NSString).length),
                          original: line)
    }

    public static func startsWithSlash(_ text: String) -> Bool {
        slashCharacters.contains { text.hasPrefix($0) }
    }

    public static func containsSlash(_ text: String) -> Bool {
        slashCharacters.contains { text.contains($0) }
    }

    public func plan(for command: SlashCommand) -> EditPlan {
        EditPlan(range: range, original: original, conversion: command.action.conversion)
    }
}

public struct SlashSelection: Sendable {
    public private(set) var commands: [SlashCommand] = SlashCommand.all
    public private(set) var index = 0
    public var selected: SlashCommand? { commands.indices.contains(index) ? commands[index] : nil }

    public init() {}
    public mutating func update(query: String, rules: ConversionRules = .default) {
        commands = SlashCommand.matching(query, rules: rules)
        index = 0
    }
    public mutating func move(_ delta: Int) {
        guard !commands.isEmpty else { index = 0; return }
        index = ((index + delta) % commands.count + commands.count) % commands.count
    }
}

public enum SlashPopupPlacement {
    /// AppKit coordinates; preserve visibility on screens above/left of the main display.
    public static func frame(anchor: CGRect, visibleFrame: CGRect, size: CGSize) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let x = min(max(anchor.minX, visibleFrame.minX), visibleFrame.maxX - width)
        let below = anchor.minY - height - 6
        let preferredY = below >= visibleFrame.minY ? below : anchor.maxY + 6
        let y = min(max(preferredY, visibleFrame.minY), visibleFrame.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
