# NoteMark

[English](README.md) | 简体中文

在 Apple 备忘录中直接写 Markdown，NoteMark 会将标记转换为备忘录原生格式。

**版本：0.1.13 测试版** · macOS 14+ · 当前安装包适用于 Apple Silicon

## 安装与权限配置

1. 解压安装包，先将 **NoteMark.app** 移到 **应用程序（Applications）**，再配置权限。自行编译请参考[编译说明](#编译)。
2. 打开 NoteMark，点击 **授权辅助功能**。在 **系统设置 → 隐私与安全性 → 辅助功能** 中开启 **NoteMark**。列表中没有时，点击 **+**，从应用程序中添加。
3. 权限就绪后自动开启转换，通常在 2 秒内生效。如果仍无法识别输入，点击 **输入监控设置…**，在 **系统设置 → 隐私与安全性 → 输入监控** 中开启 NoteMark。系统要求重启时，退出并重新打开 NoteMark。
4. 打开 **Apple 备忘录**，新建测试笔记，输入 `-` 再按 **空格**，应转换为圆点列表。

权限需要在系统设置中手动授予，无需完全磁盘访问权限。

## 使用方法

- 在备忘录正文中输入，并保持备忘录位于前台。段落标记要在空行行首输入，再按 **空格**。
- 已有文字也能转为圆点列表：将光标放到段落第一个字前，输入 `-` 或 `*`，再按 **空格**。原文字会保留，整段变成原生 `•` 列表。
- 输入 `[]` 后按 **空格**，即可开始输入待办内容；也可以加在已有段落的文字前。按 **回车** 创建下一项。
- 空行输入 `/` 打开命令菜单。输入 `/h2` 或 `/code` 搜索，用 **↑ / ↓** 选择，按 **回车 / Tab** 执行。**Esc** 关闭并保留文字，也可点击命令。
- 写完 `**粗体**` 等行内标记后，按 **空格或回车** 转换。
- NoteMark 刚切换为标题时，如果尚未输入内容或移动光标，按 **退格**、**Esc** 或 **Ctrl+K** 即可恢复正文。已有文字时，可按 **⌘⇧B** 切回正文。
- 点击菜单栏 NoteMark 图标，可 **暂停 Markdown 转换**、**恢复 Markdown 转换** 或 **退出 NoteMark**。手动暂停仅保持到本次退出；下次启动会在权限就绪后自动开启。
- 按 **⌘Z** 撤销。段落转换可能需要撤销两次。

## 支持的语法

在空行行首输入标记，再按 **空格**。`-`、`*`、`[]` 和 `[ ]` 也可加在已有段落的文字前。

| 输入 | 效果 |
| --- | --- |
| `#` / `##` / `###` | 标题 / 小标题 / 次级标题 |
| `-` / `*` | 圆点列表 `•` |
| `1.` | 编号列表 |
| `[]` / `[ ]` / `- [ ]` | 待办清单（也支持 `［］`、`【】`） |
| `>` | 引用 |
| 三个反引号 | 等宽代码段落，再次输入退出 |

三个反引号后加 `swift` 等语言名，再按 **回车**，也可开始代码段落；不提供语法高亮。

行内标记：`**粗体**`、`*斜体*`、`***粗斜体***`、`__粗体__`、`_斜体_`、`` `代码` ``、`~~删除线~~`、`[链接](https://example.com)`。

Slash 命令：`/h1`、`/h2`、`/h3`、`/body`、`/code`、`/quote`、`/checklist`、`/bullets`、`/dashed`、`/numbered`。菜单搜索会匹配命令名称、说明和中英文别名；例如“列表”会显示全部列表类型，“序号列表”会匹配编号列表。全角 `／` 也可打开菜单。首次在空行输入 `/` 会展示完整菜单。继续输入时仅展示匹配结果，例如 `/标题`、`/题`；输入空格或无匹配内容会关闭菜单，退格回到单独 `/` 也不会重新打开。继续输入匹配文字可重新展示；有效名称末尾的空格不影响匹配。用回车、Tab 或点击执行。中文输入法组词时，空格、回车、方向键和 Esc 交给输入法，确认候选词后继续搜索，再按回车执行。

## 无法转换时

- 检查 **应用程序** 中的 NoteMark 是否已授权，再退出并重新打开。更换签名身份时可能需要再次授权。
- 已暂停时点击菜单栏中的 **恢复 Markdown 转换**；连接失败时点击 **重试输入连接**。
- 待办转换失败时，检查备忘录 **格式 → 核对清单** 是否可用，也可按 **⌘⇧L** 测试（[Apple 快捷键说明](https://support.apple.com/guide/notes/apd46c25187e/mac)）。原生命令不可用时，NoteMark 会保留标记。
- 先在新建、未锁定笔记的空行试用。搜索框、选中文字和代码段落不会触发普通 Markdown 转换。

## 注意事项

- 这是本地菜单栏辅助程序，不保存或上传笔记内容，不修改备忘录数据库。
- 段落使用备忘录原生样式，行内格式保留当前字号。行内转换会短暂使用剪贴板；若未复制新内容，转换后会恢复原内容。
- 暂不支持整篇转换、嵌套 Markdown 和 Markdown 图片插入；包含图片的当前段落会跳过转换。
- 给已有文字加圆点列表或待办清单时，最多检查光标后的 512 个 UTF-16 单元；无法在此范围内确认段落结束时，会跳过转换。
- 已在 macOS 27.0.1 / Apple Silicon 编译；真实备忘录输入、输入法和快速连续输入仍需手动验证。详见[验证说明](VALIDATION.zh-CN.md)。

## 更新

退出 NoteMark，使用相同签名身份的新版本替换 **/Applications/NoteMark.app**。本地编译时运行：

```sh
sh scripts/build.sh
sh scripts/install.sh
```

安装脚本会检查签名兼容性、备份旧 App、退出程序，在原路径替换并重新打开。只检查、不安装时，运行 `sh scripts/install.sh --check`。

同签名身份的兼容版本应能沿用权限。首次从旧的 ad-hoc 签名版本换成证书签名版本，仍需重新授权一次。后续请保持签名身份和 Bundle ID 不变。详见 [Apple 对代码身份的说明](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)。

目前提供本地更新脚本，尚未加入 App 内下载更新。

## 编译

需要 macOS 14+ 和 Xcode/Swift 工具链，无第三方依赖。

先配置一次签名身份。从第一条命令输出中复制证书的 40 位 SHA-1：

```sh
security find-identity -v -p codesigning
sh scripts/configure-signing.sh CERTIFICATE_SHA1
```

选择保存在 Git 忽略的 `.signing-identity` 中，证书和私钥仍在钥匙串。macOS 可能要求允许 `codesign` 使用私钥，请在系统钥匙串弹窗中授权。本机开发可使用 Apple Development；公开分发需要 [Developer ID 签名和公证](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)。

```sh
swift test
sh scripts/build.sh
```

输出：`dist/NoteMark.app` 和 `dist/NoteMark-0.1.13.zip`。构建使用已配置的证书；未配置时会报错。临时 ad-hoc 测试构建可运行 `NOTEMARK_SIGNING_IDENTITY=- sh scripts/build.sh`，安装脚本会拒绝此类构建。

```sh
dist/NoteMark.app/Contents/MacOS/NoteMark --self-check
dist/NoteMark.app/Contents/MacOS/NoteMark --diagnose
```

`--self-check` 检查本地规则；`--diagnose` 输出系统版本、本进程权限及 App 最后记录的运行状态。本地状态文件不记录笔记文字或按键内容；退出后状态可能过时。

构建产物和本地配置已由 Git 忽略。

许可证：[MIT](LICENSE)。
