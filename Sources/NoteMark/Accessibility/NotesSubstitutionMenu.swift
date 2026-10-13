import ApplicationServices
import NoteMarkCore

/// Notes' Edit > Substitutions items.
@MainActor final class NotesSubstitutionMenu {
    private static let edit = NotesMainMenu.Titles(keys: ["W48-6f-4Dl.title", "5QF-Oa-p0T.title"], english: "Edit")
    private static let substitutions = NotesMainMenu.Titles(keys: ["9ic-FL-obx.title", "FeM-D8-WVr.title"], english: "Substitutions")
    private static let items: [NotesSubstitution: NotesMainMenu.Titles] = [
        .smartDashes: .init(keys: ["rgM-f4-ycn.title"], english: "Smart Dashes"),
        .smartLists: .init(keys: ["zWG-PB-e8J.title"], english: "Smart Lists"),
        .smartTags: .init(keys: ["v3D-JW-yHw.title"], english: "Smart Tags")
    ]

    private var process: pid_t?
    private var cache: [NotesSubstitution: AXUIElement] = [:]

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
            cache.removeAll()
        }
        guard let title = Self.items[substitution] else { return nil }
        if let cached = cache[substitution], NotesMainMenu.item(cached, matches: title) { return cached }
        cache[substitution] = NotesMainMenu.item(.init(menu: Self.edit, submenu: Self.substitutions, item: title), in: pid)
        return cache[substitution]
    }
}
