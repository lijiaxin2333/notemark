import AppKit

public enum InlineRenderer {
    public static func render(style: InlineStyle, text: String, delimiter: String,
                              attributes: [NSAttributedString.Key: Any]) -> NSAttributedString? {
        guard let font = attributes[.font] as? NSFont else { return nil }
        var inline = attributes
        inline.removeValue(forKey: .link)
        switch style {
        case .bold: inline[.font] = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        case .italic: inline[.font] = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        case .boldItalic: inline[.font] = NSFontManager.shared.convert(font, toHaveTrait: [.boldFontMask, .italicFontMask])
        case .code: inline[.font] = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
        case .strike: inline[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        case .link(let url): inline[.link] = URL(string: url)
        }
        let result = NSMutableAttributedString(string: text, attributes: inline)
        // The typed separator restores the original typing font after the span.
        result.append(NSAttributedString(string: delimiter, attributes: attributes))
        return result
    }
}
