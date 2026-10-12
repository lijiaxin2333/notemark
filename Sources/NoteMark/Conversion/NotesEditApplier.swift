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

    /// Whether the intercepted key should be delivered after the edit.
    var deliversKey: Bool { self == .notApplied }
}

/// Applies edit plans through Notes' own commands, so every change is native
/// formatting on Notes' undo stack.
@MainActor final class NotesEditApplier {
    private static let pollInterval = Duration.milliseconds(20)
    private static let selectionAttempts = 12
    private static let lineEndSearchLimit = 64
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
        case .divider:
            return await insertDivider(plan: plan, snapshot: snapshot)
        case .date:
            return await insertDate(plan: plan, snapshot: snapshot)
        case .unescape:
            return await removeEscape(plan: plan, snapshot: snapshot)
        }
    }

    private func applyParagraph(_ style: ParagraphStyle, plan: EditPlan, snapshot: EditorSnapshot,
                                cancellation: EmptyParagraphCancellation?,
                                intent: CodeBlockCancellationIntent) async -> EditOutcome {
        let isCancellation = cancellation != nil
        guard let command = menu.command(.format(style), in: snapshot.pid) else {
            session.reportFailure(isCancellation ? L10n.bodyRestoreUnavailable :
                                  style == .checklist ? L10n.checklistCommandUnavailable : L10n.formatCommandUnavailable,
                                  near: snapshot)
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
            session.reportFailure(isCancellation ? L10n.bodyRestoreUnavailable : L10n.formatCommandUnavailable,
                                  near: snapshot)
            return .notApplied
        }
        let deletesMarker = plan.range.length > 0 && !isCancellation
        if deletesMarker {
            SyntheticKeyboard.deleteBackward(in: snapshot.pid)
            guard await waitForSelection(NSRange(location: plan.range.location, length: 0), in: snapshot) else {
                session.reportFailure(L10n.editorResponseUnconfirmed, near: snapshot)
                return .incomplete // Do not duplicate the swallowed delimiter after a partial edit.
            }
        }
        if let quoteCommand {
            guard NotesApp.hasSameFocus(as: snapshot), quoteCommand.perform(kAXPressAction) else { return .notApplied }
        }
        guard NotesApp.hasSameFocus(as: snapshot), command.perform(kAXPressAction) else {
            session.reportFailure(quoteCommand != nil ? L10n.quoteExitedBodyFailed :
                                  isCancellation ? L10n.bodyNotRestored : L10n.formatCommandFailed, near: snapshot)
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
                    session.reportFailure(L10n.terminalParagraphUnconfirmed, near: snapshot)
                    return .incomplete // Body has already changed part of the selection.
                }
            }
        }
        // AXPress can return before Notes' format action moves the selection.
        // Keep later delete events held until the caret stays put.
        guard await restoreCaret(snapshot) else {
            tracker.reset()
            diagnostics.recordCancellationAttempt("caret-restoration-unconfirmed")
            session.reportFailure(L10n.caretUnconfirmed, near: snapshot)
            return .incomplete // Formatting occurred; do not replay the cancellation key.
        }
        traceCancellation("after-restoration")
        return nil
    }

    private func applyInline(_ style: InlineStyle, text: String, delimiter: String, plan: EditPlan,
                             snapshot: EditorSnapshot) async -> EditOutcome {
        guard let attributes = snapshot.baseAttributes, attributes[.font] is NSFont else {
            session.reportFailure(L10n.fontUnavailable, near: snapshot)
            return .notApplied
        }
        guard let replacement = InlineRenderer.render(style: style, text: text, delimiter: delimiter,
                                                      attributes: attributes) else { return .notApplied }
        let outcome = await paste(replacement, over: plan.range, expecting: text + delimiter, snapshot: snapshot)
        if outcome == .applied { session.report(L10n.inlineConverted) }
        return outcome
    }

    /// Replace `range` with rich text through a native paste, a single undoable edit.
    private func paste(_ replacement: NSAttributedString, over range: NSRange, expecting text: String,
                       snapshot: EditorSnapshot) async -> EditOutcome {
        guard let rtf = try? replacement.data(from: NSRange(location: 0, length: replacement.length),
                                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]),
              NotesApp.hasSameFocus(as: snapshot),
              snapshot.element.select(range) else { return .notApplied }
        guard let pasteboard = PasteboardTransaction.begin(rtf: rtf) else {
            _ = snapshot.element.select(snapshot.selection)
            return .notApplied
        }
        SyntheticKeyboard.paste(in: snapshot.pid, layout: keyboardLayout)
        let pasted = NSRange(location: range.location, length: replacement.length)
        var confirmed = false
        for _ in 0..<Self.pasteAttempts {
            try? await Task.sleep(for: Self.pollInterval)
            if snapshot.element.text(in: pasted) == text {
                confirmed = true
                break
            }
        }
        // Restoring earlier could let a slow paste insert the user's own clipboard.
        pasteboard.restore()
        if !confirmed { session.reportFailure(L10n.pasteUnconfirmed, near: snapshot) }
        return confirmed ? .applied : .incomplete
    }

    /// Replace a `---` marker or `/divider` with Notes' native divider line.
    private func insertDivider(plan: EditPlan, snapshot: EditorSnapshot) async -> EditOutcome {
        guard let command = menu.command(.insertDivider, in: snapshot.pid) else {
            session.reportFailure(L10n.dividerUnavailable, near: snapshot)
            return .notApplied
        }
        guard let marker = markerRange(of: plan, in: snapshot) else { return keepCaretAfterChangedMarker(plan, in: snapshot) }
        guard NotesApp.hasSameFocus(as: snapshot), snapshot.element.select(marker) else {
            session.reportFailure(L10n.formatCommandUnavailable, near: snapshot)
            return .notApplied
        }
        // Check again: the replacement can also land while the marker is selected.
        guard let range = markerRange(of: plan, in: snapshot), range == marker else {
            return keepCaretAfterChangedMarker(plan, in: snapshot)
        }
        SyntheticKeyboard.deleteBackward(in: snapshot.pid)
        guard await waitForSelection(NSRange(location: range.location, length: 0), in: snapshot) else {
            session.reportFailure(L10n.editorResponseUnconfirmed, near: snapshot)
            return .incomplete
        }
        guard NotesApp.hasSameFocus(as: snapshot), command.perform(kAXPressAction) else {
            session.reportFailure(L10n.formatCommandFailed, near: snapshot)
            return .incomplete
        }
        tracker.reset()
        session.report(L10n.dividerInserted)
        return .applied
    }

    /// Where the divider marker is now. Smart Dashes can replace `---` with `—`
    /// after the plan was read.
    private func markerRange(of plan: EditPlan, in snapshot: EditorSnapshot) -> NSRange? {
        if snapshot.element.text(in: plan.range) == plan.original { return plan.range }
        let dash = NSRange(location: plan.range.location, length: 1)
        guard plan.original == "---", snapshot.element.text(in: dash) == "—",
              ["", "\n"].contains(snapshot.element.text(in: NSRange(location: dash.upperBound, length: 1)) ?? "") else { return nil }
        return dash
    }

    /// The marker changed some other way: leave the caret at the end of its
    /// line, where the trigger key is then typed.
    private func keepCaretAfterChangedMarker(_ plan: EditPlan, in snapshot: EditorSnapshot) -> EditOutcome {
        _ = snapshot.element.select(NSRange(location: lineEnd(from: plan.range.location, in: snapshot), length: 0))
        return .notApplied
    }

    /// The end of the line starting at `location`, whose text may have changed
    /// since `snapshot` was read.
    private func lineEnd(from location: Int, in snapshot: EditorSnapshot) -> Int {
        let length = max(0, min(Self.lineEndSearchLimit, (snapshot.element.characterCount ?? location) - location))
        guard let text = snapshot.element.text(in: NSRange(location: location, length: length)) as NSString? else { return location }
        let lineBreak = text.rangeOfCharacter(from: .newlines)
        return location + (lineBreak.location == NSNotFound ? text.length : lineBreak.location)
    }

    /// Replace `/date` with today's date in the user's first preferred
    /// language, rather than NoteMark's interface language, and their region.
    private func insertDate(plan: EditPlan, snapshot: EditorSnapshot) async -> EditOutcome {
        let date = Date.now.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: Self.userLocale))
        guard let attributes = snapshot.baseAttributes, attributes[.font] is NSFont else {
            session.reportFailure(L10n.fontUnavailable, near: snapshot)
            return .notApplied
        }
        let replacement = NSAttributedString(string: date, attributes: attributes)
        let outcome = await paste(replacement, over: plan.range, expecting: date, snapshot: snapshot)
        if outcome == .applied { session.report(L10n.dateInserted) }
        return outcome
    }

    /// Delete the backslash in `\#` and put the caret back after the marker.
    /// The trigger key only confirms the escape, so the line reads `#`; typing
    /// no space also keeps Notes' automatic lists from turning `-` into a list.
    private func removeEscape(plan: EditPlan, snapshot: EditorSnapshot) async -> EditOutcome {
        guard NotesApp.hasSameFocus(as: snapshot), snapshot.element.select(plan.range) else { return .notApplied }
        SyntheticKeyboard.deleteBackward(in: snapshot.pid)
        let caret = NSRange(location: snapshot.selection.location - plan.range.length, length: 0)
        guard await waitForSelection(NSRange(location: plan.range.location, length: 0), in: snapshot),
              NotesApp.hasSameFocus(as: snapshot), snapshot.element.select(caret),
              await waitForSelection(caret, in: snapshot) else {
            session.reportFailure(L10n.editorResponseUnconfirmed, near: snapshot)
            return .incomplete
        }
        session.report(L10n.markerKept)
        return .applied
    }

    /// `Locale.current` takes its language from NoteMark's own localizations;
    /// keep its region but use the user's first preferred language.
    private static var userLocale: Locale {
        var components = Locale.Components(locale: .current)
        if let preferred = Locale.preferredLanguages.first {
            // The region lives in the language components; carry it over.
            var language = Locale.Language.Components(identifier: preferred)
            language.region = components.languageComponents.region ?? Locale.current.region
            components.languageComponents = language
        }
        return Locale(components: components)
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
