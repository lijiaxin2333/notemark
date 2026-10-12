/// A Notes menu command identified by its key equivalent. Unlike menu titles,
/// key equivalents are the same in every interface language.
public struct MenuShortcut: Hashable, Sendable {
    /// Lowercase key equivalent character. Command is always part of it.
    public let key: String
    public let requiresShift: Bool

    public init(key: String, requiresShift: Bool) {
        self.key = key
        self.requiresShift = requiresShift
    }

    /// Edit > Insert Divider Line (macOS 27 and later). Checklist uses Shift-Command-L.
    public static let insertDivider = MenuShortcut(key: "l", requiresShift: false)

    /// Notes' built-in paragraph format commands. NoteMark supplies no font sizes.
    public static func format(_ style: ParagraphStyle) -> MenuShortcut {
        switch style {
        case .title: return MenuShortcut(key: "t", requiresShift: true)
        case .heading: return MenuShortcut(key: "h", requiresShift: true)
        case .subheading: return MenuShortcut(key: "j", requiresShift: true)
        case .body: return MenuShortcut(key: "b", requiresShift: true)
        case .monostyled: return MenuShortcut(key: "m", requiresShift: true)
        case .quote: return MenuShortcut(key: "'", requiresShift: false)
        case .checklist: return MenuShortcut(key: "l", requiresShift: true)
        case .bullets: return MenuShortcut(key: "7", requiresShift: true)
        case .dashed: return MenuShortcut(key: "8", requiresShift: true)
        case .numbered: return MenuShortcut(key: "9", requiresShift: true)
        }
    }
}
