import Foundation
import NoteMarkCore

/// Maintains the local status report printed by `--diagnose`. Writes are
/// coalesced and happen off the main thread, so reporting never delays input.
@MainActor final class DiagnosticsReporter {
    /// `defaults write dev.local.notemark NoteMarkVerboseDiagnostics -bool YES`
    /// records paragraph observations after every editor change.
    static let verboseDefaultsKey = "NoteMarkVerboseDiagnostics"
    private static let writeDelay = Duration.milliseconds(200)

    nonisolated static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NoteMark/runtime-status.json")
    }

    let isVerbose: Bool
    private var report: RuntimeReport
    private var writtenReport: RuntimeReport?
    private var pendingWrite: Task<Void, Never>?
    private let writer = DispatchQueue(label: "\(Bundle.main.bundleIdentifier ?? "NoteMark").diagnostics", qos: .utility)
    private let dateFormatter = ISO8601DateFormatter()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    init(defaults: UserDefaults = .standard) {
        isVerbose = defaults.bool(forKey: Self.verboseDefaultsKey)
        report = RuntimeReport(pid: ProcessInfo.processInfo.processIdentifier,
                               version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
                               verboseDiagnostics: isVerbose)
    }

    func recordState(running: Bool, status: String, accessibility: Bool, inputMonitoring: Bool) {
        update {
            $0.running = running
            $0.status = status
            $0.accessibility = accessibility
            $0.inputMonitoring = inputMonitoring
        }
    }

    func recordSlash(visible: Bool, composing: Bool, matchCount: Int) {
        update {
            $0.slashVisible = visible
            $0.slashComposing = composing
            $0.slashMatchCount = matchCount
        }
    }

    func recordTrackedStyle(_ style: ParagraphStyle?) {
        update {
            $0.trackedParagraphStyle = style?.rawValue ?? "none"
            if isVerbose { $0.paragraphCancellationReady = false }
        }
    }

    func recordParagraphObservation(_ observation: ParagraphObservation, cancellationReady: Bool) {
        guard isVerbose else { return }
        update {
            $0.lastParagraphObservation = observation
            $0.paragraphCancellationReady = cancellationReady
        }
    }

    func recordCancellationAttempt(_ outcome: String) {
        update { $0.lastCancellationAttempt = outcome }
    }

    func recordUnmatchedRule(_ description: String) {
        update { $0.lastUnmatchedRule = description }
    }

    func recordCancellationTrace(_ trace: CancellationTrace) {
        update { $0.appendTrace(trace) }
    }

    /// Write the final report before the app exits. The writer queue is
    /// serial, so this lands after any write already queued, and it does not
    /// depend on whether that earlier write succeeded.
    func flush() {
        pendingWrite?.cancel()
        pendingWrite = nil
        writtenReport = nil
        guard let pending = encodePendingReport() else { return }
        if !writer.sync(execute: { Self.store(pending.data) }) { writtenReport = nil }
    }

    nonisolated static func printLastReport() {
        guard let data = try? Data(contentsOf: fileURL), let report = String(data: data, encoding: .utf8) else {
            print("No installed-app status report yet.")
            return
        }
        print("Last app status (may be stale if the app has exited):\n\(report)")
    }

    private func update(_ change: (inout RuntimeReport) -> Void) {
        change(&report)
        guard report != writtenReport, pendingWrite == nil else { return }
        pendingWrite = Task { [weak self] in
            try? await Task.sleep(for: Self.writeDelay)
            guard !Task.isCancelled else { return }
            self?.writePendingReport()
        }
    }

    private func writePendingReport() {
        pendingWrite = nil
        guard let pending = encodePendingReport() else { return }
        writer.async { [weak self] in
            guard !Self.store(pending.data) else { return }
            Task { @MainActor in self?.writeFailed(for: pending.report) }
        }
    }

    /// A failed write is retried with the next report update, as before.
    private func writeFailed(for failed: RuntimeReport) {
        if writtenReport == failed { writtenReport = nil }
    }

    /// The current report and its JSON when it differs from the last one
    /// written. It counts as written from here on so concurrent updates do
    /// not queue duplicate writes.
    private func encodePendingReport() -> (report: RuntimeReport, data: Data)? {
        guard report != writtenReport else { return nil }
        var stamped = report
        stamped.updatedAt = dateFormatter.string(from: Date())
        guard let data = try? encoder.encode(stamped) else { return nil }
        writtenReport = report
        return (report, data)
    }

    /// Returns false when the report could not be written.
    nonisolated private static func store(_ data: Data) -> Bool {
        let url = fileURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch {
            return false // Diagnostics must never interrupt editing.
        }
    }
}
