import AppKit
import ApplicationServices
import NoteMarkCore

/// What an attempted edit did to the note.
enum EditOutcome: Equatable {
    /// Nothing changed; the intercepted key can be delivered as typed.
    case notApplied
    /// The edit completed and Notes confirmed it.
    case applied
    /// The note changed but Notes did not confirm every step. The intercepted
    /// key must not be delivered again.
    case incomplete
}

/// Applies edit plans through Notes' own commands, so every change is native
/// formatting on Notes' undo stack.
@MainActor final class NotesEditApplier {
    private static let pollInterval = Duration.milliseconds(20)
    private static let selectionAttempts = 12
    /// The user's clipboard is restored only after Notes has consumed the
    /// paste, or after this many polls (one second).
    private static let pasteAttempts = 50

    private let session: ConversionSession
    private let tracker: ParagraphCancellationTracker
    private let diagnostics: DiagnosticsReporter
    private let keyboardLayout: KeyboardLayout
    private let menu = NotesMenuCommands()

    init(session: ConversionSession, tracker: ParagraphCancellationTracker, diagnostics: DiagnosticsReporter,
         keyboardLayout: KeyboardLayout) {
        self.session = session
        self.tracker = tracker
        self.diagnostics = diagnostics
        self.keyboardLayout = keyboardLayout
    }

    /// Apply `plan` to the editor in `snapshot`. With `cancellation`, the plan
    /// restores Body on a tracked empty paragraph after `intent`.
    func apply(_ plan: EditPlan, to snapshot: EditorSnapshot, cancelling cancellation: EmptyParagraphCancellation? = nil,
               intent: CodeBlockCancellationIntent = .escape) async -> EditOutcome {
        guard NotesApp.hasSameFocus(as: snapshot),
              snapshot.element.selectedRange == snapshot.selection,
              snapshot.element.text(in: plan.range) == plan.original else { return .notApplied }
        switch plan.conversion {
        case .paragraph(let style):
            return await applyParagraph(style, plan: plan, snapshot: snapshot, cancellation: cancellation, intent: intent)
        case .inline(let style, let text, let delimiter):
            return await applyInline(style, text: text, delimiter: delimiter, plan: plan, snapshot: snapshot)
        }
    }

    private func applyParagraph(_ style: ParagraphStyle, plan: EditPlan, snapshot: EditorSnapshot,
                                cancellation: EmptyParagraphCancellation?,
                                intent: CodeBlockCancellationIntent) async -> EditOutcome {
        let isCancellation = cancellation != nil
        guard let command = menu.command(.format(style), in: snapshot.pid) else {
            session.report(isCancellation ? L10n.bodyRestoreUnavailable :
                   style == .checklist ? L10n.checklistCommandUnavailable : L10n.formatCommandUnavailable)
            return .notApplied
        }
        if let cancellation {
            guard let current = EditorSnapshot.capture(), NotesApp.hasSameFocus(as: snapshot),
                  tracker.plan(for: cancellation, in: current, intent: intent) == plan else { return .notApplied }
        }
        // Body changes the font and list style but leaves Notes' quote container.
        var quoteCommand: AXUIElement?
        if cancellation?.style == .quote {
            guard let quote = menu.command(.format(.quote), in: snapshot.pid) else { return .notApplied }
            quoteCommand = quote
        }
        guard snapshot.element.selectedRange == snapshot.selection,
              NotesApp.hasSameFocus(as: snapshot),
              snapshot.element.select(plan.range) else {
            session.report(isCancellation ? L10n.bodyRestoreUnavailable : L10n.formatCommandUnavailable)
            return .notApplied
        }
        let deletesMarker = plan.range.length > 0 && !isCancellation
        if deletesMarker {
            SyntheticKeyboard.deleteBackward(in: snapshot.pid)
            guard await waitForSelection(NSRange(location: plan.range.location, length: 0), in: snapshot) else {
                session.report(L10n.editorResponseUnconfirmed)
                return .incomplete // Do not duplicate the swallowed delimiter after a partial edit.
            }
        }
        if let quoteCommand {
            guard NotesApp.hasSameFocus(as: snapshot), quoteCommand.perform(kAXPressAction) else { return .notApplied }
        }
        guard NotesApp.hasSameFocus(as: snapshot), command.perform(kAXPressAction) else {
            session.report(quoteCommand != nil ? L10n.quoteExitedBodyFailed :
                   isCancellation ? L10n.bodyNotRestored : L10n.formatCommandFailed)
            return deletesMarker || quoteCommand != nil ? .incomplete : .notApplied
        }
        if let cancellation {
            if let outcome = await finishCancellation(cancellation, plan: plan, snapshot: snapshot) { return outcome }
        }
        if session.isRunning, let next = EmptyParagraphCancellation(style: style, paragraphStart: plan.range.location) {
            tracker.track(next, at: snapshot)
        } else {
            tracker.reset()
        }
        if isCancellation { diagnostics.recordCancellationAttempt("applied") }
        session.report(isCancellation ? L10n.bodyRestored : style == .checklist ? L10n.checklistConverted : L10n.paragraphConverted)
        return .applied
    }

