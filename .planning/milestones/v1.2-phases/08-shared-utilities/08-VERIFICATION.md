---
phase: 08-shared-utilities
verified: 2026-03-13T00:00:00Z
status: passed
score: 6/6 must-haves verified
re_verification: false
---

# Phase 8: Shared Utilities Verification Report

**Phase Goal:** Three new utility modules exist with full test coverage and format.rs is wired into all callers, replacing duplicate implementations
**Verified:** 2026-03-13
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `format_bytes(1024^4)` returns `"1.0 TiB"` — TiB support present | VERIFIED | `format.rs:36` asserts `format_bytes(1024u64 * 1024 * 1024 * 1024) == "1.0 TiB"`; test passes |
| 2 | `ChecksumLine::parse` rejects single-space input — two-space contract enforced | VERIFIED | `checksum.rs:74-80` `test_parse_single_space_rejected` asserts `is_err()`; `splitn(2, "  ")` used at line 22; test passes |
| 3 | `ImageRef::parse("registry:5000/repo:1.2.0")` returns tag `"1.2.0"` — port-containing registries work | VERIFIED | `image_ref.rs:77-79` `test_parse_port_registry` asserts `tag == "1.2.0"`; `rfind(':')` used at line 45; test passes |
| 4 | `ImageRef::parse` rejects shell metacharacters ($, backtick, |, ;, &, <, >) — injection prevented | VERIFIED | 7 explicit rejection tests in `image_ref.rs` (lines 103-137); character allowlist at lines 33-42; all pass |
| 5 | No local `format_bytes` or `format_size` functions remain in `create.rs`, `verify.rs`, or `inspect.rs` | VERIFIED | grep finds only `crates/bundle-cli/src/format.rs:4` defining `format_bytes`; all three callers use `use crate::format::format_bytes` |
| 6 | `cargo test` passes with zero failures — no existing behavior broken | VERIFIED | 45 unit tests + 5 integration tests (1 ignored): all pass; 0 failures |

