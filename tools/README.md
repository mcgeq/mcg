# Tools

- Project helper entrypoints live at the repository root: `run.bat` for Windows
  and `run.sh` for Unix-like systems.
- `doctor.py`: Reports whether the local machine is ready for the project's
  main preset families, including GNU, Clang/modules, developer-mode `vcpkg`,
  and editor-facing `clangd` support, then recommends a sensible next preset.
  Use it through `run.sh --doctor` or `run.bat --doctor`.
- `fix.py`: Applies the project's checked-in `clang-format` and `codespell`
  fixes through one best-effort entrypoint. Use it through `run.sh --fix` or
  `run.bat --fix`.
- `install_git_hooks.py`: Configures `core.hooksPath` to use the tracked
  `.githooks/` directory for this repository. Use it through
  `run.sh --install-hooks` or `run.bat --install-hooks`.
- `pre_commit.py`: Runs the lightweight commit-time checks used by the tracked
  `pre-commit` hook, including preset validation plus optional staged-file
  formatting and spelling checks.
- `cmake/run-clang-tidy.cmake`: Drives the `tidy-check` target over the
  repository's configured source directories using the active build tree's
  compilation database, with optional directory exclusions.
- `cmake/cxx-modules-targets.cmake`: Wires the optional named module companion
  target plus its sample import-based executable.
- `source/modules/`: Holds the checked-in module interface sample and the
  short guidance note for keeping the module path optional.
- `benchmark/` and `fuzz/`: Sample entry points showing how to wire Google
  Benchmark and libFuzzer into this project.
- `cmake/dependencies.cmake`: Documents the dependency policy and provides a
  helper hook for installed-package `find_dependency(...)` requirements.
