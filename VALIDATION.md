# Validation

English | [简体中文](VALIDATION.zh-CN.md)

Environment: macOS 27.0.1 (26A434), Apple Silicon, Swift 6.4.

## Architecture refactor (0.1.23)

The code was restructured without intended product changes: pure rules and key classification moved into `NoteMarkCore`, the app was split into input, Accessibility, conversion, diagnostics, and UI components, and everything builds in Swift 6 language mode with main-actor isolation. It builds as 0.1.23 (build 24).

Automated checks passed:

- **159 tests, 0 failures**, including new suites for caret lines, key classification, typing history, event-tap health, styled samples and font classification, and the diagnostics report format.
- Clean debug and release builds with zero warnings; release `--self-check`.
- Offscreen renders of the Slash menu and setup window are byte-identical to the 0.1.22 sources. The generated `Info.plist` is byte-identical to the 0.1.22 bundle.
- Two rounds of independent review compared the 0.1.22 sources with the refactor subsystem by subsystem. Differential tests ran the old and new rule code side by side on millions of generated inputs, including CRLF, attachments, surrogate pairs, truncated windows, unknown boundaries, and Slash session sequences; the only difference was `/dashed` + Space (below).
- On this Mac's US layout, the layout-aware key table gives the same key codes as before: Command-V uses key 9, and only the unshifted ANSI `/` key counts as a slash key.
- `install.sh` was tested in a sandbox: compatibility check, ad-hoc rejection, invalid backup limits, a full install with the relaunch stubbed, and backup pruning with locked and future-dated backups.

Intended differences: the event tap stops only after 3 disables within 60 seconds; inline conversion restores the clipboard only after Notes confirms the paste (up to 1 second) and marks its temporary item for clipboard managers; Command-V and Control-D/H/K/A/E/F/B/P/N follow the current ASCII-capable layout; scrolling is not held during an edit, and held keys go to Notes if it lost focus; per-change paragraph diagnostics require `NoteMarkVerboseDiagnostics`; `/dashed` + Space converts like the other typed Slash names; the installer keeps the 10 most recent backups.

On 2026-10-12, 0.1.23 was installed over 0.1.22 at `/Applications/NoteMark.app` with the update script. Accessibility and Input Monitoring stayed granted and conversion restarted automatically. The user then reported that the 0.1.23 live checklist passed in Apple Notes with physical input:
- Paragraph markers, inline formatting, the Slash menu, and empty-format cancellation.
- Typing or clicking immediately after a conversion; scrolling during an edit.
- Clipboard restoration, including copying during a conversion.
- Relaunching Notes, and switching input sources while staying in Notes.
- Full Slash menu navigation: Return before the menu appears, mouse selection, Esc suppression, full-width `／`, and WeType candidate navigation.
- Quote and code-block cancellation, including Esc on blank multiline code, and Control-K/D/H.
- Undo, list and checklist markers before existing text, paragraphs below images, and search fields, tables and locked notes.
- Pause, resume and relaunch.
The non-QWERTY layout check was optional and applied only if such a layout is in use.

## Passed

