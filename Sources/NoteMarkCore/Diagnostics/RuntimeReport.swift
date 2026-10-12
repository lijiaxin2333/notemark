/// The local diagnostics report printed by `--diagnose`. Fixed fields only:
/// it never contains keystrokes or note text.
public struct RuntimeReport: Codable, Equatable, Sendable {
    public static let traceLimit = 24

    public var pid: Int32
    public var version: String
    public var running = false
    public var accessibility = false
    public var inputMonitoring = false
    public var status = ""
    public var slashVisible = false
    public var slashComposing = false
    public var slashMatchCount = 0
    public var trackedParagraphStyle = "none"
    public var lastCancellationAttempt = "none"
    public var cancellationTrace: [CancellationTrace] = []
    /// Per-keystroke paragraph observations are recorded only when enabled.
    public var verboseDiagnostics: Bool
    public var paragraphCancellationReady: Bool?
    public var lastParagraphObservation: ParagraphObservation?
    /// Set when the report is written.
    public var updatedAt: String?

    public init(pid: Int32, version: String, verboseDiagnostics: Bool) {
        self.pid = pid
        self.version = version
        self.verboseDiagnostics = verboseDiagnostics
    }

    public mutating func appendTrace(_ trace: CancellationTrace) {
        cancellationTrace = Array((cancellationTrace + [trace]).suffix(Self.traceLimit))
    }
}

/// How the editor looked to paragraph tracking after a change.
public struct ParagraphObservation: Codable, Equatable, Sendable {
    public var selectionEmpty: Bool
    public var previousCharacterMonospaced: Bool
    public var currentLineMonospaced: Bool
    public var codeContent: Bool
    public var emptyParagraphMonospaced: Bool
    public var codeContextAvailable: Bool
    public var codeContextEmpty: Bool
    public var codeBackwardDeletionReady: Bool
    public var codeForwardDeletionReady: Bool
    public var tracked: Bool

    public init(selectionEmpty: Bool, previousCharacterMonospaced: Bool, currentLineMonospaced: Bool,
                codeContent: Bool, emptyParagraphMonospaced: Bool, codeContextAvailable: Bool,
                codeContextEmpty: Bool, codeBackwardDeletionReady: Bool, codeForwardDeletionReady: Bool,
                tracked: Bool) {
        self.selectionEmpty = selectionEmpty
        self.previousCharacterMonospaced = previousCharacterMonospaced
        self.currentLineMonospaced = currentLineMonospaced
        self.codeContent = codeContent
        self.emptyParagraphMonospaced = emptyParagraphMonospaced
        self.codeContextAvailable = codeContextAvailable
        self.codeContextEmpty = codeContextEmpty
        self.codeBackwardDeletionReady = codeBackwardDeletionReady
        self.codeForwardDeletionReady = codeForwardDeletionReady
        self.tracked = tracked
    }
}

/// Format and range metadata around one cancellation step. Never note text.
public struct CancellationTrace: Codable, Equatable, Sendable {
    public var phase: String
    public var caret: Int
    public var selectionLength: Int
    public var documentLength: Int
    public var contextStart: Int
    public var contextLength: Int
    public var contextEmpty: Bool
    public var paragraphs: [ParagraphFonts]?

    public init(phase: String, caret: Int, selectionLength: Int, documentLength: Int,
                contextStart: Int, contextLength: Int, contextEmpty: Bool, paragraphs: [ParagraphFonts]? = nil) {
        self.phase = phase
        self.caret = caret
        self.selectionLength = selectionLength
        self.documentLength = documentLength
        self.contextStart = contextStart
        self.contextLength = contextLength
        self.contextEmpty = contextEmpty
        self.paragraphs = paragraphs
    }
}

public struct ParagraphFonts: Codable, Equatable, Sendable {
    public var start: Int
    public var length: Int
    public var firstFont: String
    public var lastFont: String
    public var separatorFont: String

    public init(start: Int, length: Int, firstFont: String, lastFont: String, separatorFont: String) {
        self.start = start
        self.length = length
        self.firstFont = firstFont
        self.lastFont = lastFont
        self.separatorFont = separatorFont
    }
}
