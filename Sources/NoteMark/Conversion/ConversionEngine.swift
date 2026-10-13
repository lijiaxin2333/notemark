import AppKit
import ApplicationServices
import NoteMarkCore

/// Watches keyboard and mouse input in Apple Notes and turns typed Markdown
/// into native Notes formatting.
///
/// The event tap callback decides synchronously whether to swallow an event.
/// It reads the editor only for keys that can complete or cancel Markdown,
/// and the edit itself runs afterwards while later input is held.
@MainActor final class ConversionEngine {
    var onStatus: ((String) -> Void)? {
        get { session.onStatus }
        set { session.onStatus = newValue }
    }
    var onFailure: ((String, EditorSnapshot?) -> Void)? {
        get { session.onFailure }
        set { session.onFailure = newValue }
    }
    var running: Bool { session.isRunning }
    /// Input listening stopped because macOS kept disabling the event tap.
    var onStopped: (() -> Void)?

    private static let observedEvents: [CGEventType] = [
        .keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel
    ]

    /// A paragraph identified by its editor and a document offset inside it:
    /// its start, or where the conversion happened when the start is beyond
    /// the text window.
    private struct ParagraphReference {
        let element: AXUIElement
        let anchor: Int

        /// Whether the caret is still in the paragraph: no line break lies
        /// between the anchor and the caret.
        func contains(_ snapshot: EditorSnapshot) -> Bool {
            let caret = snapshot.selection.location
            guard snapshot.element.isSameElement(as: element), anchor >= snapshot.windowStart, anchor <= caret else { return false }
            let between = (snapshot.before as NSString).substring(from: anchor - snapshot.windowStart)
            return between.rangeOfCharacter(from: .newlines) == nil
        }
    }

    private let session: ConversionSession
    private var heldInput: HeldInput { session.heldInput }
    /// The paragraph of the last conversion, until the user types elsewhere.
    private var lastConversion: ParagraphReference?
    /// Undoing a conversion keeps its paragraph's markers literal until
    /// Return, a click, a deletion, or the caret leaves it. Until more is
    /// typed, inline styles stay literal too.
    private var undoneParagraph: (paragraph: ParagraphReference, typedSince: Bool)?
    /// Escaping a marker keeps later markers in its paragraph literal until
    /// Return, a click, a deletion, or the caret leaves it.
    private var escapedParagraph: (paragraph: ParagraphReference, marker: EscapedMarker)?

    /// What a Space or Return knows beyond the editor's text.
    private struct TriggerContext {
        /// The paragraph's marker was escaped: only inline styles convert.
        var escaped: EscapedMarker?
        /// A conversion in this paragraph was undone: only inline styles convert.
        var undone = false
        /// Typed on the caret line, before text substitution such as Smart Dashes.
        var typedLine: String?
    }
    private let tap = EventTap()
    private var tapHealth = EventTapHealth()
    private let editorObserver = NotesEditorObserver()
    private var workspaceObserver: NSObjectProtocol?
    private var typing = TypingHistory()
    private let keyboardLayout = KeyboardLayout()
    private let diagnostics: DiagnosticsReporter
    private let tracker: ParagraphCancellationTracker
    private let slash: SlashMenuController
    private let editor: NotesEditApplier
    private let substitutions: NotesSubstitutionSwitcher
    private let imageShrinker: InsertedImageShrinker

    init(diagnostics: DiagnosticsReporter, preferences: Preferences) {
        session = ConversionSession(preferences: preferences)
        self.diagnostics = diagnostics
        tracker = ParagraphCancellationTracker(diagnostics: diagnostics)
        slash = SlashMenuController(session: session, diagnostics: diagnostics)
        editor = NotesEditApplier(session: session, tracker: tracker, diagnostics: diagnostics,
                                  keyboardLayout: keyboardLayout)
        substitutions = NotesSubstitutionSwitcher(preferences: preferences)
        imageShrinker = InsertedImageShrinker(preferences: preferences)
        slash.onChoose = { [weak self] command in
            self?.executeSlash(command, original: nil, composing: ComposingProbe())
        }
        editorObserver.onChange = { [weak self] in self?.notesEditorChanged() }
    }

