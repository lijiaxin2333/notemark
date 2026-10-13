import AppKit
import NoteMarkCore

/// When the user turns it on, shows images pasted or inserted into a note at
/// Notes' small size through View > Attachment View > Set All to Small, which
/// applies to every attachment in that note.
///
/// Only an attachment that appears soon after Command-V or a click in Notes
/// counts, such as a paste, a drop, or the Insert menu. Typing ends that
/// window, so text Notes adds while the user types is never taken for an image.
@MainActor final class InsertedImageShrinker {
    private static let armedTime = Duration.seconds(3)
    /// Lets a multi-image paste finish before the note is read.
    private static let settleTime = Duration.milliseconds(200)
    private static let insertedTextLimit = 4096
    private static let setAllToSmall = NotesMainMenu.Path(
        menu: .init(keys: ["HyV-fh-RgO.title", "H8h-7b-M4v.title"], english: "View"),
        submenu: .init(keys: ["8fu-Hq-o8e.title", "ERr-Z4-clH.title"], english: "Attachment View"),
        item: .init(keys: ["NOc-24-USv.title"], english: "Set All to Small"))

    private let preferences: Preferences
    /// The editor and its length before a paste or click that may insert an image.
    private struct Armed {
        let element: AXUIElement
        let count: Int
        let until: ContinuousClock.Instant
        /// Typing began: only a change Notes already reported is still checked.
        var typedSince = false
    }

    private var armed: Armed?
    private var pendingCheck: Task<Void, Never>?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    /// Command-V or a click in Notes: remember the note's length.
    func arm() {
        guard preferences.showsInsertedImagesSmall, let editor = Self.focusedEditor(), let count = editor.characterCount else {
            disarm()
            return
        }
        pendingCheck?.cancel()
        pendingCheck = nil
        armed = Armed(element: editor, count: count, until: ContinuousClock.now + Self.armedTime)
    }

    /// A key other than Command-V: an image pasted just before is still
    /// checked, but nothing Notes changes from now on counts.
    func typingStarted() {
        guard armed != nil else { return }
        if pendingCheck == nil { disarm() } else { armed?.typedSince = true }
    }

    func disarm() {
        armed = nil
        pendingCheck?.cancel()
        pendingCheck = nil
    }

    /// Notes' text or selection changed.
    func editorChanged() {
        guard let armed, !armed.typedSince else { return }
        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(for: Self.settleTime)
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    private func check() {
        pendingCheck = nil
        guard let armed else { return }
        guard ContinuousClock.now < armed.until, preferences.showsInsertedImagesSmall else { return disarm() }
        guard let editor = Self.focusedEditor(), editor.isSameElement(as: armed.element) else { return disarm() }
        guard let count = editor.characterCount, let caret = editor.selectedRange?.location,
              let range = AttachmentInsertion.insertedRange(from: armed.count, to: count, caret: caret,
                                                           limit: Self.insertedTextLimit) else {
            // Nothing inserted yet, such as after a click: keep waiting unless typing began.
            if armed.typedSince { disarm() }
            return
        }
        disarm()
        guard let inserted = editor.text(in: range), AttachmentInsertion.containsAttachment(inserted),
              let pid = NotesApp.frontmostProcess?.processIdentifier,
              let item = NotesMainMenu.item(Self.setAllToSmall, in: pid),
              item.number(kAXEnabledAttribute)?.boolValue == true else { return }
        _ = item.perform(kAXPressAction)
    }

    private static func focusedEditor() -> AXUIElement? {
        guard let process = NotesApp.frontmostProcess,
              let editor = NotesApp.applicationElement(process.processIdentifier).element(kAXFocusedUIElementAttribute)
        else { return nil }
        editor.setMessagingTimeout(NotesApp.messagingTimeout)
        return editor.role == kAXTextAreaRole ? editor : nil
    }
}
