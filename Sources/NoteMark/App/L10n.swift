import Foundation
import NoteMarkCore

/// User-visible text. English is the development language; translations live
/// in `Packaging/Resources/<language>.lproj/Localizable.strings`.
enum L10n {
    // MARK: App and menu

    static var appMenuTitle: String { String(localized: "app.menuTitle", defaultValue: "NoteMark · Markdown for Notes") }
    static var enableConversion: String { String(localized: "menu.enable", defaultValue: "Turn On Markdown Conversion") }
    static var pauseConversion: String { String(localized: "menu.pause", defaultValue: "Pause Markdown Conversion") }
    static var retryInputConnection: String { String(localized: "menu.retry", defaultValue: "Retry Input Connection") }
    static var resumeConversion: String { String(localized: "menu.resume", defaultValue: "Resume Markdown Conversion") }
    static var settingsMenuItem: String { String(localized: "menu.settings", defaultValue: "Settings…") }
    static var helpAndPermissions: String { String(localized: "menu.help", defaultValue: "Guide and Permissions…") }
    static var openNotes: String { String(localized: "menu.openNotes", defaultValue: "Open Notes") }
    static var quit: String { String(localized: "menu.quit", defaultValue: "Quit NoteMark") }
    static var windowMenu: String { String(localized: "menu.window", defaultValue: "Window") }
    static var closeWindow: String { String(localized: "menu.close", defaultValue: "Close") }
    static var minimizeWindow: String { String(localized: "menu.minimize", defaultValue: "Minimize") }
    static var editMenu: String { String(localized: "menu.edit", defaultValue: "Edit") }
    static var copy: String { String(localized: "menu.copy", defaultValue: "Copy") }
    static var selectAll: String { String(localized: "menu.selectAll", defaultValue: "Select All") }

    // MARK: Menu bar state

    static var stateRunning: String { String(localized: "state.running", defaultValue: "Conversion On") }
    static var statePaused: String { String(localized: "state.paused", defaultValue: "Paused") }
    static var stateNeedsPermission: String { String(localized: "state.needsPermission", defaultValue: "Needs Permission") }
    static var stateUnavailable: String { String(localized: "state.unavailable", defaultValue: "Can't Listen for Input") }

    // MARK: Status

    static var waitingForPermission: String {
        String(localized: "status.waitingForPermission", defaultValue: "Waiting for permission · Conversion starts once it is granted")
    }
    static var pausedManually: String { String(localized: "status.pausedManually", defaultValue: "Paused") }
    static var accessibilityRequired: String {
        String(localized: "status.accessibilityRequired", defaultValue: "Turn on the “\(accessibilityPermissionName)” permission first")
    }
    static var inputListeningUnavailable: String {
        String(localized: "status.inputListeningUnavailable",
               defaultValue: "Can't listen for input. Check “\(accessibilityPermissionName)” and “\(inputMonitoringPermissionName)” in \(privacyPaneName), then reopen NoteMark.")
    }
    static var conversionEnabled: String { String(localized: "status.enabled", defaultValue: "On · Type Markdown in Notes") }
    static var inputListeningPaused: String {
        String(localized: "status.inputListeningPaused", defaultValue: "Input listening stopped. Turn it on again from the menu.")
    }
    static var snapshotUnavailableOrComposing: String {
        String(localized: "status.notConverted.unreadable",
               defaultValue: "Not converted · The caret couldn't be read, or an input method is composing")
    }
    static var markdownDetected: String { String(localized: "status.markdownDetected", defaultValue: "Markdown detected · Waiting for Notes") }

    // MARK: Editing results

