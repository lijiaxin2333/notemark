import AppKit
import ApplicationServices
import NoteMarkCore

private final class SetupContentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = ConversionEngine()
    private var statusItem: NSStatusItem!
    private var statusLabel: NSTextField?
    private var permissionLabel: NSTextField?
    private var toggleItem: NSMenuItem!
    private var toggleButton: NSButton?
    private var automaticConversion = AutomaticConversionPolicy()
    private var window: NSWindow?
    private var setupScroll: NSScrollView?
    private var timer: Timer?
    private var status = "等待权限 · 授权后自动开启转换"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.badge.checkmark", accessibilityDescription: "NoteMark")
        statusItem.button?.toolTip = "NoteMark · 备忘录 Markdown"
        let menu = NSMenu()
        let title = NSMenuItem(title: "NoteMark · 备忘录 Markdown", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        toggleItem = menu.addItem(withTitle: "开启 Markdown 转换", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        let help = menu.addItem(withTitle: "使用说明与权限…", action: #selector(showSettings), keyEquivalent: "")
        help.target = self
        let notes = menu.addItem(withTitle: "打开备忘录", action: #selector(openNotes), keyEquivalent: "")
        notes.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "退出 NoteMark", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
        engine.onStatus = { [weak self] status in
            self?.status = status
            self?.statusLabel?.stringValue = status
            self?.refresh()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkAutomaticStart()
            self?.refresh()
        }
        checkAutomaticStart()
        showSettings()
    }

    @objc private func toggle() {
        if engine.running {
            automaticConversion.pause()
            engine.stop()
            status = "已手动暂停"
        } else {
            automaticConversion.resume()
            checkAutomaticStart()
        }
        statusLabel?.stringValue = status
        refresh()
    }

    private func refresh() {
        toggleItem.title = engine.running ? "暂停 Markdown 转换" : automaticConversion.wantsConversion ? "重试输入连接" : "恢复 Markdown 转换"
        toggleItem.state = engine.running ? .on : .off
        statusItem.button?.appearsDisabled = !engine.running
        toggleButton?.title = engine.running ? "暂停转换" : automaticConversion.wantsConversion ? "重试连接" : "恢复转换"
        permissionLabel?.stringValue = AXIsProcessTrusted()
            ? (engine.running ? "✓ 辅助功能已授权 · 转换已开启" : "✓ 辅助功能已授权")
            : (automaticConversion.wantsConversion ? "需要辅助功能权限 · 授权后自动开启转换" : "需要辅助功能权限 · 当前已手动暂停")
    }

    private func checkAutomaticStart() {
        let permissions = ConversionPermissions(accessibility: AXIsProcessTrusted(),
                                                inputMonitoring: CGPreflightListenEventAccess())
        if !permissions.accessibility {
            if engine.running { engine.stop() }
            if automaticConversion.wantsConversion {
                status = "等待权限 · 授权后自动开启转换"
                statusLabel?.stringValue = status
            }
        }
        if automaticConversion.shouldStart(permissions: permissions, running: engine.running) {
            _ = engine.start()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        checkAutomaticStart()
        refresh()
    }

    @objc private func showSettings() {
        if window == nil { makeWindow() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 680),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "NoteMark"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = SetupContentView(frame: NSRect(x: 0, y: 0, width: 620, height: 680))
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        let scroll = NSScrollView(frame: content.bounds)
        setupScroll = scroll
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        content.addSubview(scroll)
        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -26)
        ])
        func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
            let field = NSTextField(wrappingLabelWithString: text)
            field.font = .systemFont(ofSize: size, weight: weight)
            field.textColor = color
            stack.addArrangedSubview(field)
            field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            return field
        }
        _ = label("在备忘录里，直接写 Markdown。", size: 25, weight: .semibold)
        _ = label("NoteMark 把输入标记转换为备忘录格式。转换后仍是普通 Apple 备忘录，可继续同步、编辑和插入图片。", size: 14, color: .secondaryLabelColor)
        permissionLabel = label("", weight: .medium)
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        let authorize = NSButton(title: "授权辅助功能", target: self, action: #selector(authorizeAccessibility))
        let enable = NSButton(title: "暂停转换", target: self, action: #selector(toggle))
        toggleButton = enable
        enable.bezelStyle = .rounded
        authorize.bezelStyle = .rounded
        buttons.addArrangedSubview(authorize)
        buttons.addArrangedSubview(enable)
        stack.addArrangedSubview(buttons)
        statusLabel = label(status, color: .secondaryLabelColor)
        _ = label("行首标记 → 按空格", size: 15, weight: .semibold)
        let cheats = [
            ("#  /  ##  /  ###", "标题 / 小标题 / 次级标题"),
            ("[]  或  [ ]", "待办清单"),
            ("-  /  *  /  1.", "圆点项目符号 / 圆点项目符号 / 编号列表"),
            (">", "引用"),
            ("```", "进入代码块；再次输入退出"),
            ("/h1  /h2  /h3  /body", "切换原生段落样式")
        ]
        for (syntax, description) in cheats {
            let row = NSStackView()
            row.spacing = 18
            let left = NSTextField(labelWithString: syntax)
            left.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
            left.widthAnchor.constraint(equalToConstant: 220).isActive = true
            let right = NSTextField(labelWithString: description)
            right.textColor = .secondaryLabelColor
            row.addArrangedSubview(left)
            row.addArrangedSubview(right)
            stack.addArrangedSubview(row)
        }
        _ = label("Slash 命令 → 在空行输入 /", size: 15, weight: .semibold)
        _ = label("光标旁弹出格式菜单。继续输入英文或中文筛选，↑↓ 选择，回车或 Tab 执行，Esc 关闭；也可以点击命令。", color: .secondaryLabelColor)
        _ = label("行内标记 → 写完后按空格或回车", size: 15, weight: .semibold)
        let inline = label("**粗体**   *斜体*   `代码`   ~~删除线~~\n[链接文字](https://example.com)")
        inline.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        _ = label("代码块也支持输入 ```swift 后按回车。段落使用备忘录原生字号；行内格式保留光标处的字号。", color: .secondaryLabelColor)
        _ = label("测试版：请先在新笔记里试用。转换可以用 ⌘Z 撤销；输入法组词中的文字会尽量保留。暂不支持嵌套 Markdown 或整篇转换。", color: .secondaryLabelColor)
        let footer = NSStackView()
        footer.spacing = 12
        let monitoring = NSButton(title: "输入监控设置…", target: self, action: #selector(openMonitoring))
        monitoring.bezelStyle = .rounded
        let open = NSButton(title: "打开备忘录试用", target: self, action: #selector(openNotes))
        open.bezelStyle = .rounded
        footer.addArrangedSubview(open)
        footer.addArrangedSubview(monitoring)
        stack.addArrangedSubview(footer)
        self.window = window
        scrollSetupToBeginning()
    }

    private func scrollSetupToBeginning() {
        window?.contentView?.layoutSubtreeIfNeeded()
        guard let scroll = setupScroll, let document = scroll.documentView else { return }
        scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, document.bounds.height - scroll.contentView.bounds.height)))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    /// Render our own setup view offscreen for layout QA; never captures another app.
    func renderSetup(to path: String) throws {
        makeWindow()
        window?.appearance = NSAppearance(named: .aqua)
        permissionLabel?.stringValue = "需要辅助功能权限 · 授权后自动开启转换"
        toggleButton?.title = "等待自动开启"
        guard let view = window?.contentView else { throw CocoaError(.fileWriteUnknown) }
        view.layoutSubtreeIfNeeded()
        scrollSetupToBeginning()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileWriteUnknown) }
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: bitmap)
        }
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: URL(fileURLWithPath: path))
    }

    @objc private func authorizeAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        checkAutomaticStart()
        refresh()
    }
    @objc private func openMonitoring() {
        _ = CGRequestListenEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func openNotes() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { engine.stop(); timer?.invalidate() }
}
