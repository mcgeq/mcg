# mg - Multi-Package Manager CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Zig](https://img.shields.io/badge/zig-0.16.0-yellow.svg)](https://ziglang.org/)

A cross-ecosystem package management tool written in **Zig** without third-party dependencies. Supports **cargo**, **npm**, **pnpm**, **yarn**, **bun**, **pip**, **uv**, **pdm**, and **poetry**.

## Features

- **Zero dependencies**: Built with pure Zig standard library
- **Colored output**: ANSI color codes for errors/warnings/info
- **Wildcard support**: `*` and `?` pattern matching
- **Smart detection**: File/directory existence checks
- **Auto-detection**: Automatically detects project type
- **File system operations**: Built-in `fs` commands with dry run mode

## Log Format

```
[INFO]
    Created file: test.txt
[ERROR]
    Path not found: test.txt
[INFO]
    [dry-run] Remove: old.txt
```

- **Level header**: `[INFO]`, `[ERROR]`, `[WARN]`, `[DEBUG]`
- **Indented body**: Log messages are rendered on the next indented line
- **Color coding**: ERROR(red), INFO(green), WARN(yellow), DEBUG(cyan)
- **Dry-run**: `[dry-run]` prefix for preview

## Quick Start

```bash
# Build from source
git clone https://github.com/mcgeq/mg.git
cd mg
zig build

# Add to PATH (Windows)
set PATH=.\mg\zig-out\bin;%PATH%

# Or create alias
alias mg='.\mg\zig-out\bin\mg.exe'

# Use mg
mg add lodash          # Add package
mg remove lodash       # Remove package
mg upgrade             # Upgrade packages
mg version             # Show the mg version
mg fs create src/      # Create directory
mg fs copy a.txt b.txt # Copy files
```

## Usage

### General Commands

```bash
mg version             # Show the mg version
mg run <target...>     # Map to the detected manager's native run subcommand
mg exec -- <args...>   # Pass native subcommands through to the detected manager
```

### Package Manager Commands

```bash
mg add <package>       # Add package
mg remove <package>    # Remove package
mg upgrade             # Upgrade all packages
mg install             # Install dependencies
mg list                # List dependencies
mg analyze             # Alias of list
```

### File System Commands

```bash
mg fs create <path> [--dir] [--recursive|-r]   # Create file or directory
mg fs remove <path> [--recursive|-r|-p]        # Remove file or directory
mg fs copy <src> <dst> [--recursive|-r]        # Copy file or directory
mg fs move <src> <dst>          # Move/rename file or directory
mg fs list [path]               # List directory contents
mg fs read <path>               # Read file contents
mg fs write <path> <content>    # Write to file
mg fs exists <path>             # Check if path exists
```

### Short Aliases

| Command | Aliases |
|---------|---------|
| `fs create` | `c`, `touch` |
| `fs remove` | `r`, `rm` |
| `fs copy` | `cp`, `y` |
| `fs move` | `mv`, `m` |
| `fs list` | `ls` |
| `fs exists` | `test` |
| `fs read` | `cat` |
| `fs write` | `echo` |

### Options

- `--cwd`, `-C <path>`: Resolve package commands or `fs` commands in the given directory
- `--dry-run`, `-d`: Preview package commands or `fs` commands without execution
- `--dev`, `-D`: Use dev dependency mode when the detected manager supports it
- `--profile`, `-P <name>`: Target a dependency profile when the detected manager supports it; this flag can be repeated
- `--group`, `-G <name>`: Backward-compatible alias of `--profile`; this flag can also be repeated
- `--`: Append the remaining arguments to the mapped native command
- `--help`, `-h`: Show help
- `--version`: Show the mg version

Package-specific help can also be requested after the action, for example `mg add -h`. Use `mg version` or `mg --version` to inspect the current CLI build version.

For `fs`, `-C/--cwd` can be placed before `fs` or before the fs subcommand, for example `mg -C apps/web fs list src` or `mg fs --cwd=apps/web list src`.
For package actions, repeated `--profile` / `--group` values are preserved in declaration order. Install/list/upgrade flows that support profile/group selection now merge `--dev` together with all explicit profiles into one effective profile set. Add/remove still target a single profile, where the last explicit profile wins and `dev` is only used as a fallback when no explicit profile was provided.

