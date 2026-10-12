# NoteMark

English | [简体中文](README.zh-CN.md)

Write Markdown directly in Apple Notes. NoteMark converts it into native Notes formatting.

**Version: 0.2.0 beta** · macOS 14+ · Current build: Apple Silicon

## Install and grant permissions

1. Unzip the package and move **NoteMark.app** to **Applications** before granting permissions. To build it yourself, follow the [build instructions](#build).
2. Open NoteMark. Its guide shows both permissions with a live ✓ or ✗. Go to **System Settings → Privacy & Security → Accessibility** (called **Device Control and Data Access** on macOS 27) and enable **NoteMark**. If it is missing, click **+** and add it from Applications.
3. Conversion starts automatically when permission is ready, usually within 2 seconds. If input is still not detected, enable NoteMark in **System Settings → Privacy & Security → Input Monitoring**, then click **Reopen NoteMark** in the guide.
4. Open **Apple Notes**, create a new test note, and type `-` followed by **Space**. It should become a bullet list.

Permissions must be granted manually. Full Disk Access is not required. The interface follows the system language: English, Simplified Chinese, or Traditional Chinese. The guide opens on first use, when conversion cannot run, or when you open NoteMark again from Finder; otherwise it stays in the menu bar.

## Use NoteMark

- Keep Apple Notes in front and type in the note body. Start paragraph markers on an empty line, then press **Space**.
- To turn existing text into a bullet list, place the caret before its first character, type `-` or `*`, then press **Space**. The text is kept; the result is a native `•` list.
- For a checklist, type `[]`, then press **Space** and enter the task. This also works before existing paragraph text. Press **Return** for the next task.
- Type `/` on an empty line for the command menu. Search with `/h2` or `/code`; use **↑ / ↓** to select and **Return / Tab** to apply. **Esc** closes the menu and keeps your text. You can also click a command.
- Finish an inline marker such as `**bold**`, then press **Space** or **Return** to convert it. In Chinese text, markers need no surrounding spaces: `这是**重点**`.
- To keep a marker as literal text, type a backslash first (`\#` then **Space** gives `#`; Space only confirms and is not typed), or press **Shift+Space**. Pressing **⌘Z** right after a conversion also keeps that paragraph's markers as typed until you press Return, click, delete, or move to another paragraph; inline styles typed later still convert. Switching apps does not end this.
- When a conversion cannot be completed, for example a checklist in an account without checklists, a short tip appears next to the caret.
- After NoteMark applies a paragraph format (heading, quote, code, or list), press **Backspace**, **Forward Delete**, **Esc**, or **Ctrl+K / Ctrl+H / Ctrl+D** on the empty paragraph to return to Body. This also works after typing and deleting all its text within the same paragraph. Code formatting stays tracked across Return and backspacing between monospaced lines. Paragraph separator formats identify Chinese and emoji font fallbacks; unknown boundaries never prove an empty block. Backspace and Ctrl+K/H/D delete internal text and line breaks natively. Once code is all blank and the caret reaches the boundary in the deletion direction, the current paragraph returns to Body instead of merging the empty code into surrounding prose. They do not select or reformat a multiline block midway through upward deletion. Esc explicitly returns an all-blank code block to Body, preserving its blank lines. Existing monospaced paragraphs can be recognized again after focus changes or app updates, including empty code lines that can be cancelled directly. For other styles, leaving the paragraph ends tracking; clicks, app switching, and formatting changes also end it. For a line that still contains text, use **⌘⇧B** to switch to Body.
- The NoteMark menu bar icon and the line under the NoteMark title in its menu show the current state (on, paused, needs permission, or can't listen for input), and the menu provides pause, resume, settings, and quit actions. If macOS stops the input listener, the guide opens. Pausing lasts for the current session; the next launch starts automatically when permission is ready.
- **Settings** (⌘,) turns each group of conversions on or off, chooses whether `-` makes a bulleted or dashed list, and opens NoteMark at login.
- Notes' own **Edit → Substitutions** rewrite markers as you type: Smart Dashes turns `---` into `—`, Smart Lists turns `- ` into a list even after `\-`, and Smart Tags turns `#word` into a tag. NoteMark turns off Smart Dashes and Smart Lists in Notes through that menu (Smart Tags only if you ask) and turns an item back on when you switch it off in Settings.
- Use **⌘Z** to undo. Paragraph conversion may need two undo actions.

## Syntax

At the start of an empty line, type a marker and press **Space**. `-`, `*`, `[]`, and `[ ]` also work before existing text at the start of a paragraph.

| Input | Result |
| --- | --- |
| `#` / `##` / `###` | Title / Heading / Subheading (`####` to `######` also make a Subheading) |
| `-` / `*` | Bullet list `•` (Settings can make `-` a dashed list) |
| `1.` | Numbered list |
| `[]` / `[ ]` / `- [ ]` | Checklist (also accepts `［］` and `【】`) |
| `>` | Quote |
| Three backticks | Monospaced code paragraph; repeat to exit |
| `---` / `***` / `___` | Native divider line, with **Space** or **Return** (macOS 27 or later; earlier systems keep the text) |

Full-width and Chinese punctuation forms work too: `＃`, `＞` or `》`, `＊`, `－`, `１．` or `1。`, and `···` or `｀｀｀` for code.

Three backticks followed by a language name, such as `swift`, also start a code paragraph when you press **Return**. There is no syntax highlighting.

Inline markers: `**bold**`, `*italic*`, `***bold italic***`, `__bold__`, `_italic_`, `` `code` ``, `~~strike~~`, `[link](https://example.com)`.

Slash commands: `/h1`, `/h2`, `/h3`, `/body`, `/code`, `/quote`, `/checklist`, `/bullets`, `/dashed`, `/numbered`, `/divider` (macOS 27 or later), and `/date` (today's date in your preferred language's format).

Search matches command titles, descriptions, Notes' own names (such as “核对清单” or Block Quote), Chinese or English aliases, and pinyin or its initials (`/bt` finds 标题). “列表” shows every list type; “序号列表” matches Numbered List. The full-width `／` also opens the menu. A freshly typed `/` opens the full menu. Further input shows only matching commands (`/标题` or `/题`); a space-only or unmatched query hides it. Backspacing to bare `/` keeps it hidden. A matching query can reopen it; trailing spaces after a valid name do not affect matching. Use Return, Tab, or a click to execute. During IME composition, Space, Return, arrow keys, and Esc belong to the input method; commit the candidate first, then press Return to execute.

## Troubleshooting

- Check permissions for the copy in **Applications**, then quit and reopen NoteMark. Changing the signing identity may require permission again.
- If paused, resume conversion from the menu bar. If the input connection failed, use the retry action in that menu.
- If a marker no longer converts, check that its group is on in **Settings**.
- For checklists, check that **Format → Checklist** is available in Notes. You can test it with **⌘⇧L** ([Apple shortcuts](https://support.apple.com/guide/notes/apd46c25187e/mac)). NoteMark keeps the marker if that native command is unavailable.
- Try an empty line in a new, unlocked note. Search fields, selected text, and code paragraphs do not trigger normal Markdown conversion.

## Notes

- This is a local menu bar helper. It does not store or upload note content, or modify the Notes database.
- Paragraphs use native Notes styles; inline formatting preserves the current font size. Inline conversion briefly uses the clipboard, marked as transient so clipboard managers skip it, then restores it once Notes has pasted, unless you have copied something new. Before pasting, NoteMark saves every representation the source app can supply at that moment; lazily promised content such as file promises cannot be restored.
- Whole-note conversion, nested Markdown, and Markdown image insertion are not supported. Paragraphs containing images are skipped.
- Empty-code cancellation inspects at most 4096 UTF-16 units on each side of the caret. If the full block boundaries cannot be confirmed, it keeps the native key operation.
- Before converting existing text to a bullet list or checklist, NoteMark checks up to 512 UTF-16 units after the caret. Conversion is skipped if it cannot confirm the paragraph's end within that range.
- Tested builds use macOS 27.0.1 and Apple Silicon. Real Notes input, IME behavior, and rapid typing still need manual testing. See [validation details](VALIDATION.md).

## Update

Quit NoteMark and replace the app at **/Applications/NoteMark.app** with a build signed using the same identity. For local builds, run:

```sh
sh scripts/build.sh
sh scripts/install.sh
```

The installer checks signature compatibility, backs up the installed app, quits it, replaces it at the same path, and reopens it. To check compatibility without installing, run `sh scripts/install.sh --check`. Backups go to `dist/installed-backups`; the 10 most recent are kept. Set `NOTEMARK_BACKUP_LIMIT` to keep a different number, or `0` to keep all.

Permissions should carry over between compatible signed versions. The first update from an old ad-hoc build to a certificate-signed build requires permission again. Keep the signing identity and bundle identifier unchanged. See [Apple's explanation of code identity](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).

This is a local update script; there is no in-app update downloader yet.

## Build

Requires macOS 14+ and an Xcode/Swift toolchain. No third-party dependencies.

Configure a signing identity once. Copy its 40-character SHA-1 from the first command:

```sh
security find-identity -v -p codesigning
sh scripts/configure-signing.sh CERTIFICATE_SHA1
```

The selection is stored in `.signing-identity`, which Git ignores. The certificate and private key stay in your keychain. macOS may ask you to allow `codesign` to use the private key; approve it in the system Keychain dialog. Use Apple Development for local development; public releases need [Developer ID signing and notarization](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/).

```sh
sh scripts/build.sh
```

The build runs `swift test` and `scripts/check-localization.swift` first; set `NOTEMARK_SKIP_TESTS=1` to skip the tests. Translations and the app icon in `Packaging/Resources` are copied into the bundle; `swift scripts/make-icon.swift Packaging/Resources/AppIcon.icns` redraws the app icon (original artwork: a note page with a yellow plus, not Apple's Notes icon). Output: `dist/NoteMark.app` and `dist/NoteMark-<version>.zip`. The version and bundle identifier come from `Packaging/app.env`, and `Packaging/Info.plist` is the bundle's property list template. Builds use the configured certificate; they fail if no identity is configured. For a temporary ad-hoc test build, use `NOTEMARK_SIGNING_IDENTITY=- sh scripts/build.sh`; the installer rejects these builds.

```sh
dist/NoteMark.app/Contents/MacOS/NoteMark --self-check
dist/NoteMark.app/Contents/MacOS/NoteMark --diagnose
```

`--self-check` checks local rules. `--diagnose` prints the OS version, this process's permissions, and the last app status, including why the last held Space or Return matched no rule (lengths and flags only). The local report contains no note text or keystrokes; it may be stale after the app exits. To also record paragraph tracking after every editor change, run `defaults write dev.local.notemark NoteMarkVerboseDiagnostics -bool YES` and restart NoteMark; this adds Accessibility reads while typing, so turn it off with `defaults delete dev.local.notemark NoteMarkVerboseDiagnostics` when done.

Build output and local configuration are ignored by Git.

Code layout: `Sources/NoteMarkCore` holds the Markdown, slash, paragraph, and key-classification rules as pure, unit-tested Swift. `Sources/NoteMark` is the menu bar app: `App` (app delegate, command-line modes and self-check, interface text), `Input` (event tap, held input, keyboard layout, synthetic keys, pasteboard), `Accessibility` (Notes editor snapshots and menu commands), `Conversion` (event routing, slash menu, paragraph tracking, editing), `Diagnostics`, and `UI`. The app builds in Swift 6 language mode with main-actor isolation.

License: [MIT](LICENSE).
