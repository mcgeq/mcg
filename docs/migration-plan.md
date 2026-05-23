# Zig 到 C++23 迁移计划

这份计划用于跟踪原 Zig 版 `mg` 到当前 C++23 版 `mg` 的剩余迁移工作。当前约束很明确：

- 最终命令名保持 `mg`，Windows 构建产物应为 `mg.exe`。
- C++ 版本放在 `F:\mcgeq\cpps\mcg`，不修改原 Zig 仓库 `F:\mcgeq\mcg`。
- 不新增 `tools/smoke.py`；真实 smoke 继续放在 `test/mg_cli_real_smoke.cmake`。
- CMake preset、vcpkg、Catch2、benchmark、fuzz、modules 路径继续按 C++23 项目维护。

## 当前状态

| 模块 | C++23 状态 | 说明 |
| --- | --- | --- |
| CLI 名称 | 完成 | CMake project 为 `mg`，CLI 输出名为 `mg.exe`。 |
| C++ 标准 | 完成 | 主库、CLI、测试、bench、fuzz、modules 路径统一 C++23。 |
| 包管理器检测 | 完成 | 覆盖 Cargo、npm、pnpm、Bun、Yarn、pip、uv、Poetry、PDM。 |
| `packageManager` 检测 | 完成 | 支持 pnpm / bun / yarn / npm 的 `package.json.packageManager`。 |
| monorepo child routing | 完成 | 子目录 plain `package.json` 可继承父级 pnpm 等强 Node 信号，也避免被父级 Cargo/Python 根目录抢走。 |
| `run` / `exec --` | 完成 | 支持 native run 与显式原生命令透传。 |
| `--dev` / `--profile` / `--group` | 完成 | install/list/upgrade 合并有效 profile，add/remove 使用单目标 profile。 |
| fs 命令 | 完成 | create/remove/copy/move/list/read/write/exists、短别名、dry-run、wildcard `*` / `?` / `**` 已覆盖。 |
| dry-run preview | 完成 | 包命令与 fs 命令均不实际执行，并输出命令预览。 |
| 日志格式 | 完成 | 保留 `[INFO]` / `[ERROR]` 分层输出与 ANSI 开关。 |
| 真实 smoke | 基本完成 | CMake-only 脚本覆盖 Zig smoke 的核心场景，支持场景筛选、失败汇总、manager banner 校验、生成路径校验。 |

## 与 Zig 版相比的差异

| 主题 | Zig 版 | C++23 版 | 迁移判断 |
| --- | --- | --- | --- |
| 构建入口 | `zig build` / `zig build smoke` | `cmake --preset ...` / `cmake --build ...` / `ctest` | 已按 C++ 生态替换。 |
| 依赖模型 | Zig 标准库，无第三方依赖 | CMake + vcpkg + Catch2，bench/fuzz 可选 | 符合 C++23 项目定位。 |
| smoke runner | `src/smoke.zig` 编译后运行 | `test/mg_cli_real_smoke.cmake` | 已迁移，不加 Python runner。 |
| 场景筛选 | `zig build smoke -- scenario...` | `-Dmg_REAL_SMOKE_SCENARIOS="a;b"` 后运行 `run-real-smoke` | 已可用，但 ergonomics 不如 Zig 直接。 |
| smoke 数据结构 | Zig typed struct 数组 | CMake 函数和场景调用 | 功能够用，可读性稍弱。 |
| dry-run smoke | 先探测 manager，再运行 dry-run | 同样先检查 PATH | 与 Zig 行为一致；若要纯计划校验，应另加 CTest dry-run 单元覆盖。 |
| 输出二进制 | `zig-out/bin/mg` | preset build 目录下 `mg.exe` | 已完成。 |
| 原始中文 README 信息量 | 较完整 | C++ README 偏英文 | 待补中文说明。 |

## 优先级计划

### P0：保持 smoke parity 稳定

1. 继续只维护 `test/mg_cli_real_smoke.cmake`，不引入 `tools/smoke.py`。
2. 每次修改 package routing 后至少跑：
   - `ctest --preset dev-debug`
   - `cmake --build --preset dev-debug --target run-real-smoke`
3. 对真实 manager 不稳定的场景保留 SKIP 机制，但 `mg` 行为错误必须计为 FAIL。
4. 逐步补全 generated path 校验，目前已覆盖 `cargo_exec_check`、`uv_exec_sync`、`uv_exec_lock`。

### P1：补用户文档

1. 增加中文 README 或中文使用说明，内容对齐 Zig README 的命令示例。
2. README 中继续强调实际 CLI 名是 `mg`，不是 `mcg`。
3. 文档化 `mg_REAL_SMOKE_SCENARIOS` 的常用组合：
   - profile dry-run
   - packageManager fallback
   - workspace child routing
   - native `exec -- run`
4. 把常见 Windows 问题写清楚：vcpkg triplet、MinGW/MSVC ABI 混用、缺少 manager 时 smoke 会 SKIP。

### P2：项目与发布完善

1. 复查 Capricorn 是否需要同步相同的 C++23 工程升级：
   - C++23 preset
   - vcpkg toolchain/triplet 处理
   - CLI 输出名变量
   - modules/bench/fuzz/dev preset 结构
2. 决定是否保留内部 namespace/target 全部为 `mg`。
3. 准备 release 构建流程：`default-release`、`msvc-release`、压缩包、checksum。

### P3：非 Zig parity 的增强项

这些不是 Zig 版已有能力，但以后可以考虑：

1. 配置文件，例如 `.mgrc` 或 `mg.toml`，用于固定默认 profile、manager 偏好。
2. 更深的 workspace graph 扫描，跨 sibling package 找 script。
3. 原生命令短写，例如 `mg build` 自动映射到 `mg run build`。当前仍推荐显式 `mg run build`。
4. 更结构化的 CMake smoke 场景表，减少重复脚本代码。

## 推荐验证命令

```powershell
cmake --preset dev-debug
cmake --build --preset dev-debug
ctest --preset dev-debug
```

运行选定真实 smoke：

```powershell
cmake --preset dev-debug -Dmg_REAL_SMOKE_SCENARIOS="npm_package_json_install_dry_run;pnpm_package_manager_install_dry_run;pnpm_workspace_child_install_dry_run;uv_install_profiles_dry_run"
cmake --build --preset dev-debug --target run-real-smoke
```
