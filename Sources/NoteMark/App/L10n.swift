import Foundation

/// User-visible text. Keys are stable identifiers; the default values are the
/// app's current Chinese interface, used until a localization is added.
enum L10n {
    // MARK: App and menu

    static var appMenuTitle: String { String(localized: "app.menuTitle", defaultValue: "NoteMark · 备忘录 Markdown") }
    static var enableConversion: String { String(localized: "menu.enable", defaultValue: "开启 Markdown 转换") }
    static var pauseConversion: String { String(localized: "menu.pause", defaultValue: "暂停 Markdown 转换") }
    static var retryInputConnection: String { String(localized: "menu.retry", defaultValue: "重试输入连接") }
    static var resumeConversion: String { String(localized: "menu.resume", defaultValue: "恢复 Markdown 转换") }
    static var helpAndPermissions: String { String(localized: "menu.help", defaultValue: "使用说明与权限…") }
    static var openNotes: String { String(localized: "menu.openNotes", defaultValue: "打开备忘录") }
    static var quit: String { String(localized: "menu.quit", defaultValue: "退出 NoteMark") }

    // MARK: Status

    static var waitingForPermission: String { String(localized: "status.waitingForPermission", defaultValue: "等待权限 · 授权后自动开启转换") }
    static var pausedManually: String { String(localized: "status.pausedManually", defaultValue: "已手动暂停") }
    static var accessibilityRequired: String { String(localized: "status.accessibilityRequired", defaultValue: "请先开启辅助功能权限") }
    static var inputListeningUnavailable: String {
        String(localized: "status.inputListeningUnavailable", defaultValue: "无法监听输入：请检查辅助功能与输入监控权限，并重新启动 NoteMark")
    }
    static var conversionEnabled: String { String(localized: "status.enabled", defaultValue: "已开启 · 在备忘录中输入 Markdown") }
    static var inputListeningPaused: String { String(localized: "status.inputListeningPaused", defaultValue: "输入监听已暂停，请在菜单中重新开启") }
    static var snapshotUnavailableOrComposing: String {
        String(localized: "status.notConverted.unreadable", defaultValue: "未转换 · 无法读取正文光标，或输入法正在组词")
    }
    static var markdownDetected: String { String(localized: "status.markdownDetected", defaultValue: "已检测 Markdown 标记 · 等待编辑器更新") }
    static var editorSnapshotUnavailable: String { String(localized: "diagnostic.snapshotUnavailable", defaultValue: "编辑器快照不可用") }
    static func noRuleMatched(_ diagnostic: String) -> String {
        String(localized: "status.noRuleMatched", defaultValue: "未匹配转换规则 · \(diagnostic)")
    }
    /// Values are passed as text so numbers keep ASCII digits in every locale.
    static func ruleDiagnostic(prefixLength: String, checklistMarker: Bool, trimmedChecklistMarker: Bool, monospaced: Bool,
                               lineStartKnown: Bool, rightBoundaryKnown: Bool, rightLength: String, containsImage: Bool) -> String {
        String(localized: "diagnostic.rule", defaultValue: """
            前缀长度=\(prefixLength)，待办标记=\(String(checklistMarker))，去空格后待办=\(String(trimmedChecklistMarker))，\
            等宽=\(String(monospaced))，行首边界=\(String(lineStartKnown))，右边界=\(String(rightBoundaryKnown))，\
            右侧长度=\(rightLength)，含图片=\(String(containsImage))
            """)
    }
    static var unknownLength: String { String(localized: "diagnostic.unknownLength", defaultValue: "未知") }

    // MARK: Editing results

    static var bodyRestoreUnavailable: String { String(localized: "edit.bodyUnavailable", defaultValue: "无法切换正文，已保留原按键操作") }
    static var checklistCommandUnavailable: String {
        String(localized: "edit.checklistUnavailable", defaultValue: "待办命令不可用 · 请检查备忘录「格式 → 核对清单」是否可用；已保留 Markdown")
    }
    static var formatCommandUnavailable: String {
        String(localized: "edit.formatUnavailable", defaultValue: "当前编辑器没有提供可用的格式命令，已保留 Markdown")
    }
    static var editorResponseUnconfirmed: String {
        String(localized: "edit.responseUnconfirmed", defaultValue: "编辑器响应未确认；请检查刚才的输入，必要时按 ⌘Z 撤销")
    }
    static var quoteExitedBodyFailed: String { String(localized: "edit.quoteExitedBodyFailed", defaultValue: "引用已退出，但正文命令未执行") }
    static var bodyNotRestored: String { String(localized: "edit.bodyNotRestored", defaultValue: "正文格式未切换，已保留原按键操作") }
    static var formatCommandFailed: String { String(localized: "edit.formatFailed", defaultValue: "原生格式命令未执行；可按 ⌘Z 恢复标记") }
    static var terminalParagraphUnconfirmed: String {
        String(localized: "edit.terminalParagraphUnconfirmed", defaultValue: "部分空行已恢复正文；末尾段落未确认，请再按一次取消键")
    }
    static var caretUnconfirmed: String {
        String(localized: "edit.caretUnconfirmed", defaultValue: "格式已切换正文，但光标位置未确认；请检查光标后再继续删除")
    }
    static var bodyRestored: String { String(localized: "edit.bodyRestored", defaultValue: "已恢复正文 · 空格式段落已取消") }
    static var checklistConverted: String { String(localized: "edit.checklistConverted", defaultValue: "已转换 · 原生待办清单") }
    static var paragraphConverted: String { String(localized: "edit.paragraphConverted", defaultValue: "已转换 · 采用备忘录原生格式") }
    static var fontUnavailable: String { String(localized: "edit.fontUnavailable", defaultValue: "无法读取当前字体，已保留 Markdown") }
    static var inlineConverted: String { String(localized: "edit.inlineConverted", defaultValue: "已转换 · 保留当前字号") }
    static var pasteUnconfirmed: String {
        String(localized: "edit.pasteUnconfirmed", defaultValue: "粘贴响应未确认；请检查刚才的输入，必要时按 ⌘Z 撤销")
    }

