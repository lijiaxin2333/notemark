import AppKit

/// Paints the window background so offscreen renders match the real window.
private final class SetupContentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}

/// The usage and permissions window.
@MainActor final class SetupWindowController {
    struct Actions {
        var toggleConversion: () -> Void
        var authorizeAccessibility: () -> Void
        var openInputMonitoringSettings: () -> Void
        var openNotes: () -> Void
    }

    private static let contentSize = NSSize(width: 620, height: 680)

    let window: NSWindow
    private let scrollView: NSScrollView
    private let statusLabel: NSTextField
    private let permissionLabel: NSTextField
    private let toggleButton: NSButton
    private let actionTarget: ActionTarget

    init(status: String, actions: Actions) {
        let target = ActionTarget(actions: actions)
        actionTarget = target
        window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.contentSize),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "NoteMark"
        window.isReleasedWhenClosed = false
        window.center()
        let content = SetupContentView(frame: NSRect(origin: .zero, size: Self.contentSize))
        window.contentView = content
        scrollView = NSScrollView(frame: content.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        content.addSubview(scrollView)
        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = document
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -26)
        ])

        func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
                   color: NSColor = .labelColor) -> NSTextField {
            let field = NSTextField(wrappingLabelWithString: text)
            field.font = .systemFont(ofSize: size, weight: weight)
            field.textColor = color
            stack.addArrangedSubview(field)
            field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            return field
        }
        func button(_ title: String, _ action: Selector) -> NSButton {
            let button = NSButton(title: title, target: target, action: action)
            button.bezelStyle = .rounded
            return button
        }

        _ = label(L10n.setupHeadline, size: 25, weight: .semibold)
        _ = label(L10n.setupIntroduction, size: 14, color: .secondaryLabelColor)
        permissionLabel = label("", weight: .medium)
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        toggleButton = button(L10n.pauseButton, #selector(ActionTarget.toggleConversion))
        buttons.addArrangedSubview(button(L10n.authorizeAccessibility, #selector(ActionTarget.authorizeAccessibility)))
        buttons.addArrangedSubview(toggleButton)
        stack.addArrangedSubview(buttons)
        statusLabel = label(status, color: .secondaryLabelColor)
        _ = label(L10n.paragraphMarkersHeading, size: 15, weight: .semibold)
        for (syntax, meaning) in L10n.cheatSheet {
            let row = NSStackView()
            row.spacing = 18
            let left = NSTextField(labelWithString: syntax)
            left.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
            left.widthAnchor.constraint(equalToConstant: 220).isActive = true
            let right = NSTextField(labelWithString: meaning)
            right.textColor = .secondaryLabelColor
            row.addArrangedSubview(left)
            row.addArrangedSubview(right)
            stack.addArrangedSubview(row)
        }
        _ = label(L10n.slashHeading, size: 15, weight: .semibold)
        _ = label(L10n.slashExplanation, color: .secondaryLabelColor)
        _ = label(L10n.inlineHeading, size: 15, weight: .semibold)
        label(L10n.inlineExamples).font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        _ = label(L10n.codeBlockNote, color: .secondaryLabelColor)
        _ = label(L10n.betaNote, color: .secondaryLabelColor)
        let footer = NSStackView()
        footer.spacing = 12
        footer.addArrangedSubview(button(L10n.tryInNotes, #selector(ActionTarget.openNotes)))
        footer.addArrangedSubview(button(L10n.inputMonitoringSettings, #selector(ActionTarget.openInputMonitoringSettings)))
        stack.addArrangedSubview(footer)
        scrollToBeginning()
    }

    func update(status: String) { statusLabel.stringValue = status }

    func update(permission: String, toggleTitle: String) {
        permissionLabel.stringValue = permission
        toggleButton.title = toggleTitle
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Render the window offscreen for layout review. Never captures another app.
    func renderPreview(to path: String) throws {
        window.appearance = NSAppearance(named: .aqua)
        guard let view = window.contentView else { throw CocoaError(.fileWriteUnknown) }
        view.layoutSubtreeIfNeeded()
        scrollToBeginning()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileWriteUnknown) }
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: bitmap)
        }
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: URL(fileURLWithPath: path))
    }

    /// The document view is not flipped, so its top is at the highest y.
    private func scrollToBeginning() {
        window.contentView?.layoutSubtreeIfNeeded()
        guard let document = scrollView.documentView else { return }
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: max(0, document.bounds.height - scrollView.contentView.bounds.height)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

/// Target for the window's buttons, which need Objective-C selectors.
@MainActor private final class ActionTarget: NSObject {
    let actions: SetupWindowController.Actions

    init(actions: SetupWindowController.Actions) {
        self.actions = actions
    }

    @objc func toggleConversion() { actions.toggleConversion() }
    @objc func authorizeAccessibility() { actions.authorizeAccessibility() }
    @objc func openInputMonitoringSettings() { actions.openInputMonitoringSettings() }
    @objc func openNotes() { actions.openNotes() }
}