    /// After Body was applied: format the terminal empty code paragraph and put
    /// the caret back. Returns an outcome when cancellation stopped early.
    private func finishCancellation(_ cancellation: EmptyParagraphCancellation, plan: EditPlan,
                                    snapshot: EditorSnapshot) async -> EditOutcome? {
        traceCancellation("after-body")
        if cancellation.style == .monostyled {
            for terminal in CodeBlockContext.bodyFormattingSelections(for: plan).dropFirst() {
                guard NotesApp.hasSameFocus(as: snapshot), snapshot.element.select(terminal),
                      let body = menu.command(.format(.body), in: snapshot.pid),
                      body.perform(kAXPressAction) else {
                    _ = await restoreCaret(snapshot)
                    tracker.refresh()
                    diagnostics.recordCancellationAttempt("terminal-paragraph-failed")
                    session.report(L10n.terminalParagraphUnconfirmed)
                    return .incomplete // Body has already changed part of the selection.
                }
            }
        }
        // AXPress can return before Notes' format action moves the selection.
        // Keep later delete events held until the caret stays put.
        guard await restoreCaret(snapshot) else {
            tracker.reset()
            diagnostics.recordCancellationAttempt("caret-restoration-unconfirmed")
            session.report(L10n.caretUnconfirmed)
            return .incomplete // Formatting occurred; do not replay the cancellation key.
        }
        traceCancellation("after-restoration")
        return nil
    }

    private func applyInline(_ style: InlineStyle, text: String, delimiter: String, plan: EditPlan,
                             snapshot: EditorSnapshot) async -> EditOutcome {
        guard let attributes = snapshot.baseAttributes, attributes[.font] is NSFont else {
            session.report(L10n.fontUnavailable)
            return .notApplied
        }
        guard let replacement = InlineRenderer.render(style: style, text: text, delimiter: delimiter, attributes: attributes),
              let rtf = try? replacement.data(from: NSRange(location: 0, length: replacement.length),
                                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]),
              NotesApp.hasSameFocus(as: snapshot),
              snapshot.element.select(plan.range) else { return .notApplied }
        guard let pasteboard = PasteboardTransaction.begin(rtf: rtf) else {
            _ = snapshot.element.select(snapshot.selection)
            return .notApplied
        }
        SyntheticKeyboard.paste(in: snapshot.pid, layout: keyboardLayout)
        let pasted = NSRange(location: plan.range.location, length: replacement.length)
        var confirmed = false
        for _ in 0..<Self.pasteAttempts {
            try? await Task.sleep(for: Self.pollInterval)
            if snapshot.element.text(in: pasted) == text + delimiter {
                confirmed = true
                break
            }
        }
        // Restoring earlier could let a slow paste insert the user's own clipboard.
        pasteboard.restore()
        session.report(confirmed ? L10n.inlineConverted : L10n.pasteUnconfirmed)
        return confirmed ? .applied : .incomplete
    }

    private func waitForSelection(_ range: NSRange, in snapshot: EditorSnapshot) async -> Bool {
        for _ in 0..<Self.selectionAttempts {
            try? await Task.sleep(for: Self.pollInterval)
            guard NotesApp.hasSameFocus(as: snapshot) else { return false }
            if snapshot.element.selectedRange == range { return true }
        }
        return false
    }

    private func restoreCaret(_ snapshot: EditorSnapshot) async -> Bool {
        await SelectionRestoration.restore(snapshot.selection, isValid: {
            self.session.isRunning && NotesApp.hasSameFocus(as: snapshot)
        }, read: {
            snapshot.element.selectedRange
        }, write: {
            snapshot.element.select($0)
        })
    }

    private func traceCancellation(_ phase: String) {
        guard let current = EditorSnapshot.capture(.observation) else { return }
        diagnostics.recordCancellationTrace(ParagraphInspection(current).cancellationTrace(phase: phase))
    }
}
