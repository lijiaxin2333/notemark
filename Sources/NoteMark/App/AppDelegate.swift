import AppKit
import ApplicationServices
import NoteMarkCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Permissions are granted in System Settings; poll until they arrive.
    private static let permissionPollInterval: TimeInterval = 2

    private let diagnostics = DiagnosticsReporter()
    private lazy var engine = ConversionEngine(diagnostics: diagnostics)
    private var automaticConversion = AutomaticConversionPolicy()
    private var status = L10n.waitingForPermission
    private var statusMenu: StatusMenuController?
    private var setupWindow: SetupWindowController?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusMenu = StatusMenuController(actions: .init(
            toggleConversion: { [weak self] in self?.toggleConversion() },
            showSetup: { [weak self] in self?.showSetup() },
            openNotes: { NotesApp.open() },
            quit: { NSApp.terminate(nil) }))
        engine.onStatus = { [weak self] status in self?.statusDidChange(status) }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: Self.permissionPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkAutomaticStart()
                self?.refresh()
            }
        }
        checkAutomaticStart()
        showSetup()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        checkAutomaticStart()
        refresh()
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
            if engine.running { engine.stop() }
            if automaticConversion.wantsConversion {
                status = L10n.waitingForPermission
                setupWindow?.update(status: status)
            }
        }
        if automaticConversion.shouldStart(permissions: permissions, running: engine.running) {
            engine.start()
        }
    }

    private func refresh() {
        let running = engine.running
        let wantsConversion = automaticConversion.wantsConversion
        let accessibility = AXIsProcessTrusted()
        diagnostics.recordState(running: running, status: status, accessibility: accessibility,
                                inputMonitoring: CGPreflightListenEventAccess())
        statusMenu?.update(running: running, wantsConversion: wantsConversion)
        setupWindow?.update(
            permission: accessibility
                ? (running ? L10n.accessibilityGrantedRunning : L10n.accessibilityGranted)
                : (wantsConversion ? L10n.accessibilityNeededAutomatic : L10n.accessibilityNeededPaused),
            toggleTitle: running ? L10n.pauseButton : wantsConversion ? L10n.retryButton : L10n.resumeButton)
    }

    private func showSetup() {
        if setupWindow == nil { setupWindow = Self.makeSetupWindow(status: status, delegate: self) }
        refresh()
        setupWindow?.show()
    }

    static func makeSetupWindow(status: String, delegate: AppDelegate?) -> SetupWindowController {
        SetupWindowController(status: status, actions: .init(
            toggleConversion: { [weak delegate] in delegate?.toggleConversion() },
            authorizeAccessibility: { [weak delegate] in delegate?.authorizeAccessibility() },
            openInputMonitoringSettings: { Self.openInputMonitoringSettings() },
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
}
