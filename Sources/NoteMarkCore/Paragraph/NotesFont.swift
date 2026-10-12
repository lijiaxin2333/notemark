import AppKit

/// Font evidence read from Notes' Accessibility attributed strings.
public enum NotesFont {
    /// Accessibility attributed strings can describe fonts with this dictionary
    /// instead of an `NSFont`.
    public static let accessibilityFontKey = NSAttributedString.Key("AXFont")
    public static let accessibilityFontNameKey = "AXFontName"
    private static let accessibilityFontSizeKey = "AXFontSize"

    public static func font(in attributes: [NSAttributedString.Key: Any]) -> NSFont? {
        if let font = attributes[.font] as? NSFont { return font }
        guard let description = attributes[accessibilityFontKey] as? [String: Any],
              let size = (description[accessibilityFontSizeKey] as? NSNumber)?.doubleValue, size > 0, size < 200,
              let name = description[accessibilityFontNameKey] as? String else { return nil }
        return NSFont(name: name, size: size)
    }

    public static func isFixedPitch(_ font: NSFont) -> Bool {
        NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask) || font.isFixedPitch
    }

    /// Attributes for rendering replacement text: the original attributes when
    /// they carry an `NSFont`, otherwise a font, color, and paragraph style
    /// rebuilt from the Accessibility description.
    public static func renderingAttributes(from attributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any]? {
        if attributes[.font] is NSFont { return attributes }
        guard let font = font(in: attributes) else { return nil }
        var result: [NSAttributedString.Key: Any] = [.font: font]
        if let color = attributes[.foregroundColor] as? NSColor { result[.foregroundColor] = color }
        if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle { result[.paragraphStyle] = paragraph }
        return result
    }

    /// True for a code font and false for Notes' system text font. A
    /// proportional CJK or emoji fallback font is unknown: it does not
    /// establish a Body boundary.
    public static func codeState(of attributes: [NSAttributedString.Key: Any]) -> Bool? {
        guard let font = font(in: attributes) else { return nil }
        if isFixedPitch(font) { return true }
        // Only Notes' system text fonts confirm Body without a code separator.
        if font.fontName.hasPrefix(".AppleSystemUIFont") ||
            (font.familyName != nil && font.familyName == NSFont.systemFont(ofSize: font.pointSize).familyName) { return false }
        return nil
    }
}
