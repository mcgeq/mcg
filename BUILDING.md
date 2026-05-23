# Building With CMake

## Dependencies

- `CMake 3.25` or newer
- A C++23 compiler
- `vcpkg` only when you want developer-mode features such as tests

For the dependency manifest used by developer mode, see [vcpkg.json](vcpkg.json).

## Package Management Strategy

This project separates dependency management into three lanes:

- Public/runtime dependencies:
  declare them with `find_package()` and surface them explicitly in the
  installed package config.
- Developer-only dependencies:
  keep them behind opt-in `vcpkg` manifest features such as `test`,
  `benchmark`, or `fuzz`.
- Repository-local tooling:
  use `FetchContent` sparingly for tooling like docs helpers that never become
  part of the installed package surface.

The checked-in project follows that policy today:

- the installable library exports only its own target
- test, benchmark, and fuzz dependencies live in `vcpkg.json` features
- docs tooling uses `FetchContent` because it is local to this repository

## Recommended Presets

Build the primary cross-platform release target:

```sh
cmake --workflow --preset default-release
```

This is the main release path for Linux, macOS, and Windows environments that
provide `g++`. The CLI output is:

- `build/default-release-gcc/mg` on Linux and macOS
- `build/default-release-gcc/mg.exe` on Windows

Build a release artifact and run the developer-mode test suite:

```sh
cmake --workflow --preset dev-release
```

On Windows with a full Visual Studio 2022 installation, use:

```sh
cmake --workflow --preset msvc-release
```

That produces `build/msvc-release/Release/mg.exe`.

Build with developer mode enabled, including tests:

```sh
cmake --workflow --preset dev-debug
```

Build with compiler-integrated `clang-tidy` using the recommended profile:

```sh
cmake --workflow --preset tidy-debug
```

Build the optional named module target with Clang and Ninja:

```sh
cmake --workflow --preset modules-debug
```

Build the optional named module target with developer mode, tests, and package
smoke coverage:

```sh
cmake --workflow --preset modules-dev-debug
```

Build developer benchmarks:

```sh
cmake --workflow --preset bench-debug
```

Build libFuzzer entry points with Clang:

```sh
cmake --workflow --preset fuzz-debug
```

On Windows with MSVC plus `vcpkg`, use:

```sh
cmake --workflow --preset msvc-dev-debug
```

For Visual Studio's native module workflow, use:

```sh
cmake --workflow --preset msvc-modules-debug
```

Available presets are defined in [CMakePresets.json](CMakePresets.json).

## Environment Doctor

If you want a quick readiness report before the first configure, use the root
wrapper:

```sh
./run.sh --doctor
```

```cmd
run.bat --doctor
```

The doctor reports whether `cmake`, `g++`, `clang++`, `ninja`, `clangd`, and
`VCPKG_ROOT` are available, and maps that to the presets that can run in the
current environment. It also suggests the most appropriate next preset to run
on that machine. Add `--strict` if you want warnings to produce a non-zero exit
code.

## Local Git Hooks

If you want lightweight commit-time checks, install the tracked hook set:

```sh
./run.sh --install-hooks
```

```cmd
run.bat --install-hooks
```

This configures `core.hooksPath` to `.githooks/` for the current repository.
The default `pre-commit` hook checks:

- `cmake --list-presets` when `CMakePresets.json` is staged
- `clang-format` on staged C and C++ source files when `clang-format` is available
- `codespell` on staged text files when `codespell` is available

Missing optional tools are reported as warnings instead of blocking the commit.

## One-Command Local Fixes

If you want to apply the project's default local cleanups before committing,
use the root wrapper:

```sh
./run.sh --fix
```

```cmd
run.bat --fix
```

This helper is intentionally best-effort:

- it runs `clang-format` with the checked-in style when `clang-format` is available
- it runs `codespell -w` with the checked-in `.codespellrc` policy when `codespell` is available
- missing optional tools are reported as warnings instead of failing the whole command

The formatting pass now includes the normal library sources plus the optional
module, benchmark, and fuzz source trees so the modern C++ paths do not drift
away from the rest of the project.

## Where Build Outputs Go

