import Foundation

public struct SlashCommand: Equatable, Identifiable, Sendable {
    public let style: ParagraphStyle
    public let title: String
    public let detail: String
    public let symbol: String
    /// Search terms. The first one is shown in the menu as `/alias`.
    public let aliases: [String]
    /// Exact names that convert as `/name` followed by Space outside the menu.
    public let typedNames: [String]
    public var id: String { style.rawValue }

    public static let all: [SlashCommand] = [
        .init(style: .title, title: "标题", detail: "一级标题", symbol: "textformat.size.larger", aliases: ["h1", "title", "标题", "一级"], typedNames: ["title", "h1"]),
        .init(style: .heading, title: "小标题", detail: "二级标题", symbol: "textformat.size", aliases: ["h2", "heading", "小标题", "二级"], typedNames: ["heading", "h2"]),
        .init(style: .subheading, title: "次级标题", detail: "三级标题", symbol: "textformat.size.smaller", aliases: ["h3", "subheading", "次级标题", "三级"], typedNames: ["subheading", "h3"]),
        .init(style: .body, title: "正文", detail: "默认段落格式", symbol: "text.alignleft", aliases: ["body", "text", "正文", "段落"], typedNames: ["body"]),
        .init(style: .monostyled, title: "代码块", detail: "等宽代码段落", symbol: "chevron.left.forwardslash.chevron.right", aliases: ["code", "mono", "代码", "等宽"], typedNames: ["code"]),
        .init(style: .quote, title: "引用", detail: "引用段落", symbol: "text.quote", aliases: ["quote", "引用"], typedNames: ["quote"]),
        .init(style: .checklist, title: "待办清单", detail: "可勾选的任务列表", symbol: "checklist", aliases: ["checklist", "todo", "待办", "清单", "任务"], typedNames: ["checklist"]),
        .init(style: .bullets, title: "项目符号列表", detail: "无序列表", symbol: "list.bullet", aliases: ["bullets", "bullet", "list", "unordered", "unorderedlist", "无序", "项目", "圆点", "符号"], typedNames: ["bullets"]),
        .init(style: .dashed, title: "虚线列表", detail: "短横线列表", symbol: "list.dash", aliases: ["dashed", "dash", "dashlist", "虚线", "短横线"], typedNames: ["dashed"]),
        .init(style: .numbered, title: "编号列表", detail: "有序列表", symbol: "list.number", aliases: ["numbered", "number", "ordered", "numberedlist", "orderedlist", "编号", "有序", "序号", "序号列表", "有序号列表", "数字", "数字列表"], typedNames: ["numbered"])
    ]

    /// The command for an exact `/name` line, such as `/h2`.
    public static func command(typedAs line: String) -> SlashCommand? {
        guard line.hasPrefix("/") else { return nil }
        let name = String(line.dropFirst())
        return all.first { $0.typedNames.contains(name) }
    }

    public static func matching(_ query: String) -> [SlashCommand] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return all }
        return all.enumerated().compactMap { index, command -> (Int, Int, SlashCommand)? in
            let terms = (command.aliases + [command.title, command.detail]).map { $0.lowercased() }
            let rank: Int
            if terms.contains(query) { rank = 0 }
            else if terms.contains(where: { $0.hasPrefix(query) }) { rank = 1 }
            else if terms.contains(where: { $0.contains(query) }) { rank = 2 }
            else { return nil }
            return (rank, index, command)
        }.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map { $0.2 }
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
        guard query.unicodeScalars.allSatisfy(queryCharacters.contains) else { return nil }
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
        EditPlan(range: range, original: original, conversion: .paragraph(command.style))
    }
}

public struct SlashSelection: Sendable {
    public private(set) var commands: [SlashCommand] = SlashCommand.all
    public private(set) var index = 0
    public var selected: SlashCommand? { commands.indices.contains(index) ? commands[index] : nil }

    public init() {}
    public mutating func update(query: String) { commands = SlashCommand.matching(query); index = 0 }
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
