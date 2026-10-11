import AppKit

enum Keyboard {
    static let marker: Int64 = 0x4E4F54454D41524B
    static func post(_ key: CGKeyCode, flags: CGEventFlags = [], pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.postToPid(pid)
        }
    }
    static func replay(_ event: CGEvent, pid: pid_t? = nil) {
        event.setIntegerValueField(.eventSourceUserData, value: marker)
        if let pid { event.postToPid(pid) }
        else { event.post(tap: .cghidEventTap) }
    }
}

struct ClipboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
    init() {
        items = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var values: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { values[type] = data } }
            return values
        }
    }
    func restore(ifChangeCount expected: Int) {
        let board = NSPasteboard.general
        guard board.changeCount == expected else { return }
        let restored = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        board.clearContents()
        board.writeObjects(restored)
    }
}