> **Note**: Wildcard patterns (`*`, `?`, `**`) must be quoted in shell:
> - `mg fs r 'test*.txt'` - works
> - `mg fs r test*.txt` - may be expanded by shell
> - `mg fs ls 'src/**/*.zig'` - recursively matches Zig files under `src`

## Supported Package Managers

| Package Manager | Commands | Detection | Priority |
|----------------|----------|-----------|----------|
| Cargo | add, remove, upgrade, install, list | Cargo.toml | 0 (highest) |
| pnpm | add, remove, upgrade, install, list | `pnpm-lock.yaml` or `package.json.packageManager = "pnpm@..."` | 1 |
| Bun | add, remove, upgrade, install, list | `bun.lock` or `package.json.packageManager = "bun@..."` | 2 |
| npm | add, remove, upgrade, install, list | `package-lock.json`, `package.json.packageManager = "npm@..."`, or plain `package.json` fallback | 3 |
| yarn | add, remove, upgrade, install, list | `yarn.lock` or `package.json.packageManager = "yarn@..."` | 4 |
| uv | add, remove, upgrade, install, list | uv.lock or `pyproject.toml` with `[tool.uv]` | 5 |
| Poetry | add, remove, upgrade, install, list | poetry.lock or `pyproject.toml` with `[tool.poetry]` | 6 |
| PDM | add, remove, upgrade, install, list | pdm.lock or `pyproject.toml` with `[tool.pdm]` | 7 |
| pip | add, remove, upgrade, install, list | requirements.txt | 8 |

> Plain `pyproject.toml` is not treated as Poetry by default. mg only selects a Python manager when it finds a matching lockfile or tool section.
> For Node ecosystems, `package.json.packageManager` now also participates in generic high-level action detection. If a project only has a plain `package.json` and no stronger lockfile/tool signal, mg falls back to `npm`.
> In mixed repositories that contain both `Cargo.toml` and `package.json`, the generic detection priority still follows the table above. However, `mg run <target...>` and `mg exec -- run <target...>` first check whether `package.json#scripts` contains that target. When it does, mg prefers a Node manager before falling back to the generic priority order.
> For monorepo/workspace child packages, plain `package.json -> npm` is now treated as a weak Node signal. mg keeps walking upward for stronger Node signals such as `pnpm-lock.yaml` or `package.json.packageManager`, so a `pnpm` workspace child still upgrades to `pnpm`, while a parent Cargo/Python root will not steal the child package's Node path.

## Current Support Matrix

`mg` currently normalizes a fixed set of high-level actions. It also exposes `run <target>` for native `run`-capable managers and `exec -- <native args...>` for explicit pass-through to the detected package manager.

| `mg` action | cargo | npm | pnpm | bun | yarn | uv | poetry | pdm | pip |
|-------------|-------|-----|------|-----|------|----|--------|-----|-----|
| `add` | `cargo add` | `npm install` | `pnpm add` | `bun add` | `yarn add` | `uv add` | `poetry add` | `pdm add` | `pip install` |
| `remove` | `cargo remove` | `npm uninstall` | `pnpm remove` | `bun remove` | `yarn remove` | `uv remove` | `poetry remove` | `pdm remove` | `pip uninstall` |
| `upgrade` | `cargo update` | `npm update` | `pnpm update` | `bun update` | `yarn up` | `uv sync --upgrade` | `poetry update` | `pdm update` | `pip install --upgrade` |
| `install` | `cargo check` | `npm install` | `pnpm install` | `bun install` | `yarn install` | `uv sync` | `poetry install` | `pdm install` | `pip install` |
| `list` / `analyze` | `cargo tree` | `npm list` | `pnpm list` | `bun list` | `yarn list` | `uv tree` | `poetry show` | `pdm list` | `pip list` |
| `run <target...>` | `cargo run <target...>` | `npm run <target...>` | `pnpm run <target...>` | `bun run <target...>` | `yarn run <target...>` | `uv run <target...>` | `poetry run <target...>` | `pdm run <target...>` | `-` |
| `exec -- <native args...>` | `cargo <native args...>` | `npm <native args...>` | `pnpm <native args...>` | `bun <native args...>` | `yarn <native args...>` | `uv <native args...>` | `poetry <native args...>` | `pdm <native args...>` | `pip <native args...>` |

