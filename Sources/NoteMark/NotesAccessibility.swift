import AppKit
import ApplicationServices
import Carbon
import NoteMarkCore

struct EditorSnapshot {
    let pid: pid_t
    let element: AXUIElement
    let selection: NSRange
    let windowStart: Int
    let before: String
    let after: String
    let rightBoundaryKnown: Bool
    let baseAttributes: [NSAttributedString.Key: Any]?
    let isMonospaced: Bool
}

enum NotesAccessibility {
    static let bundleID = "com.apple.Notes"

    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func range(_ value: CFTypeRef?) -> NSRange? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(unsafeBitCast(value, to: AXValue.self), .cfRange, &range),
              range.location >= 0, range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    static func rangeValue(_ range: NSRange) -> AXValue? {
        var cf = CFRange(location: range.location, length: range.length)
        return AXValueCreate(.cfRange, &cf)
    }

    static func parameter(_ element: AXUIElement, _ attribute: String, range: NSRange) -> CFTypeRef? {
        guard let parameter = rangeValue(range) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, attribute as CFString, parameter, &value) == .success else { return nil }
        return value
    }

    static func text(_ element: AXUIElement, range: NSRange) -> String? {
        if range.length == 0 { return "" }
        return parameter(element, kAXStringForRangeParameterizedAttribute, range: range) as? String
    }

    static func selectedRange(_ element: AXUIElement) -> NSRange? {
        range(value(element, kAXSelectedTextRangeAttribute))
    }

    static func setSelection(_ element: AXUIElement, range: NSRange) -> Bool {
        guard let ax = rangeValue(range),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, ax) == .success else { return false }
        return selectedRange(element) == range
    }

    static func sameFocus(_ snapshot: EditorSnapshot) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.pid else { return false }
        let app = AXUIElementCreateApplication(snapshot.pid)
        guard let current = element(value(app, kAXFocusedUIElementAttribute)) else { return false }
        return CFEqual(current, snapshot.element)
    }

    static func snapshot(forSlashMenu: Bool = false) -> EditorSnapshot? {
        guard let foreground = NSWorkspace.shared.frontmostApplication,
              foreground.bundleIdentifier == bundleID else { return nil }
        let app = AXUIElementCreateApplication(foreground.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.08)
        guard let editor = element(value(app, kAXFocusedUIElementAttribute)),
              value(editor, kAXRoleAttribute) as? String == kAXTextAreaRole,
              let selection = selectedRange(editor), forSlashMenu || selection.length == 0 else { return nil }
        AXUIElementSetMessagingTimeout(editor, 0.08)
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(editor, kAXSelectedTextRangeAttribute as CFString, &settable) == .success,
              settable.boolValue else { return nil }
        // Some editors expose marked text while an IME is composing. Never replace it.
        if !forSlashMenu, hasMarkedText(editor, selection: selection) { return nil }
        if let ranges = value(editor, kAXSelectedTextRangesAttribute) as? [Any], ranges.count > 1 { return nil }
        let start = max(0, selection.location - 512)
        guard let before = text(editor, range: NSRange(location: start, length: selection.location - start)) else { return nil }
        let count = (value(editor, kAXNumberOfCharactersAttribute) as? NSNumber)?.intValue
        let after: String
        let rightBoundaryKnown: Bool
        if let count, selection.location < count {
            let beforeText = before as NSString
            let newline = beforeText.rangeOfCharacter(from: .newlines, options: .backwards)
            let line = beforeText.substring(from: newline.location == NSNotFound ? 0 : NSMaxRange(newline))
            if MarkdownRule.isListMarker(line) {
                // Inspect the rest of this paragraph before changing an existing line to a list.
                // A truncated tail or an image anchor must not be treated as plain text.
                let length = min(512, count - selection.location)
                guard let sample = text(editor, range: NSRange(location: selection.location, length: length)) else { return nil }
                let tail = sample as NSString
                let end = tail.rangeOfCharacter(from: .newlines)
                after = end.location == NSNotFound ? sample : tail.substring(to: end.location)
                rightBoundaryKnown = end.location != NSNotFound || length == count - selection.location
            } else {
                guard let next = text(editor, range: NSRange(location: selection.location, length: 1)) else { return nil }
                after = next
                rightBoundaryKnown = true
            }
        } else if count == selection.location { after = ""; rightBoundaryKnown = true }
        else {
            // Without a right-hand boundary, paragraph conversion is unsafe.
            after = "?"
            rightBoundaryKnown = false
        }
        let attributes = selection.location > 0 ? attributes(editor, at: selection.location - 1) : nil
        let font = attributes?[.font] as? NSFont
        let mono = font.map { NSFontManager.shared.traits(of: $0).contains(.fixedPitchFontMask) || $0.isFixedPitch } ?? false
        return EditorSnapshot(pid: foreground.processIdentifier, element: editor, selection: selection,
                              windowStart: start, before: before, after: after, rightBoundaryKnown: rightBoundaryKnown,
                              baseAttributes: attributes, isMonospaced: mono)
    }

    static func isComposing() -> Bool {
        guard let foreground = NSWorkspace.shared.frontmostApplication,
              foreground.bundleIdentifier == bundleID else { return false }
        let app = AXUIElementCreateApplication(foreground.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.08)
        guard let editor = element(value(app, kAXFocusedUIElementAttribute)) else { return false }
        AXUIElementSetMessagingTimeout(editor, 0.08)
        return hasMarkedText(editor, selection: selectedRange(editor)) || inputMethodHasCandidates()
    }

    private static func currentInputMethodBundleID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyBundleID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
    }

    private static func inputMethodWindows() -> [AXUIElement] {
        guard let owner = currentInputMethodBundleID() else { return [] }
        return NSRunningApplication.runningApplications(withBundleIdentifier: owner).flatMap { process in
            let app = AXUIElementCreateApplication(process.processIdentifier)
            AXUIElementSetMessagingTimeout(app, 0.04)
            // Some input methods omit AXWindows but expose their candidate dialog
            // as an application child instead.
            return (value(app, kAXWindowsAttribute) as? [AXUIElement] ?? []) +
                   (value(app, kAXChildrenAttribute) as? [AXUIElement] ?? [])
        }
    }

    static func inputMethodHasCandidates() -> Bool {
        // WeType does not expose AXMarkedTextRange or markedClauseSegment in Notes.
        // Its candidate UI is a system dialog owned by the selected input method.
        for window in inputMethodWindows() {
            let subrole = value(window, kAXSubroleAttribute) as? String
            let role = value(window, kAXRoleAttribute) as? String
            if ([kAXSystemDialogSubrole, kAXSystemFloatingWindowSubrole, kAXFloatingWindowSubrole].contains(subrole ?? "") ||
                role == kAXSystemDialogSubrole),
               (value(window, kAXMinimizedAttribute) as? NSNumber)?.boolValue != true {
                return true
            }
        }
        return false
    }

    private static func hasMarkedText(_ editor: AXUIElement, selection: NSRange?) -> Bool {
        if (range(value(editor, "AXMarkedTextRange"))?.length ?? 0) > 0 { return true }
        // Some text areas expose composition attributes instead of a marked range.
        // Check both sides of the selection because the IME caret can be inside it.
        guard let selection else { return false }
        for index in Set([max(0, selection.location - 1), selection.location]) {
            if let text = parameter(editor, kAXAttributedStringForRangeParameterizedAttribute,
                                    range: NSRange(location: index, length: 1)) as? NSAttributedString,
               text.length > 0, text.attribute(.markedClauseSegment, at: 0, effectiveRange: nil) != nil {
                return true
            }
        }
        return false
    }

    static func attributes(_ element: AXUIElement, at index: Int) -> [NSAttributedString.Key: Any]? {
        guard let attributed = parameter(element, kAXAttributedStringForRangeParameterizedAttribute,
                                         range: NSRange(location: index, length: 1)) as? NSAttributedString,
              attributed.length > 0 else { return nil }
        let raw = attributed.attributes(at: 0, effectiveRange: nil)
        if raw[.font] is NSFont { return raw }
        guard let font = accessibilityFont(raw) else { return nil }
        var result: [NSAttributedString.Key: Any] = [.font: font]
        if let color = raw[.foregroundColor] as? NSColor { result[.foregroundColor] = color }
        if let paragraph = raw[.paragraphStyle] as? NSParagraphStyle { result[.paragraphStyle] = paragraph }
        return result
    }

    private static func accessibilityFont(_ attributes: [NSAttributedString.Key: Any]) -> NSFont? {
        if let font = attributes[.font] as? NSFont { return font }
        // Accessibility attributed strings can use AXFont dictionaries instead of NSFont.
        guard let dict = attributes[NSAttributedString.Key("AXFont")] as? [String: Any],
              let size = (dict["AXFontSize"] as? NSNumber)?.doubleValue, size > 0, size < 200,
              let name = dict["AXFontName"] as? String else { return nil }
        return NSFont(name: name, size: size)
    }

    private static func monospacedState(_ attributes: [NSAttributedString.Key: Any]) -> Bool? {
        guard let font = accessibilityFont(attributes) else { return nil }
        if NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask) || font.isFixedPitch { return true }
        // A proportional CJK/emoji fallback does not establish a Body boundary.
        // Only Notes' system text fonts confirm it without a code separator.
        if font.fontName.hasPrefix(".AppleSystemUIFont") ||
            (font.familyName != nil && font.familyName == NSFont.systemFont(ofSize: font.pointSize).familyName) { return false }
        return nil
    }

    private static func codeParagraphState(_ line: NSRange, styled: NSAttributedString,
                                           source: NSString, endsAtDocumentBoundary: Bool) -> Bool? {
        // No separator or character exists for the empty terminal paragraph.
        // It cannot inherit the previous paragraph's code font.
        if line.length == 0, line.location == source.length { return endsAtDocumentBoundary ? false : nil }
        func fontState(_ index: Int) -> Bool? {
            guard index >= 0, index < styled.length else { return nil }
            return monospacedState(styled.attributes(at: index, effectiveRange: nil))
        }
        let end = NSMaxRange(line)
        let hasSeparator = end < source.length && UnicodeScalar(source.character(at: end)).map({ CharacterSet.newlines.contains($0) }) == true
        return CodeBlockContext.codeParagraphState(line, separatorIsCode: hasSeparator ? fontState(end) : nil,
                                                  fontIsCode: fontState)
    }

    static func codeBlock(_ snapshot: EditorSnapshot) -> CodeBlockContext? {
        guard let count = (value(snapshot.element, kAXNumberOfCharactersAttribute) as? NSNumber)?.intValue,
              snapshot.selection.location <= count else { return nil }
        // A truncated code block is never treated as empty. Read text and font
        // attributes together so neighboring Body paragraphs stay outside it.
        let start = max(0, snapshot.selection.location - 4096)
        let end = min(count, snapshot.selection.location + 4096)
        let range = NSRange(location: start, length: end - start)
        guard let sample = text(snapshot.element, range: range) else { return nil }
        let styled: NSAttributedString?
        if range.length == 0 { styled = NSAttributedString(string: "") }
        else { styled = parameter(snapshot.element, kAXAttributedStringForRangeParameterizedAttribute, range: range) as? NSAttributedString }
        guard let styled, styled.length == range.length else { return nil }
        return CodeBlockContext.read(text: sample, windowStart: start, documentLength: count,
            caret: snapshot.selection.location, currentLineIsCode: true, isCodeLine: { line in
                codeParagraphState(line, styled: styled, source: sample as NSString, endsAtDocumentBoundary: end == count)
            })
    }

    /// Format and range metadata only. Never serialize the sampled note text.
    static func cancellationDiagnostics(_ snapshot: EditorSnapshot) -> [String: Any] {
        let count = (value(snapshot.element, kAXNumberOfCharactersAttribute) as? NSNumber)?.intValue ?? -1
        let context = codeBlock(snapshot)
        var result: [String: Any] = [
            "caret": snapshot.selection.location, "selectionLength": snapshot.selection.length,
            "documentLength": count, "contextStart": context?.range.location ?? -1,
            "contextLength": context?.range.length ?? -1,
            "contextEmpty": context?.text.unicodeScalars.allSatisfy({ CharacterSet.newlines.contains($0) }) ?? false
        ]
        let start = max(0, snapshot.selection.location - 128)
        let end = min(count, snapshot.selection.location + 128)
        guard end >= start, let sample = text(snapshot.element, range: NSRange(location: start, length: end - start)) else { return result }
        let source = sample as NSString
        let styled = parameter(snapshot.element, kAXAttributedStringForRangeParameterizedAttribute,
                               range: NSRange(location: start, length: end - start)) as? NSAttributedString
        var lines: [[String: Any]] = []
        var lineStart = 0
        func fontName(_ index: Int) -> String {
            guard let styled, index >= start, index - start < styled.length else { return "unavailable" }
            let attributes = styled.attributes(at: index - start, effectiveRange: nil)
            return accessibilityFont(attributes)?.fontName ??
                (attributes[NSAttributedString.Key("AXFont")] as? [String: Any])?["AXFontName"] as? String ?? "unavailable"
        }
        for index in 0...source.length {
            guard index == source.length || UnicodeScalar(source.character(at: index)).map({ CharacterSet.newlines.contains($0) }) == true else { continue }
            lines.append(["start": start + lineStart, "length": index - lineStart,
                          "firstFont": fontName(start + lineStart),
                          "lastFont": fontName(start + max(lineStart, index - 1)),
                          "separatorFont": fontName(start + index)])
            lineStart = index + 1
        }
        result["paragraphs"] = Array(lines.suffix(12))
        return result
    }

    static func hasCodeContent(_ snapshot: EditorSnapshot) -> Bool {
        guard snapshot.selection.length == 0 else { return false }
        let before = snapshot.before as NSString
        let newline = before.rangeOfCharacter(from: .newlines, options: .backwards)
        let start = newline.location == NSNotFound ? 0 : NSMaxRange(newline)
        guard snapshot.windowStart == 0 || newline.location != NSNotFound,
              start < before.length else { return false }
        // An inline code fragment at the end of ordinary prose must not arm a
        // paragraph cancellation. Check the paragraph's first character too.
        return currentParagraphCodeState(snapshot) == true
    }

    static func isEmptyMonospacedParagraph(_ snapshot: EditorSnapshot) -> Bool {
        guard snapshot.selection.length == 0, snapshot.rightBoundaryKnown,
              snapshot.after.isEmpty || snapshot.after.first?.isNewline == true else { return false }
        let before = snapshot.before as NSString
        let newline = before.rangeOfCharacter(from: .newlines, options: .backwards)
        guard snapshot.windowStart == 0 || newline.location != NSNotFound,
              (newline.location == NSNotFound ? 0 : NSMaxRange(newline)) == before.length,
              let font = attributes(snapshot.element, at: snapshot.selection.location)?[.font] as? NSFont else { return false }
        // Inspect the empty paragraph's own separator, never the character to
        // its left: it may belong to a Body paragraph after repeated deletions.
        return NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask) || font.isFixedPitch
    }

    static func currentLineIsMonospaced(_ snapshot: EditorSnapshot) -> Bool {
        if let code = currentParagraphCodeState(snapshot) { return code }
        let before = snapshot.before as NSString
        let newline = before.rangeOfCharacter(from: .newlines, options: .backwards)
        let start = newline.location == NSNotFound ? 0 : NSMaxRange(newline)
        guard snapshot.windowStart == 0 || newline.location != NSNotFound else { return false }
        if let font = attributes(snapshot.element, at: snapshot.windowStart + start)?[.font] as? NSFont {
            return NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask) || font.isFixedPitch
        }
        return snapshot.isMonospaced // Empty final paragraph has no character at its start.
    }

    private static func currentParagraphCodeState(_ snapshot: EditorSnapshot) -> Bool? {
        let before = snapshot.before as NSString
        let newline = before.rangeOfCharacter(from: .newlines, options: .backwards)
        guard snapshot.windowStart == 0 || newline.location != NSNotFound,
              let count = (value(snapshot.element, kAXNumberOfCharactersAttribute) as? NSNumber)?.intValue else { return nil }
        let start = snapshot.windowStart + (newline.location == NSNotFound ? 0 : NSMaxRange(newline))
        let length = min(4096, count - start)
        guard length > 0, let sample = text(snapshot.element, range: NSRange(location: start, length: length)),
              let styled = parameter(snapshot.element, kAXAttributedStringForRangeParameterizedAttribute,
                                     range: NSRange(location: start, length: length)) as? NSAttributedString,
              styled.length == length else { return nil }
        let source = sample as NSString
        let end = source.rangeOfCharacter(from: .newlines)
        guard end.location != NSNotFound || start + length == count else { return nil }
        return codeParagraphState(NSRange(location: 0, length: end.location == NSNotFound ? length : end.location),
                                  styled: styled, source: source, endsAtDocumentBoundary: start + length == count)
    }

    static func caretBounds(_ snapshot: EditorSnapshot) -> CGRect? {
        var rectangle = CGRect.zero
        let ranges = [snapshot.selection,
                      NSRange(location: max(0, snapshot.selection.location - 1), length: snapshot.selection.location > 0 ? 1 : 0)]
        for range in ranges {
            if let value = parameter(snapshot.element, kAXBoundsForRangeParameterizedAttribute, range: range),
               CFGetTypeID(value) == AXValueGetTypeID(),
               AXValueGetValue(unsafeBitCast(value, to: AXValue.self), .cgRect, &rectangle),
               rectangle.height > 0 {
                return appKitBounds(rectangle)
            }
        }
        // Some Notes versions expose the editor bounds but not a caret rectangle.
        var origin = CGPoint.zero
        var size = CGSize.zero
        if let position = value(snapshot.element, kAXPositionAttribute),
           let dimensions = value(snapshot.element, kAXSizeAttribute),
           CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(dimensions) == AXValueGetTypeID(),
           AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &origin),
           AXValueGetValue(unsafeBitCast(dimensions, to: AXValue.self), .cgSize, &size), size.width > 0, size.height > 0 {
            return appKitBounds(CGRect(x: origin.x + 20, y: origin.y + 20, width: 1, height: 18))
        }
        return nil
    }

    private static func appKitBounds(_ rectangle: CGRect) -> CGRect {
        let mainHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: rectangle.minX, y: mainHeight - rectangle.maxY,
                      width: max(1, rectangle.width), height: rectangle.height)
    }

    static func command(for style: ParagraphStyle, pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.08)
        guard let bar = element(value(app, kAXMenuBarAttribute)) else { return nil }
        var pending: [(AXUIElement, Int)] = [(bar, 0)]
        var visited = 0
        while let (node, depth) = pending.popLast(), visited < 600 {
            visited += 1
            if let character = value(node, kAXMenuItemCmdCharAttribute) as? String,
               character.lowercased() == style.shortcut,
               let modifiers = value(node, kAXMenuItemCmdModifiersAttribute) as? NSNumber,
               modifiers.intValue == (style.needsShift ? 1 : 0),
               (value(node, kAXEnabledAttribute) as? NSNumber)?.boolValue == true {
                return node
            }
            if depth < 7, let children = value(node, kAXChildrenAttribute) as? [AXUIElement] {
                pending.append(contentsOf: children.map { ($0, depth + 1) })
            }
        }
        return nil
    }
}
