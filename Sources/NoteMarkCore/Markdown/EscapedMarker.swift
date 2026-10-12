/// A marker kept as text with a backslash. The paragraph stays text while it
/// begins with the marker: Space after `\#` and Space types `# `, and `- [ ]`
/// after `\-` stays text. Inline styles still convert.
public struct EscapedMarker: Equatable, Sendable {
    public let marker: String

    /// `line` is the paragraph text before the caret when `\` was removed.
    public init?(escaping line: String) {
        guard line.hasPrefix("\\"), line.count > 1 else { return nil }
        marker = String(line.dropFirst())
    }

    /// Whether `plan` must not run on a paragraph that begins with `line`.
    public func keepsLiteral(_ plan: EditPlan, line: String) -> Bool {
        line.hasPrefix(marker) && !plan.conversion.isInline
    }
}
