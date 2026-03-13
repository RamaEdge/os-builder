---
phase: 08-shared-utilities
plan: 01
subsystem: api
tags: [rust, refactoring, deduplication, validation, checksum, image-ref]

# Dependency graph
requires:
  - phase: 07-bundle-cli-ci
    provides: "CI quality gates (fmt, clippy) ensuring code compiles cleanly"
provides:
  - "Shared format_bytes function with TiB support (format.rs)"
  - "ChecksumLine struct with two-space parse contract (checksum.rs)"
  - "ImageRef struct with shell-safe validation (image_ref.rs)"
  - "InvalidImageRef BundleError variant"
affects: [09-verify-decomposition, 10-error-hardening]

# Tech tracking
tech-stack:
  added: []
  patterns: [pub-crate-utility-modules, character-allowlist-validation, two-space-checksum-contract]

key-files:
  created:
    - crates/bundle-cli/src/format.rs
    - crates/bundle-cli/src/checksum.rs
    - crates/bundle-cli/src/image_ref.rs
  modified:
    - crates/bundle-cli/src/main.rs
    - crates/bundle-cli/src/error.rs
    - crates/bundle-cli/src/create.rs
    - crates/bundle-cli/src/verify.rs
    - crates/bundle-cli/src/inspect.rs

key-decisions:
  - "Used inspect.rs TiB-capable implementation as canonical format_bytes source, not GiB-limited create/verify versions"
  - "Character allowlist for ImageRef rejects anything not alphanumeric or / : . _ - to prevent shell injection"
  - "ChecksumLine uses BundleError::ManifestInvalid for parse errors rather than a new error variant"

patterns-established:
  - "pub(crate) utility modules: shared functions live in dedicated modules, imported via use crate::module::fn"
  - "Character allowlist validation: reject unexpected characters rather than blocklisting known-bad ones"
  - "rfind(':') for image tag extraction: handles port-containing registries like registry:5000/repo:tag"

requirements-completed: [DEDUP-01, DEDUP-02, DEDUP-03, VALID-01, VALID-02, VALID-03, CKSM-01, CKSM-02]

# Metrics
duration: 14min
completed: 2026-03-13
---

# Phase 8 Plan 1: Shared Utilities Summary

**Three shared utility modules (format.rs, checksum.rs, image_ref.rs) with 27 new tests, eliminating 3 duplicate format_bytes implementations and adding shell-safe image reference validation**

## Performance

- **Duration:** 14 min
- **Started:** 2026-03-13T08:20:21Z
- **Completed:** 2026-03-13T08:34:16Z
- **Tasks:** 3
- **Files modified:** 8 (3 created, 5 modified)

## Accomplishments
- Consolidated three divergent format_bytes/format_size implementations into one TiB-capable shared function
- Created ChecksumLine parser enforcing GNU coreutils two-space separator contract with 6 test cases
- Created ImageRef parser with character allowlist rejecting shell metacharacters and rfind-based tag extraction for port-containing registries
- Added InvalidImageRef variant to BundleError with test coverage
- All 45 unit tests and 5 integration tests pass with zero failures

## Task Commits

Each task was committed atomically:

1. **Task 1: Create format.rs module and wire into all callers** - `c55e96f` (feat)
2. **Task 2: Create checksum.rs module with ChecksumLine struct** - `3971228` (feat)
3. **Task 3: Create image_ref.rs module with ImageRef struct and BundleError variant** - `905e0c2` (feat)

## Files Created/Modified
- `crates/bundle-cli/src/format.rs` - Shared format_bytes with TiB support and 8 boundary tests
- `crates/bundle-cli/src/checksum.rs` - ChecksumLine struct with two-space parse contract and 6 tests
- `crates/bundle-cli/src/image_ref.rs` - ImageRef struct with shell-safe validation and 13 tests
- `crates/bundle-cli/src/main.rs` - Added mod declarations for format, checksum, image_ref
- `crates/bundle-cli/src/error.rs` - Added InvalidImageRef variant with test entry
- `crates/bundle-cli/src/create.rs` - Deleted local format_bytes, added use crate::format::format_bytes
- `crates/bundle-cli/src/verify.rs` - Deleted local format_bytes, added use crate::format::format_bytes
- `crates/bundle-cli/src/inspect.rs` - Deleted format_size and its test, replaced with shared format_bytes

## Decisions Made
- Used inspect.rs TiB-capable implementation as canonical format_bytes source (not GiB-limited create/verify versions)
- Character allowlist for ImageRef rejects anything not alphanumeric or `/ : . _ -` to prevent shell injection
- ChecksumLine reuses BundleError::ManifestInvalid for parse errors rather than introducing a new variant

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- format.rs, checksum.rs, and image_ref.rs are ready for use by Phase 9 (verify decomposition)
- ChecksumLine can replace inline parsing in verify.rs Check 3
- ImageRef can replace inline tag extraction in create.rs
- dead_code warnings on ChecksumLine and ImageRef will resolve when Phase 9 wires them into callers

## Self-Check: PASSED

All 3 created files exist. All 3 task commits verified.

---
*Phase: 08-shared-utilities*
*Completed: 2026-03-13*
