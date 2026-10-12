import AppKit
import ApplicationServices

/// Command-line modes of the NoteMark binary, used by the build and install
/// scripts and for troubleshooting. None of them reads or changes notes.
@MainActor enum CommandLineTool {
    /// Modes that run before NSApplication exists. Returns an exit status, or
    /// nil to continue launching.
    static func runBeforeLaunch(_ arguments: [String]) -> Int32? {
        if arguments.contains("--self-check") {
            let failures = SelfCheck.run().filter { !$0.passed }
            guard failures.isEmpty else {
                for failure in failures { FileHandle.standardError.write(Data("Self-check failed: \(failure.name)\n".utf8)) }
                return 1
            }
            print("NoteMark self-check passed · \(ProcessInfo.processInfo.operatingSystemVersionString)")
            return 0
        }
        if arguments.contains("--diagnose") {
            print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
            print("Accessibility: \(AXIsProcessTrusted())")
            print("Input monitoring: \(CGPreflightListenEventAccess())")
            print("Input method candidate window: \(InputMethodMonitor.hasVisibleCandidateWindow())")
            DiagnosticsReporter.printLastReport()
            print("No Notes content was read or changed.")
            return 0
        }
        return nil
    }

    /// Offscreen renders of NoteMark's own windows. They need NSApplication.
    static func runRenderer(_ arguments: [String]) -> Int32? {
        if let path = value(after: "--render-slash", in: arguments) {
            return render("slash menu") { try SlashCommandPanel().renderPreview(to: path) }
        }
        if let path = value(after: "--render-settings", in: arguments) {
            return render("settings window") {
                try SettingsWindowController(preferences: Preferences(defaults: UserDefaults(suiteName: "NoteMarkRenderPreview")!),
                                             showSetup: {}).renderPreview(to: path)
            }
        }
        if let path = value(after: "--render-setup", in: arguments) {
            return render("setup view") {
                let setup = AppDelegate.makeSetupWindow(status: L10n.waitingForPermission, delegate: nil)
                setup.update(accessibility: false, inputMonitoring: false, toggleTitle: L10n.waitingForAutomaticStart)
                try setup.renderPreview(to: path)
            }
        }
        return nil
    }

    private static func value(after option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option), arguments.count > index + 1 else { return nil }
        return arguments[index + 1]
    }

    private static func render(_ name: String, _ body: () throws -> Void) -> Int32 {
        do {
            try body()
            print("Rendered NoteMark \(name) offscreen.")
            return 0
        } catch {
            print("Render failed: \(error)")
            return 1
        }
    }
}
