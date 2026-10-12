import ApplicationServices
import NoteMarkCore

/// Finds Notes menu commands by key equivalent and remembers them, so each
/// conversion validates one cached item instead of walking the menu bar.
@MainActor final class NotesMenuCommands {
    private static let searchLimit = 600
    private static let searchDepth = 7

    private var process: pid_t?
    private var cache: [MenuShortcut: AXUIElement] = [:]

    /// The enabled menu item for `shortcut`, or nil when Notes offers none.
    func command(_ shortcut: MenuShortcut, in pid: pid_t) -> AXUIElement? {
        if process != pid {
            process = pid
            cache.removeAll()
        }
        if let cached = cache[shortcut], Self.item(cached, matches: shortcut) { return cached }
        cache[shortcut] = Self.search(shortcut, in: pid)
        return cache[shortcut]
    }

    private static func item(_ item: AXUIElement, matches shortcut: MenuShortcut) -> Bool {
        // Command is implied unless `.noCommand` is set.
        let expected: AXMenuItemModifiers = shortcut.requiresShift ? .shift : []
        guard let character = item.string(kAXMenuItemCmdCharAttribute), character.lowercased() == shortcut.key,
              let modifiers = item.number(kAXMenuItemCmdModifiersAttribute),
              AXMenuItemModifiers(rawValue: modifiers.uint32Value) == expected else { return false }
        return item.number(kAXEnabledAttribute)?.boolValue == true
    }

    private static func search(_ shortcut: MenuShortcut, in pid: pid_t) -> AXUIElement? {
        guard let menuBar = NotesApp.applicationElement(pid).element(kAXMenuBarAttribute) else { return nil }
        var pending: [(element: AXUIElement, depth: Int)] = [(menuBar, 0)]
        var visited = 0
        while let (node, depth) = pending.popLast(), visited < searchLimit {
            visited += 1
            if item(node, matches: shortcut) { return node }
            if depth < searchDepth {
                pending.append(contentsOf: node.elements(kAXChildrenAttribute).map { ($0, depth + 1) })
            }
        }
        return nil
    }
}
