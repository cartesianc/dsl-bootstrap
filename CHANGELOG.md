# Changelog

## Unreleased

### Changed

- Split the current build surface into `new-framework-core` and `domain-app`.
- Moved the framework-core expression/compiler implementation into `new-framework-core`.
- Removed the old `framework-core` source tree from the active architecture.
- Reworked `domain-app` into a minimal self domain app whose content is `framework-core`.
- Updated Stack, Cabal project, and HLS cradle configuration to build both packages.
- Updated native source roots so boundary/import checks read `new-framework-core/src` instead of the old `framework-core/src`.
- Rewrote the main architecture docs around the new two-package boundary.

### Added

- Added `domain-app-self-smoke`, which verifies the external domain app can compile and run the framework-core self report through `new-framework-core`.

### Removed

- Removed core implementation ownership from `domain-app`.
- Kept old oracle smoke executables out of the current build surface.
