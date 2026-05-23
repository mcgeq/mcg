# Hacking

Here is some wisdom to help you build and test this project as a developer and
potential contributor.

If you plan to contribute, please read the [CONTRIBUTING](CONTRIBUTING.md)
guide.

## Developer mode

Build system targets that are only useful for developers of this project are
hidden if the `<ProjectName>_DEVELOPER_MODE` option is disabled. Enabling this
option makes tests and other developer targets and options available. Not
enabling this option means that you are a consumer of this project and thus you
have no need for these targets and options.

Developer mode is enabled by the `dev-*`, `coverage`, `asan`, and `ci-*`
presets.

If you are onboarding a machine or a fresh clone, start with:

```sh
./run.sh --doctor
```

or on Windows:

```powershell
.\run.bat --doctor
```

If you want lightweight local commit-time checks, install the tracked hook set:

```sh
./run.sh --install-hooks
```

If you want one root command that applies the project's default local
formatting and spelling fixes, run:

```sh
./run.sh --fix
```

or on Windows:

```powershell
.\run.bat --fix
```

This helper is best-effort by design: it applies `clang-format` and
`codespell` fixes when those tools are available, and reports missing optional
tools as warnings instead of hard failures.

### Presets

This project ships complete [CMake presets][1] in source control. You should
not need a custom `CMakeUserPresets.json` just to get started.

The main presets are:

- `default-debug` and `default-release` for the GNU/Make local path used by
  this repository
- `msvc-debug` and `msvc-release` for local Visual Studio builds
- `dev-debug` and `dev-release` for normal contributor workflows on the GNU
  path
- `msvc-dev-debug` and `msvc-dev-release` for local Visual Studio developer
  workflows
- `asan` for sanitizer-enabled builds
- `modules-debug` for the optional named module companion target on Clang/Ninja
- `modules-dev-debug` for the optional named module path with developer-mode tests
- `bench-debug` for local benchmark binaries
- `coverage` for coverage-instrumented builds
- `fuzz-debug` for libFuzzer-based smoke targets on Clang
- `msvc-modules-debug` for the optional named module target on Visual Studio
- `tidy-debug` for recommended `clang-tidy` analysis during normal development
- `tidy-strict` for stricter `clang-tidy` policy checks
- `ci-linux`, `ci-macos`, and `ci-windows` for automation

Each matching workflow preset runs configure, build, and test in one step:

```sh
cmake --workflow --preset dev-debug
```

### Dependency manager

Developer-mode presets make use of the [vcpkg][vcpkg] manifest in the project
root. After installing vcpkg, make sure the `VCPKG_ROOT` environment variable
points at the vcpkg checkout.

Use the manifest primarily for repository-local developer dependencies. Keep
consumer-visible runtime dependencies on explicit `find_package()` boundaries so
the installed package stays package-manager-agnostic.

[vcpkg]: https://github.com/microsoft/vcpkg

### Dependency policy

When extending this project, prefer the following order:

1. Public library dependency:
   `find_package()` it, link it explicitly, and register its
   `find_dependency()` requirement for installed consumers.
2. Test / benchmark / fuzz / lint support:
   add it as an opt-in `vcpkg.json` feature and enable it from developer-mode
   presets or local configure overrides.
3. Repository-local tooling:
   only then consider `FetchContent`, and keep it out of the installed target
   surface.

This keeps downstream consumers from inheriting the repository's local
package-manager choice just to use the library.

### Library layout

The checked-in sample code uses a lightweight layered structure:

1. Keep the stable umbrella include at `include/<Project>/<basename>.hpp`.
2. Put focused public APIs under `include/<Project>/core/`.
3. Put private helpers under `src/detail/`.
4. Treat `source/modules/` as an optional companion target, not as mandatory
   build input today.

This gives you a migration path toward module-aware builds without forcing
every consumer, editor, or CI environment onto an experimental workflow on day
one.
When you do enable modules, the project exports a separate
`<ProjectName>::modules` target so consumers can choose the import-based
surface explicitly.

### Configure, build and test

The standard developer loop is:

```sh
cmake --preset dev-debug
cmake --build --preset dev-debug
ctest --preset dev-debug
```

For the optional modules path with developer-mode coverage, use:

```sh
cmake --preset modules-dev-debug
cmake --build --preset modules-dev-debug
ctest --preset modules-dev-debug
```

On single-config presets, the build step also syncs the active
`compile_commands.json` into the repository root. That is mainly for
`clangd`-based editors such as Neovim, which search parent directories for the
compilation database by default.

The checked-in [`.clangd`](.clangd) file is a lighter fallback for the same
editors before a build tree exists. It keeps fallback parsing on C++23 and adds
`include/` plus `src/` as search paths.

