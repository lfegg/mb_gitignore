# mb_gitignore

一个用 MoonBit 实现的 `.gitignore` 解析与匹配库（matcher/engine），并带了一个最小命令行示例用于判断某个路径是否会被忽略。

## 定位

- 这是一个“规则文本 + 路径 -> 是否忽略”的库：用于在 MoonBit 程序中复用 `.gitignore` 的过滤逻辑
- 项目内置的 CLI 仅用于演示/调试，不追求完整复刻 `git check-ignore` 的所有行为

## 适用场景

- 构建/打包工具：遍历文件树时按 `.gitignore` 过滤
- 格式化/静态检查工具：让工具输入与仓库忽略规则一致
- 任何需要 gitignore 风格通配匹配（`* ? **`、字符类等）的 MoonBit 程序

## 范围与非目标

- 本库支持多层 `.gitignore` 的合并：你可以用 `GitIgnoreChain` 组合多个 `GitIgnore`
- CLI 默认会读取仓库根目录 `.gitignore`，并沿目标路径逐级读取每层目录下的 `.gitignore`
- CLI 默认会读取 `.git/info/exclude`
- 未实现“自动读取 git 配置”的 global excludes（例如 `core.excludesFile`）等

## 功能

- 解析 `.gitignore` 规则：注释/空行、`!` 反选、`/` 锚定、目录规则（以 `/` 结尾）
- 通配符：`*`、`?`、`**`
- 字符类：`[abc]`、`[a-z]`、`[!a-z]`，支持 `[]]`（把 `]` 当作集合成员）
- 路径归一化：支持 Windows `\\` 分隔符输入
- 目录传播语义：当某个目录被忽略时，其下的内容也会被视为忽略；并实现 “想 unignore 子文件必须先 unignore 父目录” 的行为

## 作为库使用

本项目库包在 `src/lib`，在你的包里引入：

`moon.pkg.json`：

```json
{
  "import": [
    { "path": "lfegg/mb_gitignore/src/lib", "alias": "gitignore" }
  ]
}
```

MoonBit 代码：

```mbt
let gi = @gitignore.GitIgnore::parse(
  #|*.log
  #|!important.log
  #|,
)

assert_eq(gi.is_ignored("a.log"), true)
assert_eq(gi.is_ignored("important.log"), false)
inspect(gi.why("a.log"), content="Some(\"*.log\")")
```

API 说明：

- `GitIgnore::parse(content, base? : String = "") -> GitIgnore`
- `gi.is_ignored(path, is_dir? : Bool = false) -> Bool`
- `gi.why(path, is_dir? : Bool = false) -> String?`：返回最后一条命中的规则原文

多层合并：

- `GitIgnoreChain::new() -> GitIgnoreChain`
- `chain.push(gi : GitIgnore) -> Unit`
- `chain.parse_and_push(content, base? : String = "") -> Unit`
- `chain.is_ignored(path, is_dir? : Bool = false) -> Bool`
- `chain.why(path, is_dir? : Bool = false) -> String?`

## 命令行示例（判断某路径是否被忽略）

入口在 `src/main.mbt`（用于示例/调试）。

- 默认行为：读取仓库根目录 `.gitignore`，并沿目标路径逐级读取每层目录下的 `.gitignore`
- 若传 `--gitignore <FILE>`：只读取该文件

参数说明：

- `--exclude <FILE>`：额外 excludes 文件（可重复），会参与合并
- `--no-info-exclude`：禁用 `.git/info/exclude` 的默认加载
- `--info-exclude <FILE>`：使用指定路径作为 info exclude 文件

加载优先级（后命中覆盖前命中，符合 gitignore “最后匹配生效” 的规则）：

1. `--exclude` 指定的文件（按出现顺序）
2. `.git/info/exclude`（可用 `--no-info-exclude` 禁用）
3. 仓库根目录 `.gitignore`
4. 目标路径沿途每层目录下的 `.gitignore`

注意：当使用 `--gitignore <FILE>` 时，会进入“单文件模式”，此时不会再自动加载上述其它来源。

运行：

```bash
moon run src -- <PATH> [--dir|--file] [--gitignore <FILE>] [--exclude <FILE> ...] [--no-info-exclude|--info-exclude <FILE>]
```

输出格式：

- `(path, ignored, reason)`

退出码：

- `0`：ignored 为 `true`
- `1`：ignored 为 `false`
- `2`：参数/读取 `.gitignore` 失败
