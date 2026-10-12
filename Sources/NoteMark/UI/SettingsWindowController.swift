import AppKit
import NoteMarkCore
import SwiftUI

/// The login item's state, re-read whenever Settings is shown: the user may
/// change it in System Settings while the window is closed.
@MainActor @Observable private final class LoginItemStatus {
    var state = LaunchAtLogin.state
    var changeFailed = false

    func refresh() {
        state = LaunchAtLogin.state
        changeFailed = false
    }

    func setEnabled(_ enabled: Bool) {
        changeFailed = !LaunchAtLogin.setEnabled(enabled)
        state = LaunchAtLogin.state
    }
}

/// The Settings window: launch at login and which conversions run.
@MainActor final class SettingsWindowController {
    let window: NSWindow
    private let loginItem = LoginItemStatus()

    init(preferences: Preferences, showSetup: @escaping () -> Void) {
        let view = SettingsView(preferences: preferences, loginItem: loginItem, showSetup: showSetup)
        window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = L10n.settingsTitle
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        loginItem.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Render the window offscreen for layout review.
    func renderPreview(to path: String) throws {
        window.appearance = NSAppearance(named: .aqua)
        guard let view = window.contentView else { throw CocoaError(.fileWriteUnknown) }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileWriteUnknown) }
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance { view.cacheDisplay(in: view.bounds, to: bitmap) }
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: URL(fileURLWithPath: path))
    }
}

private struct SettingsView: View {
    @Bindable var preferences: Preferences
    let loginItem: LoginItemStatus
    let showSetup: () -> Void

    var body: some View {
        Form {
            Section(L10n.settingsGeneral) {
                Toggle(L10n.settingsLaunchAtLogin, isOn: Binding(
                    get: { loginItem.state != .disabled },
                    set: { loginItem.setEnabled($0) }))
                if loginItem.state == .requiresApproval || loginItem.changeFailed {
                    HStack {
                        Text(L10n.settingsLoginItemNeedsApproval).foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.settingsOpenLoginItems) { LaunchAtLogin.openSystemSettings() }
                    }
                }
            }
            Section(L10n.settingsConversions) {
                Toggle(L10n.settingsHeadings, isOn: $preferences.rules.headings)
                Toggle(L10n.settingsLists, isOn: $preferences.rules.lists)
                Picker(L10n.settingsDashList, selection: $preferences.rules.dashMakesDashedList) {
                    Text(L10n.settingsDashBulleted).tag(false)
                    Text(L10n.settingsDashDashed).tag(true)
                }
                .disabled(!preferences.rules.lists)
                Toggle(L10n.settingsChecklists, isOn: $preferences.rules.checklists)
                Toggle(L10n.settingsQuotes, isOn: $preferences.rules.quotes)
                Toggle(L10n.settingsCodeBlocks, isOn: $preferences.rules.codeBlocks)
                Toggle(L10n.settingsDividers, isOn: $preferences.rules.dividers)
                    .disabled(!ConversionSession.notesHasDividers)
                if !ConversionSession.notesHasDividers {
                    Text(L10n.settingsDividersUnavailable).font(.caption).foregroundStyle(.secondary)
                }
                Toggle(L10n.settingsInlineStyles, isOn: $preferences.rules.inlineStyles)
                Toggle(L10n.settingsLinks, isOn: $preferences.rules.links)
                Toggle(L10n.settingsSlashCommands, isOn: $preferences.rules.slashCommands)
                Toggle(L10n.settingsFullWidthMarkers, isOn: $preferences.rules.fullWidthMarkers)
            }
            Section {
                Toggle(L10n.settingsTurnOffSmartDashes, isOn: keepsOff(.smartDashes))
                Toggle(L10n.settingsTurnOffSmartLists, isOn: keepsOff(.smartLists))
                Toggle(L10n.settingsTurnOffSmartTags, isOn: keepsOff(.smartTags))
            } header: {
                Text(L10n.settingsNotesSubstitutions)
            } footer: {
                Text(L10n.settingsNotesSubstitutionsNote).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                HStack {
                    Text(L10n.settingsCancellationNote).foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.helpAndPermissions, action: showSetup)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
    }

    private func keepsOff(_ substitution: NotesSubstitution) -> Binding<Bool> {
        Binding(get: { preferences.notesSubstitutionsOff.contains(substitution) },
                set: { off in
                    if off { preferences.notesSubstitutionsOff.insert(substitution) } else { preferences.notesSubstitutionsOff.remove(substitution) }
                })
    }
}