**Score:** 6/6 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `crates/bundle-cli/src/format.rs` | Shared `format_bytes` with TiB support | VERIFIED | 39 lines; `pub(crate) fn format_bytes` at line 4; 8-assertion test at line 28 |
| `crates/bundle-cli/src/checksum.rs` | `ChecksumLine` struct with two-space parse contract | VERIFIED | 110 lines; `pub(crate) struct ChecksumLine` at line 6; `parse()` at line 19; 6 test cases |
| `crates/bundle-cli/src/image_ref.rs` | `ImageRef` struct with shell-safe validation | VERIFIED | 139 lines; `pub(crate) struct ImageRef` at line 9; `parse()` at line 25; 13 test cases |
| `crates/bundle-cli/src/main.rs` | mod declarations for all three modules | VERIFIED | Lines 4-11: `mod checksum;`, `mod format;`, `mod image_ref;` all present, alphabetically ordered |
| `crates/bundle-cli/src/error.rs` | `InvalidImageRef` variant with test coverage | VERIFIED | `InvalidImageRef(String)` at line 16; tested at error.rs lines 56-59 in `all_error_variants_have_descriptive_messages` |
| `crates/bundle-cli/src/create.rs` | Imports `crate::format::format_bytes`; no local duplicate | VERIFIED | `use crate::format::format_bytes;` at line 12; no local `fn format_bytes` present |
| `crates/bundle-cli/src/verify.rs` | Imports `crate::format::format_bytes`; no local duplicate | VERIFIED | `use crate::format::format_bytes;` at line 7; no local `fn format_bytes` present |
| `crates/bundle-cli/src/inspect.rs` | Imports `crate::format::format_bytes`; no local `format_size` | VERIFIED | `use crate::format::format_bytes;` at line 5; no local `fn format_size` present; call site at line 65 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `main.rs` | `format.rs`, `checksum.rs`, `image_ref.rs` | `mod` declarations | WIRED | Lines 4-11: `mod checksum;`, `mod format;`, `mod image_ref;` present |
| `create.rs` | `crate::format::format_bytes` | `use` import replacing local fn | WIRED | `use crate::format::format_bytes;` at line 12; used at line 212 |
| `verify.rs` | `crate::format::format_bytes` | `use` import replacing local fn | WIRED | `use crate::format::format_bytes;` at line 7; used at line 176 |
| `inspect.rs` | `crate::format::format_bytes` | `use` import replacing local fn | WIRED | `use crate::format::format_bytes;` at line 5; used at lines 65 |
| `error.rs` | `image_ref.rs` | `InvalidImageRef` variant used by `ImageRef::parse` | WIRED | `BundleError::InvalidImageRef` defined at error.rs:16; referenced at image_ref.rs:27, 37, 47, 53 |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| DEDUP-01 | 08-01-PLAN.md | Shared `format.rs` with single `format_bytes()` used by all commands | SATISFIED | `format.rs` exists; all three commands import from `crate::format` |
| DEDUP-02 | 08-01-PLAN.md | Duplicate `format_bytes` in `create.rs` and `verify.rs` replaced with import | SATISFIED | Both files use `use crate::format::format_bytes;`; no local fn remains |
| DEDUP-03 | 08-01-PLAN.md | `format_size` in `inspect.rs` replaced with import from `crate::format` | SATISFIED | `inspect.rs` uses `use crate::format::format_bytes;`; no `format_size` present |
| VALID-01 | 08-01-PLAN.md | Image reference validated against allowlist, rejects shell metacharacters | SATISFIED | Character allowlist at `image_ref.rs:33-42`; 5+ rejection tests pass |
| VALID-02 | 08-01-PLAN.md | `ImageRef` struct extracts version tag with proper validation | SATISFIED | `ImageRef.tag` field; `rfind(':')` at line 45; validated by 3 positive tests |
| VALID-03 | 08-01-PLAN.md | Port-containing registry hosts pass validation | SATISFIED | `test_parse_port_registry` passes; `rfind(':')` correctly finds final colon |
| CKSM-01 | 08-01-PLAN.md | `ChecksumLine` struct encapsulates parsing of `checksums.sha256` lines | SATISFIED | `ChecksumLine` struct at `checksum.rs:6`; `parse()` at line 19 |
| CKSM-02 | 08-01-PLAN.md | Two-space delimiter contract preserved (not `split_whitespace`) | SATISFIED | `splitn(2, "  ")` at checksum.rs:22; `test_parse_single_space_rejected` explicitly tests this |

**No orphaned requirements.** All 8 requirement IDs from the PLAN appear in REQUIREMENTS.md mapped to Phase 8, and all are satisfied.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `checksum.rs` | 6 | `dead_code` warning — `ChecksumLine` never constructed in production code | Info | Expected; SUMMARY explicitly notes wiring into callers is deferred to Phase 9 |
| `image_ref.rs` | 9 | `dead_code` warning — `ImageRef` never constructed in production code | Info | Expected; SUMMARY explicitly notes wiring into callers is deferred to Phase 9 |

Neither warning is a blocker. The structs are exercised thoroughly by their own unit tests. Production wiring (replacing inline parsing in `verify.rs` Check 3 and `create.rs` tag extraction) is Phase 9 work and out of scope for Phase 8.

Note: `create.rs` still uses an inline `rfind(':')` block (lines 55-70) for tag extraction rather than `ImageRef::parse`. This is intentional per the PLAN scope — the PLAN's key_links do not include `create.rs -> image_ref.rs`, and the SUMMARY explicitly lists this as Phase 9 caller switchover.

---

### Human Verification Required

None. All observable truths are verifiable programmatically via the test suite and source inspection.

---

### Gaps Summary

No gaps. All six observable truths are verified, all eight required artifacts pass all three levels (exists, substantive, wired), all five key links are confirmed, and all eight requirement IDs are satisfied with evidence.

The two `dead_code` compiler warnings for `ChecksumLine` and `ImageRef` are expected and documented in the SUMMARY as work deferred to Phase 9. They do not block any Phase 8 goal.

**Task commits verified:**
- `c55e96f` — feat(08-01): create shared format.rs module and wire into all callers
- `3971228` — feat(08-01): create checksum.rs module with ChecksumLine struct
- `905e0c2` — feat(08-01): create image_ref.rs module with shell-safe ImageRef validation

---

_Verified: 2026-03-13_
_Verifier: Claude (gsd-verifier)_
