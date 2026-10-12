import AppKit
import NoteMarkCore

/// Owns the slash command menu: its search session, debounced editor reads,
/// and the floating panel.
@MainActor final class SlashMenuController {
    /// A command was clicked in the panel.
    var onChoose: ((SlashCommand) -> Void)?

    /// A slash query is being followed, whether or not the panel is shown.
    private(set) var isTracking = false
    /// Esc closed the menu; the typed `/query` stays literal text.
    var isSuppressed = false

    private static let debounce = Duration.milliseconds(40)
    private static let retryDelay = Duration.milliseconds(150)

    private let panel = SlashCommandPanel()
    private let session: ConversionSession
    private let diagnostics: DiagnosticsReporter
    private var search = SlashMenuSession()
    private var editor: EditorSnapshot?
    private var pendingUpdate: Task<Void, Never>?

    init(session: ConversionSession, diagnostics: DiagnosticsReporter) {
        self.session = session
        self.diagnostics = diagnostics
        panel.onChoose = { [weak self] command in self?.onChoose?(command) }
    }

    var isPanelVisible: Bool { panel.isVisible }
    var selectedCommand: SlashCommand? { panel.selected }
    func panelContainsMouse() -> Bool { panel.containsMouse() }

    /// A slash was just typed: only a fresh slash may open the full menu.
    func begin() {
        search.begin()
        editor = nil
        isSuppressed = false
        isTracking = true
    }

    /// Record search input before the debounced editor read catches up.
    func noteSearchInput(isDeletion: Bool = false) {
        search.noteSearchInput(isDeletion: isDeletion)
    }

    func scheduleUpdate(after delay: Duration = debounce) {
        pendingUpdate?.cancel()
        pendingUpdate = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.update(composing: ComposingProbe())
        }
    }

    func dismiss() {
        pendingUpdate?.cancel()
        pendingUpdate = nil
        isTracking = false
        search = SlashMenuSession()
        editor = nil
        panel.dismiss()
        diagnostics.recordSlash(visible: false, composing: false, matchCount: 0)
    }

    /// Move the highlighted command. Returns false when the refreshed menu is hidden.
    func moveSelection(by delta: Int, composing: ComposingProbe) -> Bool {
        pendingUpdate?.cancel()
        update(composing: composing)
        guard panel.isVisible else { return false }
        panel.move(delta)
        return true
    }

    /// Read the editor and show, hide, or dismiss the menu accordingly.
    func update(composing: ComposingProbe) {
        guard session.canEdit, !isSuppressed, NotesApp.isFrontmost else { dismiss(); return }
        if let editor, !NotesApp.hasSameFocus(as: editor) { dismiss(); return }
        let isComposing = composing.isComposing
        let snapshot = EditorSnapshot.capture(.observation)
        let update = search.update(beforeCaret: snapshot?.before, windowStart: snapshot?.windowStart ?? 0,
                                    afterCaret: snapshot?.after, selectionLength: snapshot?.selection.length ?? 0,
                                    isMonospaced: snapshot?.isMonospaced ?? false, isComposing: isComposing)
        switch update {
        case .wait:
            diagnostics.recordSlash(visible: panel.isVisible, composing: isComposing,
                                    matchCount: SlashCommand.matching(panel.currentQuery).count)
            scheduleUpdate(after: Self.retryDelay)
        case .show(let query):
            guard let snapshot, let bounds = snapshot.caretBounds() else {
                scheduleUpdate(after: Self.retryDelay)
                return
            }
            editor = snapshot
            isTracking = true
            panel.show(query: query, anchor: bounds)
            diagnostics.recordSlash(visible: panel.isVisible, composing: isComposing,
                                    matchCount: SlashCommand.matching(query).count)
            if isComposing { scheduleUpdate(after: Self.retryDelay) }
        case .hide:
            // Keep query history: deleting back to '/' must not reopen the initial
            // menu. Further edits can still produce a matching command and reopen it.
            pendingUpdate?.cancel()
            pendingUpdate = nil
            editor = snapshot ?? editor
            isTracking = true
            panel.dismiss()
            diagnostics.recordSlash(visible: false, composing: isComposing, matchCount: 0)
        case .dismiss:
            dismiss()
        }
    }

    /// Resolve the command to run for `requested` and the edit replacing the
    /// typed `/query`. Closes the menu; nil when nothing should run.
    func prepareExecution(of requested: SlashCommand, composing: ComposingProbe) -> (plan: EditPlan, snapshot: EditorSnapshot)? {
        // Mouse selection must also wait until the candidate text has been committed.
        guard !composing.isComposing else {
            scheduleUpdate()
            return nil
        }
        let previousQuery = panel.currentQuery
        update(composing: composing)
        guard panel.isVisible else { return nil }
        guard session.canEdit, let snapshot = EditorSnapshot.capture(),
              let query = SlashQuery.parse(beforeCaret: snapshot.before, windowStart: snapshot.windowStart,
                                           afterCaret: snapshot.after, isMonospaced: snapshot.isMonospaced) else {
            dismiss()
            return nil
        }
        let results = SlashCommand.matching(query.query)
        // Typing immediately before Return may precede the debounced panel update.
        let command = query.query == previousQuery ? results.first { $0.id == requested.id } : results.first
        guard let command else {
            dismiss()
            return nil
        }
        dismiss()
        return (query.plan(for: command), snapshot)
    }
}
