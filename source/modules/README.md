# Optional C++23 Modules

This template keeps `source/modules/` as an opt-in companion surface, not the
default consumption path. The regular header-first library target remains the
baseline; enabling `<ProjectName>_ENABLE_CXX_MODULES` adds a separate
`<ProjectName>::modules` target for users who prefer `import`.

The checked-in sample follows a conservative policy:

1. Keep the installable header surface under `include/mg/`.
2. Export modules from a separate target instead of changing the meaning of
   `mg::mg`.
3. Enable the module target only on CMake 3.28+ with a generator that supports
   module dependency scanning.
4. Ask downstream binaries to choose either the header target or the module
   target for a given API surface, not both.

Editor note:

- `clangd` and clang-based VSCode diagnostics usually need the
  `modules-debug` preset configured or built before `import mg;` can be
  resolved in `src/main_modules.cpp`.
