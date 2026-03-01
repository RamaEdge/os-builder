---
phase: 05-create-command
plan: "01"
subsystem: cli
tags: [rust, skopeo, sha2, indicatif, serde_json, oci, bundle]

# Dependency graph
requires:
  - phase: 04-foundation
    provides: BundleManifest, BundleImage, BundleError types and Cargo crate scaffold
provides:
  - create::run() function implementing full bundle creation pipeline
  - skopeo integration via Command subprocess with spinner progress bar
  - SHA256 streaming checksum computation via sha2 crate with progress bar
  - checksums.sha256 in GNU coreutils two-space format
  - manifest.json with all required fields per design doc §2.2
  - JSON output mode for machine-readable CI integration
affects:
  - 05-verify-command (consumes checksums.sha256 and manifest.json formats)
  - 05-inspect-command (consumes manifest.json)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Internal result struct (BundleResult) to share data between pipeline and output formatting
    - create_bundle() private function separates pipeline from output mode dispatch
    - indicatif spinner for unbounded waits (skopeo pull), ProgressBar::new(file_size) for bounded (SHA256)
    - GNU two-space checksum format: "hex  filename\n"

key-files:
  created: []
  modified:
    - crates/bundle-cli/src/create.rs
    - crates/bundle-cli/src/main.rs

key-decisions:
  - "Refactored create_bundle() private fn + BundleResult struct instead of duplicating pipeline for JSON/human modes — eliminates code duplication while keeping clean output dispatch"
  - "json flag threaded from main.rs Cli struct into create::run() as parameter — avoids global state"
  - "ProgressBar::new_spinner() for skopeo pull (unbounded duration) vs ProgressBar::new(file_size) for SHA256 (bounded by file size)"

patterns-established:
  - "Pipeline result struct pattern: private fn returns typed result, public run() dispatches to output mode"
  - "format_bytes() helper for human-readable sizes (GiB/MiB/KiB/B)"

requirements-completed: [CREATE-01, CREATE-02, CREATE-03, CREATE-05, CREATE-06]

# Metrics
duration: 2min
completed: 2026-03-01
---

# Phase 5 Plan 01: Create command core — skopeo pull, SHA256, bundle output Summary

**Full `edgeworks-bundle create` pipeline: skopeo OCI pull, streaming SHA256 via sha2, GNU checksum file, and typed manifest.json — with human and JSON output modes**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-01T18:08:16Z
- **Completed:** 2026-03-01T18:10:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Implemented complete `create::run()` replacing the `todo!()` stub with full production pipeline
- skopeo invoked as `skopeo copy docker://<ref> oci-archive:<path>` with spinner during pull
- SHA256 computed via sha2 crate in 8KB streaming chunks with `indicatif` progress bar
- `checksums.sha256` written in GNU coreutils two-space format (verifiable with `sha256sum -c`)
- `manifest.json` written with all required fields per design doc §2.2
- JSON output mode via `--json` flag (design doc §3.1) for CI integration
- All 7 unit tests pass; binary produces correct help text and error messages

## Task Commits

Each task was committed atomically:

1. **Task 1: Verify runtime dependencies** - no commit needed (all deps already present from Phase 4)
2. **Task 2: Implement create::run() with full bundle creation pipeline** - `fde00f2` (feat)

## Files Created/Modified
- `crates/bundle-cli/src/create.rs` — Full implementation: create_bundle() pipeline, run() with output dispatch, format_bytes() helper
- `crates/bundle-cli/src/main.rs` — Thread json flag into create::run() call

## Decisions Made
- Refactored internal `create_bundle()` private function returning `BundleResult` struct to share pipeline data between human and JSON output modes — avoids duplicating the entire pipeline
- `json` flag threaded as parameter from `main.rs` Cli struct into `create::run()` rather than global state
- `ProgressBar::new_spinner()` for skopeo pull (unknown duration) vs `ProgressBar::new(file_size)` for SHA256 (file size known upfront)

## Deviations from Plan

None — plan executed exactly as written. The `run_json()` initial draft was refactored to `create_bundle()` + `BundleResult` pattern during the same task for cleanliness, not as a deviation.

## Issues Encountered
None.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- `create::run()` is complete and callable from `main.rs`
- Bundle format (manifest.json, checksums.sha256, .oci.tar) is fully defined
- Ready for Phase 5 Plan 2: `verify` command implementation
- `verify.rs` stub can use `BundleError::ManifestNotFound`, `ChecksumMismatch`, `SizeMismatch`, `FileNotFound`, `UnsupportedSchema` variants already defined

## Self-Check: PASSED

All created/modified files verified present on disk. All task commits verified in git log.

---
*Phase: 05-create-command*
*Completed: 2026-03-01*
