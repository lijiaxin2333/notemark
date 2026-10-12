import Foundation
import NoteMarkCore

/// Follows the paragraph NoteMark formatted, or an existing code paragraph,
/// so a cancellation key on its empty content can restore Body.
@MainActor final class ParagraphCancellationTracker {
    struct Session {
        let snapshot: EditorSnapshot
        let cancellation: EmptyParagraphCancellation
    }

    private(set) var session: Session? {
        didSet { diagnostics.recordTrackedStyle(session?.cancellation.style) }
    }

    private let diagnostics: DiagnosticsReporter

    init(diagnostics: DiagnosticsReporter) {
        self.diagnostics = diagnostics
    }

    func track(_ cancellation: EmptyParagraphCancellation, at snapshot: EditorSnapshot) {
        session = Session(snapshot: snapshot, cancellation: cancellation)
    }

    func reset() {
        if session != nil { session = nil }
    }

    /// The edit that restores Body for `cancellation`, if its paragraph is empty now.
    func plan(for cancellation: EmptyParagraphCancellation, in snapshot: EditorSnapshot,
              intent: CodeBlockCancellationIntent = .escape, inspection: ParagraphInspection? = nil) -> EditPlan? {
        if cancellation.style == .monostyled {
            return (inspection ?? ParagraphInspection(snapshot)).codeBlock?
                .cancellationPlan(selection: snapshot.selection, intent: intent)
        }
        return cancellation.plan(beforeCaret: snapshot.before, windowStart: snapshot.windowStart,
                                 afterCaret: snapshot.after, selection: snapshot.selection)
    }

    /// Follow the caret after an edit, focus change, or IME commit.
    func refresh() {
        guard let current = EditorSnapshot.capture(.observation) else { return }
        let inspection = ParagraphInspection(current)
        defer { recordObservation(of: current, inspection) }
        if let session, !NotesApp.hasSameFocus(as: session.snapshot) { self.session = nil }
        guard let session else {
            if let recovered = EmptyParagraphCancellation.recoverCode(
                beforeCaret: current.before, windowStart: current.windowStart, selection: current.selection,
                isMonospacedParagraph: inspection.hasCodeContent,
                isEmptyMonospacedParagraph: inspection.isEmptyMonospacedParagraph) {
                self.session = Session(snapshot: current, cancellation: recovered)
            }
            return
        }
        guard session.cancellation.containsCaret(beforeCaret: current.before, windowStart: current.windowStart,
                                                 selection: current.selection) == false else { return }
        if let following = session.cancellation.followingCodeCaret(
            beforeCaret: current.before, windowStart: current.windowStart, selection: current.selection,
            isMonospaced: inspection.currentLineIsMonospaced) {
            self.session = Session(snapshot: current, cancellation: following)
        } else {
            self.session = nil
        }
    }

    private func recordObservation(of current: EditorSnapshot, _ inspection: ParagraphInspection) {
        guard diagnostics.isVerbose else { return }
        let ready = session.flatMap { plan(for: $0.cancellation, in: current, inspection: inspection) } != nil
        let context = inspection.codeBlock
        diagnostics.recordParagraphObservation(ParagraphObservation(
            selectionEmpty: current.selection.length == 0,
            previousCharacterMonospaced: current.isMonospaced,
            currentLineMonospaced: inspection.currentLineIsMonospaced,
            codeContent: inspection.hasCodeContent,
            emptyParagraphMonospaced: inspection.isEmptyMonospacedParagraph,
            codeContextAvailable: context != nil,
            codeContextEmpty: context?.cancellationPlan(selection: current.selection) != nil,
            codeBackwardDeletionReady: context?.cancellationPlan(selection: current.selection, intent: .backwardDeletion) != nil,
            codeForwardDeletionReady: context?.cancellationPlan(selection: current.selection, intent: .forwardDeletion) != nil,
            tracked: session != nil), cancellationReady: ready)
    }
}