For normalized actions, `--dev`, `--profile` / `--group`, and `--` passthrough arguments are applied on top of the mapped command when that manager/action pair supports them.
For normalized actions, if a Node project has no lockfile but `package.json.packageManager` explicitly declares `pnpm` / `yarn` / `bun` / `npm`, mg uses that manager. If the project only has a plain `package.json`, mg falls back to `npm`.
For monorepo/workspace child packages, if the current directory only has a plain `package.json`, mg records it as a Node fallback and keeps walking upward for stronger Node signals. This lets a child package inherit workspace-root `pnpm` / `yarn` / `bun` without being incorrectly absorbed by a parent `Cargo.toml` or Python root.
For install/list/upgrade style flows that support profile/group selection, `--dev` is merged with repeated `--profile` / `--group` values into one effective profile set. For add/remove, mg currently keeps the last explicit profile as the target profile and falls back to `dev` only when no explicit profile was provided.
For `run`, positional args become the native run target/args. `npm` and `pnpm` automatically insert their native `--` separator before passthrough args.
For mixed repositories, `run` / `exec -- run` will prefer a Node manager when `package.json#scripts` explicitly contains the requested target instead of being preempted by `Cargo.toml`.
For workspace child-package `run`, if the child script matches but that directory has no lockfile or `packageManager`, mg keeps walking upward to borrow the stronger parent Node manager. For example, `mg run build` inside a `pnpm` workspace child resolves to `pnpm run build`.
For `exec`, `--cwd` and `--dry-run` still apply, but `--dev` and `--group` are not rewritten into manager-native flags.

## Native Command Boundary

`mg` is still primarily a unified action layer, not a full shorthand mirror of every native CLI.

- Supported today: normalized package actions such as `add`, `remove`, `upgrade`, `install`, `list`, and `analyze`, plus `mg run <target...>` and `mg exec -- <native args...>`.
- Native `run` flows such as `pnpm run build`, `pnpm run build:apk`, `npm run dev`, `cargo run`, `uv run`, `poetry run`, and `pdm run` are supported directly through `mg run ...`.
- In repositories that contain both `package.json` and `Cargo.toml`, script-style run targets first check `package.json#scripts`; for example, `mg run build:apk` or `mg exec -- run build` will prefer `npm` / `pnpm` / `bun` `run` when that script exists, and only fall back to Cargo when it does not.
- mg still walks only along the current-directory-to-parent chain. It does not proactively scan the full workspace graph across sibling packages or search for scripts across multiple peer project roots.
- Higher-level Python-native commands such as `uv tree`, `poetry show`, and `pdm list` now also have real `exec -- ...` smoke coverage, and should continue to be accessed through `mg exec -- ...`.
- Script-oriented native PDM commands such as `pdm run --list` and `pdm <script>` also now have `exec -- ...` smoke coverage; for example, `mg exec -- run --list` and `mg exec -- smoke` are forwarded directly to `pdm`.
- Other native flows such as `cargo test`, `uv lock`, `pnpm dlx`, and `pnpm exec` are supported through `mg exec -- ...`.
- Direct shorthand forms such as `mg build` are still not supported.
- Use `--` after `exec` so the remaining tokens are forwarded verbatim to the detected manager.
- If you need automatic `--dev` / `--profile` / `--group` translation, use the normalized actions instead of `run` or `exec`.

## Examples

### Cargo Project
```bash
mg add serde
# Equivalent to: cargo add serde

mg add -- --features derive serde
# Equivalent to: cargo add --features derive serde

mg remove serde
# Equivalent to: cargo remove serde
```

### npm Project
```bash
mg -C apps/web add vite
# Equivalent to: (cd apps/web && npm install vite)

mg -d -C apps/web add vite
# Preview includes cwd, e.g. [cwd=apps/web] npm install vite

mg add lodash
# Equivalent to: npm install lodash

mg add -D vitest
# Equivalent to: npm install --save-dev vitest

mg remove lodash
# Equivalent to: npm uninstall lodash

mg run build
# Equivalent to: npm run build

mg run build -- --watch
# Equivalent to: npm run build -- --watch

mg install -G docs -G test
# Repeats group selection when the detected manager supports it

mg install -D -G docs -G lint
# Merges dev/docs/lint into one effective profile set when supported

mg install -P docs -P lint
# Same underlying behavior as --group, but expressed with the generic profile alias
```

