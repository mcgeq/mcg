# mg - 多功能包管理 CLI 工具

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Zig](https://img.shields.io/badge/zig-0.16.0-yellow.svg)](https://ziglang.org/)

一款基于 **Zig** 编写的跨生态系统包管理工具，无需第三方依赖。支持 **cargo**、**npm**、**pnpm**、**yarn**、**bun**、**pip**、**uv**、**pdm** 和 **poetry**。

## 功能特性

- **零依赖**: 基于纯 Zig 标准库构建
- **彩色输出**: 错误/警告/信息使用 ANSI 颜色编码
- **通配符支持**: `*` 和 `?` 模式匹配
- **智能检测**: 文件/目录存在性检查
- **自动检测**: 自动识别项目类型
- **文件操作**: 内置 `fs` 命令，支持预览模式

## 日志格式

```
[INFO]
    Created file: test.txt
[ERROR]
    Path not found: test.txt
[INFO]
    [dry-run] Remove: old.txt
```

- **级别头**: `[INFO]`、`[ERROR]`、`[WARN]`、`[DEBUG]`
- **缩进正文**: 日志正文会显示在下一行并带统一缩进
- **颜色编码**: ERROR(红色), INFO(绿色), WARN(黄色), DEBUG(青色)
- **预览模式**: `[dry-run]` 前缀用于预览操作

## 快速开始

```bash
# 从源码构建
git clone https://github.com/mcgeq/mg.git
cd mg
zig build

# 添加到 PATH (Windows)
set PATH=.\mg\zig-out\bin;%PATH%

# 或者创建别名
alias mg='.\mg\zig-out\bin\mg.exe'

# 使用 mg
mg add lodash          # 添加包
mg remove lodash       # 移除包
mg upgrade             # 升级所有包
mg version             # 显示 mg 版本
mg fs create src/      # 创建目录
mg fs copy a.txt b.txt # 复制文件
```

## 使用方法

### 通用命令

```bash
mg version             # 显示 mg 版本
mg run <target...>     # 映射到检测到的包管理器原生 run 子命令
mg exec -- <args...>   # 直接透传原生子命令到底层包管理器
```

### 包管理命令

```bash
mg add <package>       # 添加包
mg remove <package>    # 移除包
mg upgrade             # 升级所有包
mg install             # 安装依赖
mg list                # 列出依赖
mg analyze             # list 的别名
```

### 文件系统命令

```bash
mg fs create <path> [--dir] [--recursive|-r]   # 创建文件或目录
mg fs remove <path> [--recursive|-r|-p]        # 移除文件或目录
mg fs copy <src> <dst> [--recursive|-r]        # 复制文件或目录
mg fs move <src> <dst>          # 移动/重命名文件或目录
mg fs list [path]               # 列出目录内容
mg fs read <path>               # 读取文件内容
mg fs write <path> <content>    # 写入文件
mg fs exists <path>             # 检查路径是否存在
```

### 简短别名

| 命令 | 别名 |
|------|------|
| `fs create` | `c`, `touch` |
| `fs remove` | `r`, `rm` |
| `fs copy` | `cp`, `y` |
| `fs move` | `mv`, `m` |
| `fs list` | `ls` |
| `fs exists` | `test` |
| `fs read` | `cat` |
| `fs write` | `echo` |

### 选项

- `--cwd`, `-C <path>`: 在指定目录中解析并执行包管理命令或 `fs` 命令
- `--dry-run`, `-d`: 预览包管理命令或 `fs` 命令而不执行
- `--dev`, `-D`: 当检测到的包管理器支持时，使用开发依赖模式
- `--profile`, `-P <name>`: 当检测到的包管理器支持时，指定依赖 profile；该选项可以重复出现
- `--group`, `-G <name>`: `--profile` 的向后兼容别名；该选项也可以重复出现
- `--`: 将剩余参数追加到已映射出的原生命令后面
- `--help`, `-h`: 显示帮助
- `--version`: 显示 mg 版本

包管理命令也支持在 action 之后请求帮助，例如 `mg add -h`。使用 `mg version` 或 `mg --version` 可以查看当前 CLI 构建版本。

对于 `fs`，`-C/--cwd` 可以放在 `fs` 前，也可以放在 `fs` 子命令前，例如 `mg -C apps/web fs list src` 或 `mg fs --cwd=apps/web list src`。
对于包管理动作，重复的 `--profile` / `--group` 会按声明顺序统一保留下来。对于底层支持多 profile/group 选择的 install/list/upgrade 类动作，mg 现在会把 `--dev` 与全部显式 profile 合并成有效 profile 集；对于 add/remove 这类单目标动作，目前仍以最后一个显式 profile 作为目标组，没有显式 profile 时才回退到 `dev`。

> **注意**: 通配符模式 (`*`, `?`, `**`) 必须在 shell 中使用引号:
> - `mg fs r 'test*.txt'` - 正常工作
> - `mg fs r test*.txt` - 可能会被 shell 展开
> - `mg fs ls 'src/**/*.zig'` - 递归匹配 `src` 下的 Zig 文件

## 支持的包管理器

| 包管理器 | 命令 | 检测方式 | 优先级 |
|---------|------|---------|--------|
| Cargo | add, remove, upgrade, install, list | Cargo.toml | 0 (最高) |
| pnpm | add, remove, upgrade, install, list | `pnpm-lock.yaml` 或 `package.json.packageManager = "pnpm@..."` | 1 |
| Bun | add, remove, upgrade, install, list | `bun.lock` 或 `package.json.packageManager = "bun@..."` | 2 |
| npm | add, remove, upgrade, install, list | `package-lock.json`、`package.json.packageManager = "npm@..."`，或普通 `package.json` fallback | 3 |
| yarn | add, remove, upgrade, install, list | `yarn.lock` 或 `package.json.packageManager = "yarn@..."` | 4 |
| uv | add, remove, upgrade, install, list | `uv.lock` 或带 `[tool.uv]` 的 `pyproject.toml` | 5 |
| Poetry | add, remove, upgrade, install, list | `poetry.lock` 或带 `[tool.poetry]` 的 `pyproject.toml` | 6 |
| PDM | add, remove, upgrade, install, list | `pdm.lock` 或带 `[tool.pdm]` 的 `pyproject.toml` | 7 |
| pip | add, remove, upgrade, install, list | requirements.txt | 8 |

> 单独存在的 `pyproject.toml` 不会再默认判定为 Poetry，只有检测到对应锁文件或 `tool` 段时才会选定具体 Python 管理器。
> 对 Node 生态，`package.json.packageManager` 现在也会参与统一动作的通用检测；如果仓库只有普通 `package.json` 而没有更强的 lockfile/工具声明，mg 会默认回退到 `npm`。
> 对于同时存在 `Cargo.toml` 与 `package.json` 的混合仓库，通用检测优先级仍以上表为准；但执行 `mg run <target...>` 或 `mg exec -- run <target...>` 时，mg 会先检查 `package.json` 的 `scripts` 是否包含该 target。若命中，则优先选择 Node 管理器；未命中时才回退到通用优先级。
> 对于 monorepo/workspace 子包，普通 `package.json -> npm` 现在属于“弱 Node 信号”: mg 会继续向上查找父层更强的 Node 信号（如 `pnpm-lock.yaml`、`package.json.packageManager`），因此在 `pnpm` workspace 子包里执行统一动作或 `run` 仍会升级到 `pnpm`；但如果父层是 `Cargo.toml` 或 Python 工程根，则会保留当前子包的 Node 路径，而不会被跨生态根抢走。

## 当前支持矩阵

`mg` 当前提供的是一层固定的高层动作归一化，同时也提供了 `run <target>` 给原生支持 `run` 的管理器使用，以及 `exec -- <native args...>` 用于显式透传到底层检测出的包管理器。

| `mg` 动作 | cargo | npm | pnpm | bun | yarn | uv | poetry | pdm | pip |
|-----------|-------|-----|------|-----|------|----|--------|-----|-----|
| `add` | `cargo add` | `npm install` | `pnpm add` | `bun add` | `yarn add` | `uv add` | `poetry add` | `pdm add` | `pip install` |
| `remove` | `cargo remove` | `npm uninstall` | `pnpm remove` | `bun remove` | `yarn remove` | `uv remove` | `poetry remove` | `pdm remove` | `pip uninstall` |
| `upgrade` | `cargo update` | `npm update` | `pnpm update` | `bun update` | `yarn up` | `uv sync --upgrade` | `poetry update` | `pdm update` | `pip install --upgrade` |
| `install` | `cargo check` | `npm install` | `pnpm install` | `bun install` | `yarn install` | `uv sync` | `poetry install` | `pdm install` | `pip install` |
| `list` / `analyze` | `cargo tree` | `npm list` | `pnpm list` | `bun list` | `yarn list` | `uv tree` | `poetry show` | `pdm list` | `pip list` |
| `run <target...>` | `cargo run <target...>` | `npm run <target...>` | `pnpm run <target...>` | `bun run <target...>` | `yarn run <target...>` | `uv run <target...>` | `poetry run <target...>` | `pdm run <target...>` | `-` |
| `exec -- <native args...>` | `cargo <native args...>` | `npm <native args...>` | `pnpm <native args...>` | `bun <native args...>` | `yarn <native args...>` | `uv <native args...>` | `poetry <native args...>` | `pdm <native args...>` | `pip <native args...>` |

对于统一动作，`--dev`、`--profile` / `--group` 和 `--` 透传参数，都是在这张映射表确定后的原生命令基础上继续追加。
对于统一动作，如果 Node 项目没有 lockfile，但 `package.json.packageManager` 已声明为 `pnpm` / `yarn` / `bun` / `npm`，mg 会按该声明选定管理器；如果只有普通 `package.json`，则回退到 `npm`。
对于 monorepo/workspace 子包，如果当前目录只有普通 `package.json`，mg 会把它先记为 Node fallback，再继续向上查找父层更强的 Node 信号；因此子包可以继承 workspace 根的 `pnpm` / `yarn` / `bun`，但不会被父层 `Cargo.toml` / Python 根误吸走。
对支持 profile/group 选择的 install/list/upgrade 类动作，`--dev` 会和重复的 `--profile` / `--group` 一起构成有效 profile 集；对 add/remove，mg 当前仍使用最后一个显式 profile 作为目标组，没有显式 profile 时才回退到 `dev`。
对于 `run`，位置参数会直接变成底层 `run` 的目标与参数；`npm` / `pnpm` 在追加透传参数时会自动补底层需要的 `--` 分隔符。
对于混合仓库里的 `run` / `exec -- run`，如果 `package.json` 的 `scripts` 明确命中了目标名，mg 会优先走对应的 Node 管理器，而不是直接被 `Cargo.toml` 抢占。
对于 workspace 子包里的 `run`，如果子包脚本命中了目标，但本层没有 lockfile / `packageManager`，mg 会继续向上借用父层更强的 Node 管理器；例如在 `pnpm` workspace 子包里执行 `mg run build`，最终会走 `pnpm run build`。
对于 `exec`，`--cwd` 和 `--dry-run` 仍然生效，但 `--dev`、`--group` 不会再被自动翻译成底层管理器参数。

## 原生命令边界

`mg` 目前仍然以统一动作层为主，还不是每个生态原生 CLI 的完整短写镜像。

- 当前已支持：`add`、`remove`、`upgrade`、`install`、`list`、`analyze` 这些统一动作，以及 `mg run <target...>` 和 `mg exec -- <native args...>`。
- 像 `pnpm run build`、`pnpm run build:apk`、`npm run dev`、`cargo run`、`uv run`、`poetry run`、`pdm run` 这类原生命令，现在可以直接通过 `mg run ...` 进入。
- 在同时存在 `package.json` 与 `Cargo.toml` 的仓库里，脚本型 `run` 目标会先检查 `package.json#scripts`；例如 `mg run build:apk`、`mg exec -- run build` 会优先映射到 `npm` / `pnpm` / `bun` 的 `run`，只有脚本未命中时才回退到 Cargo 等通用检测顺序。
- 当前不会跨兄弟目录主动扫描完整 workspace graph；mg 仍然只沿“当前目录 -> 父目录”向上裁决，不会替你在多个 sibling package 之间做脚本拓扑搜索。
- `uv tree`、`poetry show`、`pdm list` 这类更高层 Python 原生命令现在也已有 `exec -- ...` 真实 smoke 覆盖，建议继续通过 `mg exec -- ...` 进入。
- `pdm run --list` 和 `pdm <script>` 这类脚本型原生命令，现在也已有 `exec -- ...` smoke 覆盖；例如 `mg exec -- run --list`、`mg exec -- smoke` 会直接透传给 `pdm`。
- 像 `cargo test`、`uv lock`、`pnpm dlx`、`pnpm exec` 这类其他原生命令，仍然建议通过 `mg exec -- ...` 进入。
- `mg build` 这种直接短写形式仍然不支持。
- 使用 `exec` 时建议保留 `--`，让后续参数完整按原生命令 argv 透传到底层管理器。
- 如果你需要自动的 `--dev` / `--profile` / `--group` 语义映射，请继续使用统一动作，而不是 `run` 或 `exec`。

## 示例

### Cargo 项目
```bash
mg add serde
# 等同于: cargo add serde

mg add -- --features derive serde
# 等同于: cargo add --features derive serde

mg remove serde
# 等同于: cargo remove serde
```

### npm 项目
```bash
mg -C apps/web add vite
# 等同于: (cd apps/web && npm install vite)

mg -d -C apps/web add vite
# 预览会带上 cwd，例如: [cwd=apps/web] npm install vite

mg add lodash
# 等同于: npm install lodash

mg add -D vitest
# 等同于: npm install --save-dev vitest

mg remove lodash
# 等同于: npm uninstall lodash

mg run build
# 等同于: npm run build

mg run build -- --watch
# 等同于: npm run build -- --watch

mg install -G docs -G test
# 当检测到的管理器支持时，会重复展开 group 选择

mg install -D -G docs -G lint
# 当检测到的管理器支持 profile/group 选择时，会把 dev/docs/lint 一起纳入

mg install -P docs -P lint
# 与 --group 语义相同，但更贴近统一 profile 抽象
```

### Python/uv
```bash
mg add requests
# 等同于: uv add requests

mg add -G docs mkdocs
# 等同于: uv add --group docs mkdocs

mg install -G docs -G test -- --frozen
# 等同于: uv sync --group docs --group test --frozen

mg install -D -G docs -G lint
# 等同于: uv sync --group dev --group docs --group lint

mg install -P docs -P lint
# 等同于: uv sync --group docs --group lint
```

### Python/Poetry
```bash
mg add -D pytest
# 等同于: poetry add --group dev pytest

mg install -G docs -G lint
# 等同于: poetry install --with docs --with lint

mg install -D -G docs -G lint
# 等同于: poetry install --with dev --with docs --with lint

mg install -P docs -P lint
# 等同于: poetry install --with docs --with lint
```

### Python/PDM
```bash
mg add -P dev pytest
# 等同于: pdm add --dev pytest

mg install -G test
# 等同于: pdm install --group test

mg install -D -P docs -P lint
# 等同于: pdm install --dev --group docs --group lint

mg list -D -G docs -G lint
# 等同于: pdm list --dev --group docs --group lint
```

对于 PDM，通用的 `dev` profile 会优先归一化为原生 `--dev`，其余非 `dev` profile 继续展开为重复的 `--group` 选择。

### 通配符示例 (新增)
```bash
# 删除多个匹配的文件
mg fs r 'test*.txt'       # 删除所有 test*.txt 文件
mg fs r '*.log'          # 删除所有 log 文件
mg fs r 'build/**/*.tmp' # 递归删除 build/ 下所有 .tmp 文件

# 删除前预览
mg fs r 'old_*.tmp' --dry-run

# 使用模式列出
mg fs ls 'src/*.c'         # 列出 src/ 下所有 .c 文件
mg fs ls 'src/**/*.zig'    # 递归列出 src/ 下所有 .zig 文件
```

## 文件系统操作

```bash
# 自动检测创建
mg fs c test.txt       # 创建文件
mg fs c src/           # 创建目录 (尾部斜杠)
mg fs c a.txt b.txt    # 一次创建多个文件

# 通配符支持 (新增)
mg fs r 'test*.txt'      # 删除 test1.txt, test2.txt 等
mg fs r 'demo_?.txt'   # 删除 demo_a.txt, demo_b.txt (单个字符)
mg fs r '*.log'         # 删除所有 .log 文件
mg fs r 'cache/**/*.tmp' # 递归删除 cache/ 下所有 .tmp 文件
mg fs r 'backup*' --dry-run  # 预览删除
mg fs ls '*.txt'        # 列出所有 .txt 文件
mg fs ls 'src/*.zig'    # 列出 src/ 下所有 .zig 文件
mg fs ls 'src/**/*.zig' # 递归列出 src/ 下所有 .zig 文件

# 智能存在性检查 (新增)
mg fs c existing.txt
# [INFO]
#     File already exists: existing.txt

# 递归复制
mg fs y src/ backup/ --recursive  # 递归复制目录

# 安全删除
mg fs r file.txt       # 删除文件
mg fs r dir/ --recursive  # 递归删除目录树

# 更精确的 move 报错
mg fs mv missing.txt out.txt
# [ERROR]
#     Source not found: missing.txt

mg fs mv draft.txt missing/out.txt
# [ERROR]
#     Destination parent directory not found: missing

# 预览模式
mg --dry-run fs remove old/
# [dry-run] Remove: old/
```

## 项目结构

```
mg/
├── build.zig           # Zig 构建配置
├── build.zig.zon       # Zig 包元数据与最低版本约束
├── docs/
│   └── zig-0.16-upgrade-plan.md
├── src/
│   ├── app.zig        # 应用调度与高层命令入口
│   ├── main.zig       # 主入口
│   ├── cli/
│   │   ├── help.zig   # CLI 帮助文案
│   │   ├── mod.zig
│   │   └── parser.zig # CLI 解析
│   ├── core/
│   │   ├── config.zig
│   │   ├── error.zig
│   │   ├── logger.zig
│   │   ├── mod.zig
│   │   ├── runtime.zig
│   │   └── types.zig
│   ├── fs/
│   │   ├── commands.zig
│   │   ├── core.zig
│   │   └── mod.zig
│   ├── pkgm/
│   │   ├── core.zig
│   │   ├── detect.zig
│   │   ├── executor.zig
│   │   ├── mod.zig
│   │   └── registry.zig
│   └── smoke.zig      # 真实包管理器 smoke 验证入口
└── README.md
```

## 构建

```bash
# Debug 构建
zig build

# Release 构建
zig build -Doptimize=ReleaseSafe

# 运行测试
zig build test

# 运行真实 smoke 验证
zig build smoke

# 只跑部分 smoke 场景
zig build smoke -- npm_run uv_run pip_exec_version

# 运行 profile dry-run smoke 场景
zig build smoke -- uv_install_profiles_dry_run poetry_install_profiles_dry_run pdm_list_profiles_dry_run

# 运行 package.json / packageManager fallback dry-run smoke 场景
zig build smoke -- npm_package_json_install_dry_run pnpm_package_manager_install_dry_run

# 运行 monorepo/workspace 子包裁决 smoke 场景
zig build smoke -- pnpm_workspace_child_install_dry_run pnpm_workspace_child_run npm_child_package_over_cargo_root_install_dry_run

# 运行更贴近原生命令的 exec smoke 场景
zig build smoke -- cargo_exec_test pnpm_exec_node uv_exec_lock

# 运行 npm / poetry / pdm 的真实工作流 smoke 场景
zig build smoke -- npm_exec_node poetry_run pdm_run

# 运行 native exec -- run 透传 smoke 场景
zig build smoke -- npm_exec_run pnpm_exec_run bun_exec_run yarn_exec_run uv_exec_run poetry_exec_run pdm_exec_run

# 运行更高层的 native subcommand smoke 场景
zig build smoke -- cargo_exec_check cargo_exec_metadata npm_exec_list pnpm_exec_list bun_exec_test yarn_exec_list uv_exec_sync poetry_exec_check

# 运行 Python 生态更高层 native subcommand smoke 场景
zig build smoke -- uv_exec_tree poetry_exec_show pdm_exec_list

# 运行 PDM 脚本型 native subcommand smoke 场景
zig build smoke -- pdm_exec_run_list pdm_exec_script_shortcut
```

请使用 Zig `0.16.0`。仓库通过 `build.zig.zon` 声明 `mg` 自身版本与最低 Zig 版本，并在 `build.zig` 中强制要求精确 `0.16.0`。

`zig build smoke` 会在 `.zig-cache/smoke/<scenario>` 下生成最小示例工程，并对本机可用的包管理器执行真实子进程验证。当前覆盖范围已经包括 `run`、`exec -- --version`、`uv` / `poetry` / `pdm` 的 profile 类 dry-run 预览场景、`package.json` / `packageManager` fallback 的 dry-run 预览场景、monorepo/workspace 子包起始目录裁决场景，以及更贴近原生命令的 `cargo test`、`cargo check`、`cargo metadata --no-deps`、`npm exec -- node smoke.js`、`npm list`、`pnpm exec node smoke.js`、`pnpm list`、`bun test`、`yarn list`、`poetry check`、`poetry show`、`poetry run python smoke.py`、`pdm list`、`pdm run --list`、`pdm <script>` shortcut、`pdm run python smoke.py`、`uv lock`、`uv sync`、`uv tree`，以及 `npm` / `pnpm` / `bun` / `yarn` / `uv` / `poetry` / `pdm` 的 `exec -- run ...` 透传路径。新增 smoke 也已经覆盖了“父层 `pnpm` workspace 根 + 子包普通 `package.json`”和“父层 Cargo 根 + 子包普通 `package.json`”这两类典型混合仓库裁决，并把 Python 生态更高层的 `tree/show/list` 原生命令与 `pdm` 脚本型 shortcut 一起纳入了同一套验证链路。未安装的管理器会标记为 `SKIP`；像本机工具链缺件这类明确的环境阻塞也会被标记为 `SKIP`，避免误判为 `mg` 分发错误。

## 为什么选择 Zig?

- **无运行时依赖**: 编译为单个静态二进制文件
- **性能**: 原生级别速度
- **安全性**: 内存安全，无垃圾回收
- **简洁**: 标准库就是你所需要的

## 贡献

1. 添加新的包管理器: 更新 `src/pkgm/` 下的相关文件
2. 改进错误处理: 更新 `src/core/error.zig`
3. 添加测试: 添加到现有测试部分

## 许可证

MIT License

---

**基于 Zig 构建** ⚡
