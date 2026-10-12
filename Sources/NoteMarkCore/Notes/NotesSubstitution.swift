/// Notes' Edit > Substitutions items that rewrite Markdown markers as they
/// are typed: Smart Dashes turns `---` into `—`, Smart Lists turns `- ` into a
/// list even when the marker was kept as text, and Smart Tags turns `#word`
/// into a tag.
public enum NotesSubstitution: String, CaseIterable, Codable, Sendable {
    case smartDashes, smartLists, smartTags

    /// Tags are a Notes feature of their own, so NoteMark leaves them on unless asked.
    public static let turnedOffByDefault: Set<NotesSubstitution> = [.smartDashes, .smartLists]
}

/// How to switch Notes' substitutions to match the user's choice. NoteMark
/// turns an item back on only when it turned that item off itself.
public struct NotesSubstitutionChanges: Equatable, Sendable {
    public private(set) var turnOff: [NotesSubstitution] = []
    public private(set) var turnOn: [NotesSubstitution] = []
    /// Items NoteMark turned off that the user has turned on again in Notes.
    public private(set) var forget: [NotesSubstitution] = []

    /// `isOn` is nil for an item Notes does not offer now, such as when no
    /// note has keyboard focus; such items wait for the next attempt.
    public init(keepingOff wanted: Set<NotesSubstitution>, turnedOffByNoteMark: Set<NotesSubstitution>,
                isOn: (NotesSubstitution) -> Bool?) {
        for substitution in NotesSubstitution.allCases {
            guard let on = isOn(substitution) else { continue }
            if wanted.contains(substitution) {
                if on { turnOff.append(substitution) }
            } else if turnedOffByNoteMark.contains(substitution) {
                if on { forget.append(substitution) } else { turnOn.append(substitution) }
            }
        }
    }
}
