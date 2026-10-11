import AppKit
import ApplicationServices
import NoteMarkCore

final class ConversionEngine {
    var onStatus: ((String) -> Void)?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var busy: EditorSnapshot?
    private var buffered: [CGEvent] = []
    private(set) var running = false
    private var timeoutCount = 0
    private var recentInput = ""
    private let slashPanel = SlashCommandPanel()
    private var slashUpdate: Task<Void, Never>?
    private var slashTracking = false
    private var slashSuppressed = false
    private var workspaceObserver: NSObjectProtocol?
    private var emptyHeading: (snapshot: EditorSnapshot, cancellation: EmptyHeadingCancellation)?

    init() {
        slashPanel.onChoose = { [weak self] command in
            _ = self?.executeSlash(command, original: nil)
        }
    }

    func start() -> Bool {
        stop()
        guard AXIsProcessTrusted() else { onStatus?("请先开启辅助功能权限"); return false }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp,
                    .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel]
            .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<ConversionEngine>.fromOpaque(pointer).takeUnretainedValue()
            return engine.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            onStatus?("无法监听输入：请检查辅助功能与输入监控权限，并重新启动 NoteMark")
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        running = true
        timeoutCount = 0
        recentInput = ""
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                                               object: nil, queue: .main) { [weak self] _ in
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != NotesAccessibility.bundleID {
                self?.dismissSlash()
                self?.emptyHeading = nil
            }
        }
        onStatus?("已开启 · 在备忘录中输入 Markdown")
        return true
    }

    func stop() {
        emptyHeading = nil
        dismissSlash()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        workspaceObserver = nil
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        tap = nil
        runLoopSource = nil
        running = false
        // A running conversion completes and replays its queued input before stopping.
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            timeoutCount += 1
            if timeoutCount < 3, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            else { stop(); onStatus?("输入监听已暂停，请在菜单中重新开启") }
            return false
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Keyboard.marker else { return false }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == NotesAccessibility.bundleID else {
            emptyHeading = nil
            recentInput = ""
            dismissSlash()
            return false
        }
        if busy != nil {
            // Preserve rapid typing while the native editor acknowledges an edit.
            if let copy = event.copy() { buffered.append(copy) }
            return true
        }
        if type == .scrollWheel { emptyHeading = nil; dismissSlash(); return false }
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) {
            emptyHeading = nil
            if !slashPanel.containsMouse() { recentInput = ""; dismissSlash() }
            return false
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if running, type == .keyDown {
            let modifiers = event.flags.intersection([.maskShift, .maskCommand, .maskControl, .maskAlternate])
            let cancelKey = ([51, 53].contains(key) && modifiers.isEmpty) ||
                            (key == 40 && modifiers == .maskControl)
            if cancelKey, !slashPanel.isVisible, let heading = emptyHeading,
               !NotesAccessibility.isComposing(), NotesAccessibility.sameFocus(heading.snapshot),
               let snapshot = NotesAccessibility.snapshot(),
               let plan = heading.cancellation.plan(beforeCaret: snapshot.before, windowStart: snapshot.windowStart,
                                                    afterCaret: snapshot.after, selection: snapshot.selection) {
                emptyHeading = nil
                recentInput = ""
                dismissSlash()
                beginConversion(plan, snapshot: snapshot, original: event.copy(), cancellation: heading.cancellation)
                return true
            }
            // Typing, navigation, and other shortcuts end the initial empty-heading state.
            emptyHeading = nil
        }
        if type == .keyDown, !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            dismissSlash()
            recentInput = ""
            return false
        }
        guard running, type == .keyDown,
              event.getIntegerValueField(.keyboardEventAutorepeat) == 0 ||
                (slashPanel.isVisible && [125, 126].contains(event.getIntegerValueField(.keyboardEventKeycode))),
              event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else { return false }
        if slashPanel.isVisible && !event.flags.contains(.maskShift) {
            if NotesAccessibility.isComposing() {
                scheduleSlashUpdate()
                return false // Candidate navigation and confirmation belong to the IME.
            }
            if key == 126 || key == 125 {
                slashUpdate?.cancel()
                updateSlashMenu()
                slashPanel.move(key == 126 ? -1 : 1)
                return true
            }
            if key == 53 { dismissSlash(); slashSuppressed = true; return true }
            if key == 36 || key == 76 || key == 48 {
                if let selected = slashPanel.selected, executeSlash(selected, original: event.copy()) { return true }
                dismissSlash()
            }
        }
        let trigger: Trigger
        if key == 49 { trigger = .space }
        else if key == 36 || key == 76 { trigger = .enter }
        else {
            if key == 51 {
                if !recentInput.isEmpty { recentInput.removeLast() }
                if slashTracking { scheduleSlashUpdate() }
                return false
            }
            if [123, 124, 125, 126, 115, 119, 116, 121, 48, 53].contains(key) {
                recentInput = ""; dismissSlash(); return false
            }
            var count = 0
            var characters = [UniChar](repeating: 0, count: 16)
            event.keyboardGetUnicodeString(maxStringLength: 16, actualStringLength: &count, unicodeString: &characters)
            let typed = String(utf16CodeUnits: characters, count: count)
            recentInput += typed
            recentInput = String(recentInput.suffix(64))
            if typed.contains("/") { slashSuppressed = false; slashTracking = true }
            if slashTracking && !slashSuppressed { scheduleSlashUpdate() }
            return false
        }
        guard !event.flags.contains(.maskShift) else { recentInput = ""; return false }
        // Avoid Accessibility round trips on ordinary prose spaces and returns.
        let mayMatch = recentInput.last.map { "#*_`~].>)".contains($0) } ?? false
        let slashCommand = recentInput.hasPrefix("/") || recentInput.contains("\n/")
        if slashSuppressed && slashCommand {
            recentInput = trigger == .enter ? "\n" : ""
            if trigger == .enter { slashSuppressed = false }
            return false
        }
        dismissSlash()
        guard mayMatch || slashCommand || recentInput.contains("```") || ["-", "[]", "[ ]", "- [ ]", "1."].contains(recentInput) else {
            recentInput = trigger == .space ? "" : "\n"
            return false
        }
        recentInput = ""
        guard let snapshot = NotesAccessibility.snapshot(),
              let plan = MarkdownRule.plan(beforeCaret: snapshot.before, windowStart: snapshot.windowStart,
                                           trigger: trigger, isMonospaced: snapshot.isMonospaced,
                                           afterCaret: snapshot.after, rightBoundaryKnown: snapshot.rightBoundaryKnown) else { return false }
        beginConversion(plan, snapshot: snapshot, original: event.copy())
        return true
    }

    private func beginConversion(_ plan: EditPlan, snapshot: EditorSnapshot, original: CGEvent?,
                                 cancellation: EmptyHeadingCancellation? = nil) {
        // Menu traversal and editing run outside the event-tap callback.
        busy = snapshot
        Task { @MainActor [weak self] in
            guard let self else { return }
            let converted = await self.apply(plan, snapshot: snapshot, cancellation: cancellation)
            if !converted, let original, NotesAccessibility.sameFocus(snapshot),
               NotesAccessibility.setSelection(snapshot.element, range: snapshot.selection) {
                Keyboard.replay(original, pid: snapshot.pid)
            }
            let queued = self.buffered
            self.buffered.removeAll()
            self.busy = nil
            // Reprocess queued user input so an immediate heading cancellation is recognized.
            for event in queued { Keyboard.replay(event, reprocess: true) }
        }
    }

    private func dismissSlash() {
        slashUpdate?.cancel()
        slashUpdate = nil
        slashTracking = false
        slashPanel.dismiss()
    }

    private func scheduleSlashUpdate(delay: UInt64 = 40_000_000) {
        slashUpdate?.cancel()
        slashUpdate = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.updateSlashMenu()
        }
    }

    private func updateSlashMenu() {
        guard running, busy == nil, !slashSuppressed else { dismissSlash(); return }
        if NotesAccessibility.isComposing() {
            slashTracking = true
            scheduleSlashUpdate(delay: 150_000_000)
            return
        }
        guard
              let snapshot = NotesAccessibility.snapshot(),
              let query = SlashQuery.parse(beforeCaret: snapshot.before, windowStart: snapshot.windowStart,
                                           afterCaret: snapshot.after, isMonospaced: snapshot.isMonospaced),
              let bounds = NotesAccessibility.caretBounds(snapshot) else { dismissSlash(); return }
        slashTracking = true
        slashPanel.show(query: query.query, anchor: bounds)
    }

    private func executeSlash(_ requested: SlashCommand, original: CGEvent?) -> Bool {
        guard running, busy == nil, let snapshot = NotesAccessibility.snapshot(),
              let query = SlashQuery.parse(beforeCaret: snapshot.before, windowStart: snapshot.windowStart,
                                           afterCaret: snapshot.after, isMonospaced: snapshot.isMonospaced) else {
            dismissSlash(); return false
        }
        let results = SlashCommand.matching(query.query)
        // Typing immediately before Return may precede the debounced panel update.
        let command = query.query == slashPanel.currentQuery ? results.first(where: { $0.id == requested.id }) : results.first
        guard let command else { dismissSlash(); return false }
        dismissSlash()
        recentInput = ""
        beginConversion(query.plan(for: command), snapshot: snapshot, original: original)
        return true
    }

    private func apply(_ plan: EditPlan, snapshot: EditorSnapshot, cancellation: EmptyHeadingCancellation?) async -> Bool {
        guard NotesAccessibility.sameFocus(snapshot),
              NotesAccessibility.selectedRange(snapshot.element) == snapshot.selection,
              NotesAccessibility.text(snapshot.element, range: plan.range) == plan.original else { return false }
        switch plan.conversion {
        case .paragraph(let style):
            guard let command = NotesAccessibility.command(for: style, pid: snapshot.pid) else {
                onStatus?(cancellation != nil ? "无法切换正文，已保留原按键操作" : "当前编辑器没有提供可用的格式命令，已保留 Markdown")
                return false
            }
            if let cancellation {
                guard let current = NotesAccessibility.snapshot(), NotesAccessibility.sameFocus(snapshot),
                      cancellation.plan(beforeCaret: current.before, windowStart: current.windowStart,
                                        afterCaret: current.after, selection: current.selection) == plan else { return false }
            }
            guard NotesAccessibility.selectedRange(snapshot.element) == snapshot.selection,
                  NotesAccessibility.sameFocus(snapshot),
                  NotesAccessibility.setSelection(snapshot.element, range: plan.range) else {
                onStatus?(cancellation != nil ? "无法切换正文，已保留原按键操作" : "当前编辑器没有提供可用的格式命令，已保留 Markdown")
                return false
            }
            if plan.range.length > 0 {
                Keyboard.post(51, pid: snapshot.pid) // Native delete, preserving the surrounding note.
                guard await waitForSelection(NSRange(location: plan.range.location, length: 0), snapshot: snapshot) else {
                    onStatus?("编辑器响应未确认；请检查刚才的输入，必要时按 ⌘Z 撤销")
                    return true // Do not duplicate the swallowed delimiter after a partial edit.
                }
            }
            guard NotesAccessibility.sameFocus(snapshot),
                  AXUIElementPerformAction(command, kAXPressAction as CFString) == .success else {
                onStatus?(cancellation != nil ? "正文格式未切换，已保留原按键操作" : "原生格式命令未执行；可按 ⌘Z 恢复标记")
                return plan.range.length > 0
            }
            if running, let cancellation = EmptyHeadingCancellation(style: style, paragraphStart: plan.range.location) {
                emptyHeading = (snapshot, cancellation)
            } else { emptyHeading = nil }
            onStatus?(cancellation != nil ? "已恢复正文 · 空标题已取消" : "已转换 · 采用备忘录原生格式")
            return true
        case .inline(let style, let text, let delimiter):
            guard let attributes = snapshot.baseAttributes,
                  attributes[.font] is NSFont else {
                onStatus?("无法读取当前字体，已保留 Markdown")
                return false
            }
            guard let replacement = InlineRenderer.render(style: style, text: text, delimiter: delimiter,
                                                            attributes: attributes) else { return false }
            guard let data = try? replacement.data(from: NSRange(location: 0, length: replacement.length),
                                                   documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]),
                  NotesAccessibility.sameFocus(snapshot),
                  NotesAccessibility.setSelection(snapshot.element, range: plan.range) else { return false }
            let clipboard = ClipboardSnapshot()
            let board = NSPasteboard.general
            board.clearContents()
            guard board.setData(data, forType: .rtf) else {
                clipboard.restore(ifChangeCount: board.changeCount)
                _ = NotesAccessibility.setSelection(snapshot.element, range: snapshot.selection)
                return false
            }
            let count = board.changeCount
            Keyboard.post(9, flags: .maskCommand, pid: snapshot.pid) // Native paste creates an undoable edit.
            let newRange = NSRange(location: plan.range.location, length: replacement.length)
            var verified = false
            for _ in 0..<12 {
                try? await Task.sleep(nanoseconds: 20_000_000)
                if NotesAccessibility.text(snapshot.element, range: newRange) == text + delimiter {
                    verified = true; break
                }
            }
            clipboard.restore(ifChangeCount: count)
            onStatus?(verified ? "已转换 · 保留当前字号" : "粘贴响应未确认；请检查刚才的输入，必要时按 ⌘Z 撤销")
            return true
        }
    }

    private func waitForSelection(_ range: NSRange, snapshot: EditorSnapshot) async -> Bool {
        for _ in 0..<12 {
            try? await Task.sleep(nanoseconds: 20_000_000)
            guard NotesAccessibility.sameFocus(snapshot) else { return false }
            if NotesAccessibility.selectedRange(snapshot.element) == range { return true }
        }
        return false
    }
}
