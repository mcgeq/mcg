# mg - Multi-Package Manager CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Zig](https://img.shields.io/badge/zig-0.15.1-yellow.svg)](https://ziglang.org/)

A cross-ecosystem package management tool written in **Zig** without third-party dependencies. Supports **cargo**, **npm**, **pnpm**, **yarn**, **bun**, **pip**, **pdm**, and **poetry**.

## Features

- **Zero dependencies**: Built with pure Zig standard library
- **Colored output**: ANSI color codes for errors/warnings/info
- **Wildcard support**: `*` and `?` pattern matching
- **Smart detection**: File/directory existence checks
- **Auto-detection**: Automatically detects project type
- **File system operations**: Built-in `fs` commands with dry run mode

## Log Format

```
[17:53:31] INFO Created file: test.txt
[17:53:31] ERROR Path not found: test.txt
[17:53:31] DEBUG [dry-run] Remove: old.txt
```

- **Timestamp**: `[HH:MM:SS]` (local time)
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
mg fs create src/      # Create directory
mg fs copy a.txt b.txt # Copy files
```

## Usage

### Package Manager Commands

```bash
mg add <package>       # Add package
mg remove <package>    # Remove package
mg upgrade             # Upgrade all packages
mg install             # Install dependencies
mg analyze             # List dependencies
```

### File System Commands

```bash
mg fs create <path>              # Create file or directory
mg fs remove <path>             # Remove file or directory
mg fs copy <src> <dst>          # Copy file or directory
mg fs move <src> <dst>          # Move/rename file or directory
mg fs list <path>               # List directory contents
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

### Options

- `--dry-run`, `-d`: Preview command without execution
- `--help`, `-h`: Show help

> **Note**: Wildcard patterns (`*`, `?`) must be quoted in shell:
> - `mg fs r 'test*.txt'` - works
> - `mg fs r test*.txt` - may be expanded by shell

## Supported Package Managers

| Package Manager | Commands | Detection File | Priority |
|----------------|----------|----------------|----------|
| Cargo | add, remove, upgrade | Cargo.toml | 0 (highest) |
| pnpm | add, remove, upgrade | pnpm-lock.yaml | 1 |
| Bun | add, remove, upgrade | bun.lock | 2 |
| npm | add, remove, upgrade | package-lock.json | 3 |
| yarn | add, remove, upgrade | yarn.lock | 4 |
| pip | add, remove, upgrade | requirements.txt | 5 |
| Poetry | add, remove, upgrade | pyproject.toml | 6 |
| PDM | add, remove, upgrade | pdm.lock | 7 |

## Examples

### Cargo Project
```bash
mg add serde -F derive
# Equivalent to: cargo add serde --features derive

mg remove serde
# Equivalent to: cargo remove serde
```

### npm Project
```bash
mg add lodash -D
# Equivalent to: npm install lodash --save-dev

mg remove lodash
# Equivalent to: npm uninstall lodash
```

### Python/Poetry
```bash
mg add requests -G dev
# Equivalent to: poetry add requests --group dev
```

### Wildcard Examples (NEW)
```bash
# Delete multiple matching files
mg fs r 'test*.txt'       # Remove all test*.txt files
mg fs r '*.log'          # Remove all log files

# Preview before deleting
mg fs r 'old_*.tmp' --dry-run

# Copy with pattern
mg fs y 'src/*.c' backup/  # Copy all .c files
```

## File System Operations

```bash
# Create with auto-detection
mg fs c test.txt       # Create file
mg fs c src/           # Create directory (trailing /)

# Wildcard support (NEW)
mg fs r 'test*.txt'      # Delete test1.txt, test2.txt, etc.
mg fs r 'demo_?.txt'   # Delete demo_a.txt, demo_b.txt (single char)
mg fs r '*.log'         # Delete all .log files
mg fs r 'backup*' --dry-run  # Preview deletions
mg fs ls '*.txt'        # List all .txt files
mg fs ls 'src/*.zig'    # List all .zig files in src/

# Smart existence check (NEW)
mg fs c existing.txt
# [17:53:31] INFO File already exists: existing.txt

# Copy with recursive support
mg fs y src/ backup/   # Copy directory recursively

# Remove safely
mg fs r file.txt       # Remove file
mg fs r dir/           # Remove directory recursively

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
```

## Why Zig?

- **No runtime dependencies**: Compiles to a single static binary
- **Performance**: Native-level speed
- **Safety**: Memory-safe with no garbage collector
- **Simplicity**: Standard library is all you need

## Contributing

1. Add a new package manager: Implement in `src/pkgm.zig`
2. Improve error handling: Update `src/error.zig`
3. Add tests: Add to existing test sections

## License

MIT License

---

**Built with Zig** ⚡
