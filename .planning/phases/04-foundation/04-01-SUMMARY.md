---
phase: 04-foundation
plan: "01"
subsystem: cli
tags: [rust, cargo, clap, serde, thiserror, bundle-cli]

requires: []
provides:
  - "Compilable edgeworks-bundle Rust crate at crates/bundle-cli/"
  - "clap CLI entry point with create, verify, inspect subcommands and --json global flag"
  - "Stub modules for create, verify, inspect with BundleError return types"
  - "Placeholder BundleManifest and BundleImage structs in manifest.rs"
  - "BundleError enum with thiserror derivation in error.rs"
affects:
  - "04-02 — manifest types and error handling build on this crate scaffold"
  - "05-create — create.rs stub is the target for full implementation"
  - "06-verify-inspect — verify.rs and inspect.rs stubs are targets for implementation"

tech-stack:
  added:
    - "clap 4 (derive API) — CLI argument parsing"
    - "serde 1 + serde_json 1 — manifest serialization"
    - "chrono 0.4 (serde feature) — timestamps"
    - "sha2 0.10 — SHA256 digest computation"
    - "indicatif 0.17 — progress bars"
    - "thiserror 2 — error type derivation"
  patterns:
    - "Standalone Cargo project (not workspace) at crates/bundle-cli/"
    - "clap derive API with global --json flag for machine-readable output"
    - "Module-per-command pattern: create.rs, verify.rs, inspect.rs"
    - "Stub functions return Result<(), BundleError> with todo! macro"

key-files:
  created:
    - "crates/bundle-cli/Cargo.toml"
    - "crates/bundle-cli/src/main.rs"
    - "crates/bundle-cli/src/create.rs"
    - "crates/bundle-cli/src/verify.rs"
    - "crates/bundle-cli/src/inspect.rs"
    - "crates/bundle-cli/src/manifest.rs"
    - "crates/bundle-cli/src/error.rs"
  modified: []

key-decisions:
  - "Standalone Cargo project (not workspace) to keep bundle-cli independent from any future workspace additions"
  - "Global --json flag declared with #[arg(long, global = true)] so it works on all subcommands"
  - "Stub functions use todo!() not NotImplemented error so cargo build succeeds but runtime is obviously incomplete"

patterns-established:
  - "Module-per-command: each CLI command has its own .rs file with a pub fn run(...) -> Result<(), BundleError>"
  - "Global flag pattern: #[arg(long, global = true)] on Cli struct propagates to all subcommands"

requirements-completed: [SCAF-01, SCAF-02]

duration: 2min
completed: "2026-03-01"
---

# Phase 4 Plan 01: Cargo Crate Scaffolding + CLI Entry Point Summary

**Compilable `edgeworks-bundle` Rust crate at `crates/bundle-cli/` with clap-based CLI showing `create`, `verify`, `inspect` subcommands and global `--json` flag**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-01T17:59:17Z
- **Completed:** 2026-03-01T18:01:00Z
- **Tasks:** 2 (Task 2 was verification only, no code changes)
- **Files modified:** 7

## Accomplishments
- Created standalone Rust crate at `crates/bundle-cli/` with all 6 dependencies in Cargo.toml
- Implemented clap derive-based CLI entry point with `create`, `verify`, `inspect` subcommands and global `--json` flag
- Added stub modules (`create.rs`, `verify.rs`, `inspect.rs`) with correct function signatures returning `Result<(), BundleError>`
- Added placeholder manifest types (`BundleManifest`, `BundleImage`) and error enum (`BundleError`) so crate compiles cleanly
- `cargo build` completes with zero errors (3 expected dead_code warnings for stub types)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Cargo crate with dependencies and CLI entry point** - `6305ca9` (feat)
2. **Task 2: Verify CLI subcommands and --json flag render correctly** - No separate commit (verification confirmed Task 1 output; no code changes needed)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `crates/bundle-cli/Cargo.toml` — Package definition with all 6 runtime dependencies
- `crates/bundle-cli/src/main.rs` — clap CLI entry point with Cli struct, Commands enum, main() dispatch
- `crates/bundle-cli/src/create.rs` — Stub: `pub fn run(image, output, notes, target_device) -> Result<(), BundleError>`
- `crates/bundle-cli/src/verify.rs` — Stub: `pub fn run(path) -> Result<(), BundleError>`
- `crates/bundle-cli/src/inspect.rs` — Stub: `pub fn run(path) -> Result<(), BundleError>`
- `crates/bundle-cli/src/manifest.rs` — Placeholder `BundleManifest` and `BundleImage` structs with serde derives
- `crates/bundle-cli/src/error.rs` — `BundleError` enum with `NotImplemented` and `Io` variants via thiserror

## Decisions Made
- Used standalone Cargo project (not workspace) to keep bundle-cli self-contained — matches design doc §5 note
- Global `--json` flag declared with `#[arg(long, global = true)]` on the top-level `Cli` struct so it's available to all subcommands without repetition
- Stub functions use `todo!()` rather than returning `BundleError::NotImplemented` — ensures the compiler accepts the signatures while making the runtime behavior obvious

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Crate scaffold is complete and compiles cleanly — Phase 4 Plan 02 (manifest types and error handling) can build on this directly
- `manifest.rs` placeholder structs will be replaced with full types in Plan 02
- `error.rs` stub errors will be expanded to the full BundleError enum in Plan 02
- No blockers

---
*Phase: 04-foundation*
*Completed: 2026-03-01*