    // MARK: Setup window

    static var setupHeadline: String { String(localized: "setup.headline", defaultValue: "在备忘录里，直接写 Markdown。") }
    static var setupIntroduction: String {
        String(localized: "setup.introduction", defaultValue: "NoteMark 把输入标记转换为备忘录格式。转换后仍是普通 Apple 备忘录，可继续同步、编辑和插入图片。")
    }
    static var authorizeAccessibility: String { String(localized: "setup.authorizeAccessibility", defaultValue: "授权辅助功能") }
    static var pauseButton: String { String(localized: "setup.pause", defaultValue: "暂停转换") }
    static var retryButton: String { String(localized: "setup.retry", defaultValue: "重试连接") }
    static var resumeButton: String { String(localized: "setup.resume", defaultValue: "恢复转换") }
    static var waitingForAutomaticStart: String { String(localized: "setup.waitingForAutomaticStart", defaultValue: "等待自动开启") }
    static var accessibilityGrantedRunning: String {
        String(localized: "setup.permission.grantedRunning", defaultValue: "✓ 辅助功能已授权 · 转换已开启")
    }
    static var accessibilityGranted: String { String(localized: "setup.permission.granted", defaultValue: "✓ 辅助功能已授权") }
    static var accessibilityNeededAutomatic: String {
        String(localized: "setup.permission.neededAutomatic", defaultValue: "需要辅助功能权限 · 授权后自动开启转换")
    }
    static var accessibilityNeededPaused: String {
        String(localized: "setup.permission.neededPaused", defaultValue: "需要辅助功能权限 · 当前已手动暂停")
    }
    static var paragraphMarkersHeading: String { String(localized: "setup.paragraphMarkers", defaultValue: "行首标记 → 按空格") }
    static var cheatSheet: [(syntax: String, meaning: String)] {
        [
            ("#  /  ##  /  ###", String(localized: "setup.cheat.headings", defaultValue: "标题 / 小标题 / 次级标题")),
            (String(localized: "setup.cheat.checklistSyntax", defaultValue: "[]  或  [ ]"),
             String(localized: "setup.cheat.checklist", defaultValue: "待办清单")),
            ("-  /  *  /  1.", String(localized: "setup.cheat.lists", defaultValue: "圆点项目符号 / 圆点项目符号 / 编号列表")),
            (">", String(localized: "setup.cheat.quote", defaultValue: "引用")),
            ("```", String(localized: "setup.cheat.code", defaultValue: "进入代码块；再次输入退出")),
            ("/h1  /h2  /h3  /body", String(localized: "setup.cheat.slash", defaultValue: "切换原生段落样式"))
        ]
    }
    static var slashHeading: String { String(localized: "setup.slashHeading", defaultValue: "Slash 命令 → 在空行输入 /") }
    static var slashExplanation: String {
        String(localized: "setup.slashExplanation", defaultValue: "光标旁弹出格式菜单。继续输入英文或中文筛选，↑↓ 选择，回车或 Tab 执行，Esc 关闭；也可以点击命令。")
    }
    static var inlineHeading: String { String(localized: "setup.inlineHeading", defaultValue: "行内标记 → 写完后按空格或回车") }
    static var inlineExamples: String {
        String(localized: "setup.inlineExamples", defaultValue: "**粗体**   *斜体*   `代码`   ~~删除线~~\n[链接文字](https://example.com)")
    }
    static var codeBlockNote: String {
        String(localized: "setup.codeBlockNote", defaultValue: "代码块也支持输入 ```swift 后按回车。段落使用备忘录原生字号；行内格式保留光标处的字号。")
    }
    static var betaNote: String {
        String(localized: "setup.betaNote", defaultValue: "测试版：请先在新笔记里试用。转换可以用 ⌘Z 撤销；输入法组词中的文字会尽量保留。暂不支持嵌套 Markdown 或整篇转换。")
    }
    static var inputMonitoringSettings: String { String(localized: "setup.inputMonitoringSettings", defaultValue: "输入监控设置…") }
    static var tryInNotes: String { String(localized: "setup.tryInNotes", defaultValue: "打开备忘录试用") }

    // MARK: Slash menu

    static var slashMenuTitle: String { String(localized: "slash.title", defaultValue: "段落格式") }
    static func slashSearch(_ query: String) -> String { String(localized: "slash.search", defaultValue: "搜索：\(query)") }
    static var slashFooter: String { String(localized: "slash.footer", defaultValue: "↑↓ 选择    ↩ / Tab 执行    Esc 关闭") }
    static var slashNoMatches: String { String(localized: "slash.noMatches", defaultValue: "没有匹配命令，Esc 关闭并保留文字") }
    static func slashCommandAccessibilityLabel(title: String, detail: String, alias: String) -> String {
        String(localized: "slash.commandLabel", defaultValue: "\(title)，\(detail)，/\(alias)")
    }
}
