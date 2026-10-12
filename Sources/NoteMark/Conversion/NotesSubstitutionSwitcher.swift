import AppKit
import NoteMarkCore

/// Keeps the Notes substitutions the user chose in Settings turned off, and
/// turns back on those NoteMark turned off when the user changes their mind.
/// It works whether or not conversion is paused, since it changes Notes itself.
@MainActor final class NotesSubstitutionSwitcher {
    /// Notes shows an item's new check mark about a second after it changes,
    /// so a read before then could undo a switch NoteMark just made.
    private static let settleTime = Duration.milliseconds(1500)

    private let preferences: Preferences
    private let menu = NotesSubstitutionMenu()
    /// The Notes process whose substitutions already match the settings.
    private var matchedProcess: pid_t?
    private var settlesAt: ContinuousClock.Instant?
    private var pendingCheck: Task<Void, Never>?
    nonisolated(unsafe) private var activationObserver: NSObjectProtocol?

    init(preferences: Preferences) {
        self.preferences = preferences
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if NotesApp.isFrontmost { self?.apply() }
            }
        }
    }

    deinit {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

    /// Check again once a newly focused editor's state shows in the menu.
    /// Notes does not save Smart Dashes, so a new editor can start with it on.
    func applySoon() {
        schedule(at: ContinuousClock.now + Self.settleTime)
    }

    /// Switch Notes' items once per Notes launch, or again when `force` is set
    /// after the settings changed. Items Notes does not offer yet, such as
    /// before a note has keyboard focus, are retried when Notes is next activated.
    func apply(force: Bool = false) {
        if let settlesAt, ContinuousClock.now < settlesAt {
            schedule(at: settlesAt)
            return
        }
        guard let pid = NotesApp.runningProcess?.processIdentifier, force || matchedProcess != pid else { return }
        var turnedOff = preferences.notesSubstitutionsTurnedOff
        var states: [NotesSubstitution: Bool?] = [:]
        for substitution in NotesSubstitution.allCases { states[substitution] = menu.isOn(substitution, in: pid) }
        let changes = NotesSubstitutionChanges(keepingOff: preferences.notesSubstitutionsOff,
                                               turnedOffByNoteMark: turnedOff, isOn: { states[$0] ?? nil })
        var complete = states.values.allSatisfy { $0 != nil }
        var switched = false
        for substitution in changes.turnOff {
            let result = menu.toggle(substitution, in: pid)
            // A press that timed out may still run, so remember it as NoteMark's.
            if result != .failed { turnedOff.insert(substitution); switched = true }
            if result != .switched { complete = false }
        }
        for substitution in changes.turnOn {
            let result = menu.toggle(substitution, in: pid)
            // Until a later check shows it on, NoteMark still owes turning it on.
            if result == .switched { turnedOff.remove(substitution) }
            if result != .failed { switched = true }
            if result != .switched { complete = false }
        }
        turnedOff.subtract(changes.forget)
        if turnedOff != preferences.notesSubstitutionsTurnedOff { preferences.notesSubstitutionsTurnedOff = turnedOff }
        if switched { settlesAt = ContinuousClock.now + Self.settleTime }
        matchedProcess = complete ? pid : nil
        // Confirm a press whose result is unknown once its effect can show.
        if switched, !complete { schedule(at: ContinuousClock.now + Self.settleTime) }
    }

    private func schedule(at instant: ContinuousClock.Instant) {
        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(until: instant, clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.apply(force: true)
        }
    }
}
