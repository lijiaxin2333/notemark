import Foundation
import NoteMarkCore
import Observation
import ServiceManagement

/// User settings, stored in the app's defaults.
@MainActor @Observable final class Preferences {
    private enum Key {
        static let rules = "ConversionRules"
        static let onboardingCompleted = "OnboardingCompleted"
        static let notesSubstitutionsOff = "NotesSubstitutionsOff"
        static let notesSubstitutionsTurnedOff = "NotesSubstitutionsTurnedOffByNoteMark"
        static let showsInsertedImagesSmall = "ShowsInsertedImagesSmall"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var rules: ConversionRules {
        didSet { save(rules) }
    }

    /// Set once conversion has run with the needed permissions.
    var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) }
    }

    /// Notes substitutions NoteMark keeps turned off.
    var notesSubstitutionsOff: Set<NotesSubstitution> {
        didSet {
            save(notesSubstitutionsOff, forKey: Key.notesSubstitutionsOff)
            onNotesSubstitutionsChange?()
        }
    }

    /// Those NoteMark itself turned off, so it can turn them back on.
    var notesSubstitutionsTurnedOff: Set<NotesSubstitution> {
        didSet { save(notesSubstitutionsTurnedOff, forKey: Key.notesSubstitutionsTurnedOff) }
    }

    /// Images pasted or inserted into a note are set to Notes' small size. Off by default.
    var showsInsertedImagesSmall: Bool {
        didSet { defaults.set(showsInsertedImagesSmall, forKey: Key.showsInsertedImagesSmall) }
    }

    /// Called after the user changes which Notes substitutions stay off.
    @ObservationIgnored var onNotesSubstitutionsChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rules = defaults.data(forKey: Key.rules).flatMap { try? JSONDecoder().decode(ConversionRules.self, from: $0) } ?? .default
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        notesSubstitutionsOff = Self.substitutions(defaults, Key.notesSubstitutionsOff) ?? NotesSubstitution.turnedOffByDefault
        notesSubstitutionsTurnedOff = Self.substitutions(defaults, Key.notesSubstitutionsTurnedOff) ?? []
        showsInsertedImagesSmall = defaults.bool(forKey: Key.showsInsertedImagesSmall)
    }

    private static func substitutions(_ defaults: UserDefaults, _ key: String) -> Set<NotesSubstitution>? {
        defaults.stringArray(forKey: key).map { Set($0.compactMap(NotesSubstitution.init(rawValue:))) }
    }

    private func save(_ substitutions: Set<NotesSubstitution>, forKey key: String) {
        defaults.set(substitutions.map(\.rawValue).sorted(), forKey: key)
    }

    private func save(_ rules: ConversionRules) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: Key.rules)
    }
}

/// Opening NoteMark at login, through the system's Login Items.
@MainActor enum LaunchAtLogin {
    enum State { case enabled, disabled, requiresApproval }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        default: return .disabled
        }
    }

    /// Returns false when the system refused the change.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            return false
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
