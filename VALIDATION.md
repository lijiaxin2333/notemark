# Validation

English | [简体中文](VALIDATION.zh-CN.md)

Environment: macOS 27.0.1 (26A434), Apple Silicon, Swift 6.4.

## Passed

- **84 tests, 0 failures** (`swift test`): Markdown rules, Slash search and selection, UTF-16 ranges, font-size preservation, RTF, automatic startup/pause behavior, and empty-heading cancellation. Bullet and checklist prefixes before existing text remove only the marker; code, selections, unknown boundaries, and images in the same paragraph are excluded.
- Menu visibility tests cover fresh slash input, title and substring matches, space-only and unmatched searches hiding the menu, rapid edits and backspacing to bare slash staying hidden, matching edits reopening it, and visiting an existing bare slash without opening it.
- Slash session tests simulate WeType pinyin `biao'ti`, composition selections, composition before the first menu refresh, candidate windows closing before text commits, transient snapshot failures, and Chinese commits. The menu is retained during composition and search resumes after commit.
- Search regressions cover every displayed title and description, all four list types in Chinese/English list searches, numbered-list synonyms, and exact-match priority.
- Slash regressions cover spaces after Chinese and English commands, full-width slash and space, and UTF-16 deletion ranges following emoji.
- Input acknowledgement tests simulate a delayed closing bracket, unmatched input, focus changes, and cancellation.
- Release build, `--self-check`, signature verification, and ZIP integrity check for **0.1.13**, signed with the configured Apple Development certificate.
- Shell syntax checks and installer preflight for migration from the old ad-hoc build. Local signing configuration is ignored by Git.
- Two builds with different code-directory hashes satisfy each other's signing requirements. Installer preflight rejects ad-hoc builds, incompatible signing identifiers, and tampered resources without changing the installed app.
- Updated **0.1.10 → 0.1.11 → 0.1.12 → 0.1.13** at `/Applications/NoteMark.app` with the update script; signature compatibility passed, the old app was backed up, the new signature verified, and the app restarted.
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
| Type `#` / `##` / `###` + Space, then Backspace, Esc, or Ctrl+K without typing text; also try cancelling immediately | Return to Body without deleting or merging lines; typing, caret movement, and app switching end this cancellation state |
| Type `**bold**` + Space after Chinese text or emoji | Correct text range; normal font afterward |
| Enter and leave a code paragraph | Code operators and markers stay unchanged inside |
| Convert a paragraph below an image | Image stays in place |
| Type a fresh `/`, then `/标题` or `/题`; try `/ `, unmatched text, backspacing to bare `/`, arrows, Return, Tab, Esc, and clicks | Fresh slash opens all commands; later input shows matching results only. Space-only and unmatched searches hide the menu; backspacing to bare slash keeps it hidden. Return or Tab applies the style with correct caret and focus |
| During Chinese IME composition, use Space, Return, arrows, and Esc; commit a command, then test rapid typing and undo | Candidate keys belong to the IME; search resumes after commit and a second Return executes; no lost text or unexpected conversion |
| Copy before and during inline conversion | Clipboard restored; new copies preserved |
| Switch apps; try search fields, tables, and locked notes | No unintended edits |
| Grant permissions to the certificate-signed build, then install a later compatible build | Accessibility and Input Monitoring permissions remain available; this retention has not been tested yet |

Also check different account types, shared notes, multiple displays, and Slash menus near window edges.

Computer Use in a separate test note confirmed WeType candidate UI for `biao'ti` and the committed `/标题`. Automated input did not trigger the foreground event listener; the user confirmed that 0.1.11 keeps the menu visible during WeType composition and after Chinese commit. Return execution, candidate navigation, and mouse selection need separate verification. Validation did not convert existing user notes or read the Notes database.