### Python/uv
```bash
mg add requests
# Equivalent to: uv add requests

mg add -G docs mkdocs
# Equivalent to: uv add --group docs mkdocs

mg install -G docs -G test -- --frozen
# Equivalent to: uv sync --group docs --group test --frozen

mg install -D -G docs -G lint
# Equivalent to: uv sync --group dev --group docs --group lint

mg install -P docs -P lint
# Equivalent to: uv sync --group docs --group lint
```

### Python/Poetry
```bash
mg add -D pytest
# Equivalent to: poetry add --group dev pytest

mg install -G docs -G lint
# Equivalent to: poetry install --with docs --with lint

mg install -D -G docs -G lint
# Equivalent to: poetry install --with dev --with docs --with lint

mg install -P docs -P lint
# Equivalent to: poetry install --with docs --with lint
```

### Python/PDM
```bash
mg add -P dev pytest
# Equivalent to: pdm add --dev pytest

mg install -G test
# Equivalent to: pdm install --group test

mg install -D -P docs -P lint
# Equivalent to: pdm install --dev --group docs --group lint

mg list -D -G docs -G lint
# Equivalent to: pdm list --dev --group docs --group lint
```

For PDM, the generic `dev` profile is normalized to the native `--dev` flag, while non-`dev` profiles continue to expand to repeated `--group` selectors.

### Wildcard Examples (NEW)
```bash
# Delete multiple matching files
mg fs r 'test*.txt'       # Remove all test*.txt files
mg fs r '*.log'          # Remove all log files
mg fs r 'build/**/*.tmp' # Recursively remove all .tmp files under build/

# Preview before deleting
mg fs r 'old_*.tmp' --dry-run

# List with pattern
mg fs ls 'src/*.c'         # List all .c files in src/
mg fs ls 'src/**/*.zig'    # Recursively list all .zig files under src/
```

## File System Operations

```bash
# Create with auto-detection
mg fs c test.txt       # Create file
mg fs c src/           # Create directory (trailing /)
mg fs c a.txt b.txt    # Create multiple files

# Wildcard support (NEW)
mg fs r 'test*.txt'      # Delete test1.txt, test2.txt, etc.
mg fs r 'demo_?.txt'   # Delete demo_a.txt, demo_b.txt (single char)
mg fs r '*.log'         # Delete all .log files
mg fs r 'cache/**/*.tmp' # Recursively delete .tmp files under cache/
mg fs r 'backup*' --dry-run  # Preview deletions
mg fs ls '*.txt'        # List all .txt files
mg fs ls 'src/*.zig'    # List all .zig files in src/
mg fs ls 'src/**/*.zig' # Recursively list all .zig files in src/

# Smart existence check (NEW)
mg fs c existing.txt
# [INFO]
#     File already exists: existing.txt

# Copy with recursive support
mg fs y src/ backup/ --recursive  # Copy directory recursively

# Remove safely
mg fs r file.txt       # Remove file
mg fs r dir/ --recursive  # Remove directory tree

# More precise move errors
mg fs mv missing.txt out.txt
# [ERROR]
#     Source not found: missing.txt

mg fs mv draft.txt missing/out.txt
# [ERROR]
#     Destination parent directory not found: missing

# Dry run to preview
mg --dry-run fs remove old/
# [dry-run] Remove: old/
```

## Building

