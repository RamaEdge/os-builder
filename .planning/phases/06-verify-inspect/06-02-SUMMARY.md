---
phase: 06-verify-inspect
plan: 02
subsystem: bundle-cli/inspect
tags: [rust, cli, inspect, metadata, serde_json]
dependency_graph:
  requires: [06-01]
  provides: [inspect-command, format-inspect-human, format-inspect-json, format-size]
  affects: [crates/bundle-cli/src/inspect.rs, crates/bundle-cli/src/main.rs]
tech_stack:
  added: []
  patterns: [same-as-verify pattern for run/format split, BundleManifest::from-serde-json inline]
key_files:
  created: [crates/bundle-cli/src/inspect.rs]
  modified: [crates/bundle-cli/src/main.rs]
decisions:
  - run_inspect returns Err only for ManifestNotFound (nonexistent dir/manifest) mapped to exit 2; ManifestInvalid maps to exit 1 — mirrors verify exit code semantics
  - format_size shared helper duplicated in inspect.rs (not extracted to shared module) — keeps modules self-contained; refactor if needed in future
  - Empty notes shows '—' rather than omitting line — completeness per design doc intent
metrics:
  duration: 1.5 min
  completed: 2026-03-01
  tasks_completed: 2
  files_changed: 2
requirements: [INSP-01, INSP-02, INSP-03, INSP-04]
---

# Phase 6 Plan 02: Inspect Command Summary

**One-liner:** `edgeworks-bundle inspect` displays all bundle manifest fields instantly using serde_json deserialization, with human-readable and JSON output modes and no checksum computation.

## What Was Built

The `inspect` subcommand for `edgeworks-bundle` that reads and displays `manifest.json` without computing checksums. Key components:

- **`run_inspect(bundle_dir)`** — Loads manifest.json from the bundle directory. Returns `Err(ManifestNotFound)` for nonexistent paths/missing manifest (exit 2), `Err(ManifestInvalid)` for malformed JSON (exit 1).
- **`format_inspect_human(manifest, bundle_dir)`** — Formats all manifest fields matching design doc §3.3 exactly. Empty notes shows '—'.
- **`format_inspect_json(manifest)`** — Pretty-prints the full `BundleManifest` as JSON via `serde_json::to_string_pretty`.
- **`format_size(bytes)`** — Human-readable size formatter handling B, KiB, MiB, GiB, TiB with 1 decimal place.
- **main.rs wiring** — `Commands::Inspect { path }` match arm dispatches to inspect functions, exit codes 0/1/2 correctly mapped.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement inspect command with human and JSON output | 4f7a55e | crates/bundle-cli/src/inspect.rs |
| 2 | Wire inspect subcommand into main.rs | 1ad2597 | crates/bundle-cli/src/main.rs |

## Tests

8 unit tests in `inspect.rs`:
- `test_inspect_valid_bundle` — loads all fields correctly from valid bundle
- `test_inspect_json_output` — JSON output is valid and round-trips to same manifest
- `test_inspect_human_output` — human output contains all 8 expected fields
- `test_inspect_missing_manifest` — returns ManifestNotFound for dir with no manifest.json
- `test_inspect_malformed_manifest` — returns ManifestInvalid for bad JSON
- `test_inspect_nonexistent_path` — returns ManifestNotFound for nonexistent path
- `test_format_size` — validates B/KiB/MiB/GiB/TiB conversions
- `test_inspect_empty_notes_shows_dash` — empty notes renders as '—'

Total test suite: 26 unit tests + 5 integration tests all passing.

## Verification Results

1. `cargo test inspect` — 8/8 passed
2. `cargo test` — ALL 26 unit tests + 5 integration tests passed (1 skopeo e2e ignored)
3. `cargo build` — compiles without errors
4. `edgeworks-bundle inspect <path>` — shows all fields in design doc format
5. `edgeworks-bundle --json inspect <path>` — outputs valid JSON manifest
6. `edgeworks-bundle inspect /nonexistent` — exits 2 with ManifestNotFound error
7. No checksum computation — only reads manifest.json, ignores tarball entirely

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] main.rs still called `inspect::run()` (old stub signature)**

- **Found during:** Task 1 verification — cargo test failed to compile
- **Issue:** The existing inspect stub exported `run()` but plan spec uses `run_inspect()`. The main.rs arm `Commands::Inspect { path } => inspect::run(path)` caused a compile error.
- **Fix:** Updated main.rs Inspect match arm inline during Task 1 compilation fix, then completed full wiring in Task 2.
- **Files modified:** crates/bundle-cli/src/main.rs
- **Commit:** 1ad2597

## Decisions Made

- `run_inspect` returns `Err` for both nonexistent directory AND missing manifest (both use `ManifestNotFound`), allowing main.rs to map both to exit 2 — matches design intent that "path not found" means the bundle dir isn't accessible.
- `format_size` helper is duplicated in `inspect.rs` (same logic as `format_bytes` in `verify.rs`) — kept self-contained to avoid premature abstraction. If a third consumer appears, extract to a shared `util.rs`.
- Empty `notes` field displays as `—` rather than being omitted — ensures the output always has 8 lines for consistent parsing.

## Self-Check: PASSED

- [x] crates/bundle-cli/src/inspect.rs — exists with 231 lines
- [x] crates/bundle-cli/src/main.rs — Inspect arm wired
- [x] Commit 4f7a55e — feat(06-verify-inspect-02): implement inspect command
- [x] Commit 1ad2597 — feat(06-verify-inspect-02): wire inspect subcommand
- [x] All 8 inspect tests pass
- [x] All 26 unit tests pass
- [x] Binary exits 2 for nonexistent path
