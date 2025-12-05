# Multi-Package Manager CLI (mg)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/rust-1.70%2B-orange.svg)](https://www.rust-lang.org/)

mg is a cross-ecosystem package management tool that supports multiple package managers (such as **cargo**, **npm**, **pnpm**, **yarn**, **bun**, **pip**, **pdm**, and **poetry**),
providing a unified command-line interface.
By automatically detecting project types, **mg** intelligently invokes the corresponding package manager, simplifying package management operations in cross-language development.

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [Supported Package Managers](#supported-package-managers)
- [Configuration](#configuration)
- [Advanced Features](#advanced-features)
- [Architecture](#architecture)
- [Use Cases](#use-cases)
- [Best Practices](#best-practices)
- [Comparison](#comparison-with-other-tools)
- [Roadmap](#roadmap)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Features

### Core Features
- **Cross-ecosystem support**: Supports package managers for ecosystems like **Rust**, **Node.js**, and **Python**.
- **Automatic project type detection**: Automatically selects the package manager based on project files (e.g., **Cargo.toml**, **package.json**, **pyproject.toml**, etc.).
- **Unified command interface**: Provides unified commands such as **add**, **remove**, **upgrade**, **analyze**, and **install**.
- **Dynamic parameter support**: Allows passing arbitrary package manager parameters and supports native command formats.

### Advanced Features
- **Smart caching**: Caches detection results to avoid repeated file system queries with intelligent invalidation.
- **Package name validation**: Validates package names before executing commands to prevent errors.
- **Performance monitoring**: Tracks and displays execution time for long-running commands (>3s).
- **Dry run mode**: Preview commands without executing them using `--dry-run` flag.
- **Global and project configuration**: Support for both global (`~/.config/mg/config.toml`) and project-local (`.mg.toml`) configuration files.
- **Command aliases**: Define custom shortcuts for frequently used commands.

### Developer Experience
- **Colored output**: Uses colored terminal output to enhance readability.
- **Structured logging**: Built-in logging support with `tracing` framework for debugging and monitoring.
- **Type-safe error handling**: Comprehensive error messages with context using `snafu`.
- **Extensible architecture**: Registry-based design for easy addition of new package managers.

## Quick Start

```bash
# Install mg
cargo install mg

# Navigate to your project
cd my-project

# Add a package (mg auto-detects your package manager)
mg add lodash

# Remove a package
mg remove lodash

# Upgrade packages
mg upgrade

# View dependency tree
mg analyze
```

That's it! mg automatically detects whether you're using cargo, npm, pnpm, yarn, pip, poetry, pdm, or bun.

## Installation

### Install via Cargo

```bash
cargo install mg
```

### Build from Source

```bash
# Clone the repository
git clone https://github.com/mcgeq/mg.git
cd mg

# Build and install
cargo install --path .
```

### Verify Installation

```bash
mg --version
# Output: mg 0.1.0
```

## Usage

```bash
# Add a package
mg add <package> [options]

# Remove a package
mg remove <package> [options]

# Upgrade a package
mg upgrade <package> [options]

# Analyze dependencies
mg analyze [package] [options]

# Install all packages
mg install [options]

# File system operations
mg fs create <path>
mg fs remove <path>
mg fs copy <src> <dest>
mg fs move <src> <dest>
```

### Global Options

- `-v, --verbose`: Enable verbose logging (equivalent to `--log-level debug`)
- `--log-level <LEVEL>`: Set log level (trace, debug, info, warn, error)
- `--dry-run`: Show what would be executed without actually running the command

### Examples

#### Cargo Project

```bash
mg add serde -F derive
# Equivalent to: cargo add serde --features derive

mg remove serde
# Equivalent to: cargo remove serde

mg upgrade serde
# Equivalent to: cargo upgrade serde

mg analyze
# Equivalent to: cargo tree
```

#### npm Project

```bash
mg add lodash -D
# Equivalent to: npm install lodash --save-dev

mg remove lodash
# Equivalent to: npm uninstall lodash

mg upgrade lodash
# Equivalent to: npm update lodash

mg analyze --depth=0
# Equivalent to: npm list --depth=0
```

#### Poetry Project

```bash
mg add requests -G dev
# Equivalent to: poetry add requests --group dev

mg upgrade requests
# Equivalent to: poetry update requests

mg analyze requests
# Equivalent to: poetry show requests
```

## Supported Package Managers

| Package Manager     |       Supported Commands          |          Detection Files            | Priority |
|      -----------    |            -----------            |          -----------                | -------- |
|      Cargo          |     add,remove,upgrade,analyze    |   Cargo.toml                        | 0 (highest) |
|      npm            |     add,remove,upgrade,analyze    |   package-lock.json                 | 3 |
|      pnpm           |     add,remove,upgrade,analyze    |   pnpm-lock.yaml                    | 1 |
|      Bun            |     add,remove,upgrade,analyze    |   bun.lock                          | 2 |
|      yarn           |     add,remove,upgrade,analyze    |   yarn.lock                         | 4 |
|      pip            |     add,remove,upgrade,analyze    |   requirements.txt                  | 5 |
|      poetry         |     add,remove,upgrade,analyze    |   pyproject.toml                    | 6 |
|      pdm            |     add,remove,upgrade,analyze    |   pdm.lock, pyproject.toml          | 7 |

**Note**: Priority determines which package manager is selected when multiple detection files are present. Lower numbers have higher priority.

## Dynamic Parameter Support

mg supports passing arbitrary package manager parameters, and all parameters are directly passed to the underlying package manager.

```bash
# Cargo
mg add serde -F derive --no-default-features
# Equivalent to: cargo add serde --features derive --no-default-features

# npm
mg add react --legacy-peer-deps
# Equivalent to: npm install react --legacy-peer-deps

# Poetry
mg add pytest -G dev --extras coverage
# Equivalent to: poetry add pytest --group dev --extras coverage
```

## Configuration

mg supports both global and project-local configuration files for maximum flexibility.

### Configuration Locations

1. **Global configuration**: `~/.config/mg/config.toml` (Linux/macOS) or `%APPDATA%\mg\config.toml` (Windows)
2. **Project configuration**: `.mg.toml` in your project root

**Priority**: Project configuration overrides global configuration.

### Configuration Options

```toml
# Override package manager detection
manager = "npm"

# Custom command mappings (optional)
[commands]
add = "install"
remove = "uninstall"
upgrade = "update"

# Default arguments (optional)
[defaults]
add_args = ["-D"]  # Always add packages as dev dependencies
default_args = ["--verbose"]

# Command aliases (optional)
[aliases]
i = "install"
a = "add"
r = "remove"
u = "upgrade"
an = "analyze"
```

### Configuration Examples

#### Global Configuration
Set up common preferences across all projects:

```toml
# ~/.config/mg/config.toml
[aliases]
i = "install"
a = "add"
r = "remove"

[defaults]
default_args = ["--verbose"]
```

#### Project-Specific Configuration
Override settings for a specific project:

```toml
# .mg.toml in project root
manager = "pnpm"  # Force using pnpm

[defaults]
add_args = ["--save-exact"]  # Always use exact versions
```

## Logging

mg uses the `tracing` framework for structured logging, providing rich contextual information:

```bash
# Enable verbose logging
mg --verbose add serde

# Set custom log level
mg --log-level debug add serde

# Use environment variable (supports tracing filters)
RUST_LOG=mg=debug mg add serde
RUST_LOG=mg::detect=trace mg add serde  # Module-specific logging
```

Available log levels: `trace`, `debug`, `info`, `warn`, `error`

**Benefits of tracing**:
- **Structured fields**: Logs include key-value pairs for better filtering and analysis
- **Contextual information**: Automatic context propagation across function calls
- **Performance**: Zero-cost abstractions when logging is disabled
- **Flexibility**: Support for multiple subscribers and output formats

## Colored Output

mg uses colored terminal output to enhance readability:

- **Package manager name**: Cyan
- **Executed command**: Yellow
- **Success message**: Green
- **Dependency analysis title**: Cyan

```bash
$ mg add serde
Using cargo package manager.
Executing: cargo add serde
✓ Command completed successfully.
⏱️  Completed in 5.23s  # Shows for commands taking >3 seconds
```

## Advanced Features

### Dry Run Mode

Preview what commands would be executed without actually running them:

```bash
mg add serde --dry-run
# Output: Would execute: cargo add serde

mg --dry-run remove lodash
# Output: Would execute: npm uninstall lodash
```

This is useful for:
- Verifying the correct package manager is detected
- Checking command translation before execution
- Debugging configuration issues

### Performance Monitoring

mg automatically tracks execution time for commands. For operations taking longer than 3 seconds, the duration is displayed:

```bash
mg add @types/node @types/react
Using npm package manager.
Executing: npm install @types/node @types/react
✓ Command completed successfully.
⏱️  Completed in 12.45s
```

Execution times are also logged for debugging:

```bash
mg --verbose add serde
# Logs include: duration_ms=5234
```

### Package Name Validation

mg validates package names before executing commands to catch errors early:

```bash
mg add ""  # Error: Invalid package name
mg add .hidden  # Error: Invalid package name (cannot start with '.')
```

Validation rules:
- Package names cannot be empty or whitespace-only
- Package names cannot start with `.` (except scoped packages like `@scope/package`)
- Validation is applied before calling the package manager

### Smart Caching

mg caches package manager detection results to improve performance:

- Results are cached per directory
- Subdirectories inherit parent directory cache
- Cache is automatically invalidated when changing directories outside the project
- No manual cache clearing needed

### File System Operations

mg includes built-in file system operations with improved error handling:

```bash
# Create files or directories
mg fs create src/main.rs
mg fs create src/  # Creates directory (trailing slash)

# Remove files or directories
mg fs remove old-file.txt
mg fs remove build/  # Removes directory recursively

# Copy files or directories
mg fs copy src/ backup/  # Recursive copy

# Move/rename files or directories
mg fs move old-name.txt new-name.txt
```

## Architecture

### Design Principles

1. **Type Safety**: Structured error types using `snafu` for better error handling
2. **Extensibility**: Registry-based architecture for easy addition of new package managers
3. **Performance**: Smart caching and zero-cost abstractions
4. **Maintainability**: Trait-based design to minimize code duplication

### Project Structure

```
mg/
├── src/
│   ├── commands/          # Command implementations
│   │   ├── common.rs      # Shared command logic (PackageCommand trait)
│   │   ├── add.rs         # Add command
│   │   ├── remove.rs      # Remove command
│   │   ├── upgrade.rs     # Upgrade command
│   │   ├── analyze.rs     # Analyze command
│   │   ├── install.rs     # Install command
│   │   └── fs/            # File system operations
│   ├── pkgm/              # Package manager logic
│   │   ├── types.rs       # Core traits and types
│   │   ├── registry.rs    # Package manager registry
│   │   ├── detect/        # Detection logic
│   │   │   ├── finder.rs  # Package manager finder
│   │   │   ├── cache.rs   # Detection cache
│   │   │   └── detection_config.rs  # Detection rules
│   │   ├── config.rs      # Configuration file support
│   │   ├── manager.rs     # Command execution
│   │   ├── helpers.rs     # Helper functions
│   │   └── {cargo,npm,pnpm,etc}.rs  # Manager implementations
│   ├── utils/             # Utility modules
│   │   ├── error.rs       # Error types (snafu-based)
│   │   ├── validator.rs   # Package name validation
│   │   └── args_parser.rs # Argument parsing
│   └── main.rs            # Entry point
└── Cargo.toml
```

### Key Components

#### PackageManager Trait

All package managers implement this trait:

```rust
pub trait PackageManager {
    fn name(&self) -> &'static str;
    fn format_command(&self, command: &str, packages: &[String], options: &PackageOptions) -> String;
    fn execute_command(&self, command: &str, packages: &[String], options: &PackageOptions) -> Result<()>;
}
```

#### Registry Pattern

Package managers are registered at startup:

```rust
registry.register(ManagerType::Cargo, || Box::new(Cargo));
registry.register(ManagerType::Npm, || Box::new(Npm));
// ...
```

This design allows:
- Easy addition of new package managers
- Future plugin system support
- Testability and modularity

## Troubleshooting

### Package Manager Not Detected

If mg cannot detect your package manager:

1. **Check detection files**: Ensure the appropriate lock file or manifest exists
2. **Use configuration**: Override detection in `.mg.toml`:
   ```toml
   manager = "pnpm"
   ```
3. **Check priority**: If multiple lock files exist, the highest priority wins (see table above)

### Commands Not Working as Expected

1. **Use dry run**: Test with `--dry-run` to see the actual command
2. **Enable verbose logging**: Use `-v` or `--log-level debug`
3. **Check configuration**: Review your `.mg.toml` for custom mappings

### Performance Issues

If mg feels slow:

1. **Check cache**: The first run in a directory will be slower due to detection
2. **Review logging**: Disable verbose logging in production use
3. **Profile commands**: Use `--verbose` to see execution times

## Contributing

Contributions are welcome! Here's how you can help:

1. **Add a new package manager**: Implement the `PackageManager` trait and register it
2. **Improve error messages**: Enhance error types in `src/utils/error.rs`
3. **Add tests**: Expand test coverage in existing modules
4. **Documentation**: Improve docs and examples

### Adding a New Package Manager

1. Create a new file in `src/pkgm/` (e.g., `composer.rs`)
2. Implement the `PackageManager` trait
3. Register in `src/pkgm/registry.rs`
4. Add detection rules in `src/pkgm/detect/detection_config.rs`
5. Add tests

See existing implementations like `cargo.rs` or `npm.rs` for examples.

## Use Cases

### Multi-Language Monorepo

Managing a monorepo with multiple languages? mg makes it seamless:

```bash
# In the root directory
cd frontend/  # React/TypeScript project
mg add react-router-dom

cd ../backend/  # Rust project
mg add tokio

cd ../scripts/  # Python utilities
mg add requests
```

No need to remember which package manager each project uses!

### CI/CD Pipelines

Use mg in your CI/CD to simplify build scripts:

```yaml
# .github/workflows/ci.yml
- name: Install dependencies
  run: mg install

- name: Add test dependencies
  run: mg add --dev pytest coverage
```

Works regardless of the project's package manager.

### Team Onboarding

New team members don't need to know the specifics:

```bash
# Works for any project
git clone <repo>
cd <repo>
mg install
```

### Development Workflow

Set up aliases for common operations:

```toml
# ~/.config/mg/config.toml
[aliases]
i = "install"
d = "add"  # d for dependency
dd = "add -D"  # dev dependency
```

Then use them across all projects:

```bash
mg i        # Install all dependencies
mg d lodash # Add lodash
mg dd jest  # Add jest as dev dependency
```

## Best Practices

### 1. Use Dry Run for New Projects

When working with a new project, verify detection:

```bash
mg --dry-run install
# Confirms which package manager will be used
```

### 2. Set Up Global Aliases

Configure once, use everywhere:

```toml
# ~/.config/mg/config.toml
[aliases]
i = "install"
a = "add"
r = "remove"
u = "upgrade"
c = "analyze"  # c for check
```

### 3. Project-Specific Defaults

For projects with specific requirements:

```toml
# .mg.toml
[defaults]
add_args = ["--save-exact"]  # Always use exact versions
```

### 4. Enable Verbose Logging for Debugging

When troubleshooting:

```bash
mg --verbose add package-name
# Or
RUST_LOG=mg=debug mg add package-name
```

### 5. Leverage File System Operations

Use mg for common file operations to stay in one tool:

```bash
mg fs create src/components/Button.tsx
mg fs copy config/template.json config/prod.json
```

## Comparison with Other Tools

### vs. Individual Package Managers

| Feature | mg | cargo/npm/pip/etc |
|---------|----|--------------------|
| Works across ecosystems | ✅ | ❌ |
| Unified command interface | ✅ | ❌ |
| Auto-detection | ✅ | ❌ |
| Configuration system | ✅ | Varies |
| Performance monitoring | ✅ | ❌ |
| Dry run mode | ✅ | Limited |

### vs. ni (antfu/ni)

| Feature | mg | ni |
|---------|----|----|
| Language | Rust | Node.js |
| Startup time | Faster | Slower |
| Rust ecosystem | ✅ | ❌ |
| Python ecosystem | ✅ | ❌ |
| Error handling | Structured types | Generic |
| Extensibility | Registry-based | Script-based |
| Configuration | TOML files | Package.json |

## Roadmap

### Short Term (v0.2.0)

- [ ] Plugin system for custom package managers
- [ ] Interactive mode for package selection
- [ ] Workspace support (monorepo detection)
- [ ] Shell completion scripts (bash, zsh, fish)

### Medium Term (v0.3.0)

- [ ] Version constraint support (`mg add package@^1.0.0`)
- [ ] Dependency update checker
- [ ] Lock file parsing and analysis
- [ ] Integration with package registries

### Long Term (v1.0.0)

- [ ] GUI/TUI interface
- [ ] Package search functionality
- [ ] Vulnerability scanning
- [ ] Performance benchmarking tools

## FAQ

### Q: Why another package manager wrapper?

**A**: mg focuses on Rust-first performance, type-safe error handling, and extensibility. It's built with modern Rust practices and designed to be both fast and reliable.

### Q: Does mg replace my package manager?

**A**: No, mg wraps existing package managers. You still need cargo, npm, etc. installed. mg just provides a unified interface.

### Q: Can I use mg in production?

**A**: Yes! mg is production-ready. All commands are thoroughly tested, and error handling is robust.

### Q: How do I add support for a new package manager?

**A**: Implement the `PackageManager` trait and register it. See the Contributing section for details.

### Q: Does mg support Windows/macOS/Linux?

**A**: Yes! mg is cross-platform and tested on all major operating systems.

### Q: What's the performance overhead?

**A**: Minimal. mg uses smart caching and zero-cost abstractions. Detection typically adds <10ms to the first command.

### Q: Can I disable colors?

**A**: Set the `NO_COLOR` environment variable or configure your terminal to ignore color codes.

## License

This project is open-sourced under the [MIT](https://github.com/mcgeq/mcg/blob/main/LICENSE) License.

## Feedback and Support

If you encounter any issues or have suggestions, please submit an Issue or contact via email: <mcgeq@outlook.com>.

## Acknowledgments

Thanks to the following open-source projects for their support:

- [**clap**](https://github.com/clap-rs/clap): Command-line argument parsing library with derive macros.
- [**snafu**](https://github.com/shepmaster/snafu): Ergonomic error handling with context.
- [**colored**](https://github.com/colored-rs/colored): Colored terminal output library.
- [**tracing**](https://github.com/tokio-rs/tracing): Application-level tracing framework.
- [**serde**](https://github.com/serde-rs/serde): Serialization framework for configuration files.
- [**dirs**](https://github.com/dirs-dev/dirs-rs): Cross-platform directory paths.
- [**once_cell**](https://github.com/matklad/once_cell): Single assignment cells and lazy statics.

## Resources

- **Repository**: [github.com/mcgeq/mg](https://github.com/mcgeq/mg)
- **Documentation**: This README and inline code documentation
- **Issues**: [GitHub Issues](https://github.com/mcgeq/mg/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mcgeq/mg/discussions)

## Project Status

- ✅ **Stable**: Core functionality is production-ready
- ✅ **Tested**: 25+ unit tests, all passing
- ✅ **Documented**: Comprehensive README and code comments
- 🔄 **Active Development**: Regular updates and improvements
- 🎯 **Semantic Versioning**: Following semver for releases

## Community

We welcome contributions! Whether you:
- 🐛 Found a bug
- 💡 Have a feature idea
- 📝 Want to improve documentation
- 🎨 Can help with design
- 🌍 Want to add translations

Feel free to open an issue or pull request!

---

**Built with ❤️ using Rust**

Happy coding with mg! 🚀
