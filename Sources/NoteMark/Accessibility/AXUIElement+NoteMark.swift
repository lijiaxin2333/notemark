import AppKit
import ApplicationServices

/// Typed access to the Accessibility attributes NoteMark reads and writes.
extension AXUIElement {
    static func application(_ pid: pid_t) -> AXUIElement { AXUIElementCreateApplication(pid) }

    /// Bound how long requests to this element may block the caller.
    func setMessagingTimeout(_ seconds: Float) { AXUIElementSetMessagingTimeout(self, seconds) }

    func attribute(_ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else { return nil }
        return value
    }

    func element(_ name: String) -> AXUIElement? { AXValueConversion.element(attribute(name)) }
    func string(_ name: String) -> String? { attribute(name) as? String }
    func number(_ name: String) -> NSNumber? { attribute(name) as? NSNumber }
    func elements(_ name: String) -> [AXUIElement] { attribute(name) as? [AXUIElement] ?? [] }

    var role: String? { string(kAXRoleAttribute) }
    var characterCount: Int? { number(kAXNumberOfCharactersAttribute)?.intValue }
    var selectedRange: NSRange? { AXValueConversion.range(attribute(kAXSelectedTextRangeAttribute)) }

    func isSettable(_ name: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(self, name as CFString, &settable) == .success && settable.boolValue
    }

    /// Select `range` and confirm that the editor reports it back.
    func select(_ range: NSRange) -> Bool {
        guard let value = AXValueConversion.value(range),
              AXUIElementSetAttributeValue(self, kAXSelectedTextRangeAttribute as CFString, value) == .success else { return false }
        return selectedRange == range
    }

    func parameterized(_ name: String, range: NSRange) -> CFTypeRef? {
        guard let parameter = AXValueConversion.value(range) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(self, name as CFString, parameter, &value) == .success else { return nil }
        return value
    }

    func text(in range: NSRange) -> String? {
        if range.length == 0 { return "" }
        return parameterized(kAXStringForRangeParameterizedAttribute, range: range) as? String
    }

    func attributedText(in range: NSRange) -> NSAttributedString? {
        parameterized(kAXAttributedStringForRangeParameterizedAttribute, range: range) as? NSAttributedString
    }

    /// Screen bounds in Accessibility (top-left origin) coordinates.
    func bounds(for range: NSRange) -> CGRect? {
        AXValueConversion.rect(parameterized(kAXBoundsForRangeParameterizedAttribute, range: range))
    }

    func perform(_ action: String) -> Bool { AXUIElementPerformAction(self, action as CFString) == .success }

    func isSameElement(as other: AXUIElement) -> Bool { CFEqual(self, other) }
}

/// Conversions between Core Foundation values and Swift types.
enum AXValueConversion {
    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    static func range(_ value: CFTypeRef?) -> NSRange? {
        var range = CFRange()
        guard let axValue = axValue(value), AXValueGetValue(axValue, .cfRange, &range),
              range.location >= 0, range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    static func value(_ range: NSRange) -> AXValue? {
        var cfRange = CFRange(location: range.location, length: range.length)
        return AXValueCreate(.cfRange, &cfRange)
    }

    static func rect(_ value: CFTypeRef?) -> CGRect? {
        var rect = CGRect.zero
        guard let axValue = axValue(value), AXValueGetValue(axValue, .cgRect, &rect) else { return nil }
        return rect
    }

    static func point(_ value: CFTypeRef?) -> CGPoint? {
        var point = CGPoint.zero
        guard let axValue = axValue(value), AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    static func size(_ value: CFTypeRef?) -> CGSize? {
        var size = CGSize.zero
        guard let axValue = axValue(value), AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private static func axValue(_ value: CFTypeRef?) -> AXValue? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXValue.self)
    }
}
