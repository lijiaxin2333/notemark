# Validation

English | [简体中文](VALIDATION.zh-CN.md)

Environment: macOS 27.0.1 (26A434), Apple Silicon, Swift 6.4.

## Passed

- **40 tests, 0 failures** (`swift test`): Markdown rules, Slash search and selection, UTF-16 ranges, font-size preservation, RTF, and automatic startup/pause behavior. `-` + Space maps to a bullet list.
- Release build, `--self-check`, signature verification, and ZIP integrity check for **0.1.3**.
- Offscreen rendering and visual review of the app's own setup and Slash views.

`--diagnose` reported permissions available in the development process. This does not verify permissions for a separately launched app.

## Manual checks still needed

Use a new test note after granting permissions. These checks have **not** been completed in Apple Notes.

| Check | Expected |
| --- | --- |
| Type `-` + Space, then `##` + Space | Native bullet list and heading |
| Type `**bold**` + Space after Chinese text or emoji | Correct text range; normal font afterward |
| Enter and leave a code paragraph | Code operators and markers stay unchanged inside |
| Convert a paragraph below an image | Image stays in place |
| Search `/h2`, use arrows, Return, Tab, Esc, and clicks | Correct command, caret position, and focus |
| Test IMEs, rapid typing, and undo | No lost text or unexpected conversion |
| Copy before and during inline conversion | Clipboard restored; new copies preserved |
| Switch apps; try search fields, tables, and locked notes | No unintended edits |

Also check different account types, shared notes, multiple displays, and Slash menus near window edges.

Validation did not convert existing user notes, read the Notes database, or use Computer Use.
