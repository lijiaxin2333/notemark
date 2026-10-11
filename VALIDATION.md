# Validation / 验证说明

Environment / 环境：macOS 27.0.1 (26A434), Apple Silicon, Swift 6.4。

## Passed / 已通过

- **40 tests, 0 failures** (`swift test`): Markdown rules, Slash search and selection, UTF-16 ranges, font-size preservation, RTF, and automatic startup/pause behavior. `-` + Space maps to a bullet list.
  **40 项测试，0 失败**：覆盖 Markdown 规则、Slash 搜索与选择、UTF-16 范围、字号保留、RTF、自动启动与暂停；`-` 加空格映射为圆点列表。
- Release build, `--self-check`, signature verification, and ZIP integrity check for **0.1.3**.
  **0.1.3** 的 Release 构建、本地规则自检、签名检查和 ZIP 完整性检查。
- Offscreen rendering and visual review of the app's own setup and Slash views.
  App 自身设置页和 Slash 菜单的离屏渲染及图像检查。

`--diagnose` reported permissions available in the development process. This does not verify permissions for a separately launched app.

`--diagnose` 在开发进程中报告权限可用，不代表独立启动的 App 已获得权限。

## Manual checks still needed / 仍需手动验证

Use a new test note after granting permissions. These checks have **not** been completed in Apple Notes.

授权后请使用新建测试笔记。以下检查**尚未在真实备忘录中完成**。

| Check / 检查 | Expected / 预期 |
| --- | --- |
| Type `-` + Space, then `##` + Space / 输入 `-` 加空格，再试 `##` 加空格 | Native bullet list and heading / 原生圆点列表和小标题 |
| Type `**bold**` + Space after Chinese text or emoji / 在中文或 emoji 后输入 `**粗体**` 加空格 | Correct text range; normal font afterward / 范围正确，后续文字恢复原字体 |
| Enter and leave a code paragraph / 进入并退出代码段落 | Code operators and markers stay unchanged inside / 代码中的运算符和标记保持原样 |
| Convert a paragraph below an image / 在图片下一段转换格式 | Image stays in place / 图片位置不变 |
| Search `/h2`, use arrows, Return, Tab, Esc, and clicks / 测试 Slash 搜索、方向键、回车、Tab、Esc 和点击 | Correct command, caret position, and focus / 命令、光标位置及焦点正确 |
| Test IMEs, rapid typing, and undo / 测试输入法、快速输入和撤销 | No lost text or unexpected conversion / 不丢字、不误转换 |
| Copy before and during inline conversion / 在行内转换前及转换时复制内容 | Clipboard restored; new copies preserved / 剪贴板恢复，保留新复制内容 |
| Switch apps; try search fields, tables, and locked notes / 切换 App，测试搜索框、表格和锁定笔记 | No unintended edits / 不误编辑 |

Also check different account types, shared notes, multiple displays, and Slash menus near window edges.

还需检查不同账户、共享笔记、多显示器，以及窗口边缘的 Slash 菜单。

Validation did not convert existing user notes, read the Notes database, or use Computer Use.

验证过程未转换用户现有笔记、未读取备忘录数据库，也未使用 Computer Use。