Every preset writes into the `binaryDir` declared in
[CMakePresets.json](CMakePresets.json). That means the preset name already tells
you where to look:

- `default-debug` -> `build/default-debug-gcc/`
- `default-release` -> `build/default-release-gcc/`
- `dev-debug` -> `build/dev-debug/`
- `dev-release` -> `build/dev-release/`
- `bench-debug` -> `build/bench-debug/`
- `fuzz-debug` -> `build/fuzz-debug/`
- `modules-debug` -> `build/modules-debug-clang/`
- `modules-dev-debug` -> `build/modules-dev-debug-clang/`
- `msvc-debug` -> `build/msvc-debug/`
- `msvc-release` -> `build/msvc-release/`
- `msvc-dev-release` -> `build/msvc-dev-release/`

The CLI executable name is `mg` on Unix-like platforms and `mg.exe` on
Windows. Common release output paths are:

- single-config generators (`Unix Makefiles`, `Ninja`):
  `build/default-release-gcc/mg` or `build/dev-release/mg`
- Visual Studio generators:
  `build/msvc-release/Release/mg.exe` or
  `build/msvc-dev-release/Release/mg.exe`

Additional developer-mode binaries keep their target names as file names:

- tests: `<binary-dir>/mg_test`
- benchmarks: `<binary-dir>/mg_benchmark`
- fuzzing: `<binary-dir>/mg_fuzz`
- modules CLI: `<binary-dir>/mg-modules`

For `clangd`-based editors such as Neovim, single-config preset builds also
refresh a gitignored root `compile_commands.json` from the active build tree.
That gives `clangd` a project-root compilation database to discover by default,
which avoids false missing-include diagnostics for paths such as `src/detail/`.

The repository also ships a checked-in [`.clangd`](.clangd) fallback config for
cases where the editor starts before a build tree exists. It supplies `-std=c++23`
plus the repository's `include/` and `src/` directories so clang-based editors
avoid noisy fallback parsing.

Module-aware editor diagnostics are a stricter case. For files under
`source/modules/` and the sample `src/main_modules.cpp`, run:

```sh
cmake --workflow --preset modules-debug
```

That preset generates the module-aware compilation database clang-based editors
need in order to resolve `import mg;` correctly.

When using multi-config generators such as Visual Studio, expect the active
configuration subdirectory such as `Debug/` or `Release/` between
`<binary-dir>/` and the executable file.

Test-related generated artifacts also live under the active build tree:

- installed package smoke prefix: `<binary-dir>/package/`
- generated smoke project sources: `<binary-dir>/package-smoke-src/`
- generated smoke project build tree: `<binary-dir>/package-smoke/`

If you prefer not to run binaries by path, the project provides helper targets:

```sh
cmake --build --preset dev-debug --target run-exe
cmake --build --preset bench-debug --target run-benchmarks
cmake --build --preset fuzz-debug --target run-fuzz-smoke
ctest --preset dev-debug
```

## Manual Configure / Build

If you prefer raw CMake commands, a basic top-level build looks like this:

```sh
cmake -S . -B build/default -D CMAKE_BUILD_TYPE=Release
cmake --build build/default --config Release
```

To enable developer mode manually, point CMake at the vcpkg toolchain and turn
on the test feature from the manifest:

```sh
cmake -S . -B build/dev ^
  -D CMAKE_BUILD_TYPE=Debug ^
  -D mg_DEVELOPER_MODE=ON ^
  -D VCPKG_MANIFEST_FEATURES=test ^
  -D CMAKE_TOOLCHAIN_FILE=%VCPKG_ROOT%/scripts/buildsystems/vcpkg.cmake
cmake --build build/dev --config Debug
ctest --test-dir build/dev --output-on-failure --build-config Debug
```

## Install

Install from an existing build tree:

```sh
cmake --install build/default --prefix prefix --config Release
```

The installed package exports `mg::mg` and can be consumed with
`find_package(mg CONFIG REQUIRED)`.

If you later add a public third-party dependency to the library itself, keep
the consumer contract explicit:

