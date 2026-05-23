# Contributing

Thank you for improving mg.

## Code of Conduct

Please see the [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) document.

## Getting started

Helpful notes for developers can be found in the [`HACKING.md`](HACKING.md)
document.

Please preserve the template's dependency layering:

- public library dependencies stay on explicit `find_package()` boundaries
- developer-only tooling dependencies stay behind opt-in manifest features
- `FetchContent` is reserved for repository-local tooling, not installed runtime
  dependencies

If you create a personal `CMakeUserPresets.json` for local preferences, do not
check it into source control.