- **131 tests, 0 failures** (`swift test`): Markdown rules, Slash search and selection, UTF-16 ranges, font-size preservation, RTF, automatic startup/pause behavior, and empty-paragraph cancellation. Bullet and checklist prefixes before existing text remove only the marker; code, selections, unknown boundaries, and images in the same paragraph are excluded.
- Whole-code regressions exercise every intermediate deletion in `abc\ndef`, including the empty last line while `abc` remains. They also cover code below the caret, whole-block restyling with line breaks preserved, surrounding Body boundaries, UTF-16/CRLF, whitespace, attachments, selections, and truncated windows. The executable self-check includes whole-block emptiness.
- Native Notes tests in `NoteMark Multiline Reset Regression` selected all blank code lines and applied Body without deleting line breaks; both first and last lines showed Body in the Format popover. These were direct native commands, not the physical event listener.
- Code tracking recovers from the empty paragraph's own font. Backspace/Ctrl+K/H/D delete content and internal separators natively before boundary cancellation; Esc can restyle an all-blank block. The user confirmed 0.1.20 avoided intermediate jumps but its last line still merged upward. Version 0.1.21 fixed boundary cancellation but failed live testing: deleting upward exited below the code block. Its captured metadata showed a 13-character code paragraph at 44..<57 with unresolvable glyph fonts and a monospaced separator at 57; cancellation at caret 58 incorrectly considered only the empty paragraph below. Version 0.1.22 uses paragraph separator formats before glyph fonts, keeps unknown boundary states distinct from Body, and applies the same classification to tracking. Nine new tests cover that captured range, Chinese/emoji fallback, Body separators with inline code, unknown adjacent paragraphs, and a window truncated immediately after LF. Cancellation diagnostics now run outside the event tap only when a format cancellation is scheduled, recording ranges/fonts without note text. On 2026-10-11, the user confirmed 0.1.22 with physical keyboard input: upward deletion through multiple Chinese code lines and repeated blank lines stays inside code; after the block is empty, another Backspace restores Body at the same caret position.
- Code cancellation regressions cover Return into a new empty code line, typing on multiple lines and backspacing to the original line, UTF-16 windows, and leaving code for Body. Cancellation also synchronizes before the key is handled, covering AX observer delays. Native Notes' Format popover confirmed Body selected after the code content was deleted and the Body command executed; the user confirmed no intermediate jump during physical multiline deletion, while the complete multiline Esc flow still needs a separate check.
- Empty-paragraph regressions cover all non-Body styles, typing and deleting content, selections, movement within/outside the paragraph, long text windows, and UTF-16 boundaries.
- Native Notes commands in the separate `NoteMark Empty Format Regression` note confirmed that Body removes bullet/checklist formatting; quotes need their toggle disabled before Body. The empty quote was removed without merging the preceding line. These checks used direct native commands, not NoteMark's physical-key listener.
- Menu visibility tests cover fresh slash input, title and substring matches, space-only and unmatched searches hiding the menu, rapid edits and backspacing to bare slash staying hidden, matching edits reopening it, and visiting an existing bare slash without opening it.
- Slash session tests simulate WeType pinyin `biao'ti`, composition selections, composition before the first menu refresh, candidate windows closing before text commits, transient snapshot failures, and Chinese commits. The menu is retained during composition and search resumes after commit.
- Search regressions cover every displayed title and description, all four list types in Chinese/English list searches, numbered-list synonyms, and exact-match priority.
- Slash regressions cover spaces after Chinese and English commands, full-width slash and space, and UTF-16 deletion ranges following emoji.
- Input acknowledgement tests simulate a delayed closing bracket, unmatched input, focus changes, and cancellation.
- Release build, `--self-check`, signature verification, and ZIP integrity check for **0.1.22**, signed with the configured Apple Development certificate.
- Shell syntax checks and installer preflight for migration from the old ad-hoc build. Local signing configuration is ignored by Git.
- Two builds with different code-directory hashes satisfy each other's signing requirements. Installer preflight rejects ad-hoc builds, incompatible signing identifiers, and tampered resources without changing the installed app.
- Updated **0.1.10 → 0.1.11 → 0.1.12 → 0.1.13 → 0.1.14 → 0.1.15 → 0.1.16 → 0.1.17 → 0.1.18 → 0.1.19 → 0.1.20 → 0.1.21 → 0.1.22** at `/Applications/NoteMark.app` with the update script; signature compatibility passed, the old app was backed up, the new signature verified, and the app restarted.
- Offscreen rendering and visual review of the app's own setup and Slash views.

The installed 0.1.10 app reported Accessibility and Input Monitoring available, with conversion running, after the compatible update. The CLI also prints its own permissions separately.

The user confirmed that `[]` + Space creates a native checklist in 0.1.10. Space-triggered detection now checks committed editor text even when the keyboard-event prefilter has no Markdown hint. Existing-text checklists are covered by rule tests; that scenario still needs live verification.

## Manual checks still needed

Use a new test note after granting permissions. Apart from the confirmed empty-line checklist above, these checks still need live verification in Apple Notes.

| Check | Expected |
| --- | --- |
| Type `[]`, `[ ]`, `［］`, or `【】` + Space on the first line and before existing text | Native checklist; original text remains |
| Type `-` + Space, then `##` + Space | Native bullet list and heading |
| Write `Hello`, move to the paragraph start, type `-` or `*`, then Space | Native `• Hello` list with the original text and following paragraphs preserved |
| Apply headings, quote, code, or lists via Markdown/Slash, then Backspace, Forward Delete, Esc, or Ctrl+K/H/D on the empty paragraph; repeat after typing and deleting its content, including Ctrl+A then Ctrl+K | Return to Body without deleting or merging lines; edits within the paragraph keep tracking; leaving it, clicks, unrelated shortcuts, or app switching end the session |
| Type `**bold**` + Space after Chinese text or emoji | Correct text range; normal font afterward |
| Start code, press Return, type multiple lines, delete back to the empty code line, then Backspace, Esc, or Ctrl+K | Body restored after the final cancellation key; Return does not lose code tracking; code operators and markers stay unchanged inside |
| Convert a paragraph below an image | Image stays in place |
| Type a fresh `/`, then `/标题` or `/题`; try `/ `, unmatched text, backspacing to bare `/`, arrows, Return, Tab, Esc, and clicks | Fresh slash opens all commands; later input shows matching results only. Space-only and unmatched searches hide the menu; backspacing to bare slash keeps it hidden. Return or Tab applies the style with correct caret and focus |
| During Chinese IME composition, use Space, Return, arrows, and Esc; commit a command, then test rapid typing and undo | Candidate keys belong to the IME; search resumes after commit and a second Return executes; no lost text or unexpected conversion |
| Copy before and during inline conversion | Clipboard restored; new copies preserved |
| Switch apps; try search fields, tables, and locked notes | No unintended edits |
| Grant permissions to the certificate-signed build, then install a later compatible build | Accessibility and Input Monitoring permissions remain available; this retention has not been tested yet |

Also check different account types, shared notes, multiple displays, and Slash menus near window edges.

Computer Use in a separate test note confirmed WeType candidate UI for `biao'ti` and the committed `/标题`. Automated input did not trigger the foreground event listener; the user confirmed that 0.1.11 keeps the menu visible during WeType composition and after Chinese commit. Return execution, candidate navigation, and mouse selection need separate verification. Validation did not convert existing user notes or read the Notes database.