For the optional named module sample, clang-based editors generally also need a
module-aware build tree. Run `cmake --workflow --preset modules-debug` so
`source/modules/` and `src/main_modules.cpp` can pick up the dedicated modules
compilation database.

The repository also tracks [`.editorconfig`](.editorconfig) for shared
whitespace and line-ending defaults, plus
[`.vscode/extensions.json`](.vscode/extensions.json) for lightweight VSCode
extension recommendations.

Tracked [`.gitattributes`](.gitattributes) complements that by normalizing line
endings at the Git boundary, with explicit CRLF for batch files and LF for the
rest of the repository by default.

For MSVC contributors with Visual Studio 2022 installed, the equivalent loop
is:

```sh
cmake --preset msvc-dev-debug
cmake --build --preset msvc-dev-debug
ctest --preset msvc-dev-debug
```

If you are using a compatible editor (e.g. VSCode) or IDE (e.g. CLion, VS), you
will also be able to select the checked-in presets directly.

Please note that both the build and test commands accept a `-j` flag to specify
the number of jobs to use, which should ideally be specified to the number of
threads your CPU has.

### Developer mode targets

These are targets you may invoke using the build command from above, with an
additional `-t <target>` flag:

#### `coverage`

Available if `ENABLE_COVERAGE` is enabled. This target processes the output of
the previously run tests when built with the `coverage` preset. The commands
this target runs can be found in the `COVERAGE_TRACE_COMMAND` and
`COVERAGE_HTML_COMMAND` cache variables. The trace command produces an info
file by default, which can be submitted to services with CI integration. The
HTML command uses the trace command's output to generate an HTML document to
`<binary-dir>/coverage_html` by default.

#### `docs`

Available if `BUILD_MCSS_DOCS` is enabled. Builds to documentation using
Doxygen and m.css. The output will go to `<binary-dir>/docs` by default
(customizable using `DOXYGEN_OUTPUT_DIRECTORY`).

#### `format-check` and `format-fix`

These targets run the clang-format tool on the codebase to check errors and to
fix them respectively. The default scope includes the normal library sources,
tests, optional module interfaces, and the sample benchmark/fuzz entries.
Customization is available using the `FORMAT_DIRECTORIES` and
`FORMAT_COMMAND` cache variables.

#### `tidy-check`

Runs `clang-tidy` against the configured source directories using the active
build tree's `compile_commands.json`. Compiler-integrated `clang-tidy` can also
be enabled during configure time through `<ProjectName>_ENABLE_CLANG_TIDY`,
with `<ProjectName>_CLANG_TIDY_PROFILE` set to either `recommended` or
`strict`.

When the strict profile is enabled, this project intentionally keeps the
example CLI target and the test target on the recommended profile so the public
library remains the main policy gate. You can override or disable analysis for
specific targets with:

```cmake
mg_set_target_clang_tidy(my_target PROFILE strict WARNINGS_AS_ERRORS ON)
mg_set_target_clang_tidy(legacy_adapter DISABLE)
```

For repository-wide scans, `tidy-check` also respects the
`CLANG_TIDY_EXCLUDE_DIRECTORIES` cache variable.

#### `run-benchmarks`

Available when `<ProjectName>_BUILD_BENCHMARKS` is enabled. Runs the sample
Google Benchmark binary with a short minimum benchmark time so contributors can
sanity-check performance-sensitive changes quickly.

#### `run-fuzz-smoke`

Available when `<ProjectName>_BUILD_FUZZ_TESTS` is enabled with a Clang
toolchain. Runs the sample libFuzzer target for a few seconds as a lightweight
smoke pass.

#### `run-real-smoke`

Runs the real package-manager smoke scenarios through CMake only. It creates
temporary sample projects, invokes the built CLI, checks manager detection
banners and expected output, and skips scenarios when the corresponding manager
or local runtime is not available.

To narrow the run, configure a semicolon-separated scenario list first:

```sh
cmake --preset dev-debug -Dmg_REAL_SMOKE_SCENARIOS="npm_package_json_install_dry_run;uv_install_profiles_dry_run"
cmake --build --preset dev-debug --target run-real-smoke
```

The real smoke path intentionally stays in `test/mg_cli_real_smoke.cmake`; there
is no separate Python smoke runner.

#### `run-exe`

Runs the example executable target `<ProjectName>_cli`.

#### `run-modules-exe`

Available when `<ProjectName>_ENABLE_CXX_MODULES` is enabled and the CLI sample
is built. Runs the import-based example executable target
`<ProjectName>_modules_cli`.

#### `spell-check` and `spell-fix`

These targets run the codespell tool on the codebase to check errors and to fix
them respectively. Customization available using the `SPELL_COMMAND` cache
variable. The root `run.sh --fix` and `run.bat --fix` wrappers call into the
same checked-in spelling policy for a lighter-weight local workflow.

[1]: https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html
[2]: https://cmake.org/download/
