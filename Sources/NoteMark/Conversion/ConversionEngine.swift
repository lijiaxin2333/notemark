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
    var running: Bool { session.isRunning }

    private static let observedEvents: [CGEventType] = [
        .keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel
    ]

    private let session = ConversionSession()
    private var heldInput: HeldInput { session.heldInput }
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

    init(diagnostics: DiagnosticsReporter) {
        self.diagnostics = diagnostics
        tracker = ParagraphCancellationTracker(diagnostics: diagnostics)
        slash = SlashMenuController(session: session, diagnostics: diagnostics)
        editor = NotesEditApplier(session: session, tracker: tracker, diagnostics: diagnostics,
                                  keyboardLayout: keyboardLayout)
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
    }

    private func frontmostApplicationChanged() {
        if NotesApp.isFrontmost {
            observeNotesEditor()
        } else {
            slash.dismiss()
            tracker.reset()
        }
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
    }

    private func notesEditorChanged() {
        guard session.canEdit, NotesApp.isFrontmost else { return }
        bindFocusedEditor()
        if !ComposingProbe().isComposing { tracker.refresh() }
        // IME commits and pasted text need not contain a usable raw slash key event.
        // Observe the editor so committed Chinese search resumes without another key.
        guard !slash.isSuppressed else { return }
        slash.scheduleUpdate()
    }

    private func tapWasDisabled() {
        switch tapHealth.recordDisable(at: ProcessInfo.processInfo.systemUptime) {
        case .reenable:
            tap.enable()
        case .stop:
            stop()
            onStatus?(L10n.inputListeningPaused)
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
            if slash.isTracking, composing.isComposing {
                slash.scheduleUpdate()
                return .pass
            }
            if !slash.panelContainsMouse() {
                typing.clear()
                slash.dismiss()
            }
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
        if running, slash.isTracking || slash.isPanelVisible, composing.isComposing {
            // Before modifiers, repeat filtering, and menu navigation: every
            // candidate key (including Shift/Option and Esc) belongs to the IME.
            slash.noteSearchInput(isDeletion: key.isDeleteBackward)
            slash.scheduleUpdate()
            return .pass
        }
        if running, let disposition = handleParagraphCancellation(key, event, composing) { return disposition }
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
        if SlashQuery.containsSlash(typed) || key.typesSlash {
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
        if slash.isSuppressed, typing.containsSlashCommand {
            typing.reset(after: trigger)
            if trigger == .enter { slash.isSuppressed = false }
            return .pass
        }
        slash.dismiss()
        // Return reads the editor only after typed Markdown evidence. Space always
        // does: IMEs may commit brackets without matching Unicode in the CGEvent.
        let looksLikeMarkdown = typing.looksLikeMarkdown
        guard trigger == .space || looksLikeMarkdown else {
            typing.reset(after: trigger)
            return .pass
        }
        typing.clear()
        guard !composing.isComposing, let snapshot = EditorSnapshot.capture() else {
            if looksLikeMarkdown { onStatus?(L10n.snapshotUnavailableOrComposing) }
            return .pass
        }
        // The editor's text is authoritative; ordinary prose spaces pass through.
        if !looksLikeMarkdown, Self.plan(for: snapshot, trigger: trigger) == nil { return .pass }
        beginTriggeredConversion(trigger, snapshot: snapshot, original: event.copy())
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

    private func beginTriggeredConversion(_ trigger: Trigger, snapshot: EditorSnapshot, original: CGEvent?) {
        heldInput.begin(for: snapshot.pid)
        onStatus?(L10n.markdownDetected)
        Task { [weak self] in
            guard let self else { return }
            var diagnostic = L10n.editorSnapshotUnavailable
            // The event tap sees Space before Notes necessarily handles the preceding ']'.
            // Keep Space and later input held while Notes acknowledges that input.
            let acknowledged: (snapshot: EditorSnapshot, plan: EditPlan)? = await InputAcknowledgement.wait(isValid: {
                self.running && NotesApp.hasSameFocus(as: snapshot) && !InputMethodMonitor.isComposing()
            }, read: {
                guard let current = EditorSnapshot.capture(), current.element.isSameElement(as: snapshot.element) else { return nil }
                diagnostic = Self.ruleDiagnostic(for: current)
                return Self.plan(for: current, trigger: trigger).map { (current, $0) }
            })
            var outcome = EditOutcome.notApplied
            if let acknowledged {
                outcome = await editor.apply(acknowledged.plan, to: acknowledged.snapshot)
            } else {
                onStatus?(L10n.noRuleMatched(diagnostic))
            }
            if outcome == .notApplied, let original, NotesApp.hasSameFocus(as: snapshot) {
                // No edit occurred: replay at the current caret without restoring a stale selection.
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
            if outcome == .notApplied, let original, NotesApp.hasSameFocus(as: snapshot),
               snapshot.element.select(snapshot.selection) {
                SyntheticKeyboard.deliver(original, to: snapshot.pid)
            }
            heldInput.release()
        }
    }

    private static func plan(for snapshot: EditorSnapshot, trigger: Trigger) -> EditPlan? {
        MarkdownRule.plan(beforeCaret: snapshot.before, windowStart: snapshot.windowStart, trigger: trigger,
                          isMonospaced: snapshot.isMonospaced, afterCaret: snapshot.after)
    }

    /// Shown when Space or Return matched no rule after Notes caught up.
    private static func ruleDiagnostic(for snapshot: EditorSnapshot) -> String {
        let line = snapshot.caretLine
        let checklistMarkers = MarkdownRule.checklistMarkers
        let attachment = MarkdownRule.attachmentCharacter
        return L10n.ruleDiagnostic(
            prefixLength: String((line.text as NSString).length),
            checklistMarker: checklistMarkers.contains(line.text),
            trimmedChecklistMarker: checklistMarkers.contains(line.text.trimmingCharacters(in: .whitespaces)),
            monospaced: snapshot.isMonospaced,
            lineStartKnown: line.startIsKnown,
            rightBoundaryKnown: snapshot.rightBoundaryKnown,
            rightLength: snapshot.sampledTail.map { String(($0 as NSString).length) } ?? L10n.unknownLength,
            containsImage: line.text.contains(attachment) || snapshot.sampledTail?.contains(attachment) == true)
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