1. `find_package(...)` it in your build.
2. Link it publicly on the library target.
3. Register the matching installed-package lookup in
   [`cmake/dependencies.cmake`](cmake/dependencies.cmake).

## Source Layout Strategy

This project separates the sample code into a few lanes so it can grow into a
real library instead of getting stuck as a single-header demo:

- `include/mg/mg.hpp` is the compatibility umbrella header.
- `include/mg/core/` is the preferred home for focused public APIs.
- `src/detail/` holds internal helpers that support the public API but are not
  installed.
- `source/modules/` contains the optional named module companion target and is
  still excluded from the default non-modules presets.

The checked-in sample keeps modules optional on purpose:

1. The default presets keep using the header-first library target.
2. `modules-*` presets switch to a generator and toolchain path suitable for
   `FILE_SET CXX_MODULES`.
3. The installed package exports a separate `mg::modules` target when
   modules are enabled.

If you want that optional module path to be exercised by tests instead of just
compiled, prefer `modules-dev-debug` over `modules-debug`.

Do not link the header target and the module target into the same final binary;
the sample surfaces are alternatives for the same API, not separate features.

## Static Analysis Profiles

The project ships two `clang-tidy` profiles:

- `recommended` is the default low-noise profile for day-to-day development.
- `strict` adds broader `cppcoreguidelines` coverage, naming checks, and turns
  `clang-tidy` findings into build errors.

You can enable either profile manually:

```powershell
cmake -S . -B build/tidy `
  -D CMAKE_BUILD_TYPE=Debug `
  -D mg_DEVELOPER_MODE=ON `
  -D mg_ENABLE_CLANG_TIDY=ON `
  -D mg_CLANG_TIDY_PROFILE=strict `
  -D mg_CLANG_TIDY_WARNINGS_AS_ERRORS=ON `
  -D VCPKG_MANIFEST_FEATURES=test `
  -D CMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
```

When developer mode is enabled, you can also run:

```sh
cmake --build --preset dev-debug --target tidy-check
```

That target runs `clang-tidy` over `src/`, `include/`, and `test/` using the
active build tree's compilation database. To skip directories that are
intentionally noisy, set `CLANG_TIDY_EXCLUDE_DIRECTORIES` to a semicolon-
separated list such as `test/fixtures;src/compat`.

## Benchmarks And Fuzzing

Benchmarks are opt-in through `<ProjectName>_BUILD_BENCHMARKS` and the
`benchmark` vcpkg feature. The project wires a small Google Benchmark sample
that exercises the public library surface and exposes a `run-benchmarks`
target.

Fuzz targets are opt-in through `<ProjectName>_BUILD_FUZZ_TESTS` and the
`fuzz` feature. The project assumes a Clang toolchain and links
`-fsanitize=fuzzer,address,undefined` for a minimal libFuzzer setup. A
`run-fuzz-smoke` target is provided for short local smoke runs.

## Optional C++23 Modules

The module path is guarded behind `<ProjectName>_ENABLE_CXX_MODULES`.
When enabled, this project builds an additional `mg::modules` target
from `source/modules/`.

Current module assumptions:

- CMake 3.28 or newer
- a generator with module dependency scanning support such as Ninja or Visual Studio
- a Clang-family or MSVC toolchain

When developer mode is also enabled, the package smoke project builds a tiny
installed-package consumer that imports the named module.

## Notes

- `default-*` presets are the primary single-config GNU-style workflows across
  Linux, macOS, and Windows environments that provide `g++`.
- `msvc-*` presets are the intended local Visual Studio workflows.
- `dev-*`, `msvc-dev-*`, `coverage`, `asan`, and `tidy-*` presets expect
  `VCPKG_ROOT` to be set.
- `modules-debug` expects Ninja plus a `clang++` toolchain on PATH.
- `modules-dev-debug` also expects `VCPKG_ROOT` because it enables developer-mode tests.
- `msvc-modules-debug` expects a working Visual Studio 2022 C++ environment.
- `bench-debug` expects the `benchmark` feature dependencies to be available.
- `fuzz-debug` expects a Clang-based toolchain with libFuzzer support.
- The example CLI is controlled by the `<ProjectName>_BUILD_CLI` option.
