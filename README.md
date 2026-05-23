# mg - Multi-Package Manager CLI

`mg` is a small C++23 command-line tool that normalizes common package-manager
workflows across Cargo, Node, Python, and a few built-in file-system helpers.

The executable built by this repository is `mg.exe` on Windows.

## Features

- Detects project package managers from the current directory upward.
- Supports Cargo, npm, pnpm, Bun, Yarn, pip, uv, Poetry, and PDM.
- Maps common actions such as `add`, `remove`, `upgrade`, `install`, `list`,
  `run`, and explicit native pass-through with `exec --`.
- Includes `fs` helpers for create, remove, copy, move, list, read, write, and
  existence checks.
- Supports dry-run previews and cwd routing through `--dry-run` and `--cwd`.
- Builds as a C++23 library plus CLI with CMake presets.

## Quick Start

```powershell
cmake --workflow --preset default-debug
.\build\default-debug-gcc\mg.exe --help
```

For a cross-platform release build, use:

```sh
cmake --workflow --preset default-release
```

This is the primary release preset for Linux, macOS, and Windows environments
that provide a GNU-style `g++` toolchain. The resulting CLI is:

- `build/default-release-gcc/mg` on Linux and macOS
- `build/default-release-gcc/mg.exe` on Windows

For developer builds with tests through vcpkg:

```powershell
cmake --workflow --preset dev-debug
ctest --preset dev-debug
```

For a release build that also runs the developer-mode test preset:

```sh
cmake --workflow --preset dev-release
```

If you are using MSVC:

```powershell
cmake --workflow --preset msvc-release
```

## General Commands

```bash
mg version             # Show the mg version
mg add <package>       # Add a dependency
mg remove <package>    # Remove a dependency
mg upgrade             # Upgrade dependencies
mg install             # Install dependencies
mg list                # List dependencies
mg analyze             # Alias of list
mg run <target...>     # Use the detected manager's native run command
mg exec -- <args...>   # Forward native args to the detected manager
```

## Options

- `--cwd`, `-C <path>`: resolve package commands or `fs` commands in a directory.
- `--dry-run`, `-d`: preview the native command or file-system operation.
- `--dev`, `-D`: select dev dependency mode when the manager supports it.
- `--profile`, `-P <name>`: select a generic dependency profile.
- `--group`, `-G <name>`: backward-compatible alias of `--profile`.
- `--`: pass the remaining arguments through to the mapped native command.
- `--help`, `-h`: show help.
- `--version`: show the current `mg` version.

For `fs`, `-C/--cwd` can be placed before `fs` or before the fs subcommand, for
example `mg -C apps/web fs list src` or `mg fs --cwd=apps/web list src`.

## Package Manager Detection

| Package Manager | Detection | Priority |
| --- | --- | --- |
| Cargo | `Cargo.toml` | 0 |
| pnpm | `pnpm-lock.yaml` or `package.json.packageManager = "pnpm@..."` | 1 |
| Bun | `bun.lock` or `package.json.packageManager = "bun@..."` | 2 |
| npm | `package-lock.json`, `package.json.packageManager = "npm@..."`, or plain `package.json` fallback | 3 |
| Yarn | `yarn.lock` or `package.json.packageManager = "yarn@..."` | 4 |
| uv | `uv.lock` or `pyproject.toml` with `[tool.uv]` | 5 |
| Poetry | `poetry.lock` or `pyproject.toml` with `[tool.poetry]` | 6 |
| PDM | `pdm.lock` or `pyproject.toml` with `[tool.pdm]` | 7 |
| pip | `requirements.txt` | 8 |

Plain `pyproject.toml` is not treated as Poetry by default. `mg` only selects a
Python manager when it finds a matching lockfile or tool section.

For Node ecosystems, `package.json.packageManager` participates in generic
high-level action detection. If a project only has a plain `package.json` and no
stronger Node signal, `mg` falls back to npm.

In mixed repositories that contain both `Cargo.toml` and `package.json`, `run`
and `exec -- run` first check whether `package.json#scripts` contains the target.
When it does, `mg` prefers a Node manager before falling back to the generic
priority order.

## Support Matrix

