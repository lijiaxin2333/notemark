import Foundation

/// Menu lifetime is separate from an executable edit: an IME can temporarily
/// expose a selection, apostrophes in pinyin, or no readable editor snapshot.
public struct SlashMenuSession: Sendable {
    public enum Update: Equatable, Sendable {
        case show(String)
        case wait
        /// Hide the panel while continuing to track edits to this slash query.
        case hide
        case dismiss
    }

    public private(set) var paragraphStart: Int?
    private var unavailableReads = 0
    private var waitingForCommit = false
    private var commitReads = 0
    private var initialSlashPending = false
    private var initialPresentationPending = false
    private var emptyMenuOpen = false
    private var presentedQuery: String?

    public init() {}

    /// Only a newly typed slash may open the unfiltered menu.
    public mutating func begin() {
        self = SlashMenuSession()
        initialSlashPending = true
        initialPresentationPending = true
    }

    /// Record input before the debounced editor snapshot catches up.
    public mutating func noteSearchInput(isDeletion: Bool = false) {
        initialSlashPending = false
        emptyMenuOpen = false
        if isDeletion { initialPresentationPending = false }
    }

    /// `afterCaret` is nil when the paragraph's right boundary is unknown.
    public mutating func update(beforeCaret: String?, windowStart: Int = 0,
                                afterCaret: String? = "", selectionLength: Int = 0,
                                isMonospaced: Bool = false, isComposing: Bool = false) -> Update {
        guard let beforeCaret else {
            if isComposing { waitingForCommit = true; commitReads = 0; return .wait }
            unavailableReads += 1
            return unavailableReads <= 5 ? .wait : .dismiss
        }
        unavailableReads = 0
        let caretLine = CaretLine(beforeCaret: beforeCaret, windowStart: windowStart)
        guard windowStart >= 0, caretLine.startIsKnown else { return .dismiss }
        let line = caretLine.text
        guard !isMonospaced, SlashQuery.startsWithSlash(line) else { return .dismiss }
        let paragraph = caretLine.documentStart
        if let paragraphStart, paragraphStart != paragraph {
            // Visiting an existing slash on another line is not a fresh slash input.
            initialSlashPending = false
            initialPresentationPending = false
            emptyMenuOpen = false
            presentedQuery = nil
        }
        paragraphStart = paragraph

        if isComposing {
            waitingForCommit = true
            commitReads = 0
            // Keep the last committed search and selection while the IME owns input.
            // Fast typing can begin composition before the first debounced read.
            let showInitial = initialPresentationPending && presentedQuery == nil
            initialSlashPending = false
            initialPresentationPending = false
            emptyMenuOpen = false
            if showInitial { presentedQuery = ""; return .show("") }
            return .wait
        }
        let rawQuery = String(line.dropFirst())
        if !rawQuery.isEmpty { initialSlashPending = false; emptyMenuOpen = false }
        guard let query = SlashQuery.parse(beforeCaret: beforeCaret, windowStart: windowStart,
                                           afterCaret: afterCaret, isMonospaced: isMonospaced,
                                           selectionLength: selectionLength) else {
            // Candidate windows can close before Notes publishes committed text.
            if waitingForCommit {
                commitReads += 1
                if commitReads <= 5 { return .wait }
            }
            return hide()
        }
        waitingForCommit = false
        commitReads = 0
        if query.query.isEmpty {
            // A space is input, not another request for the initial full menu.
            guard rawQuery.isEmpty, initialSlashPending || emptyMenuOpen else { return hide() }
            initialSlashPending = false
            emptyMenuOpen = true
        } else {
            initialSlashPending = false
            emptyMenuOpen = false
            guard !SlashCommand.matching(query.query).isEmpty else { return hide() }
        }
        presentedQuery = query.query
        initialPresentationPending = false
        return .show(query.query)
    }

    private mutating func hide() -> Update {
        initialSlashPending = false
        initialPresentationPending = false
        emptyMenuOpen = false
        presentedQuery = nil
        return .hide
    }
}
