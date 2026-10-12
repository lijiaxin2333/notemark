import XCTest
@testable import NoteMarkCore

final class RuntimeReportTests: XCTestCase {
    private func json(_ report: RuntimeReport) throws -> [String: Any] {
        let data = try JSONEncoder().encode(report)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testKeepsTheExistingReportKeys() throws {
        var report = RuntimeReport(pid: 42, version: "0.1.22", verboseDiagnostics: true)
        report.paragraphCancellationReady = true
        report.lastParagraphObservation = ParagraphObservation(selectionEmpty: true, previousCharacterMonospaced: false,
            currentLineMonospaced: true, codeContent: true, emptyParagraphMonospaced: false, codeContextAvailable: true,
            codeContextEmpty: false, codeBackwardDeletionReady: false, codeForwardDeletionReady: false, tracked: true)
        report.appendTrace(CancellationTrace(phase: "before-escape", caret: 5, selectionLength: 0, documentLength: 9,
            contextStart: 5, contextLength: 1, contextEmpty: true,
            paragraphs: [ParagraphFonts(start: 0, length: 4, firstFont: "Menlo", lastFont: "Menlo", separatorFont: "unavailable")]))
        report.updatedAt = "2026-10-11T00:00:00Z"
        report.lastUnmatchedRule = "prefixLength=1"
        let object = try json(report)
        XCTAssertEqual(Set(object.keys), [
            "pid", "version", "running", "accessibility", "inputMonitoring", "status", "slashVisible", "slashComposing",
            "slashMatchCount", "trackedParagraphStyle", "paragraphCancellationReady", "lastParagraphObservation",
            "lastCancellationAttempt", "cancellationTrace", "updatedAt", "verboseDiagnostics", "lastUnmatchedRule"
        ])
        let observation = try XCTUnwrap(object["lastParagraphObservation"] as? [String: Bool])
        XCTAssertEqual(Set(observation.keys), [
            "selectionEmpty", "previousCharacterMonospaced", "currentLineMonospaced", "codeContent",
            "emptyParagraphMonospaced", "codeContextAvailable", "codeContextEmpty", "codeBackwardDeletionReady",
            "codeForwardDeletionReady", "tracked"
        ])
        let trace = try XCTUnwrap((object["cancellationTrace"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(trace.keys), ["phase", "caret", "selectionLength", "documentLength", "contextStart",
                                         "contextLength", "contextEmpty", "paragraphs"])
        let paragraph = try XCTUnwrap((trace["paragraphs"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(paragraph.keys), ["start", "length", "firstFont", "lastFont", "separatorFont"])
    }

    func testVerboseFieldsAreOmittedWhenDisabled() throws {
        let object = try json(RuntimeReport(pid: 1, version: "development", verboseDiagnostics: false))
        XCTAssertNil(object["paragraphCancellationReady"])
        XCTAssertNil(object["lastParagraphObservation"])
        XCTAssertEqual(object["trackedParagraphStyle"] as? String, "none")
        XCTAssertEqual(object["lastCancellationAttempt"] as? String, "none")
    }

    func testTraceKeepsTheMostRecentEntries() {
        var report = RuntimeReport(pid: 1, version: "x", verboseDiagnostics: false)
        for index in 0..<30 {
            report.appendTrace(CancellationTrace(phase: "\(index)", caret: 0, selectionLength: 0, documentLength: 0,
                                                 contextStart: -1, contextLength: -1, contextEmpty: false))
        }
        XCTAssertEqual(report.cancellationTrace.count, RuntimeReport.traceLimit)
        XCTAssertEqual(report.cancellationTrace.first?.phase, "6")
        XCTAssertEqual(report.cancellationTrace.last?.phase, "29")
    }
}
