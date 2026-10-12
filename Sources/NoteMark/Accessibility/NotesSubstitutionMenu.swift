import AppKit
import ApplicationServices
import NoteMarkCore

/// Notes' Edit > Substitutions items, found by title in any language Notes
/// ships, so Notes' own language does not matter.
@MainActor final class NotesSubstitutionMenu {
    /// Keys in Notes' MainMenu localization table, with the English titles.
    private static let editMenuTitleKeys = ["W48-6f-4Dl.title", "5QF-Oa-p0T.title"]
    private static let submenuTitleKeys = ["9ic-FL-obx.title", "FeM-D8-WVr.title"]
    private static let itemTitleKeys: [NotesSubstitution: String] = [
        .smartDashes: "rgM-f4-ycn.title", .smartLists: "zWG-PB-e8J.title", .smartTags: "v3D-JW-yHw.title"
    ]
    private nonisolated static let englishTitles: [NotesSubstitution: String] = [
        .smartDashes: "Smart Dashes", .smartLists: "Smart Lists", .smartTags: "Smart Tags"
    ]

    private static let titles: MenuTitles = loadTitles()

    private struct MenuTitles {
        var editMenu: Set<String> = ["Edit"]
        var submenu: Set<String> = ["Substitutions"]
        var items = englishTitles.mapValues { Set([$0]) }
    }

    private var process: pid_t?
    private var items: [NotesSubstitution: AXUIElement] = [:]

    /// Whether the item is on, or nil when Notes does not offer it now.
    func isOn(_ substitution: NotesSubstitution, in pid: pid_t) -> Bool? {
        guard let item = item(substitution, in: pid), item.number(kAXEnabledAttribute)?.boolValue == true else { return nil }
        return !(item.string(kAXMenuItemMarkCharAttribute) ?? "").isEmpty
    }

    enum ToggleResult { case switched, failed, unknown }

    /// Choose the item once, as the user would; each press switches it. A
    /// press that times out may still run once Notes responds.
    func toggle(_ substitution: NotesSubstitution, in pid: pid_t) -> ToggleResult {
        guard let item = item(substitution, in: pid) else { return .failed }
        switch AXUIElementPerformAction(item, kAXPressAction as CFString) {
        case .success: return .switched
        case .cannotComplete: return .unknown
        default: return .failed
        }
    }

    private func item(_ substitution: NotesSubstitution, in pid: pid_t) -> AXUIElement? {
        if process != pid {
            process = pid
            items.removeAll()
        }
        if let cached = items[substitution], Self.titles.items[substitution]?.contains(cached.string(kAXTitleAttribute) ?? "") == true {
            return cached
        }
        items[substitution] = Self.search(substitution, in: pid)
        return items[substitution]
    }

    /// Edit > Substitutions > item. Every menu and submenu is searched when
    /// the titles do not match, as after a Notes update renames them.
    private static func search(_ substitution: NotesSubstitution, in pid: pid_t) -> AXUIElement? {
        guard let wanted = titles.items[substitution],
              let menuBar = NotesApp.applicationElement(pid).element(kAXMenuBarAttribute) else { return nil }
        let menus = children(of: menuBar)
        let editMenus = menus.filter { titles.editMenu.contains($0.string(kAXTitleAttribute) ?? "") }
        let entries = (editMenus.isEmpty ? menus : editMenus).flatMap(children).flatMap(children)
        let substitutions = entries.filter { titles.submenu.contains($0.string(kAXTitleAttribute) ?? "") }
        for entry in substitutions.isEmpty ? entries : substitutions {
            for submenu in children(of: entry) {
                if let item = children(of: submenu).first(where: { wanted.contains($0.string(kAXTitleAttribute) ?? "") }) {
                    return item
                }
            }
        }
        return nil
    }

    /// Children with the same short timeout as the application element: a
    /// busy Notes must not stall NoteMark, whose main thread also reads input.
    private static func children(of element: AXUIElement) -> [AXUIElement] {
        element.setMessagingTimeout(NotesApp.messagingTimeout)
        let children = element.elements(kAXChildrenAttribute)
        children.forEach { $0.setMessagingTimeout(NotesApp.messagingTimeout) }
        return children
    }

    private static func loadTitles() -> MenuTitles {
        var titles = MenuTitles()
        guard let notes = NSWorkspace.shared.urlForApplication(withBundleIdentifier: NotesApp.bundleIdentifier),
              let data = try? Data(contentsOf: notes.appendingPathComponent("Contents/Resources/MainMenu.loctable")),
              let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return titles }
        for case let strings as [String: String] in table.values {
            titles.editMenu.formUnion(editMenuTitleKeys.compactMap { strings[$0] })
            titles.submenu.formUnion(submenuTitleKeys.compactMap { strings[$0] })
            for (substitution, key) in itemTitleKeys {
                if let title = strings[key] { titles.items[substitution, default: []].insert(title) }
            }
        }
        return titles
    }
}
