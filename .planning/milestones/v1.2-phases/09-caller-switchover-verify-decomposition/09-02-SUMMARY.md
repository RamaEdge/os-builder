---
phase: 09-caller-switchover-verify-decomposition
plan: 02
subsystem: verify
tags: [rust, sha256, decomposition, refactoring, checksum-cross-reference]

# Dependency graph
requires:
  - phase: 08-shared-utilities
    provides: "format_bytes in format.rs, ChecksumLine in checksum.rs"
provides:
  - "Decomposed run_verify with 6 named check_* functions"
  - "CKSM-03 filename cross-reference between checksums.sha256 and manifest"
  - "ChecksumLine integration in verify.rs"
affects: [10-caller-switchover-main-rs]

# Tech tracking
tech-stack:
  added: []
  patterns: ["orchestrator-over-check-functions pattern for verify pipeline"]

key-files:
  created: []
  modified:
    - "crates/bundle-cli/src/verify.rs"

key-decisions:
  - "Used ChecksumLine.file field (not filename) matching actual Phase 8 API"
  - "CKSM-03 reuses checksums.sha256 well-formed check name slot on mismatch"
  - "check_sha256 returns CheckResult directly (not Result) since IO errors become failed checks"

patterns-established:
  - "Orchestrator pattern: run_verify is ~30-line coordinator calling 6 private check_* functions with early-return on failure"
  - "Each check_* returns exactly one CheckResult (directly or via tuple with optional data)"

requirements-completed: [VRFY-01, VRFY-02, VRFY-03, CKSM-03]

# Metrics
duration: 15min
completed: 2026-03-13
---

# Phase 9 Plan 2: Verify Decomposition Summary

**Decomposed 230-line monolithic run_verify into 6 named check_* functions with orchestrator pattern, switched to ChecksumLine parser, added CKSM-03 filename cross-reference**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-13T08:40:29Z
- **Completed:** 2026-03-13T08:55:29Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Extracted check_manifest, check_schema_version, check_checksums_file, check_tarball_exists, check_sha256, check_file_size as private functions
- Replaced monolithic run_verify with ~30-line orchestrator that coordinates checks with early-return semantics
- Integrated ChecksumLine::parse from crate::checksum (replacing inline splitn parsing)
- Added CKSM-03 filename cross-reference: checksums.sha256 filename is validated against manifest.image.file
- All 13 tests pass (11 original + 2 new safety-net tests)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add safety-net tests and switch format import** - `b0c309e` (test)
2. **Task 2: Decompose run_verify into check functions and add CKSM-03** - `5c8ae45` (feat)

## Files Created/Modified
- `crates/bundle-cli/src/verify.rs` - Decomposed into 6 check_* functions + orchestrator, CKSM-03 cross-reference, 2 new tests

## Decisions Made
- Used ChecksumLine.file field (Phase 8 named it `file` not `filename` as plan assumed) -- adapted CKSM-03 check accordingly
- check_sha256 returns CheckResult directly rather than Result<CheckResult, BundleError> since compute errors become failed checks (not BundleError propagation)
- format_bytes import was already in place from Phase 8 (no local copy existed to delete)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adapted to ChecksumLine.file field name**
- **Found during:** Task 2 (check_checksums_file extraction)
- **Issue:** Plan referenced `cs_line.filename` but Phase 8 ChecksumLine struct uses field name `file`
- **Fix:** Used `cs_line.file` throughout, including CKSM-03 cross-reference
- **Files modified:** crates/bundle-cli/src/verify.rs
- **Verification:** All tests pass, CKSM-03 filename mismatch correctly detected
- **Committed in:** 5c8ae45

**2. [Rule 3 - Blocking] format_bytes import already present**
- **Found during:** Task 1 Step 4
- **Issue:** Plan Step 4 said to add import and delete local function, but Phase 8 already completed this
- **Fix:** Skipped Step 4 (no-op) -- import already correct
- **Files modified:** None
- **Verification:** Confirmed `use crate::format::format_bytes` present, no local `fn format_bytes` exists

---

**Total deviations:** 2 (both blocking adjustments to match actual Phase 8 API)
**Impact on plan:** Minor field name difference. No scope creep.

## Issues Encountered
- Pre-existing compiler warnings for unused ImageRef struct and parse method (from Phase 8, not yet wired into callers) -- out of scope for this plan

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- verify.rs fully decomposed with individually testable check functions
- Adding a 7th check in future: write one function, add one line in orchestrator
- Ready for Phase 10 caller switchover in main.rs

---
*Phase: 09-caller-switchover-verify-decomposition*
*Completed: 2026-03-13*
