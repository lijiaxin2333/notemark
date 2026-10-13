import AppKit
import ApplicationServices
import NoteMarkCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Permissions are granted in System Settings; poll until they arrive.
    private static let permissionPollInterval: TimeInterval = 2

    private let diagnostics = DiagnosticsReporter()
    private let preferences = Preferences()
    private lazy var engine = ConversionEngine(diagnostics: diagnostics, preferences: preferences)
    private let feedback = FeedbackToast()
    private var automaticConversion = AutomaticConversionPolicy()
    private var status = L10n.waitingForPermission
    private var statusMenu: StatusMenuController?
    private var setupWindow: SetupWindowController?
    private var settingsWindow: SettingsWindowController?
    private var permissionTimer: Timer?
    /// The event tap has run in this session, which shows that input can be
    /// read even when Input Monitoring is not separately reported as granted.
    private var tapHasWorked = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = makeMainMenu()
        statusMenu = StatusMenuController(actions: .init(
            toggleConversion: { [weak self] in self?.toggleConversion() },
            showsInsertedImagesSmall: { [weak self] in self?.preferences.showsInsertedImagesSmall ?? false },
            toggleInsertedImagesSmall: { [weak self] in self?.preferences.showsInsertedImagesSmall.toggle() },
            showSetup: { [weak self] in self?.showSetup() },
            showSettings: { [weak self] in self?.showSettings() },
            openNotes: { NotesApp.open() },
            quit: { NSApp.terminate(nil) }))
        engine.onStatus = { [weak self] status in self?.statusDidChange(status) }
        engine.onFailure = { [weak self] message, snapshot in
            self?.feedback.show(message, near: snapshot?.caretBounds())
        }
        preferences.onNotesSubstitutionsChange = { [weak self] in self?.engine.updateNotesSubstitutions() }
        engine.onStopped = { [weak self] in
            // macOS kept disabling the input listener. Show the guide without
            // taking keyboard focus from the note being typed.
            self?.showSetup(activating: false)
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: Self.permissionPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkAutomaticStart()
                self?.refresh()
            }
        }
        checkAutomaticStart()
        refresh()
        // The guide opens on first use, or when conversion cannot run.
        if !preferences.onboardingCompleted || !engine.running { showSetup() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        checkAutomaticStart()
        refresh()
    }

    /// Opening NoteMark again from Finder or Spotlight shows the guide, so it
    /// stays reachable when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showSetup() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
        permissionTimer?.invalidate()
        diagnostics.flush()
    }

    private func statusDidChange(_ newStatus: String) {
        status = newStatus
        setupWindow?.update(status: newStatus)
        refresh()
    }

    private func toggleConversion() {
        if engine.running {
            automaticConversion.pause()
            engine.stop()
            status = L10n.pausedManually
        } else {
            automaticConversion.resume()
            checkAutomaticStart()
        }
        setupWindow?.update(status: status)
        refresh()
    }

    private func checkAutomaticStart() {
        let permissions = ConversionPermissions(accessibility: AXIsProcessTrusted(),
                                                inputMonitoring: CGPreflightListenEventAccess())
        if !permissions.accessibility {
            if engine.running {
                engine.stop()
                showSetup() // Permission was revoked while running.
            }
            if automaticConversion.wantsConversion {
                status = L10n.waitingForPermission
                setupWindow?.update(status: status)
            }
        }
        if automaticConversion.shouldStart(permissions: permissions, running: engine.running), !engine.start() {
            showSetup()
        }
    }

    private var state: ConversionState {
        if engine.running { return .running }
        if !automaticConversion.wantsConversion { return .pausedByUser }
        return AXIsProcessTrusted() ? .unavailable : .needsPermission
    }

    private func refresh() {
        let running = engine.running
        let wantsConversion = automaticConversion.wantsConversion
        let accessibility = AXIsProcessTrusted()
        let inputMonitoring = CGPreflightListenEventAccess()
        if running { tapHasWorked = true }
        if running, accessibility, !preferences.onboardingCompleted { preferences.onboardingCompleted = true }
        diagnostics.recordState(running: running, status: status, accessibility: accessibility,
                                inputMonitoring: inputMonitoring)
        statusMenu?.update(state: state, status: status, wantsConversion: wantsConversion)
        setupWindow?.update(accessibility: accessibility, inputMonitoring: inputMonitoring || tapHasWorked,
                            toggleTitle: running ? L10n.pauseButton : wantsConversion ? L10n.retryButton : L10n.resumeButton)
    }

    /// NoteMark shows no menu bar, but key equivalents such as ⌘, and ⌘W still
    /// go through the main menu while one of its windows is active.
    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.settingsMenuItem, action: #selector(showSettingsFromMenu), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editMenu = NSMenu(title: L10n.editMenu)
        editMenu.addItem(withTitle: L10n.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.selectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let windowMenu = NSMenu(title: L10n.windowMenu)
        windowMenu.addItem(withTitle: L10n.closeWindow, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: L10n.minimizeWindow, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        let mainMenu = NSMenu()
        for submenu in [appMenu, editMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        return mainMenu
    }

    @objc private func showSettingsFromMenu() { showSettings() }

    private func showSetup(activating: Bool = true) {
        if setupWindow == nil { setupWindow = Self.makeSetupWindow(status: status, delegate: self) }
        refresh()
        setupWindow?.show(activating: activating)
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(preferences: preferences, showSetup: { [weak self] in self?.showSetup() })
        }
        settingsWindow?.show()
    }

    static func makeSetupWindow(status: String, delegate: AppDelegate?) -> SetupWindowController {
        SetupWindowController(status: status, actions: .init(
            toggleConversion: { [weak delegate] in delegate?.toggleConversion() },
            authorizeAccessibility: { [weak delegate] in delegate?.authorizeAccessibility() },
            openInputMonitoringSettings: { Self.openInputMonitoringSettings() },
            relaunch: { Self.relaunch() },
            showSettings: { [weak delegate] in delegate?.showSettings() },
            openNotes: { NotesApp.open() }))
    }

    private func authorizeAccessibility() {
        // The value of kAXTrustedCheckOptionPrompt, which Swift 6 imports as a
        // mutable global and so rejects as not concurrency-safe.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        checkAutomaticStart()
        refresh()
    }

    private static func openInputMonitoringSettings() {
        _ = CGRequestListenEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Input Monitoring granted while NoteMark runs takes effect after a restart.
    private static func relaunch() {
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        reopen.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        guard (try? reopen.run()) != nil else { return }
        NSApp.terminate(nil)
    }
}
