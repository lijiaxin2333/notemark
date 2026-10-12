import AppKit
import NoteMarkCore

/// A floating panel that never takes keyboard focus from Notes.
private final class CommandPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class CommandRow: NSButton {
    static let height: CGFloat = 46

    let command: SlashCommand
    var isCurrent = false {
        didSet { if isCurrent != oldValue { needsDisplay = true } }
    }

    init(command: SlashCommand, target: AnyObject, action: Selector) {
        self.command = command
        super.init(frame: .zero)
        self.target = target
        self.action = action
        setButtonType(.momentaryChange)
        isBordered = false
        title = command.title
        setAccessibilityLabel(L10n.slashCommandAccessibilityLabel(title: command.title, detail: command.detail,
                                                                  alias: command.aliases[0]))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func draw(_ dirtyRect: NSRect) {
        if isCurrent {
            NSColor.controlAccentColor.withAlphaComponent(0.13).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 1), xRadius: 7, yRadius: 7).fill()
        }
        NSColor.labelColor.set()
        NSImage(systemSymbolName: command.symbol, accessibilityDescription: nil)?
            .draw(in: NSRect(x: 14, y: 14, width: 18, height: 18))
        (command.title as NSString).draw(at: NSPoint(x: 43, y: 7), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: isCurrent ? .semibold : .medium), .foregroundColor: NSColor.labelColor
        ])
        (command.detail as NSString).draw(at: NSPoint(x: 43, y: 25), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor
        ])
        let alias = "/" + command.aliases[0]
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let width = (alias as NSString).size(withAttributes: attributes).width
        (alias as NSString).draw(at: NSPoint(x: bounds.width - width - 14, y: 18), withAttributes: attributes)
    }
}

/// The slash command menu shown next to the caret in Notes.
@MainActor final class SlashCommandPanel: NSObject {
    /// Panel metrics in points. AppKit's origin is the bottom-left corner.
    private enum Layout {
        static let width: CGFloat = 340
        static let screenMargin: CGFloat = 8
        static let cornerRadius: CGFloat = 12
        static let textInset: CGFloat = 16
        /// The heading's baseline box sits this far below the top edge.
        static let headingTop: CGFloat = 29
        static let headingHeight: CGFloat = 16
        static let footerBottom: CGFloat = 10
        static let footerHeight: CGFloat = 14
        static let listInset: CGFloat = 7
        /// The list starts above the footer and ends below the heading.
        static let listBottom: CGFloat = 31
        static let listTop: CGFloat = 33
        /// Extra list height below the last row.
        static let listSlack: CGFloat = 4
        static var chromeHeight: CGFloat { listBottom + listTop + listSlack }
    }

    var onChoose: ((SlashCommand) -> Void)?
    private(set) var currentQuery = ""
    private var panel: CommandPanel?
    private var selection = SlashSelection()
    private var anchor = CGRect.zero
    private var rows: [CommandRow] = []
    private weak var rowContainer: NSView?

    var isVisible: Bool { panel?.isVisible == true }
    var selected: SlashCommand? { selection.selected }

    func show(query: String, anchor: CGRect, present: Bool = true) {
        // The visible menu already shows this query at this anchor; rebuilding
        // it would produce the same view and scroll position.
        let unchanged = isVisible && currentQuery == query && self.anchor == anchor
        if !isVisible || currentQuery != query { selection.update(query: query) }
        currentQuery = query
        self.anchor = anchor
        let panel = panel ?? makePanel()
        if !unchanged { render(in: panel) }
        if present { panel.orderFrontRegardless() }
    }

    func dismiss() {
        panel?.orderOut(nil)
        currentQuery = ""
    }

    func containsMouse() -> Bool { isVisible && panel?.frame.contains(NSEvent.mouseLocation) == true }

    func move(_ delta: Int) {
        selection.move(delta)
        for (index, row) in rows.enumerated() { row.isCurrent = index == selection.index }
        scrollSelectionToVisible()
    }

