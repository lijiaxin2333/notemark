import AppKit

/// Paints the window background so offscreen renders match the real window.
private final class SetupContentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}

/// One permission with its live status and a button that opens its settings pane.
@MainActor private final class PermissionRow {
    let view = NSStackView()
    private let icon = NSImageView()

    init(name: String, buttonTitle: String, target: AnyObject, action: Selector) {
        view.orientation = .horizontal
        view.spacing = 8
        icon.symbolConfiguration = .init(pointSize: 15, weight: .medium)
        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        let button = NSButton(title: buttonTitle, target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.setAccessibilityLabel(L10n.openSettings(for: name))
        view.addArrangedSubview(icon)
        view.addArrangedSubview(label)
        view.addArrangedSubview(button)
        update(granted: false)
    }

    /// VoiceOver reads the icon's description, then the permission name.
    func update(granted: Bool) {
        icon.image = NSImage(systemSymbolName: granted ? "checkmark.circle.fill" : "xmark.circle.fill",
                             accessibilityDescription: granted ? L10n.permissionGranted : L10n.permissionMissing)
        icon.contentTintColor = granted ? .systemGreen : .systemOrange
    }
}

/// The usage and permissions window.
@MainActor final class SetupWindowController {
    struct Actions {
        var toggleConversion: () -> Void
        var authorizeAccessibility: () -> Void
        var openInputMonitoringSettings: () -> Void
        var relaunch: () -> Void
        var showSettings: () -> Void
        var openNotes: () -> Void
    }

    private static let contentSize = NSSize(width: 620, height: 680)

    let window: NSWindow
    private let scrollView: NSScrollView
    private let statusLabel: NSTextField
    private let toggleButton: NSButton
    private let accessibilityRow: PermissionRow
    private let inputMonitoringRow: PermissionRow
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
        func row(_ views: [NSView]) {
            let row = NSStackView(views: views)
            row.orientation = .horizontal
            row.spacing = 10
            stack.addArrangedSubview(row)
        }

        _ = label(L10n.setupHeadline, size: 25, weight: .semibold)
        _ = label(L10n.setupIntroduction, size: 14, color: .secondaryLabelColor)
        _ = label(L10n.permissionsHeading, size: 15, weight: .semibold)
        accessibilityRow = PermissionRow(name: L10n.accessibilityPermissionName, buttonTitle: L10n.openPermissionSettings,
                                         target: target, action: #selector(ActionTarget.authorizeAccessibility))
        inputMonitoringRow = PermissionRow(name: L10n.inputMonitoringPermissionName, buttonTitle: L10n.openPermissionSettings,
                                           target: target, action: #selector(ActionTarget.openInputMonitoringSettings))
        stack.addArrangedSubview(accessibilityRow.view)
        stack.addArrangedSubview(inputMonitoringRow.view)
        _ = label(L10n.permissionsNote, color: .secondaryLabelColor)
        toggleButton = button(L10n.pauseButton, #selector(ActionTarget.toggleConversion))
        row([toggleButton, button(L10n.relaunchButton, #selector(ActionTarget.relaunch)),
             button(L10n.settingsButton, #selector(ActionTarget.showSettings))])
        statusLabel = label(status, color: .secondaryLabelColor)
        _ = label(L10n.paragraphMarkersHeading, size: 15, weight: .semibold)
        for (syntax, meaning) in L10n.cheatSheet {
            let left = NSTextField(labelWithString: syntax)
            left.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
            left.widthAnchor.constraint(equalToConstant: 200).isActive = true
            let right = NSTextField(wrappingLabelWithString: meaning)
            right.textColor = .secondaryLabelColor
            let line = NSStackView(views: [left, right])
            line.alignment = .firstBaseline
            line.spacing = 18
            stack.addArrangedSubview(line)
            right.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -218).isActive = true
        }
        _ = label(L10n.fullWidthNote, color: .secondaryLabelColor)
        _ = label(L10n.slashHeading, size: 15, weight: .semibold)
        _ = label(L10n.slashExplanation, color: .secondaryLabelColor)
        _ = label(L10n.inlineHeading, size: 15, weight: .semibold)
        label(L10n.inlineExamples).font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        _ = label(L10n.codeBlockNote, color: .secondaryLabelColor)
        _ = label(L10n.literalTextNote, color: .secondaryLabelColor)
        _ = label(L10n.betaNote, color: .secondaryLabelColor)
        row([button(L10n.tryInNotes, #selector(ActionTarget.openNotes))])
        scrollToBeginning()
    }

    func update(status: String) { statusLabel.stringValue = status }

    func update(accessibility: Bool, inputMonitoring: Bool, toggleTitle: String) {
        accessibilityRow.update(granted: accessibility)
        inputMonitoringRow.update(granted: inputMonitoring)
        toggleButton.title = toggleTitle
    }

    /// Bring the guide forward. Without `activating`, keyboard focus stays
    /// where the user is typing, as when NoteMark itself notices a problem.
    func show(activating: Bool = true) {
        guard activating else {
            window.orderFrontRegardless()
            return
        }
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
    @objc func relaunch() { actions.relaunch() }
    @objc func showSettings() { actions.showSettings() }
    @objc func openNotes() { actions.openNotes() }
}
