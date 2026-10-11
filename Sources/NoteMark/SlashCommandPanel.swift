import AppKit
import NoteMarkCore

private final class CommandPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class CommandRow: NSButton {
    let command: SlashCommand
    let selected: Bool

    init(command: SlashCommand, selected: Bool, target: AnyObject, action: Selector) {
        self.command = command
        self.selected = selected
        super.init(frame: .zero)
        self.target = target
        self.action = action
        setButtonType(.momentaryChange)
        isBordered = false
        title = command.title
        setAccessibilityLabel("\(command.title)，\(command.detail)，/\(command.aliases[0])")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        if selected {
            NSColor.controlAccentColor.withAlphaComponent(0.13).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 1), xRadius: 7, yRadius: 7).fill()
        }
        NSColor.labelColor.set()
        NSImage(systemSymbolName: command.symbol, accessibilityDescription: nil)?
            .draw(in: NSRect(x: 14, y: 14, width: 18, height: 18))
        (command.title as NSString).draw(at: NSPoint(x: 43, y: 7), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: selected ? .semibold : .medium), .foregroundColor: NSColor.labelColor
        ])
        (command.detail as NSString).draw(at: NSPoint(x: 43, y: 25), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor
        ])
        let alias = "/" + command.aliases[0]
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.tertiaryLabelColor]
        let width = (alias as NSString).size(withAttributes: attributes).width
        (alias as NSString).draw(at: NSPoint(x: bounds.width - width - 14, y: 18), withAttributes: attributes)
    }
}

final class SlashCommandPanel: NSObject {
    var onChoose: ((SlashCommand) -> Void)?
    private var panel: CommandPanel?
    private var selection = SlashSelection()
    private var query = ""
    private var anchor = CGRect.zero
    var isVisible: Bool { panel?.isVisible == true }
    var selected: SlashCommand? { selection.selected }
    var currentQuery: String { query }

    func show(query: String, anchor: CGRect, present: Bool = true) {
        let wasVisible = isVisible
        if !wasVisible || self.query != query { selection.update(query: query) }
        self.query = query
        self.anchor = anchor
        if panel == nil {
            let panel = CommandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.hasShadow = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            self.panel = panel
        }
        render()
        if present { panel?.orderFrontRegardless() }
    }

    func dismiss() { panel?.orderOut(nil); query = "" }
    func containsMouse() -> Bool { isVisible && panel?.frame.contains(NSEvent.mouseLocation) == true }
    func move(_ delta: Int) { selection.move(delta); render() }

    private func render() {
        guard let panel else { return }
        let height = CGFloat(max(1, selection.commands.count)) * 46 + 68
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) }) ?? NSScreen.main
        guard let screen else { return }
        let frame = SlashPopupPlacement.frame(anchor: anchor, visibleFrame: screen.visibleFrame.insetBy(dx: 8, dy: 8), size: CGSize(width: 340, height: height))
        panel.setFrame(frame, display: false)
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        background.material = .popover
        background.blendingMode = .withinWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        let heading = NSTextField(labelWithString: query.isEmpty ? "段落格式" : "搜索：\(query)")
        heading.font = .systemFont(ofSize: 11, weight: .semibold)
        heading.textColor = .secondaryLabelColor
        heading.frame = NSRect(x: 16, y: frame.height - 29, width: frame.width - 32, height: 16)
        background.addSubview(heading)
        let footer = NSTextField(labelWithString: "↑↓ 选择    ↩ / Tab 执行    Esc 关闭")
        footer.font = .systemFont(ofSize: 10)
        footer.textColor = .secondaryLabelColor
        footer.frame = NSRect(x: 16, y: 10, width: frame.width - 32, height: 14)
        background.addSubview(footer)
        // A small display scrolls the results rather than clipping commands.
        let scroll = NSScrollView(frame: NSRect(x: 7, y: 31, width: frame.width - 14, height: max(0, frame.height - 64)))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        let document = NSView(frame: NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: CGFloat(max(1, selection.commands.count)) * 46))
        if selection.commands.isEmpty {
            let empty = NSTextField(labelWithString: "没有匹配命令，Esc 关闭并保留文字")
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = .secondaryLabelColor
            empty.frame = NSRect(x: 12, y: 15, width: document.frame.width - 24, height: 18)
            document.addSubview(empty)
        } else {
            for (index, command) in selection.commands.enumerated() {
                let row = CommandRow(command: command, selected: index == selection.index, target: self, action: #selector(choose(_:)))
                row.frame = NSRect(x: 0, y: document.frame.height - CGFloat(index + 1) * 46, width: document.frame.width, height: 46)
                document.addSubview(row)
            }
        }
        scroll.documentView = document
        background.addSubview(scroll)
        if !selection.commands.isEmpty {
            document.scrollToVisible(NSRect(x: 0, y: document.frame.height - CGFloat(selection.index + 1) * 46, width: document.frame.width, height: 46))
        }
        panel.contentView = background
    }

    @objc private func choose(_ sender: CommandRow) { onChoose?(sender.command) }

    /// Only renders our own menu, without reading or operating Notes.
    func renderPreview(to path: String) throws {
        show(query: "", anchor: CGRect(x: 100, y: 600, width: 1, height: 18), present: false)
        defer { dismiss() }
        panel?.appearance = NSAppearance(named: .aqua)
        guard let view = panel?.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileWriteUnknown) }
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance { view.cacheDisplay(in: view.bounds, to: bitmap) }
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: URL(fileURLWithPath: path))
    }
}