    static var bodyRestoreUnavailable: String {
        String(localized: "edit.bodyUnavailable", defaultValue: "Couldn't switch to Body. The key was typed as usual.")
    }
    static var checklistCommandUnavailable: String {
        String(localized: "edit.checklistUnavailable",
               defaultValue: "Checklists aren't available here (Format > Checklist). The Markdown was kept.")
    }
    static var formatCommandUnavailable: String {
        String(localized: "edit.formatUnavailable", defaultValue: "Notes doesn't offer this format here. The Markdown was kept.")
    }
    static var editorResponseUnconfirmed: String {
        String(localized: "edit.responseUnconfirmed", defaultValue: "Notes didn't confirm the edit. Check your text, and press ⌘Z if needed.")
    }
    static var quoteExitedBodyFailed: String {
        String(localized: "edit.quoteExitedBodyFailed", defaultValue: "Left the quote, but Body wasn't applied.")
    }
    static var bodyNotRestored: String {
        String(localized: "edit.bodyNotRestored", defaultValue: "Body wasn't applied. The key was typed as usual.")
    }
    static var formatCommandFailed: String {
        String(localized: "edit.formatFailed", defaultValue: "Notes didn't apply the format. Press ⌘Z to get the marker back.")
    }
    static var terminalParagraphUnconfirmed: String {
        String(localized: "edit.terminalParagraphUnconfirmed",
               defaultValue: "Some blank lines returned to Body. Press the key again for the last one.")
    }
    static var caretUnconfirmed: String {
        String(localized: "edit.caretUnconfirmed",
               defaultValue: "Switched to Body, but the caret position wasn't confirmed. Check it before deleting more.")
    }
    static var bodyRestored: String { String(localized: "edit.bodyRestored", defaultValue: "Back to Body · Empty format removed") }
    static var checklistConverted: String { String(localized: "edit.checklistConverted", defaultValue: "Converted · Native checklist") }
    static var paragraphConverted: String { String(localized: "edit.paragraphConverted", defaultValue: "Converted · Native Notes format") }
    static var fontUnavailable: String {
        String(localized: "edit.fontUnavailable", defaultValue: "Couldn't read the current font. The Markdown was kept.")
    }
    static var inlineConverted: String { String(localized: "edit.inlineConverted", defaultValue: "Converted · Font size kept") }
    static var pasteUnconfirmed: String {
        String(localized: "edit.pasteUnconfirmed", defaultValue: "Notes didn't confirm the paste. Check your text, and press ⌘Z if needed.")
    }
    static var dividerUnavailable: String {
        String(localized: "edit.dividerUnavailable",
               defaultValue: "Notes can't insert a divider line here. The text was kept.")
    }
    static var dividerInserted: String { String(localized: "edit.dividerInserted", defaultValue: "Inserted · Native divider line") }
    static var dateInserted: String { String(localized: "edit.dateInserted", defaultValue: "Inserted · Today's date") }
    static var markerKept: String { String(localized: "edit.markerKept", defaultValue: "Kept the marker as text") }

    // MARK: Permissions

    /// macOS 27 renamed the Accessibility privacy pane.
    static var accessibilityPermissionName: String {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
            ? String(localized: "permission.accessibility", defaultValue: "Device Control and Data Access")
            : String(localized: "permission.accessibility.legacy", defaultValue: "Accessibility")
    }
    /// macOS 27 renamed the Simplified Chinese Privacy & Security pane.
    static var privacyPaneName: String {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
            ? String(localized: "permission.privacyPane", defaultValue: "Privacy & Security")
            : String(localized: "permission.privacyPane.legacy", defaultValue: "Privacy & Security")
    }
    static func openSettings(for permission: String) -> String {
        String(localized: "permission.openSettingsFor", defaultValue: "Open Settings for “\(permission)”")
    }
    static var inputMonitoringPermissionName: String {
        String(localized: "permission.inputMonitoring", defaultValue: "Input Monitoring")
    }
    static var permissionGranted: String { String(localized: "permission.granted", defaultValue: "granted") }
    static var permissionMissing: String { String(localized: "permission.missing", defaultValue: "not granted") }

    // MARK: Setup window

