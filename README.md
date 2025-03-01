# Multi-Package Manager CLI (mg)

mg is a cross-ecosystem package management tool that supports multiple package managers (such as **cargo**, **npm**, **pnpm**, **yarn**, **pip**, **pdm**, and **poetry**),
providing a unified command-line interface.
By automatically detecting project types, **mg** intelligently invokes the corresponding package manager, simplifying package management operations in cross-language development.

## Features

- **Cross-ecosystem support**: Supports package managers for ecosystems like **Rust**, **Node.js**, and **Python**.
- **Automatic project type detection**: Automatically selects the package manager based on project files (e.g., **Cargo.toml**, **package.json**, **pyproject.toml**, etc.).
- **Unified command interface**: Provides unified commands such as **add**, **remove**, **upgrade**, and **analyze**.
- **Dynamic parameter support**: Allows passing arbitrary package manager parameters and supports native command formats.
- **Colored output**: Uses colored terminal output to enhance readability.

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
```

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

| Package Manager     |       Supported Commands          |          Detection Files            |
|      -----------    |            -----------            |          -----------                |
|      Cargo          |     add,remove,upgrade,analyze    |   Cargo.toml                        |
|      npm            |     add,remove,upgrade,analyze    |   package.json, package-lock.json   |
|      pnpm           |     add,remove,upgrade,analyze    |   pnpm-lock.yaml                    |
|      yarn           |     add,remove,upgrade,analyze    |   yarn.lock                         |
|      pip            |     add,remove,upgrade,analyze    |   requirements.txt                  |
|      pdm            |     add,remove,upgrade,analyze    |   pdm.lock, pyproject.toml          |
|      poetry         |     add,remove,upgrade,analyze    |   pyproject.toml                    |

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

## Colored Output

mg uses colored terminal output to enhance readability:

- **Package manager name**: Cyan
- **Executed command**: Yellow
- **Success message**: Green
- **Dependency analysis title**: Cyan

```bash
$ mg add serde
Using cargo package manager
Executing: cargo add serde
✓ Packages added successfully
```

## License

This project is open-sourced under the [MIT](https://github.com/mcgeq/mcg/blob/main/LICENSE) License.

## Feedback and Support

If you encounter any issues or have suggestions, please submit an Issue or contact via email: <mcgeq@outlook.com>.

## Acknowledgments

Thanks to the following open-source projects for their support:

- [**clap**](https://github.com/clap-rs/clap): Command-line argument parsing library.
- [**colored**](https://github.com/colored-rs/colored): Colored terminal output library.
- [**anyhow**](https://github.com/dtolnay/anyhow): Error handling library.

Happy coding with mg! 🚀
