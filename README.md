# NoteMark

English | [简体中文](README.zh-CN.md)

Write Markdown directly in Apple Notes. NoteMark converts it into native Notes formatting.

**Version: 0.1.3 beta** · macOS 14+ · Current build: Apple Silicon

## Install and grant permissions

1. Unzip the package and move **NoteMark.app** to **Applications** before granting permissions. To build it yourself, follow the [build instructions](#build).
2. Open NoteMark. Go to **System Settings → Privacy & Security → Accessibility** and enable **NoteMark**. If it is missing, click **+** and add it from Applications.
3. Conversion starts automatically when permission is ready, usually within 2 seconds. If input is still not detected, enable NoteMark in **System Settings → Privacy & Security → Input Monitoring**. Quit and reopen NoteMark if macOS asks you to restart it.
4. Open **Apple Notes**, create a new test note, and type `-` followed by **Space**. It should become a bullet list.

Permissions must be granted manually. Full Disk Access is not required. The app interface is currently in Chinese; these instructions describe how to configure permissions directly in System Settings.

## Use NoteMark

- Keep Apple Notes in front and type in the note body. Start paragraph markers on an empty line, then press **Space**.
- Type `/` on an empty line for the command menu. Search with `/h2` or `/code`; use **↑ / ↓** to select and **Return / Tab** to apply. **Esc** closes the menu and keeps your text. You can also click a command.
- Finish an inline marker such as `**bold**`, then press **Space** or **Return** to convert it.
- The NoteMark menu bar icon provides pause, resume, and quit actions. Pausing lasts for the current session; the next launch starts automatically when permission is ready.
- Use **⌘Z** to undo. Paragraph conversion may need two undo actions.

## Syntax

At the start of an empty line, type a marker and press **Space**.

| Input | Result |
| --- | --- |
| `#` / `##` / `###` | Title / Heading / Subheading |
| `-` / `*` | Bullet list `•` |
| `1.` | Numbered list |
| `[]` / `[ ]` / `- [ ]` | Checklist |
| `>` | Quote |
| Three backticks | Monospaced code paragraph; repeat to exit |

Three backticks followed by a language name, such as `swift`, also start a code paragraph when you press **Return**. There is no syntax highlighting.

Inline markers: `**bold**`, `*italic*`, `***bold italic***`, `__bold__`, `_italic_`, `` `code` ``, `~~strike~~`, `[link](https://example.com)`.

Slash commands: `/h1`, `/h2`, `/h3`, `/body`, `/code`, `/quote`, `/checklist`, `/bullets`, `/dashed`, `/numbered`.

## Troubleshooting

- Check permissions for the copy in **Applications**, then quit and reopen NoteMark. Rebuilt apps may need permission again.
- If paused, resume conversion from the menu bar. If the input connection failed, use the retry action in that menu.
- Try an empty line in a new, unlocked note. Search fields, selected text, and code paragraphs do not trigger normal Markdown conversion.

## Notes

- This is a local menu bar helper. It does not store or upload note content, or modify the Notes database.
- Paragraphs use native Notes styles; inline formatting preserves the current font size. Inline conversion briefly uses the clipboard, then restores it unless you have copied something new.
- Whole-note conversion, nested Markdown, and Markdown image insertion are not supported. Paragraphs containing images are skipped.
- Tested builds use macOS 27.0.1 and Apple Silicon. Real Notes input, IME behavior, and rapid typing still need manual testing. See [validation details](VALIDATION.md).

## Build

Requires macOS 14+ and an Xcode/Swift toolchain. No third-party dependencies.

```sh
swift test
sh scripts/build.sh
```

Output: `dist/NoteMark.app` and `dist/NoteMark-0.1.3.zip`. The build uses ad-hoc signing.

```sh
dist/NoteMark.app/Contents/MacOS/NoteMark --self-check
dist/NoteMark.app/Contents/MacOS/NoteMark --diagnose
```

`--self-check` checks local rules. `--diagnose` prints the OS version and this process's permissions without reading notes or requesting permission.

Build output and local configuration are ignored by Git.

License: [MIT](LICENSE).