    static var setupHeadline: String { String(localized: "setup.headline", defaultValue: "Write Markdown right in Notes.") }
    static var setupIntroduction: String {
        String(localized: "setup.introduction",
               defaultValue: "NoteMark turns the Markdown you type into Notes formatting. Your notes stay ordinary Apple Notes: they sync, edit, and hold images as usual.")
    }
    static var permissionsHeading: String { String(localized: "setup.permissionsHeading", defaultValue: "Permissions") }
    static var openPermissionSettings: String { String(localized: "setup.openPermissionSettings", defaultValue: "Open Settings…") }
    static var permissionsNote: String {
        String(localized: "setup.permissionsNote",
               defaultValue: "Turn on NoteMark for both under \(privacyPaneName). Conversion starts automatically once permission is ready. If you just turned on “\(inputMonitoringPermissionName)”, reopen NoteMark.")
    }
    static var pauseButton: String { String(localized: "setup.pause", defaultValue: "Pause") }
    static var retryButton: String { String(localized: "setup.retry", defaultValue: "Retry") }
    static var resumeButton: String { String(localized: "setup.resume", defaultValue: "Resume") }
    static var relaunchButton: String { String(localized: "setup.relaunch", defaultValue: "Reopen NoteMark") }
    static var settingsButton: String { String(localized: "setup.settings", defaultValue: "Settings…") }
    static var waitingForAutomaticStart: String { String(localized: "setup.waitingForAutomaticStart", defaultValue: "Waiting to Start") }
    static var paragraphMarkersHeading: String { String(localized: "setup.paragraphMarkers", defaultValue: "Line-start markers → Space") }
    static var cheatSheet: [(syntax: String, meaning: String)] {
        [
            ("#  ##  ###", String(localized: "setup.cheat.headings", defaultValue: "Title / Heading / Subheading")),
            ("-  *", String(localized: "setup.cheat.bullets", defaultValue: "Bulleted list (Settings can make - a dashed list)")),
            ("1.", String(localized: "setup.cheat.numbered", defaultValue: "Numbered list")),
            (String(localized: "setup.cheat.checklistSyntax", defaultValue: "[]  or  [ ]"),
             String(localized: "setup.cheat.checklist", defaultValue: "Checklist")),
            (">", String(localized: "setup.cheat.quote", defaultValue: "Quote")),
            ("```", String(localized: "setup.cheat.code", defaultValue: "Start a code block; type it again to leave")),
            ("---", String(localized: "setup.cheat.divider", defaultValue: "Divider line (macOS 27 or later)"))
        ]
    }
    static var fullWidthNote: String {
        String(localized: "setup.fullWidthNote", defaultValue: "Full-width and Chinese punctuation work too: ＃ 》 ＊ ··· 1。")
    }
    static var slashHeading: String { String(localized: "setup.slashHeading", defaultValue: "Slash commands → type / on an empty line") }
    static var slashExplanation: String {
        String(localized: "setup.slashExplanation",
               defaultValue: "A format menu opens at the caret. Keep typing to filter in English, Chinese, or pinyin initials (bt finds 标题). Use ↑↓ to choose, Return or Tab to apply, and Esc to close, or click a command. /divider inserts a divider (macOS 27 or later) and /date today's date.")
    }
    static var inlineHeading: String { String(localized: "setup.inlineHeading", defaultValue: "Inline markers → Space or Return when finished") }
    static var inlineExamples: String {
        String(localized: "setup.inlineExamples",
               defaultValue: "**bold**   *italic*   `code`   ~~strikethrough~~\n[link text](https://example.com)")
    }
    static var codeBlockNote: String {
        String(localized: "setup.codeBlockNote",
               defaultValue: "Code blocks also start with ```swift and Return. Paragraphs use Notes' own sizes; inline formats keep the size at the caret. In Chinese text, inline markers need no spaces around them.")
    }
    static var literalTextNote: String {
        String(localized: "setup.literalTextNote",
               defaultValue: "To keep a marker as text, type a backslash first: \\# and Space give #. Or press Shift-Space. Press ⌘Z right after a conversion to keep that paragraph as typed.")
    }
    static var betaNote: String {
        String(localized: "setup.betaNote",
               defaultValue: "Beta: try it in a new note first. Conversions can be undone with ⌘Z, and text an input method is composing is preserved where possible. Nested Markdown and whole-note conversion aren't supported.")
    }
    static var tryInNotes: String { String(localized: "setup.tryInNotes", defaultValue: "Try It in Notes") }

    // MARK: Settings window