    // MARK: Lifecycle

    @discardableResult
    func start() -> Bool {
        stop()
        guard AXIsProcessTrusted() else {
            onStatus?(L10n.accessibilityRequired)
            return false
        }
        guard tap.install(events: Self.observedEvents, handler: { [weak self] type, event in
            self?.handle(type, event) ?? .pass
        }) else {
            onStatus?(L10n.inputListeningUnavailable)
            return false
        }
        session.isRunning = true
        tapHealth.reset()
        typing.clear()
        observeNotesEditor()
        substitutions.apply()
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.frontmostApplicationChanged() }
        }
        onStatus?(L10n.conversionEnabled)
        return true
    }

    /// An edit in progress completes and releases its held input after stopping.
    func stop() {
        tracker.reset()
        slash.dismiss()
        editorObserver.stop()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        workspaceObserver = nil
        tap.remove()
        session.isRunning = false
        imageShrinker.disarm()
        lastConversion = nil
        undoneParagraph = nil
        endEscapedParagraph()
    }

    /// Switching apps leaves the caret where it was, so an undone or escaped
    /// paragraph stays literal; the next trigger checks the caret is still there.
    private func frontmostApplicationChanged() {
        lastConversion = nil
        if NotesApp.isFrontmost {
            observeNotesEditor()
        } else {
            slash.dismiss()
            tracker.reset()
        }
    }

    /// The user changed which Notes substitutions stay off.
    func updateNotesSubstitutions() {
        substitutions.apply(force: true)
    }

    private func observeNotesEditor() {
        guard let process = NotesApp.runningProcess, editorObserver.observe(process) else { return }
        bindFocusedEditor()
    }

    /// A different focused element starts with no slash or paragraph state.
    private func bindFocusedEditor() {
        guard editorObserver.bindFocusedEditor() else { return }
        slash.dismiss()
        tracker.reset()
        slash.isSuppressed = false
        lastConversion = nil
        undoneParagraph = nil
        escapedParagraph = nil
        substitutions.applySoon()
    }

    private func notesEditorChanged() {
        guard session.canEdit, NotesApp.isFrontmost else { return }
        bindFocusedEditor()
        if !ComposingProbe().isComposing { tracker.refresh() }
        imageShrinker.editorChanged()
        // IME commits and pasted text need not contain a usable raw slash key event.
        // Observe the editor so committed Chinese search resumes without another key.
        guard session.rules.slashCommands, !slash.isSuppressed else { return }
        slash.scheduleUpdate()
    }

    private func tapWasDisabled() {
        switch tapHealth.recordDisable(at: ProcessInfo.processInfo.systemUptime) {
        case .reenable:
            tap.enable()
        case .stop:
            stop()
            onStatus?(L10n.inputListeningPaused)
            onStopped?()
        }
    }

    // MARK: Event routing

    private func handle(_ type: CGEventType, _ event: CGEvent) -> EventDisposition {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            tapWasDisabled()
            return .pass
        }
        switch event.syntheticTag {
        case .synthetic: return .pass
        case .requeued, nil: break // Held input posted again is processed like new input.
        }
        guard NotesApp.isFrontmost else {
            tracker.reset()
            typing.clear()
            slash.dismiss()
            lastConversion = nil
            if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) {
                // A click that brings Notes forward may also move its caret.
                undoneParagraph = nil
                endEscapedParagraph()
            }
            return .pass
        }
        if heldInput.isHolding {
            // Scrolling cannot move the caret; other input waits for the edit.
            guard type != .scrollWheel else { return .pass }
            heldInput.hold(event)
            return .swallow
        }
        let composing = ComposingProbe()
        switch type {
        case .scrollWheel:
            if slash.isTracking, composing.isComposing {
                slash.scheduleUpdate()
            } else {
                slash.dismiss()
            }
            return .pass
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            tracker.reset()
            lastConversion = nil
            undoneParagraph = nil
            endEscapedParagraph()
            if slash.isTracking, composing.isComposing {
                slash.scheduleUpdate()
                return .pass
            }
            if !slash.panelContainsMouse() {
                typing.clear()
                slash.dismiss()
            }
            return .pass
        case .leftMouseUp:
            // A drop, the Insert menu, or Paste in a menu may insert an image next.
            imageShrinker.arm()
            return .pass
        case .keyDown:
            return handleKeyDown(keyPress(from: event), event, composing)
        default:
            return .pass
        }
    }

    private func keyPress(from event: CGEvent) -> KeyPress {
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = KeyModifiers(event.flags)
        return KeyPress(code: code, modifiers: modifiers,
                        isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                        layoutCharacter: keyboardLayout.character(for: code, shift: modifiers.contains(.shift)))
    }

    /// Steps run in a fixed order; each either decides the event or falls through.
    private func handleKeyDown(_ key: KeyPress, _ event: CGEvent, _ composing: ComposingProbe) -> EventDisposition {
        if key.isPaste { imageShrinker.arm() } else { imageShrinker.typingStarted() }
        if running, slash.isTracking || slash.isPanelVisible, composing.isComposing {
            // Before modifiers, repeat filtering, and menu navigation: every
            // candidate key (including Shift/Option and Esc) belongs to the IME.
            slash.noteSearchInput(isDeletion: key.isDeleteBackward)
            slash.scheduleUpdate()
            return .pass
        }
        if running, let disposition = handleParagraphCancellation(key, event, composing) { return disposition }
        if key.isDeletion {
            // Deleting may remove the kept marker; a marker typed again converts.
            undoneParagraph = nil
            endEscapedParagraph()
        }
        if key.isUndo, let lastConversion {
            // The user took the conversion back: keep that paragraph literal.
            undoneParagraph = (lastConversion, typedSince: false)
        } else if key.hasCommandControlOrOption, !key.isRedo {
            // Another shortcut may edit the note; a later Command-Z undoes that edit instead.
            lastConversion = nil
        }
        if key.hasCommandControlOrOption {
            slash.dismiss()
            typing.clear()
            return .pass
        }
        guard running, !key.isAutorepeat || (slash.isPanelVisible && key.isVerticalArrow) else { return .pass }
        if slash.isPanelVisible, !key.modifiers.contains(.shift),
           let disposition = handleSlashPanelKey(key, event, composing) { return disposition }
        if key.isSpace, slash.isTracking, !slash.isSuppressed {
            // Space is search input, not a Markdown delimiter while the slash
            // session is active. Keep tracking even before the panel is first shown.
            slash.noteSearchInput()
            slash.scheduleUpdate()
            return .pass
        }
        guard let trigger = key.trigger else { return handleTyping(key, event) }
        guard !key.modifiers.contains(.shift) else {
            typing.clear()
            lastConversion = nil
            return .pass
        }
        return handleTrigger(trigger, event, composing)
    }

    /// Restore Body when a cancellation key reaches an empty tracked paragraph,
    /// and end tracking on keys that leave it. Nil lets routing continue.
    private func handleParagraphCancellation(_ key: KeyPress, _ event: CGEvent,
                                             _ composing: ComposingProbe) -> EventDisposition? {
        if key.isCancellationKey, !composing.isComposing {
            // Read the current line before cancellation too: a rapid Return
            // and Backspace can arrive before the AX observer follows it.
            tracker.refresh()
            diagnostics.recordCancellationAttempt(tracker.session == nil ? "untracked" : "not-empty-or-unavailable")
        }
        if key.isCancellationKey, !slash.isPanelVisible, let session = tracker.session, !composing.isComposing,
           NotesApp.hasSameFocus(as: session.snapshot), let snapshot = EditorSnapshot.capture(),
           let plan = tracker.plan(for: session.cancellation, in: snapshot, intent: key.cancellationIntent) {
            diagnostics.recordCancellationAttempt("scheduled")
            tracker.reset()
            typing.clear()
            slash.dismiss()
            beginEdit(plan, snapshot: snapshot, original: event.copy(),
                      cancelling: session.cancellation, intent: key.cancellationIntent)
            return .swallow
        }
        // Keep the session through text input and native deletions. Undo and
        // formatting shortcuts may change the style independently of NoteMark.
        let endsParagraph = key.isReturn && tracker.session?.cancellation.style != .monostyled
        if endsParagraph || key.isEscape ||
            (!key.isControlDeletion && !key.isControlNavigation && key.hasCommandControlOrOption) {
            tracker.reset()
        }
        return nil
    }

    private func handleSlashPanelKey(_ key: KeyPress, _ event: CGEvent, _ composing: ComposingProbe) -> EventDisposition? {
        if key.isVerticalArrow {
            return slash.moveSelection(by: key.isUpArrow ? -1 : 1, composing: composing) ? .swallow : .pass
        }
        if key.isEscape {
            slash.dismiss()
            slash.isSuppressed = true
            return .swallow
        }
        if key.isReturn || key.isTab {
            if let selected = slash.selectedCommand,
               executeSlash(selected, original: event.copy(), composing: composing) { return .swallow }
            slash.dismiss()
        }
        return nil
    }

    /// Keys other than Space and Return: follow typed text and slash input.
    private func handleTyping(_ key: KeyPress, _ event: CGEvent) -> EventDisposition {
        // Typing or moving the caret ends the conversion just made; after an
        // undo, inline styles typed later in the paragraph convert again.
        lastConversion = nil
        undoneParagraph?.typedSince = true
        if key.isDeleteBackward {
            typing.deleteBackward()
            if slash.isTracking {
                slash.noteSearchInput(isDeletion: true)
                slash.scheduleUpdate()
            }
            return .pass
        }
        if key.resetsTypingHistory {
            typing.clear()
            slash.dismiss()
            return .pass
        }
        let typed = event.typedText
        typing.append(typed)
        if session.rules.slashCommands, SlashQuery.containsSlash(typed) || key.typesSlash {
            bindFocusedEditor()
            slash.begin()
        } else if slash.isTracking {
            slash.noteSearchInput()
        }
        if slash.isTracking, !slash.isSuppressed { slash.scheduleUpdate() }
        return .pass
    }

    /// Space or Return may complete a Markdown marker.
    private func handleTrigger(_ trigger: Trigger, _ event: CGEvent, _ composing: ComposingProbe) -> EventDisposition {
        lastConversion = nil
        // Return leaves the paragraph, so an undone or escaped paragraph applies to this key at most.
        // A Return that commits IME text stays in the paragraph.
        let undoneParagraph = self.undoneParagraph
        let escapedParagraph = self.escapedParagraph
        let leavesParagraph = trigger == .enter && !composing.isComposing
        if leavesParagraph {
            self.undoneParagraph = nil
            endEscapedParagraph()
        }
        if slash.isSuppressed, typing.containsSlashCommand {
            typing.reset(after: trigger)
            if leavesParagraph { slash.isSuppressed = false }
            return .pass
        }
        slash.dismiss()
        // Return reads the editor only after typed Markdown evidence. Space always
        // does: IMEs may commit brackets without matching Unicode in the CGEvent.
        let looksLikeMarkdown = typing.looksLikeMarkdown(rules: session.rules)
        guard trigger == .space || looksLikeMarkdown else {
            typing.reset(after: trigger)
            return .pass
        }
        let typedLine = typing.currentLine
        typing.clear()
        guard !composing.isComposing, let snapshot = EditorSnapshot.capture() else {
            if looksLikeMarkdown { onStatus?(L10n.snapshotUnavailableOrComposing) }
            return .pass
        }
        var undone = false
        if let undoneParagraph {
            if !undoneParagraph.paragraph.contains(snapshot) {
                self.undoneParagraph = nil
            } else if !undoneParagraph.typedSince {
                return .pass // Right after Command-Z: keep everything as typed.
            } else {
                undone = true
            }
        }
        var escaped: EscapedMarker?
        if let escapedParagraph {
            if escapedParagraph.paragraph.contains(snapshot) { escaped = escapedParagraph.marker } else { endEscapedParagraph() }
        }
        // The editor's text is authoritative; ordinary prose spaces pass through.
        let context = TriggerContext(escaped: escaped, undone: undone, typedLine: typedLine)
        if !looksLikeMarkdown, plan(for: snapshot, trigger: trigger, context: context) == nil { return .pass }
        beginTriggeredConversion(trigger, snapshot: snapshot, original: event.copy(), context: context)
        return .swallow
    }

    // MARK: Editing

    @discardableResult
    private func executeSlash(_ requested: SlashCommand, original: CGEvent?, composing: ComposingProbe) -> Bool {
        guard let execution = slash.prepareExecution(of: requested, composing: composing) else { return false }
        typing.clear()
        beginEdit(execution.plan, snapshot: execution.snapshot, original: original)
        return true
    }

    private func beginTriggeredConversion(_ trigger: Trigger, snapshot: EditorSnapshot, original: CGEvent?,
                                          context: TriggerContext) {
        heldInput.begin(for: snapshot.pid)
        onStatus?(L10n.markdownDetected)
        Task { [weak self] in
            guard let self else { return }
            var diagnostic = "editorSnapshotUnavailable"
            // The event tap sees Space before Notes necessarily handles the preceding ']'.
            // Keep Space and later input held while Notes acknowledges that input.
            let acknowledged: (snapshot: EditorSnapshot, plan: EditPlan)? = await InputAcknowledgement.wait(isValid: {
                self.running && NotesApp.hasSameFocus(as: snapshot) && !InputMethodMonitor.isComposing()
            }, read: {
                guard let current = EditorSnapshot.capture(), current.element.isSameElement(as: snapshot.element) else { return nil }
                diagnostic = Self.ruleDiagnostic(for: current)
                return self.plan(for: current, trigger: trigger, context: context).map { (current, $0) }
            })
            var outcome = EditOutcome.notApplied
            if var acknowledged {
                outcome = await editor.apply(acknowledged.plan, to: acknowledged.snapshot)
                // Smart Dashes may have replaced `---` with `—` as the edit began: plan once more.
                if outcome == .notApplied, acknowledged.plan.conversion == .divider, NotesApp.hasSameFocus(as: snapshot),
                   let current = EditorSnapshot.capture(), current.element.isSameElement(as: snapshot.element),
                   let plan = self.plan(for: current, trigger: trigger, context: context), plan != acknowledged.plan {
                    acknowledged = (current, plan)
                    outcome = await editor.apply(plan, to: current)
                }
                rememberConversion(outcome, of: acknowledged.plan, in: acknowledged.snapshot)
            } else {
                diagnostics.recordUnmatchedRule(diagnostic)
                if running { onStatus?(L10n.conversionEnabled) } // Nothing to convert: back to the idle status.
            }
            if outcome.deliversKey, let original, NotesApp.hasSameFocus(as: snapshot) {
                // Replay at the current caret without restoring a stale selection.
                SyntheticKeyboard.deliver(original, to: snapshot.pid)
            }
            heldInput.release()
        }
    }

    /// Menu traversal and editing run outside the event tap callback.
    private func beginEdit(_ plan: EditPlan, snapshot: EditorSnapshot, original: CGEvent?,
                           cancelling cancellation: EmptyParagraphCancellation? = nil,
                           intent: CodeBlockCancellationIntent = .escape) {
        heldInput.begin(for: snapshot.pid)
        Task { [weak self] in
            guard let self else { return }
            if cancellation != nil, NotesApp.hasSameFocus(as: snapshot) {
                diagnostics.recordCancellationTrace(ParagraphInspection(snapshot).cancellationTrace(phase: "before-\(intent)"))
            }
            let outcome = await editor.apply(plan, to: snapshot, cancelling: cancellation, intent: intent)
            if cancellation != nil, outcome == .notApplied {
                diagnostics.recordCancellationAttempt("revalidation-or-command-failed")
            }
            if cancellation == nil { rememberConversion(outcome, of: plan, in: snapshot) }
            if outcome.deliversKey, let original, NotesApp.hasSameFocus(as: snapshot),
               snapshot.element.select(snapshot.selection) {
                SyntheticKeyboard.deliver(original, to: snapshot.pid)
            }
            heldInput.release()
        }
    }

    /// Leave an escaped paragraph. A new `/` reopens the menu anyway; this also
    /// lets edits that do not type a slash key, such as IME commits, open it.
    private func endEscapedParagraph() {
        if let escapedParagraph, SlashQuery.startsWithSlash(escapedParagraph.marker.marker) { slash.isSuppressed = false }
        escapedParagraph = nil
    }

    private func plan(for snapshot: EditorSnapshot, trigger: Trigger, context: TriggerContext) -> EditPlan? {
        guard let plan = MarkdownRule.plan(beforeCaret: snapshot.before, windowStart: snapshot.windowStart, trigger: trigger,
                                           isMonospaced: snapshot.isMonospaced, afterCaret: snapshot.after,
                                           rules: session.rules, typedLine: context.typedLine) else { return nil }
        // Removing the user's own backslash adds no format, so it still runs.
        if context.undone, !plan.conversion.isInline, plan.conversion != .unescape { return nil }
        if let escaped = context.escaped, escaped.keepsLiteral(plan, line: snapshot.caretLine.text) { return nil }
        return plan
    }

    /// Remember a completed conversion so an immediate Command-Z can keep its
    /// paragraph literal, and an escaped marker so its paragraph stays literal.
    private func rememberConversion(_ outcome: EditOutcome, of plan: EditPlan, in snapshot: EditorSnapshot) {
        let line = snapshot.caretLine
        if plan.conversion == .unescape, outcome == .applied, let marker = EscapedMarker(escaping: line.text) {
            escapedParagraph = (ParagraphReference(element: snapshot.element, anchor: plan.range.location), marker)
            // `\/date` keeps `/date` as text, as Esc does for the menu.
            if SlashQuery.startsWithSlash(marker.marker) {
                slash.dismiss()
                slash.isSuppressed = true
            }
        }
        guard outcome == .applied || outcome == .incomplete else { return }
        lastConversion = ParagraphReference(element: snapshot.element,
                                            anchor: line.startIsKnown ? line.documentStart : plan.range.location)
    }

    /// Recorded in diagnostics when a held Space or Return matched no rule.
    /// Lengths and flags only, never note text.
    private static func ruleDiagnostic(for snapshot: EditorSnapshot) -> String {
        let line = snapshot.caretLine
        let checklistMarkers = MarkdownRule.checklistMarkers
        let attachment = MarkdownRule.attachmentCharacter
        let fields: [(String, String)] = [
            ("prefixLength", String((line.text as NSString).length)),
            ("checklistMarker", String(checklistMarkers.contains(line.text))),
            ("trimmedChecklistMarker", String(checklistMarkers.contains(line.text.trimmingCharacters(in: .whitespaces)))),
            ("monospaced", String(snapshot.isMonospaced)),
            ("lineStartKnown", String(line.startIsKnown)),
            ("rightBoundaryKnown", String(snapshot.rightBoundaryKnown)),
            ("rightLength", snapshot.sampledTail.map { String(($0 as NSString).length) } ?? "unknown"),
            ("containsImage", String(line.text.contains(attachment) || snapshot.sampledTail?.contains(attachment) == true))
        ]
        return fields.map { "\($0.0)=\($0.1)" }.joined(separator: ", ")
    }
}

private extension KeyModifiers {
    init(_ flags: CGEventFlags) {
        self = []
        if flags.contains(.maskShift) { insert(.shift) }
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskCommand) { insert(.command) }
    }
}