    private func makePanel() -> CommandPanel {
        let panel = CommandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.panel = panel
        return panel
    }

    private func render(in panel: CommandPanel) {
        let commands = selection.commands
        let height = CGFloat(max(1, commands.count)) * CommandRow.height + Layout.chromeHeight
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) } ?? NSScreen.main
        guard let screen else { return }
        let frame = SlashPopupPlacement.frame(
            anchor: anchor, visibleFrame: screen.visibleFrame.insetBy(dx: Layout.screenMargin, dy: Layout.screenMargin),
            size: CGSize(width: Layout.width, height: height))
        panel.setFrame(frame, display: false)
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        background.material = .popover
        background.blendingMode = .withinWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Layout.cornerRadius
        background.layer?.masksToBounds = true
        let heading = NSTextField(labelWithString: currentQuery.isEmpty ? L10n.slashMenuTitle : L10n.slashSearch(currentQuery))
        heading.font = .systemFont(ofSize: 11, weight: .semibold)
        heading.textColor = .secondaryLabelColor
        heading.frame = NSRect(x: Layout.textInset, y: frame.height - Layout.headingTop,
                               width: frame.width - 2 * Layout.textInset, height: Layout.headingHeight)
        background.addSubview(heading)
        let footer = NSTextField(labelWithString: L10n.slashFooter)
        footer.font = .systemFont(ofSize: 10)
        footer.textColor = .secondaryLabelColor
        footer.frame = NSRect(x: Layout.textInset, y: Layout.footerBottom,
                              width: frame.width - 2 * Layout.textInset, height: Layout.footerHeight)
        background.addSubview(footer)
        // A small display scrolls the results rather than clipping commands.
        let scroll = NSScrollView(frame: NSRect(x: Layout.listInset, y: Layout.listBottom,
                                                width: frame.width - 2 * Layout.listInset,
                                                height: max(0, frame.height - Layout.listBottom - Layout.listTop)))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        let document = NSView(frame: NSRect(x: 0, y: 0, width: scroll.contentSize.width,
                                            height: CGFloat(max(1, commands.count)) * CommandRow.height))
        rows = commands.enumerated().map { index, command in
            let row = CommandRow(command: command, target: self, action: #selector(choose(_:)))
            row.isCurrent = index == selection.index
            row.frame = NSRect(x: 0, y: document.frame.height - CGFloat(index + 1) * CommandRow.height,
                               width: document.frame.width, height: CommandRow.height)
            document.addSubview(row)
            return row
        }
        if commands.isEmpty {
            let empty = NSTextField(labelWithString: L10n.slashNoMatches)
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = .secondaryLabelColor
            empty.frame = NSRect(x: 12, y: 15, width: document.frame.width - 24, height: 18)
            document.addSubview(empty)
        }
        scroll.documentView = document
        background.addSubview(scroll)
        rowContainer = document
        scrollSelectionToVisible()
        panel.contentView = background
    }

    /// Scroll as a newly built list would: a non-flipped document starts at its
    /// bottom, then scrolls just enough to show the selected row.
    private func scrollSelectionToVisible() {
        guard let document = rowContainer, !selection.commands.isEmpty else { return }
        document.scroll(.zero)
        document.scrollToVisible(NSRect(x: 0, y: document.frame.height - CGFloat(selection.index + 1) * CommandRow.height,
                                        width: document.frame.width, height: CommandRow.height))
    }

    @objc private func choose(_ sender: CommandRow) { onChoose?(sender.command) }

    /// Render the menu offscreen for layout review. Never reads or operates Notes.
    func renderPreview(to path: String) throws {
        show(query: "", anchor: CGRect(x: 100, y: 600, width: 1, height: 18), present: false)
        defer { dismiss() }
        panel?.appearance = NSAppearance(named: .aqua)
        guard let view = panel?.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance { view.cacheDisplay(in: view.bounds, to: bitmap) }
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: URL(fileURLWithPath: path))
    }
}
