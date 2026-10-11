# NoteMark

Write Markdown directly in Apple Notes. NoteMark converts it into native Notes formatting.

在 Apple 备忘录中直接写 Markdown，NoteMark 会将标记转换为备忘录原生格式。

**Version / 版本：0.1.3 beta** · macOS 14+ · Apple Silicon build / 当前安装包适用于 Apple Silicon

[English](#english) · [中文](#中文) · [Syntax / 语法](#syntax--语法)

## English

### Install and grant permissions

1. Unzip the package and move **NoteMark.app** to **Applications** before granting permissions. If building from source, use the app in `dist/`.
2. Open NoteMark. Click **授权辅助功能** (Grant Accessibility). In **System Settings → Privacy & Security → Accessibility**, enable **NoteMark**. Add it from Applications with the **+** button if it is missing.
3. Conversion starts automatically when permission is ready, usually within 2 seconds. If input is still not detected, click **输入监控设置…** (Input Monitoring Settings), then enable NoteMark in **System Settings → Privacy & Security → Input Monitoring**. Quit and reopen NoteMark if macOS asks you to restart it.
4. Open **Apple Notes**, create a new test note, and type `-` followed by Space. It should become a bullet list. Try the [syntax below](#syntax--语法).

The app's buttons are currently in Chinese; the labels above match what you see. Permissions must be granted manually in System Settings. Full Disk Access is not required.

### Use NoteMark

- Keep Apple Notes in front and type in the note body. Start paragraph markers on an empty line, then press **Space**.
- Type `/` on an empty line for the command menu. Search with `/h2` or `/code`; use **↑ / ↓** to select and **Return / Tab** to apply. **Esc** closes the menu and keeps your text. You can also click a command.
- Finish an inline marker such as `**bold**`, then press **Space** or **Return** to convert it.
- Use the NoteMark menu bar icon to **暂停 Markdown 转换** (Pause), **恢复 Markdown 转换** (Resume), or **退出 NoteMark** (Quit). Pausing lasts for the current session; the next launch starts automatically when permission is ready.
- Use **⌘Z** to undo. Paragraph conversion may need two undo actions.

## 中文

### 安装与权限配置

1. 解压安装包，先将 **NoteMark.app** 移到 **应用程序（Applications）**，再配置权限。自行编译时，App 位于 `dist/`。
2. 打开 NoteMark，点击 **授权辅助功能**。在 **系统设置 → 隐私与安全性 → 辅助功能** 中开启 **NoteMark**。列表中没有时，点击 **+**，从应用程序中添加。
3. 权限就绪后自动开启转换，通常在 2 秒内生效。如果仍无法识别输入，点击 **输入监控设置…**，在 **系统设置 → 隐私与安全性 → 输入监控** 中开启 NoteMark。系统要求重启时，退出并重新打开 NoteMark。
4. 打开 **Apple 备忘录**，新建测试笔记，输入 `-` 再按空格，应转换为圆点列表。其他语法见下表。

权限需要在系统设置中手动授予，无需完全磁盘访问权限。

### 使用方法

- 在备忘录正文中输入，并保持备忘录位于前台。段落标记要在空行行首输入，再按 **空格**。
- 空行输入 `/` 打开命令菜单。输入 `/h2` 或 `/code` 搜索，用 **↑ / ↓** 选择，按 **回车 / Tab** 执行。**Esc** 关闭并保留文字，也可点击命令。
- 写完 `**粗体**` 等行内标记后，按 **空格或回车** 转换。
- 点击菜单栏 NoteMark 图标，可 **暂停 Markdown 转换**、**恢复 Markdown 转换** 或 **退出 NoteMark**。手动暂停仅保持到本次退出；下次启动会在权限就绪后自动开启。
- 按 **⌘Z** 撤销。段落转换可能需要撤销两次。

## Syntax / 语法

At the start of an empty line, type a marker and press **Space**.

在空行行首输入标记，再按 **空格**。

| Input / 输入 | Result / 效果 |
| --- | --- |
| `#` / `##` / `###` | Title / Heading / Subheading · 标题 / 小标题 / 次级标题 |
| `-` / `*` | Bullet list `•` · 圆点列表 |
| `1.` | Numbered list · 编号列表 |
| `[]` / `[ ]` / `- [ ]` | Checklist · 待办清单 |
| `>` | Quote · 引用 |
| Three backticks / 三个反引号 | Monospaced code paragraph; repeat to exit · 等宽代码段落，再次输入退出 |

Three backticks followed by a language name, such as `swift`, also start a code paragraph when you press **Return**. There is no syntax highlighting.

三个反引号后加 `swift` 等语言名，再按 **回车**，也可开始代码段落；不提供语法高亮。

Inline markers / 行内标记：`**bold**`、`*italic*`、`***bold italic***`、`__bold__`、`_italic_`、`` `code` ``、`~~strike~~`、`[link](https://example.com)`。

Slash commands / Slash 命令：`/h1`、`/h2`、`/h3`、`/body`、`/code`、`/quote`、`/checklist`、`/bullets`、`/dashed`、`/numbered`。Chinese names also work in menu search / 中文名称也可用于菜单搜索。

## Troubleshooting / 无法转换时

- Check permissions for the copy in **Applications**, then quit and reopen NoteMark. Rebuilt apps may need permission again.
  检查 **应用程序** 中的 NoteMark 是否已授权，再退出并重新打开。重新编译后可能需要再次授权。
- If paused, choose **恢复 Markdown 转换** (Resume). If the connection failed, choose **重试输入连接** (Retry Input Connection).
  已暂停时点击 **恢复 Markdown 转换**；连接失败时点击 **重试输入连接**。
- Try an empty line in a new, unlocked note. Search fields, selected text, and code paragraphs do not trigger normal Markdown conversion.
  先在新建、未锁定笔记的空行试用。搜索框、选中文字和代码段落不会触发普通 Markdown 转换。

## Notes / 注意事项

- This is a local menu bar helper. It does not store or upload note content, or modify the Notes database.
  这是本地菜单栏辅助程序，不保存或上传笔记内容，不修改备忘录数据库。
- Paragraphs use native Notes styles; inline formatting preserves the current font size. Inline conversion briefly uses the clipboard, then restores it unless you have copied something new.
  段落使用备忘录原生样式，行内格式保留当前字号。行内转换会短暂使用剪贴板；若未复制新内容，转换后会恢复原内容。
- Whole-note conversion, nested Markdown, and Markdown image insertion are not supported. Paragraphs containing images are skipped.
  暂不支持整篇转换、嵌套 Markdown 和 Markdown 图片插入；包含图片的当前段落会跳过转换。
- Tested builds use macOS 27.0.1 and Apple Silicon. Real Notes input, IME behavior, and rapid typing still need manual testing. See [validation details](VALIDATION.md).
  已在 macOS 27.0.1 / Apple Silicon 编译；真实备忘录输入、输入法和快速连续输入仍需手动验证。详见 [验证说明](VALIDATION.md)。

## Build / 编译

Requires macOS 14+ and an Xcode/Swift toolchain. No third-party dependencies.

需要 macOS 14+ 和 Xcode/Swift 工具链，无第三方依赖。

```sh
swift test
sh scripts/build.sh
```

Output / 输出：`dist/NoteMark.app`、`dist/NoteMark-0.1.3.zip`。The build uses ad-hoc signing / 构建使用本地 ad-hoc 签名。

```sh
dist/NoteMark.app/Contents/MacOS/NoteMark --self-check
dist/NoteMark.app/Contents/MacOS/NoteMark --diagnose
```

`--self-check` checks local rules. `--diagnose` prints the OS version and this process's permissions without reading notes or requesting permission.

`--self-check` 检查本地规则；`--diagnose` 输出系统版本和本进程权限，不读取笔记或申请权限。

Build output and local configuration are ignored by Git / 构建产物和本地配置已由 Git 忽略。

License / 许可证：[MIT](LICENSE)。
