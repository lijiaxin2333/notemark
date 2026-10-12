import AppKit

/// A panel that shows text without taking keyboard focus from Notes.
private final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// A short message next to the caret when a conversion could not be
/// completed, so the user does not have to open the setup window to learn why.
@MainActor final class FeedbackToast {
    private enum Layout {
        static let maximumWidth: CGFloat = 320
        static let padding = NSSize(width: 12, height: 8)
        static let gap: CGFloat = 6
        static let screenMargin: CGFloat = 8
        static let cornerRadius: CGFloat = 8
    }

    private static let visibleDuration = Duration.milliseconds(1500)

    private var panel: ToastPanel?
    private var hideTask: Task<Void, Never>?

    /// Show `message` below the caret, or near the pointer when the caret is unknown.
    func show(_ message: String, near caret: CGRect?) {
        let panel = panel ?? makePanel()
        let label = NSTextField(wrappingLabelWithString: message)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.preferredMaxLayoutWidth = Layout.maximumWidth - 2 * Layout.padding.width
        let textSize = label.fittingSize
        let size = NSSize(width: min(Layout.maximumWidth, textSize.width + 2 * Layout.padding.width),
                          height: textSize.height + 2 * Layout.padding.height)
        label.frame = NSRect(origin: NSPoint(x: Layout.padding.width, y: Layout.padding.height),
                             size: NSSize(width: size.width - 2 * Layout.padding.width, height: textSize.height))
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Layout.cornerRadius
        background.layer?.masksToBounds = true
        background.addSubview(label)
        panel.contentView = background
        panel.setFrame(frame(for: size, near: caret), display: true)
        panel.orderFrontRegardless()
        // Announcements are posted for the application element.
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleDuration)
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }

    private func frame(for size: NSSize, near caret: CGRect?) -> NSRect {
        let anchor = caret ?? CGRect(origin: NSEvent.mouseLocation, size: .zero)
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) } ?? NSScreen.main
        let visible = (screen?.visibleFrame ?? .zero).insetBy(dx: Layout.screenMargin, dy: Layout.screenMargin)
        var origin = NSPoint(x: anchor.minX, y: anchor.minY - Layout.gap - size.height)
        if origin.y < visible.minY { origin.y = anchor.maxY + Layout.gap }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        return NSRect(origin: origin, size: size)
    }

    private func makePanel() -> ToastPanel {
        let panel = ToastPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.panel = panel
        return panel
    }
}
