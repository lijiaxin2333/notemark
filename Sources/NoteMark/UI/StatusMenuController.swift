import AppKit

/// The menu bar item and its menu.
@MainActor final class StatusMenuController: NSObject {
    struct Actions {
        var toggleConversion: () -> Void
        var showSetup: () -> Void
        var openNotes: () -> Void
        var quit: () -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let toggleItem = NSMenuItem(title: L10n.enableConversion, action: #selector(toggleConversion), keyEquivalent: "")
    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "text.badge.checkmark", accessibilityDescription: "NoteMark")
        statusItem.button?.toolTip = L10n.appMenuTitle
        let menu = NSMenu()
        let title = NSMenuItem(title: L10n.appMenuTitle, action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        menu.addItem(item(toggleItem))
        menu.addItem(item(NSMenuItem(title: L10n.helpAndPermissions, action: #selector(showSetup), keyEquivalent: "")))
        menu.addItem(item(NSMenuItem(title: L10n.openNotes, action: #selector(openNotes), keyEquivalent: "")))
        menu.addItem(.separator())
        menu.addItem(item(NSMenuItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q")))
        statusItem.menu = menu
    }

    func update(running: Bool, wantsConversion: Bool) {
        toggleItem.title = running ? L10n.pauseConversion : wantsConversion ? L10n.retryInputConnection : L10n.resumeConversion
        toggleItem.state = running ? .on : .off
        statusItem.button?.appearsDisabled = !running
    }

    private func item(_ item: NSMenuItem) -> NSMenuItem {
        item.target = self
        return item
    }

    @objc private func toggleConversion() { actions.toggleConversion() }
    @objc private func showSetup() { actions.showSetup() }
    @objc private func openNotes() { actions.openNotes() }
    @objc private func quit() { actions.quit() }
}
