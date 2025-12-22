# mb_gitignore

一个用 MoonBit 实现的 `.gitignore` 解析与匹配库，并带了一个简单的命令行示例用于判断某个路径是否会被忽略。

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

## 命令行示例（判断某路径是否被忽略）

入口在 `src/main.mbt`，默认读取仓库根目录的 `.gitignore`。

运行：

```bash
moon run src -- <PATH> [--dir|--file] [--gitignore <FILE>]
```

输出格式：

- `(path, ignored, reason)`

退出码：

- `0`：ignored 为 `true`
- `1`：ignored 为 `false`
- `2`：参数/读取 `.gitignore` 失败

## 开发

```bash
moon fmt
moon test
moon info
```

## 已知限制（目前实现）

- 只解析单个 `.gitignore` 内容；未实现 Git 那套“多层目录 `.gitignore` + `.git/info/exclude` + global excludes”的合并逻辑
- 通配与边界行为以测试覆盖为准；如你需要更严格对齐 Git 行为，可以提供用例继续补齐
