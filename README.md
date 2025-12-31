# mb_gitignore

MoonBit 的 `.gitignore` 规则解析与路径匹配库（matcher/engine）。

## 适用场景

- 构建工具/打包器：扫描文件树时跳过被忽略的文件
- 格式化/静态分析工具：遵循仓库的 `.gitignore` 过滤输入
- 任意需要“gitignore 风格 glob 匹配”的 MoonBit 程序

## 范围与非目标

- 本库支持多层 `.gitignore` 的合并（通过 `GitIgnoreChain`；CLI 默认会按目录层级加载）
- CLI 默认会读取 `.git/info/exclude`
- CLI 只是最小示例，不等价于 `git check-ignore`

## 功能

- 解析 `.gitignore` 规则：注释/空行、`!` 反选、`/` 锚定、目录规则（以 `/` 结尾）
- 通配符：`*`、`?`、`**`
- 字符类：`[abc]`、`[a-z]`、`[!a-z]`，支持 `[]]`（把 `]` 当作集合成员）
- 路径归一化：支持 Windows `\` 分隔符输入
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

## 命令行示例（判断某路径是否被忽略）

入口在 `src/main.mbt`。

- 默认行为：读取仓库根目录 `.gitignore`，并沿目标路径逐级读取每层目录下的 `.gitignore`，合并后判断
- 若传 `--gitignore <FILE>`：只读取该文件（保留旧行为）

参数说明：

- `--exclude <FILE>`：额外 excludes 文件（可重复），会参与合并
- `--no-info-exclude`：禁用 `.git/info/exclude` 的默认加载
- `--info-exclude <FILE>`：使用指定路径作为 info exclude 文件

加载优先级（后命中覆盖前命中）：

1. `--exclude` 指定的文件（按出现顺序）
2. `.git/info/exclude`
3. 仓库根目录 `.gitignore`
4. 目标路径沿途每层目录下的 `.gitignore`

注意：当使用 `--gitignore <FILE>` 时，会进入“单文件模式”，此时不会再自动加载上述其它来源。

运行：

```bash
moon run src -- <PATH> [--dir|--file] [--gitignore <FILE>] [--exclude <FILE> ...] [--no-info-exclude|--info-exclude <FILE>]
```

示例：

```bash
moon run .\src\main.mbt .\.mooncakes\
```

输出格式：

- `(path, ignored, reason)`

> 如果不传 `--dir/--file`，程序会尝试用 `@fs.is_dir(PATH)` 推断；当路径不存在时可能推断不准，建议显式指定。