```bash
# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseSafe

# Run tests
zig build test

# Run real package-manager smoke verification
zig build smoke

# Run only selected smoke scenarios
zig build smoke -- npm_run uv_run pip_exec_version

# Run profile dry-run smoke scenarios
zig build smoke -- uv_install_profiles_dry_run poetry_install_profiles_dry_run pdm_list_profiles_dry_run

# Run package.json / packageManager fallback dry-run smoke scenarios
zig build smoke -- npm_package_json_install_dry_run pnpm_package_manager_install_dry_run

# Run monorepo/workspace child-package routing smoke scenarios
zig build smoke -- pnpm_workspace_child_install_dry_run pnpm_workspace_child_run npm_child_package_over_cargo_root_install_dry_run

# Run native exec smoke scenarios
zig build smoke -- cargo_exec_test pnpm_exec_node uv_exec_lock

# Run npm / poetry / pdm real workflow smoke scenarios
zig build smoke -- npm_exec_node poetry_run pdm_run

# Run native exec -- run passthrough smoke scenarios
zig build smoke -- npm_exec_run pnpm_exec_run bun_exec_run yarn_exec_run uv_exec_run poetry_exec_run pdm_exec_run

# Run higher-level native subcommand smoke scenarios
zig build smoke -- cargo_exec_check cargo_exec_metadata npm_exec_list pnpm_exec_list bun_exec_test yarn_exec_list uv_exec_sync poetry_exec_check

# Run higher-level Python-native subcommand smoke scenarios
zig build smoke -- uv_exec_tree poetry_exec_show pdm_exec_list

# Run PDM script-oriented native subcommand smoke scenarios
zig build smoke -- pdm_exec_run_list pdm_exec_script_shortcut
```

## GitHub Release Packaging

- Workflow file: `.github/workflows/release.yml`
- Trigger:
  - push a formal release tag such as `v0.1.0`
  - or run `workflow_dispatch` manually with the same tag format, for example `v0.1.0`
- The workflow will:
  - create or reuse the matching GitHub Release
  - download official Zig `0.16.0`
  - build and upload these Release assets:
    - `mg-<tag>-windows-x86_64.exe`
    - `mg-<tag>-windows-x86_64.zip`
    - `mg-<tag>-windows-x86_64.sha256.txt`
    - `mg-<tag>-linux-x86_64`
    - `mg-<tag>-linux-x86_64.tar.gz`
    - `mg-<tag>-linux-x86_64.sha256.txt`
    - `mg-<tag>-macos-aarch64`
    - `mg-<tag>-macos-aarch64.tar.gz`
    - `mg-<tag>-macos-aarch64.sha256.txt`
- Typical flow:
  - `git tag v0.1.0`
  - `git push origin v0.1.0`
  - wait for Actions to create or update the matching GitHub Release

Use Zig `0.16.0`. `build.zig.zon` declares the package version and minimum Zig version, and `build.zig` enforces an exact `0.16.0` build. The `mg` package version in `build.zig.zon` remains `0.1.0`, while the Git Release tag uses the conventional `v` prefix, for example `v0.1.0`.

`zig build smoke` creates minimal sample projects under `.zig-cache/smoke/<scenario>` and runs real subprocess verification against locally available package managers. Current coverage includes `run`, `exec -- --version`, profile-oriented dry-run previews for `uv`, `poetry`, and `pdm`, dry-run previews for `package.json` / `packageManager` fallback detection, monorepo/workspace child-package start-directory routing, plus more native flows such as `cargo test`, `cargo check`, `cargo metadata --no-deps`, `npm exec -- node smoke.js`, `npm list`, `pnpm exec node smoke.js`, `pnpm list`, `bun test`, `yarn list`, `poetry check`, `poetry show`, `poetry run python smoke.py`, `pdm list`, `pdm run --list`, `pdm <script>` shortcuts, `pdm run python smoke.py`, `uv lock`, `uv sync`, `uv tree`, and native `exec -- run ...` passthrough for `npm`, `pnpm`, `bun`, `yarn`, `uv`, `poetry`, and `pdm`. The new workspace smoke coverage now explicitly exercises both “parent `pnpm` workspace root + child plain `package.json`” and “parent Cargo root + child plain `package.json`” routing, and now also brings Python-native `tree/show/list` style commands plus PDM script shortcuts into the same verification chain. Missing managers are reported as `SKIP`, and clearly local toolchain blockers are also downgraded to `SKIP` so they do not look like `mg` routing regressions.

## Why Zig?

- **No runtime dependencies**: Compiles to a single static binary
- **Performance**: Native-level speed
- **Safety**: Memory-safe with no garbage collector
- **Simplicity**: Standard library is all you need

## Contributing

1. Add a new package manager: Update the files under `src/pkgm/`
2. Improve error handling: Update `src/core/error.zig`
3. Add tests: Add to existing test sections

## License

MIT License

---

**Built with Zig** ⚡
