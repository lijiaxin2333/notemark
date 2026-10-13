import AppKit
import ApplicationServices

/// Items of Notes' main menu, found by title in every language Notes ships,
/// so Notes' own language does not matter. Titles come from Notes' MainMenu
/// localization table, with the English title as a fallback.
@MainActor enum NotesMainMenu {
    /// One menu level's title: its keys in the MainMenu table and its English title.
    struct Titles: Sendable {
        let keys: [String]
        let english: String
    }

    /// Menu bar menu > submenu entry > item.
    struct Path: Sendable {
        let menu: Titles
        let submenu: Titles
        let item: Titles
    }

    /// The item at `path`. Every menu and submenu is searched when a level's
    /// titles do not match, as after a Notes update renames them.
    static func item(_ path: Path, in pid: pid_t) -> AXUIElement? {
        guard let menuBar = NotesApp.applicationElement(pid).element(kAXMenuBarAttribute) else { return nil }
        let wanted = titles(path.item)
        let menus = children(of: menuBar)
        let named = menus.filter { titles(path.menu).contains(title(of: $0)) }
        let entries = (named.isEmpty ? menus : named).flatMap(children).flatMap(children)
        let submenus = entries.filter { titles(path.submenu).contains(title(of: $0)) }
        for entry in submenus.isEmpty ? entries : submenus {
            for submenu in children(of: entry) {
                if let item = children(of: submenu).first(where: { wanted.contains(title(of: $0)) }) { return item }
            }
        }
        return nil
    }

    /// Whether `item` still has one of `level`'s titles, as a check on a cached item.
    static func item(_ item: AXUIElement, matches level: Titles) -> Bool {
        titles(level).contains(title(of: item))
    }

    private static var cache: [String: Set<String>] = [:]

    private static func titles(_ level: Titles) -> Set<String> {
        let key = level.keys.joined(separator: ",") + "|" + level.english
        if let cached = cache[key] { return cached }
        var titles: Set<String> = [level.english]
        for strings in table { titles.formUnion(level.keys.compactMap { strings[$0] }) }
        cache[key] = titles
        return titles
    }

    /// One dictionary of titles per language.
    private static let table: [[String: String]] = {
        guard let notes = NSWorkspace.shared.urlForApplication(withBundleIdentifier: NotesApp.bundleIdentifier),
              let data = try? Data(contentsOf: notes.appendingPathComponent("Contents/Resources/MainMenu.loctable")),
              let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [] }
        return table.values.compactMap { $0 as? [String: String] }
    }()

    private static func title(of element: AXUIElement) -> String { element.string(kAXTitleAttribute) ?? "" }

    /// Children with the same short timeout as the application element: a
    /// busy Notes must not stall NoteMark, whose main thread also reads input.
    private static func children(of element: AXUIElement) -> [AXUIElement] {
        element.setMessagingTimeout(NotesApp.messagingTimeout)
        let children = element.elements(kAXChildrenAttribute)
        children.forEach { $0.setMessagingTimeout(NotesApp.messagingTimeout) }
        return children
    }
}
