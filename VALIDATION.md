# Validation

English | [简体中文](VALIDATION.zh-CN.md)

Environment: macOS 27.0.1 (26A434), Apple Silicon, Swift 6.4.

## Passed

- **48 tests, 0 failures** (`swift test`): Markdown rules, Slash search and selection, UTF-16 ranges, font-size preservation, RTF, automatic startup/pause behavior, and empty-heading cancellation. `-` + Space maps to a bullet list; empty-heading cancellation produces a zero-length Body edit.
- Release build, `--self-check`, signature verification, and ZIP integrity check for **0.1.5**, signed with the configured Apple Development certificate.
- Shell syntax checks and installer preflight for migration from the old ad-hoc build. Local signing configuration is ignored by Git.
- Two builds with different code-directory hashes satisfy each other's signing requirements. Installer preflight rejects ad-hoc builds, incompatible signing identifiers, and tampered resources without changing the installed app.
- Installed **0.1.5** at `/Applications/NoteMark.app` with the update script; the old app was backed up, the new signature verified, and the app restarted. A subsequent compatibility preflight passed.
- Offscreen rendering and visual review of the app's own setup and Slash views.

`--diagnose` reported permissions available in the development process. This does not verify permissions for a separately launched app.

## Manual checks still needed

Use a new test note after granting permissions. These checks have **not** been completed in Apple Notes.

| Check | Expected |
| --- | --- |
| Type `-` + Space, then `##` + Space | Native bullet list and heading |
| Type `#` / `##` / `###` + Space, then Backspace, Esc, or Ctrl+K without typing text; also try cancelling immediately | Return to Body without deleting or merging lines; typing, caret movement, and app switching end this cancellation state |
| Type `**bold**` + Space after Chinese text or emoji | Correct text range; normal font afterward |
| Enter and leave a code paragraph | Code operators and markers stay unchanged inside |
| Convert a paragraph below an image | Image stays in place |
| Search `/h2`, use arrows, Return, Tab, Esc, and clicks | Correct command, caret position, and focus |
| Test IMEs, rapid typing, and undo | No lost text or unexpected conversion |
| Copy before and during inline conversion | Clipboard restored; new copies preserved |
| Switch apps; try search fields, tables, and locked notes | No unintended edits |
| Grant permissions to the certificate-signed build, then install a later compatible build | Accessibility and Input Monitoring permissions remain available; this retention has not been tested yet |

Also check different account types, shared notes, multiple displays, and Slash menus near window edges.

Validation did not convert existing user notes, read the Notes database, or use Computer Use.