| `mg` action | cargo | npm | pnpm | bun | yarn | uv | poetry | pdm | pip |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `add` | `cargo add` | `npm install` | `pnpm add` | `bun add` | `yarn add` | `uv add` | `poetry add` | `pdm add` | `pip install` |
| `remove` | `cargo remove` | `npm uninstall` | `pnpm remove` | `bun remove` | `yarn remove` | `uv remove` | `poetry remove` | `pdm remove` | `pip uninstall` |
| `upgrade` | `cargo update` | `npm update` | `pnpm update` | `bun update` | `yarn up` | `uv sync --upgrade` | `poetry update` | `pdm update` | `pip install --upgrade` |
| `install` | `cargo check` | `npm install` | `pnpm install` | `bun install` | `yarn install` | `uv sync` | `poetry install` | `pdm install` | `pip install` |
| `list` / `analyze` | `cargo tree` | `npm list` | `pnpm list` | `bun list` | `yarn list` | `uv tree` | `poetry show` | `pdm list` | `pip list` |
| `run <target...>` | `cargo run` | `npm run` | `pnpm run` | `bun run` | `yarn run` | `uv run` | `poetry run` | `pdm run` | - |
| `exec -- <args...>` | `cargo` | `npm` | `pnpm` | `bun` | `yarn` | `uv` | `poetry` | `pdm` | `pip` |

For normalized actions, `--dev`, `--profile` / `--group`, and `--` passthrough
arguments are applied on top of the mapped command when the manager/action pair
supports them.

## File System Commands

```bash
mg fs create <path> [--dir] [--recursive|-r]
mg fs remove <path> [--recursive|-r|-p]
mg fs copy <src> <dst> [--recursive|-r]
mg fs move <src> <dst>
mg fs list [path]
mg fs read <path>
mg fs write <path> <content>
mg fs exists <path>
```

Short aliases:

| Command | Aliases |
| --- | --- |
| `fs create` | `c`, `touch` |
| `fs remove` | `r`, `rm` |
| `fs copy` | `cp`, `y` |
| `fs move` | `mv`, `m` |
| `fs list` | `ls` |
| `fs exists` | `test` |
| `fs read` | `cat` |
| `fs write` | `echo` |

Quote wildcard patterns in shells so `mg` receives the pattern:

```bash
mg fs r 'test*.txt'
mg fs r 'build/**/*.tmp'
mg fs ls 'src/**/*.cpp'
```

## Building

```powershell
cmake --workflow --preset default-release
cmake --workflow --preset dev-release
cmake --preset default-debug
cmake --build --preset default-debug
cmake --preset dev-debug
cmake --build --preset dev-debug
ctest --preset dev-debug
```

The regular developer test suite includes a dry-run CLI smoke matrix that does
not require package managers such as npm, pnpm, uv, Poetry, or PDM to be
installed. To exercise real package-manager commands when those tools are
available locally, run:

```powershell
cmake --build --preset dev-debug --target run-real-smoke
```

To run only selected real smoke scenarios, configure the cache variable first:

```powershell
cmake --preset dev-debug -Dmg_REAL_SMOKE_SCENARIOS="npm_package_json_install_dry_run;uv_install_profiles_dry_run"
cmake --build --preset dev-debug --target run-real-smoke
```

To include the same real smoke layer in CTest, configure with:

```powershell
cmake --preset dev-debug -Dmg_ENABLE_REAL_SMOKE=ON
ctest --preset dev-debug -R real-smoke
```

Preset outputs are configured in `CMakePresets.json`. Common build directories:

- `default-debug`: `build/default-debug-gcc/`
- `default-release`: `build/default-release-gcc/`
- `dev-debug`: `build/dev-debug/`
- `dev-release`: `build/dev-release/`
- `msvc-debug`: `build/msvc-debug/`
- `msvc-release`: `build/msvc-release/`

The main CLI output name is `mg` on Unix-like platforms and `mg.exe` on Windows.

## Current Migration Notes

This repository is the C++23 refactor of the original Zig implementation. Core
package command planning, CLI parsing, execution previews, package-manager
detection, fs wildcard behavior, and the real smoke harness are implemented and
covered by Catch2/CTest.

Some internal names still use the historical `mg` namespace and CMake target
names while the shipped CLI remains `mg`. Remaining parity work is mostly around
extra edge-case coverage and deciding whether to rename internal symbols.

The detailed Zig-to-C++23 parity and migration plan is tracked in
[`docs/migration-plan.md`](docs/migration-plan.md).

## License

MIT License
