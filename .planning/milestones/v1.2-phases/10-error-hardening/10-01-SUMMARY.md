---
phase: 10-error-hardening
plan: 01
subsystem: error-handling
tags: [serde_json, thiserror, error-propagation, exit-codes, integration-tests]

# Dependency graph
requires:
  - phase: 09-caller-switchover
    provides: "decomposed verify checks and shared format_bytes"
provides:
  - "BundleError::JsonSerialize variant with #[from] serde_json::Error"
  - "Result-returning format_inspect_json and format_verify_json"
  - "Exit code integration tests (verify/inspect exit 2 on nonexistent path)"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: ["Result propagation for JSON serialization instead of silent fallbacks"]

key-files:
  created:
    - "crates/bundle-cli/tests/exit_codes.rs"
  modified:
    - "crates/bundle-cli/src/error.rs"
    - "crates/bundle-cli/src/inspect.rs"
    - "crates/bundle-cli/src/verify.rs"
    - "crates/bundle-cli/src/create.rs"
    - "crates/bundle-cli/src/main.rs"

key-decisions:
  - "create.rs Err arm uses .expect() not ? because json! literal is infallible and path exits unconditionally"
  - "format function Err in main.rs uses exit(1) not exit(2) -- exit(2) reserved for path-not-found"

patterns-established:
  - "JSON serialization returns Result<String, BundleError> -- no silent {} fallbacks"
  - "Exit code 1 for logic/format errors, exit code 2 for path-not-found"

requirements-completed: [ERR-01, ERR-02]

# Metrics
duration: 2min
completed: 2026-03-13
---

# Phase 10 Plan 01: Error Hardening Summary

**Replaced silent JSON {} fallbacks with Result-based error propagation and added exit code integration tests**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-13T09:53:11Z
- **Completed:** 2026-03-13T09:55:11Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Eliminated all `unwrap_or_else(|_| "{}".to_string())` patterns from source code
- Changed `format_inspect_json` and `format_verify_json` to return `Result<String, BundleError>`
- Added `BundleError::JsonSerialize` variant with `#[from] serde_json::Error` conversion
- Added exit code integration tests verifying exit(2) for nonexistent paths
- All 47 unit tests + 7 integration tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Add JsonSerialize error variant and replace all 4 unwrap sites** - `d7d8fc8` (feat)
2. **Task 2: Add exit code integration tests** - `a40b9fb` (test)

## Files Created/Modified
- `crates/bundle-cli/src/error.rs` - Added JsonSerialize variant and test coverage
- `crates/bundle-cli/src/inspect.rs` - format_inspect_json returns Result
- `crates/bundle-cli/src/verify.rs` - format_verify_json returns Result
- `crates/bundle-cli/src/create.rs` - Replaced .unwrap() with ? and .expect()
- `crates/bundle-cli/src/main.rs` - Match on Result from format functions
- `crates/bundle-cli/tests/exit_codes.rs` - Exit code contract integration tests

## Decisions Made
- create.rs Err arm uses `.expect("infallible: ...")` instead of `?` because the `json!` literal cannot fail and the code path exits unconditionally
- JSON format errors in main.rs use exit(1) not exit(2) -- exit(2) is reserved for path-not-found from run_verify/run_inspect

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Pre-existing clippy dead_code warning on `ImageRef.full` field -- out of scope per deviation rules (not caused by this plan's changes).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Error hardening complete -- all JSON serialization paths propagate errors properly
- Exit code contract (0/1/2) preserved and tested
- No further phases in v1.2 milestone

---
*Phase: 10-error-hardening*
*Completed: 2026-03-13*