    static var settingsTitle: String { String(localized: "settings.title", defaultValue: "NoteMark Settings") }
    static var settingsGeneral: String { String(localized: "settings.general", defaultValue: "General") }
    static var settingsLaunchAtLogin: String { String(localized: "settings.launchAtLogin", defaultValue: "Open NoteMark at login") }
    static var settingsLoginItemNeedsApproval: String {
        String(localized: "settings.loginItemNeedsApproval", defaultValue: "Allow NoteMark in Login Items.")
    }
    static var settingsOpenLoginItems: String { String(localized: "settings.openLoginItems", defaultValue: "Open Login Items…") }
    static var settingsConversions: String { String(localized: "settings.conversions", defaultValue: "Conversions") }
    static var settingsHeadings: String { String(localized: "settings.headings", defaultValue: "Headings  # ## ###") }
    static var settingsLists: String { String(localized: "settings.lists", defaultValue: "Lists  - * 1.") }
    static var settingsDashList: String { String(localized: "settings.dashList", defaultValue: "- makes a") }
    static var settingsDashBulleted: String { String(localized: "settings.dashBulleted", defaultValue: "Bulleted list") }
    static var settingsDashDashed: String { String(localized: "settings.dashDashed", defaultValue: "Dashed list") }
    static var settingsChecklists: String { String(localized: "settings.checklists", defaultValue: "Checklists  [ ]") }
    static var settingsQuotes: String { String(localized: "settings.quotes", defaultValue: "Quotes  >") }
    static var settingsCodeBlocks: String { String(localized: "settings.codeBlocks", defaultValue: "Code blocks  ```") }
    static var settingsDividers: String { String(localized: "settings.dividers", defaultValue: "Dividers  ---") }
    static var settingsDividersUnavailable: String {
        String(localized: "settings.dividersUnavailable", defaultValue: "Dividers need macOS 27 or later.")
    }
    static var settingsInlineStyles: String {
        String(localized: "settings.inlineStyles", defaultValue: "Inline styles  **bold** *italic* `code` ~~strike~~")
    }
    static var settingsLinks: String { String(localized: "settings.links", defaultValue: "Links  [text](url)") }
    static var settingsSlashCommands: String { String(localized: "settings.slashCommands", defaultValue: "Slash commands  /") }
    static var settingsFullWidthMarkers: String {
        String(localized: "settings.fullWidthMarkers", defaultValue: "Full-width and Chinese punctuation markers  ＃ 》 ＊")
    }
    static var smallImagesMenuItem: String {
        String(localized: "menu.smallImages", defaultValue: "Show New Images Small")
    }
    static var settingsImages: String {
        String(localized: "settings.images", defaultValue: "Images")
    }
    static var settingsSmallImages: String {
        String(localized: "settings.smallImages", defaultValue: "Show pasted or inserted images small")
    }
    static var settingsSmallImagesNote: String {
        String(localized: "settings.smallImagesNote",
               defaultValue: "After you paste or insert an image, NoteMark chooses View > Attachment View > Set All to Small in Notes. It applies to every attachment in that note, including ones you made larger.")
    }
    static var settingsNotesSubstitutions: String {
        String(localized: "settings.notesSubstitutions", defaultValue: "Apple Notes Substitutions")
    }
    static var settingsTurnOffSmartDashes: String {
        String(localized: "settings.turnOffSmartDashes", defaultValue: "Turn off Smart Dashes  --- becomes —")
    }
    static var settingsTurnOffSmartLists: String {
        String(localized: "settings.turnOffSmartLists", defaultValue: "Turn off Smart Lists  - can stay text")
    }
    static var settingsTurnOffSmartTags: String {
        String(localized: "settings.turnOffSmartTags", defaultValue: "Turn off Smart Tags  #word becomes a tag")
    }
    static var settingsNotesSubstitutionsNote: String {
        String(localized: "settings.notesSubstitutionsNote",
               defaultValue: "These items in Notes’ Edit > Substitutions menu change Markdown markers as you type, so NoteMark turns them off in Notes. Switching one off here turns it back on in Notes.")
    }
    static var settingsCancellationNote: String {
        String(localized: "settings.cancellationNote",
               defaultValue: "A formatted paragraph you empty always returns to Body with Delete or Esc.")
    }

    // MARK: Slash menu

    static var slashMenuTitle: String { String(localized: "slash.title", defaultValue: "Commands") }
    static func slashSearch(_ query: String) -> String { String(localized: "slash.search", defaultValue: "Search: \(query)") }
    static var slashFooter: String { String(localized: "slash.footer", defaultValue: "↑↓ Select    ↩ / Tab Apply    Esc Close") }
    static var slashNoMatches: String {
        String(localized: "slash.noMatches", defaultValue: "No matching command. Esc closes and keeps your text.")
    }
    static func slashCommandAccessibilityLabel(title: String, detail: String, alias: String) -> String {
        String(localized: "slash.commandLabel", defaultValue: "\(title), \(detail), /\(alias)")
    }
    static func slashTitle(_ command: SlashCommand) -> String {
        Bundle.main.localizedString(forKey: "slash.\(command.id).title", value: command.englishTitle, table: nil)
    }
    static func slashDetail(_ command: SlashCommand) -> String {
        Bundle.main.localizedString(forKey: "slash.\(command.id).detail", value: command.englishDetail, table: nil)
    }
}
