import Foundation

public struct SlashCommand: Equatable, Identifiable {
    public let style: ParagraphStyle
    public let title: String
    public let detail: String
    public let symbol: String
    public let aliases: [String]
    public var id: String { style.rawValue }

    public static let all: [SlashCommand] = [
        .init(style: .title, title: "标题", detail: "一级标题", symbol: "textformat.size.larger", aliases: ["h1", "title", "标题", "一级"]),
        .init(style: .heading, title: "小标题", detail: "二级标题", symbol: "textformat.size", aliases: ["h2", "heading", "小标题", "二级"]),
        .init(style: .subheading, title: "次级标题", detail: "三级标题", symbol: "textformat.size.smaller", aliases: ["h3", "subheading", "次级标题", "三级"]),
        .init(style: .body, title: "正文", detail: "默认段落格式", symbol: "text.alignleft", aliases: ["body", "text", "正文", "段落"]),
        .init(style: .monostyled, title: "代码块", detail: "等宽代码段落", symbol: "chevron.left.forwardslash.chevron.right", aliases: ["code", "mono", "代码", "等宽"]),
        .init(style: .quote, title: "引用", detail: "引用段落", symbol: "text.quote", aliases: ["quote", "引用"]),
        .init(style: .checklist, title: "待办清单", detail: "可勾选的任务列表", symbol: "checklist", aliases: ["checklist", "todo", "待办", "清单", "任务"]),
        .init(style: .bullets, title: "项目符号列表", detail: "无序列表", symbol: "list.bullet", aliases: ["bullets", "bullet", "list", "无序", "项目"]),
        .init(style: .dashed, title: "虚线列表", detail: "短横线列表", symbol: "list.dash", aliases: ["dashed", "dash", "虚线", "短横线"]),
        .init(style: .numbered, title: "编号列表", detail: "有序列表", symbol: "list.number", aliases: ["numbered", "number", "ordered", "编号", "有序"])
    ]

    public static func matching(_ query: String) -> [SlashCommand] {
        let query = query.lowercased()
        guard !query.isEmpty else { return all }
        return all.enumerated().compactMap { index, command -> (Int, Int, SlashCommand)? in
            let aliases = command.aliases.map { $0.lowercased() }
            let rank: Int
            if aliases.contains(query) { rank = 0 }
            else if aliases.contains(where: { $0.hasPrefix(query) }) { rank = 1 }
            else if aliases.contains(where: { $0.contains(query) }) { rank = 2 }
            else { return nil }
            return (rank, index, command)
        }.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map { $0.2 }
    }
}

public struct SlashQuery: Equatable {
    public let query: String
    public let range: NSRange
    public let original: String

    public static func parse(beforeCaret: String, windowStart: Int = 0, afterCaret: String = "",
                             isMonospaced: Bool = false, selectionLength: Int = 0) -> SlashQuery? {
        guard !isMonospaced, selectionLength == 0, windowStart >= 0,
              afterCaret.isEmpty || afterCaret.first?.isNewline == true else { return nil }
        let text = beforeCaret as NSString
        let newline = text.rangeOfCharacter(from: .newlines, options: .backwards)
        guard windowStart == 0 || newline.location != NSNotFound else { return nil }
        let start = newline.location == NSNotFound ? 0 : NSMaxRange(newline)
        let line = text.substring(from: start)
        guard line.hasPrefix("/"), line.count <= 41 else { return nil }
        let query = String(line.dropFirst())
        guard query.unicodeScalars.allSatisfy({ CharacterSet.letters.union(.decimalDigits).contains($0) || $0 == "-" || $0 == "_" }) else { return nil }
        return SlashQuery(query: query, range: NSRange(location: windowStart + start, length: (line as NSString).length), original: line)
    }

    public func plan(for command: SlashCommand) -> EditPlan {
        EditPlan(range: range, original: original, conversion: .paragraph(command.style))
    }
}

public struct SlashSelection {
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
