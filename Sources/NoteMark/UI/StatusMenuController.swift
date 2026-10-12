import AppKit

/// What the menu bar icon tells the user at a glance.
enum ConversionState {
    case running
    case pausedByUser
    /// Accessibility is not granted.
    case needsPermission
    /// Permissions look granted but the input listener is not running.
    case unavailable

    /// A short label for the menu and VoiceOver; details stay in the guide window.
    var label: String {
        switch self {
        case .running: return L10n.stateRunning
        case .pausedByUser: return L10n.statePaused
        case .needsPermission: return L10n.stateNeedsPermission
        case .unavailable: return L10n.stateUnavailable
        }
    }

    var symbolName: String {
        switch self {
        case .running: return "text.badge.checkmark"
        case .pausedByUser: return "pause.circle"
        case .needsPermission, .unavailable: return "exclamationmark.triangle"
        }
    }
}

/// The menu bar item and its menu.
@MainActor final class StatusMenuController: NSObject {
    struct Actions {
        var toggleConversion: () -> Void
        var showSetup: () -> Void
        var showSettings: () -> Void
        var openNotes: () -> Void
        var quit: () -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: L10n.enableConversion, action: #selector(toggleConversion), keyEquivalent: "")
    private let actions: Actions
    private var state: ConversionState?

    init(actions: Actions) {
        self.actions = actions
        super.init()
        statusItem.button?.toolTip = L10n.appMenuTitle
        let menu = NSMenu()
        let title = NSMenuItem(title: L10n.appMenuTitle, action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(item(toggleItem))
        menu.addItem(item(NSMenuItem(title: L10n.settingsMenuItem, action: #selector(showSettings), keyEquivalent: ",")))
        menu.addItem(item(NSMenuItem(title: L10n.helpAndPermissions, action: #selector(showSetup), keyEquivalent: "")))
        menu.addItem(item(NSMenuItem(title: L10n.openNotes, action: #selector(openNotes), keyEquivalent: "")))
        menu.addItem(.separator())
        menu.addItem(item(NSMenuItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q")))
        statusItem.menu = menu
        update(state: .unavailable, status: "", wantsConversion: true)
    }

    /// `status` is the latest detailed message, shown as the tooltip.
    func update(state: ConversionState, status: String, wantsConversion: Bool) {
        let running = state == .running
        toggleItem.title = running ? L10n.pauseConversion : wantsConversion ? L10n.retryInputConnection : L10n.resumeConversion
        toggleItem.state = running ? .on : .off
        statusLine.title = state.label
        statusItem.button?.toolTip = status.isEmpty ? L10n.appMenuTitle : "\(L10n.appMenuTitle)\n\(status)"
        guard state != self.state else { return }
        self.state = state
        let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: "NoteMark: \(state.label)")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = state == .pausedByUser
    }

    private func item(_ item: NSMenuItem) -> NSMenuItem {
        item.target = self
        return item
    }

    @objc private func toggleConversion() { actions.toggleConversion() }
    @objc private func showSetup() { actions.showSetup() }
    @objc private func showSettings() { actions.showSettings() }
    @objc private func openNotes() { actions.openNotes() }
    @objc private func quit() { actions.quit() }
}
