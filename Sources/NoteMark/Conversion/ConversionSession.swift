import Foundation
import NoteMarkCore

/// State the conversion engine shares with its collaborators, passed at
/// initialization so the wiring is checked by the compiler.
@MainActor final class ConversionSession {
    /// The event tap is installed and conversion is enabled.
    var isRunning = false
    /// Input held while Notes acknowledges an edit.
    let heldInput = HeldInput()
    let preferences: Preferences
    var onStatus: ((String) -> Void)?
    /// A conversion failed; show the message next to the caret of `snapshot`.
    var onFailure: ((String, EditorSnapshot?) -> Void)?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    /// Notes can be read and edited: conversion is on and no edit is in progress.
    var canEdit: Bool { isRunning && !heldInput.isHolding }

    /// Notes has Edit > Insert Divider Line from macOS 27.
    static let notesHasDividers = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27

    /// The user's rules, limited to what this version of Notes supports.
    var rules: ConversionRules {
        var rules = preferences.rules
        if !Self.notesHasDividers { rules.dividers = false }
        return rules
    }

    /// An edit can finish after conversion stopped; the reason it stopped
    /// stays the status then.
    func report(_ status: String) {
        guard isRunning else { return }
        onStatus?(status)
    }

    /// Report a conversion that did not happen as the user expected.
    func reportFailure(_ status: String, near snapshot: EditorSnapshot?) {
        report(status)
        onFailure?(status, snapshot)
    }
}
