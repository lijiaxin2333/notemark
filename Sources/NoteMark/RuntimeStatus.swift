import AppKit
import ApplicationServices

/// Fixed diagnostic fields only; never store keystrokes or note contents.
enum RuntimeStatus {
    static let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("NoteMark/runtime-status.json")
    private static var lastReport = ""
    private static var lastRunning = false
    private static var lastStatus = ""
    private static var slashVisible = false
    private static var slashComposing = false
    private static var slashMatchCount = 0
    private static var trackedParagraphStyle: String?
    private static var paragraphCancellationReady = false
    private static var paragraphObservation: [String: Bool] = [:]
    private static var cancellationAttempt = "none"
    private static var cancellationTrace: [[String: Any]] = []

    static func recordCancellation(_ phase: String, metrics: [String: Any]) {
        var entry = metrics
        entry["phase"] = phase
        cancellationTrace.append(entry)
        cancellationTrace = Array(cancellationTrace.suffix(24))
        lastReport = "" // Every deletion step matters, even when its flags agree.
        save(running: lastRunning, status: lastStatus)
    }

    static func saveParagraphObservation(_ observation: [String: Bool]) {
        paragraphObservation = observation
        save(running: lastRunning, status: lastStatus)
    }

    static func saveCancellationAttempt(_ outcome: String) {
        cancellationAttempt = outcome
        save(running: lastRunning, status: lastStatus)
    }

    static func saveParagraph(style: String?, ready: Bool) {
        trackedParagraphStyle = style
        paragraphCancellationReady = ready
        save(running: lastRunning, status: lastStatus)
    }

    static func saveSlash(visible: Bool, composing: Bool, matchCount: Int) {
        slashVisible = visible
        slashComposing = composing
        slashMatchCount = matchCount
        save(running: lastRunning, status: lastStatus)
    }

    static func save(running: Bool, status: String) {
        lastRunning = running
        lastStatus = status
        let observation = paragraphObservation.keys.sorted().map { "\($0):\(paragraphObservation[$0]!)" }.joined(separator: "|")
        let report = "\(running)|\(status)|\(AXIsProcessTrusted())|\(CGPreflightListenEventAccess())|\(slashVisible)|\(slashComposing)|\(slashMatchCount)|\(trackedParagraphStyle ?? "none")|\(paragraphCancellationReady)|\(observation)|\(cancellationAttempt)"
        guard report != lastReport else { return }
        let fields: [String: Any] = [
            "pid": ProcessInfo.processInfo.processIdentifier,
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            "running": running,
            "accessibility": AXIsProcessTrusted(),
            "inputMonitoring": CGPreflightListenEventAccess(),
            "status": status,
            "slashVisible": slashVisible,
            "slashComposing": slashComposing,
            "slashMatchCount": slashMatchCount,
            "trackedParagraphStyle": trackedParagraphStyle ?? "none",
            "paragraphCancellationReady": paragraphCancellationReady,
            "lastParagraphObservation": paragraphObservation,
            "lastCancellationAttempt": cancellationAttempt,
            "cancellationTrace": cancellationTrace,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let data = try JSONSerialization.data(withJSONObject: fields, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            lastReport = report
        } catch { /* Diagnostics must never interrupt editing. */ }
    }

    static func printLastReport() {
        guard let data = try? Data(contentsOf: url),
              let report = String(data: data, encoding: .utf8) else {
            print("No installed-app status report yet.")
            return
        }
        print("Last app status (may be stale if the app has exited):\n\(report)")
    }
}
