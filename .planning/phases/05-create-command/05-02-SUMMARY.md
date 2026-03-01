---
phase: "05"
plan: "05-02"
subsystem: bundle-cli
tags: [json-output, integration-tests, create-command, assert_cmd]
dependency_graph:
  requires: [05-01]
  provides: [json-output-mode, integration-test-suite]
  affects: [crates/bundle-cli/src/create.rs, crates/bundle-cli/tests/create_integration.rs]
tech_stack:
  added: [tempfile=3, assert_cmd=2, predicates=3]
  patterns: [integration-testing, cargo_bin_cmd-macro, ProgressBar::hidden-for-json-mode]
key_files:
  created:
    - crates/bundle-cli/tests/create_integration.rs
  modified:
    - crates/bundle-cli/src/create.rs
    - crates/bundle-cli/Cargo.toml
decisions:
  - "Used assert_cmd::cargo::cargo_bin_cmd! macro (non-deprecated) instead of Command::cargo_bin()"
  - "ProgressBar::hidden() chosen to suppress progress output in JSON mode — cleaner than conditional rendering"
  - "JSON error output goes to stdout (not stderr) per design doc requirement — main.rs error handler is bypassed via process::exit(1)"
  - "std::fs::canonicalize() for absolute output path in JSON success output"
metrics:
  duration: "~3 min"
  completed_date: "2026-03-01"
  tasks_completed: 2
  files_changed: 3
---

# Phase 5 Plan 02: JSON output mode and integration tests Summary

**One-liner:** JSON output mode with `CreateOutput` struct and 5 integration tests covering all error paths using `assert_cmd`.

## What Was Built

### Task 05-02-01: JSON output mode for create command

Refactored `crates/bundle-cli/src/create.rs` to properly implement JSON output mode:

- Added `CreateOutput` struct with `#[derive(Serialize)]` matching design doc §3.1 schema exactly
- Threaded `json: bool` flag into `create_bundle()` private function to suppress progress bars
- `ProgressBar::hidden()` used in JSON mode — ensures stdout is clean for machine parsing
- `std::fs::canonicalize()` produces absolute output directory path in JSON success output
- JSON error path: prints `{"status":"error","message":"..."}` to stdout and calls `process::exit(1)` — bypasses main.rs's stderr error handler so stdout is the sole output channel
- Restructured `run()` with `match create_bundle(...)` to separate Ok/Err handling cleanly

**JSON success output shape (design doc §3.1):**
```json
{
  "status": "ok",
  "directory": "/absolute/path/to/output",
  "image": "registry/repo:tag",
  "version": "tag",
  "digest": "sha256:hex",
  "size_bytes": 1234567,
  "files": ["manifest.json", "checksums.sha256", "edge-os-tag.oci.tar"]
}
```

### Task 05-02-02: Integration tests

Created `crates/bundle-cli/tests/create_integration.rs` with 5 runnable tests + 1 ignored:

| Test | What it verifies |
|------|-----------------|
| `test_create_missing_skopeo` | Empty PATH causes skopeo error |
| `test_create_existing_output_dir` | Existing manifest.json causes OutputExists error |
| `test_create_invalid_image_ref` | Missing tag in image ref causes validation error |
| `test_create_json_error_output` | `--json` error path outputs `{"status":"error"}` to stdout |
| `test_create_help_shows_flags` | `create --help` shows all four flags |
| `test_create_e2e_with_skopeo` (#ignore) | Full pipeline with sha256sum -c verification |

Added dev-dependencies: `tempfile = "3"`, `assert_cmd = "2"`, `predicates = "3"`.

## Verification Results

```
cargo build: PASS (1 warning about unused error variants — pre-existing)
cargo test --no-run: PASS
cargo test -- --skip e2e:
  - 7 unit tests: PASS
  - 5 integration tests: PASS
  - 1 e2e test: IGNORED (requires skopeo)

Manual JSON error verification:
  edgeworks-bundle --json create --image notatag --output /tmp/test
  -> stdout: {"message":"image pull failed: ...","status":"error"}
  -> exit code: 1
```

## Decisions Made

1. **`ProgressBar::hidden()` over conditional rendering** — Cleaner: `create_bundle()` receives `json` flag and creates hidden bars when `true`. No conditional `if !json { pb.inc() }` scattered through hashing loop.

2. **`assert_cmd::cargo::cargo_bin_cmd!` macro** — The `Command::cargo_bin()` associated function was deprecated in assert_cmd 2.1.0 (incompatible with custom cargo build-dir). Used the macro form to avoid warnings.

3. **JSON errors go to stdout via `process::exit(1)`** — Design doc requires JSON error output on stdout (not stderr). The main.rs error handler writes to stderr. Solution: call `process::exit(1)` after printing JSON error, bypassing the main.rs error handler entirely.

4. **`std::fs::canonicalize()` with fallback** — If canonicalization fails (dir doesn't exist yet), falls back to the raw path. This is defensive; canonicalize should always succeed since `create_dir_all()` already ran.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

### Files created/modified
- [x] `crates/bundle-cli/src/create.rs` — modified
- [x] `crates/bundle-cli/tests/create_integration.rs` — created
- [x] `crates/bundle-cli/Cargo.toml` — modified

### Commits
- [x] 2c3f2e5 — feat(05-02): add JSON output mode to create command
- [x] e507cec — feat(05-02): add integration tests for create command

## Self-Check: PASSED
