# Phase 9: Caller Switchover + Verify Decomposition — Research

**Researched:** 2026-03-13
**Domain:** Rust CLI refactoring — bundle-cli crate, verify.rs decomposition and caller integration
**Confidence:** HIGH (based on direct source audit of all six affected files)

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VRFY-01 | `run_verify()` decomposed into individual check functions each returning `CheckResult` | Architecture Pattern 3 (check function decomposition); verified 6 discrete blocks in verify.rs:65–285 each maps to one named function |
| VRFY-02 | Coordinator function composes checks in a loop (~30 lines, down from 230) | Orchestrator loop pattern documented; early-return semantics must be preserved at each step |
| VRFY-03 | All 9 existing verify tests pass without modification | Tests analyzed line by line; every assertion is behavior-based, not implementation-based, except `checks.len() == 6` at line 415 — this assertion is the only one at risk and must be handled before decomposing |
| CKSM-03 | Checksum filename cross-referenced against `manifest.image.file` | `_checksum_filename` is already extracted at verify.rs:171 but suppressed with `_`; one equality check against `manifest.image.file` is the complete implementation |
</phase_requirements>

## Summary

Phase 9 is the second of three v1.2 tech-debt phases. It operates on the codebase *as Phase 8 leaves it*: Phase 8 creates `format.rs`, `checksum.rs`, and `image_ref.rs` and wires `create.rs`, `inspect.rs`, and the checksum-parsing block in `verify.rs` to use them. Phase 9 then takes over the two remaining tasks: (1) wire `create.rs`, `verify.rs`, and `inspect.rs` to import `crate::format::format_bytes` wherever local `format_bytes`/`format_size` copies still exist, and (2) decompose `run_verify()` into six named `check_*` private functions with a ~20-line orchestrator.

The full source has been audited directly. The current `verify.rs` is 617 lines: `run_verify()` occupies lines 56–285 (230 lines, 6 sequential checks), the two formatter functions follow, and the 9 test cases close the file. The six check blocks are already logically isolated — each has its own early-return path and maps to a single `CheckResult` push. Extraction is a mechanical operation with one critical pre-condition: the `checks.len() == 6` assertion at test line 415 must be augmented to name-based assertions *before* extraction begins, or any accidental merge/split of checks will produce a silent regression.

CKSM-03 is a small addition enabled by the existing structure: `_checksum_filename` (verify.rs:171) is already parsed and suppressed. One equality check against `manifest.image.file` and a new `CheckResult` failure path is the entire implementation.

**Primary recommendation:** Follow a strict four-step order — (1) wire format imports and delete local copies, (2) augment `checks.len()` assertion to named checks before touching `run_verify()`, (3) extract check functions one at a time compiling after each, (4) add CKSM-03 cross-reference after orchestrator is stable.

## Standard Stack

### Core (no new dependencies required)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `thiserror` | 2 (existing) | `BundleError` variants — no new variants needed for Phase 9 | Existing dep; `ManifestInvalid` covers checksum filename mismatch |
| `serde_json` | 1 (existing) | Already used in `format_verify_json` | No changes to JSON formatting in this phase |
| `sha2` | 0.10 (existing) | `compute_sha256` stays unchanged | No changes to hashing logic |

No `Cargo.toml` changes are required for Phase 9.

### Modules After Phase 8 (preconditions for Phase 9)

Phase 9 assumes these exist when it begins:

| Module | Path | What It Provides | Used By Phase 9 |
|--------|------|-----------------|-----------------|
| `format.rs` | `crates/bundle-cli/src/format.rs` | `pub(crate) fn format_bytes(u64) -> String` with TiB support | `create.rs`, `verify.rs`, `inspect.rs` switch to `use crate::format::format_bytes` |
| `checksum.rs` | `crates/bundle-cli/src/checksum.rs` | `ChecksumLine { hex, filename }` with `parse(line) -> Result<Self, BundleError>` | `verify.rs` already uses it after Phase 8; CKSM-03 uses `filename` field |
| `image_ref.rs` | `crates/bundle-cli/src/image_ref.rs` | `ImageRef { full, tag }` with `parse(raw) -> Result<Self, BundleError>` | `create.rs` uses it after Phase 8 |

If Phase 8 is incomplete when Phase 9 begins, the format-switchover steps can still be done if `format.rs` exists, but verify decomposition is independent of all three utility modules — it can be done in any order.

## Architecture Patterns

### Recommended Post-Phase-9 Structure

```
crates/bundle-cli/src/
├── main.rs          # Unchanged — CLI dispatch
├── error.rs         # Unchanged — BundleError enum
├── manifest.rs      # Unchanged — BundleManifest structs
├── format.rs        # Phase 8: single format_bytes() with TiB
├── image_ref.rs     # Phase 8: ImageRef struct
├── checksum.rs      # Phase 8: ChecksumLine struct
├── create.rs        # Phase 9: use crate::format::format_bytes (drop local copy)
├── verify.rs        # Phase 9: use crate::format::format_bytes + 6 check_* functions
└── inspect.rs       # Phase 9: use crate::format::format_bytes (drop local format_size)
```

### Pattern 1: Local-Copy Deletion (Format Switchover)

**What:** Replace three private `format_bytes`/`format_size` copies with `use crate::format::format_bytes`. Delete the now-unreachable private function to avoid unused-function warnings.

**Exact locations:**
- `create.rs:27–41` — `fn format_bytes(bytes: u64) -> String` (no TiB tier)
- `verify.rs:34–48` — `fn format_bytes(bytes: u64) -> String` (no TiB tier)
- `inspect.rs:36–53` — `pub fn format_size(bytes: u64) -> String` (has TiB tier — this is the canonical version)

**Call sites that switch:**
- `create.rs:228` — `format_bytes(result.size_bytes)` stays identical, now calls `crate::format`
- `verify.rs:192` — `format_bytes(tarball_size)` stays identical, now calls `crate::format`
- `inspect.rs:84` — `format_size(manifest.image.size_bytes)` becomes `format_bytes(...)` from `crate::format`

**Precondition check:** The `test_format_size` test in `inspect.rs:232–241` currently tests the local `format_size`. After switchover it implicitly tests `crate::format::format_bytes`. This test MUST pass — it covers the TiB boundary (line 240: `format_size(1024u64 * 1024 * 1024 * 1024)` = `"1.0 TiB"`). Verify `format.rs` was created with TiB support before deleting `inspect.rs::format_size`.

**Example:**
```rust
// Before (verify.rs)
fn format_bytes(bytes: u64) -> String {
    const GIB: u64 = 1024 * 1024 * 1024;
    // ... no TiB tier
}

// After (verify.rs) — delete the local fn, add import
use crate::format::format_bytes;
// format_bytes call sites are unchanged
```

### Pattern 2: Check Count Assertion Hardening (Critical Pre-Step)

**What:** Before touching `run_verify()`, augment `test_verify_valid_bundle` (verify.rs:407–417) to verify named check presence in addition to (not instead of) the count.

**Why it's a pre-step, not a follow-up:** If the count assertion at line 415 is the only guard and extraction accidentally merges two checks, the count drops to 5 but the tests still compile. The bug ships silently. Adding name assertions before extraction means a merge is caught immediately.

**Current assertion (line 415):**
```rust
assert_eq!(result.checks.len(), 6);
```

**Augmented assertions (add immediately after line 415, before any extraction):**
```rust
assert_eq!(result.checks.len(), 6);
// Named check assertions — these must survive decomposition unchanged
let check_names: Vec<&str> = result.checks.iter().map(|c| c.name.as_str()).collect();
assert!(check_names.iter().any(|n| n.contains("manifest.json schema valid")),
    "missing manifest check");
assert!(check_names.iter().any(|n| n.contains("schema_version is supported")),
    "missing schema_version check");
assert!(check_names.iter().any(|n| n.contains("checksums.sha256 well-formed")),
    "missing checksums check");
assert!(check_names.iter().any(|n| n.contains("exists")),
    "missing tarball-exists check");
assert!(check_names.iter().any(|n| n.contains("SHA256 checksum matches")),
    "missing sha256 check");
assert!(check_names.iter().any(|n| n.contains("File size matches manifest")),
    "missing size check");
```

Note: The test requirement VRFY-03 says "All 9 existing verify tests pass **without modification**." Adding assertions to the test does not violate this — it means the test body can be extended, but existing assertion lines and test function signatures must stay. Confirm with VRFY-03 intent: "without modification" means no test may be weakened or deleted. Adding stronger assertions is acceptable.

### Pattern 3: Check Function Extraction (VRFY-01, VRFY-02)

**What:** Extract each of the six check blocks in `run_verify()` into a private function. The orchestrator becomes a 20–30 line function that calls them in sequence, short-circuiting on failure.

**The six check blocks and their current line ranges (current verify.rs):**

| Check | Current Lines | Check Result Name | Return Shape |
|-------|--------------|-------------------|--------------|
| Check 1: manifest.json parse | 65–103 | `"manifest.json schema valid"` | `(CheckResult, Option<BundleManifest>)` — must carry manifest out |
| Check 2: schema_version | 106–124 | `"schema_version is supported"` | `CheckResult` only — manifest already loaded |
| Check 3: checksums.sha256 | 126–169 | `"checksums.sha256 well-formed"` | `(CheckResult, Option<ChecksumLine>)` — carry checksum out; after Phase 8 `ChecksumLine` is available |
| Check 4: tarball exists | 173–193 | `"{manifest.image.file} exists"` | `(CheckResult, Option<u64>)` — carry tarball_size out |
| Check 5: SHA256 match | 195–255 | `"SHA256 checksum matches"` | `CheckResult` only — consumes hash, checksum_hash, manifest_digest_hex |
| Check 6: file size match | 257–284 | `"File size matches manifest"` | `CheckResult` only |

**Function signatures (recommended):**

```rust
// Source: direct analysis of verify.rs:65–285
fn check_manifest(
    bundle_dir: &Path,
) -> Result<(CheckResult, Option<BundleManifest>), BundleError> {
    // Lines 65–103
    // Returns Err only for IO failures (fatal)
    // Returns Ok((failed_check, None)) for logical failure
    // Returns Ok((passed_check, Some(manifest))) for success
}

fn check_schema_version(manifest: &BundleManifest) -> CheckResult {
    // Lines 106–124
    // Pure function — no IO, no error possible
    // Returns CheckResult with passed=true or passed=false
}

fn check_checksums_file(
    bundle_dir: &Path,
) -> Result<(CheckResult, Option<ChecksumLine>), BundleError> {
    // Lines 126–169
    // After Phase 8: uses ChecksumLine::parse() internally
    // Returns Ok((failed_check, None)) when file missing or malformed
    // Returns Ok((passed_check, Some(cs_line))) on success
}

fn check_tarball_exists(
    bundle_dir: &Path,
    manifest: &BundleManifest,
) -> Result<(CheckResult, Option<u64>), BundleError> {
    // Lines 173–193
    // Returns Ok((failed_check, None)) when tarball missing
    // Returns Ok((passed_check, Some(tarball_size))) on success
}

fn check_sha256(
    tarball_path: &Path,
    expected_hash: &str,
    manifest_digest_hex: &str,
) -> Result<CheckResult, BundleError> {
    // Lines 195–255
    // Returns Err for IO failure computing hash (fatal)
    // Returns Ok(CheckResult) for pass or fail
}

fn check_file_size(tarball_size: u64, manifest: &BundleManifest) -> CheckResult {
    // Lines 257–284
    // Pure function
}
```

**Orchestrator pattern:**

```rust
pub fn run_verify(bundle_dir: &Path) -> Result<VerifyResult, BundleError> {
    if !bundle_dir.exists() {
        return Err(BundleError::ManifestNotFound(
            bundle_dir.display().to_string(),
        ));
    }

    let mut checks: Vec<CheckResult> = Vec::new();

    // Check 1
    let (c1, manifest_opt) = check_manifest(bundle_dir)?;
    let passed = c1.passed;
    checks.push(c1);
    let manifest = match manifest_opt {
        Some(m) => m,
        None => return Ok(VerifyResult { valid: false, checks, manifest: None }),
    };
    // Note: check_manifest returns passed=false in manifest_opt=None paths already

    // Check 2
    let c2 = check_schema_version(&manifest);
    let passed = c2.passed;
    checks.push(c2);
    if !passed {
        return Ok(VerifyResult { valid: false, checks, manifest: Some(manifest) });
    }

    // Check 3
    let (c3, cs_line_opt) = check_checksums_file(bundle_dir)?;
    let passed = c3.passed;
    checks.push(c3);
    let cs_line = match cs_line_opt {
        Some(cs) => cs,
        None => return Ok(VerifyResult { valid: false, checks, manifest: Some(manifest) }),
    };

    // Check 4
    let tarball_path = bundle_dir.join(&manifest.image.file);
    let (c4, size_opt) = check_tarball_exists(bundle_dir, &manifest)?;
    let passed = c4.passed;
    checks.push(c4);
    let tarball_size = match size_opt {
        Some(s) => s,
        None => return Ok(VerifyResult { valid: false, checks, manifest: Some(manifest) }),
    };

    // Check 5
    let manifest_digest_hex = manifest.image.digest
        .strip_prefix("sha256:").unwrap_or(&manifest.image.digest);
    let c5 = check_sha256(&tarball_path, &cs_line.hex, manifest_digest_hex)?;
    let passed = c5.passed;
    checks.push(c5);
    if !passed {
        return Ok(VerifyResult { valid: false, checks, manifest: Some(manifest) });
    }

    // Check 6
    let c6 = check_file_size(tarball_size, &manifest);
    let passed = c6.passed;
    checks.push(c6);
    if !passed {
        return Ok(VerifyResult { valid: false, checks, manifest: Some(manifest) });
    }

    Ok(VerifyResult { valid: true, checks, manifest: Some(manifest) })
}
```

### Pattern 4: CKSM-03 Filename Cross-Reference

**What:** The `_checksum_filename` already exists at verify.rs:171 (suppressed with `_`). After Phase 8 wires in `ChecksumLine`, the struct's `filename` field is the equivalent. After `check_checksums_file` extraction, `cs_line.filename` is available in the orchestrator. One equality check added to Check 3 (or as an inline guard in the orchestrator after Check 3) completes CKSM-03.

**Two valid implementation positions:**

Option A — Inside `check_checksums_file` (pass `manifest.image.file` as parameter):
```rust
fn check_checksums_file(
    bundle_dir: &Path,
    expected_filename: &str,   // manifest.image.file
) -> Result<(CheckResult, Option<ChecksumLine>), BundleError>
```
Then after parsing `cs_line`, add:
```rust
if cs_line.filename != expected_filename {
    // Return failed CheckResult with mismatch detail
}
```

Option B — In the orchestrator after Check 3 passes (no signature change to check_checksums_file):
```rust
// After cs_line extracted from Check 3:
if cs_line.filename != manifest.image.file {
    checks.push(CheckResult {
        name: "checksums.sha256 well-formed".to_string(),
        passed: false,
        detail: format!(
            "filename mismatch: checksums.sha256 lists '{}', manifest.image.file is '{}'",
            cs_line.filename, manifest.image.file
        ),
    });
    return Ok(VerifyResult { valid: false, checks, manifest: Some(manifest) });
}
```

**Recommendation:** Option B is safer for VRFY-03 (no test modification needed). The 9 existing tests all use `make_valid_bundle()` which writes a checksum line matching `manifest.image.file`, so the cross-reference check passes silently in all existing tests. A new test for the mismatch case is a P2 addition, not required by VRFY-03.

**Note on Check 3 `checks.len()` after CKSM-03:** If the filename mismatch is surfaced as a separate failed check (not reusing Check 3's CheckResult), `checks.len()` for that path would be 3, not 4 — since Checks 4–6 are never reached. The `checks.len() == 6` assertion only fires on the all-passing path in `test_verify_valid_bundle`. Since Option B above reuses Check 3's slot, the count on the happy path remains 6.

### Anti-Patterns to Avoid

- **Extracting `check_manifest` to return `Option<BundleManifest>` via a tuple with complex early returns buried inside:** Keep the function contract clear — return `Err` only for fatal IO, return `Ok((check, None))` for logical failure, return `Ok((check, Some(m)))` for success.
- **Running all 6 checks unconditionally and then filtering:** The original monolithic function has explicit early-return semantics. A check that fails due to a missing file must not execute downstream checks that depend on that file. Preserve early returns.
- **Merging Check 1 and Check 2 into one "manifest valid" check:** They are distinct check names in existing tests. `test_verify_bad_schema_version` asserts `c.name.contains("schema_version")` — that only passes if Check 2 is a separate `CheckResult`.
- **Using `split_whitespace` in `check_checksums_file`:** After Phase 8, `ChecksumLine::parse` already uses `splitn(2, "  ")`. Do not reintroduce whitespace-agnostic parsing.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Byte formatting | New `format_bytes` in verify.rs | `crate::format::format_bytes` (Phase 8) | Three divergent copies are the tech debt being eliminated |
| Checksum line parsing | Inline `splitn` again | `crate::checksum::ChecksumLine::parse` (Phase 8) | struct was built in Phase 8 specifically to be used here |
| Image ref tag extraction | Inline `rfind(':')` again in create.rs | `crate::image_ref::ImageRef::parse` (Phase 8) | same reason — struct exists |
| Trait-based check pipeline | `VerificationCheck` trait | Free functions + loop | Over-engineering; 6 checks, no plugins, no external consumers |
| Parallel check execution | `rayon` | Sequential in-order | I/O-bound on same file; early-return semantics are a safety property |

## Common Pitfalls

### Pitfall 1: Check Count Assertion Fails After Extraction

**What goes wrong:** `test_verify_valid_bundle` at verify.rs:415 asserts `result.checks.len() == 6`. If extraction accidentally merges two checks (e.g., Check 1 and Check 2 into a single "manifest valid" function), the count drops to 5, the count assertion fails, and the build is broken. Worse: if two checks are accidentally split (unlikely but possible), the count becomes 7, and the assertion also fails.

**Why it happens:** Extraction of a 230-line function is mechanical but the inner early-return logic interleaves the `checks.push(...)` calls with the control flow. A developer might consolidate two logically related pushes.

**How to avoid:** Add named-check assertions to `test_verify_valid_bundle` *before starting any extraction*. Each extracted function must push exactly one `CheckResult` to the caller's `checks` vec. Count each `checks.push(...)` in the original function — there are exactly 6 (lines 68–72, 83–88/91–95, 160–167, 189–193, 251–255/220–227/236–243, 274–278).

**Warning signs:** `result.checks.len() != 6` in test output; any check function that pushes more than one `CheckResult`.

### Pitfall 2: Early-Return Semantics Lost in Orchestrator

**What goes wrong:** The orchestrator uses a loop or collects all results before checking failures, instead of returning early when a check fails. This causes Check 5 (SHA256) to run even when Check 3 (checksums.sha256 exists) failed — computing a hash on a file when the checksum file is absent is not only wasteful but semantically incorrect.

**Why it happens:** Loop-based composition feels idiomatic. But the verify checks have hard dependencies: you cannot compare hashes without having parsed the hash from the checksum file.

**How to avoid:** Each intermediate extraction result must be checked before proceeding. The orchestrator must use explicit early returns after each check that produces a value needed by subsequent checks (checks 1, 3, 4).

**Warning signs:** SHA256 computation occurring in test cases where `checksums.sha256` is absent; `result.checks.len()` being higher than expected in early-failure paths.

### Pitfall 3: `manifest_opt` vs `manifest` in VerifyResult

**What goes wrong:** The current `run_verify()` carries both `manifest` (the loaded struct) and `manifest_opt = Some(manifest.clone())` for passing into `VerifyResult.manifest`. After extraction, losing track of which variable to use in early returns can cause `manifest: None` in cases where it should be `Some`, or vice versa.

**Current pattern (verify.rs:104, 122, 137, etc.):** The manifest is cloned into `manifest_opt` and individual early returns either pass `manifest: None` (before manifest loaded) or `manifest: manifest_opt` (after manifest loaded).

**How to avoid:** In the new orchestrator, consume `manifest` from `check_manifest` and pass it to `VerifyResult` directly. Do not double-clone. After Check 1 succeeds and `manifest` is in scope, all subsequent early returns use `manifest: Some(manifest)`.

**Warning signs:** `test_format_verify_human_valid` — the human formatter accesses `result.manifest` and outputs image reference/version. If `manifest` is accidentally `None` in a success path, this assertion fails.

### Pitfall 4: CKSM-03 Check Name Conflicts With Check 3

**What goes wrong:** If the filename mismatch is surfaced as a second failed `CheckResult` with name `"checksums.sha256 well-formed"`, the checks vector now has two entries with the same name. `test_verify_missing_checksums_file` asserts `failed.iter().any(|c| c.name.contains("checksums"))` — this still passes (it uses `any`), but the duplicate name is confusing and inconsistent with the one-check-per-function contract.

**How to avoid:** Use Option B from Pattern 4 above: re-use Check 3's slot by returning an early failure from the orchestrator before pushing Check 3's success result. Or use a distinct name like `"checksums.sha256 filename matches manifest"` for the cross-reference check as a separate 7th check — but this would break `checks.len() == 6`.

**Recommended approach:** Return an early failure inline in the orchestrator, reusing Check 3 position, as shown in Option B. This keeps the 6-check contract intact.

### Pitfall 5: format_bytes TiB Regression

**What goes wrong:** `verify.rs` local `format_bytes` (lines 34–48) has no TiB tier. When switching to `crate::format::format_bytes`, bundles near the 1 TiB size boundary suddenly display "1024.0 GiB" vs "1.0 TiB" (or correctly show TiB for the first time). Either way it is a visible output change.

**Why it matters for Phase 9:** This is only a problem if `format.rs` was NOT built with TiB support in Phase 8. If Phase 8 used `inspect.rs::format_size` as the canonical implementation (with TiB), the switch is strictly an improvement. Verify before deleting local copies.

**Warning signs:** `test_format_size` in `inspect.rs` calls the shared function after the switchover — if TiB is missing from `format.rs`, this test fails with `"1024.0 GiB"` instead of `"1.0 TiB"`.

## Code Examples

Verified from direct source audit of verify.rs:

### The Six Check Names (Exact Strings — Test Sensitive)

```
// Source: direct audit of verify.rs
"manifest.json schema valid"     // Check 1 — verify.rs:69, 84
"schema_version is supported"    // Check 2 — verify.rs:109, 115
"checksums.sha256 well-formed"   // Check 3 — verify.rs:130, 161
"{manifest.image.file} exists"   // Check 4 — verify.rs:177, 190 (dynamic, uses file name)
"SHA256 checksum matches"        // Check 5 — verify.rs:201, 221, 237, 252
"File size matches manifest"     // Check 6 — verify.rs:259, 274
```

Tests that match on these names:
- `test_verify_valid_bundle:416` — `result.checks.iter().all(|c| c.passed)`
- `test_verify_corrupted_checksum:443` — `.any(|c| c.name.contains("SHA256"))`
- `test_verify_missing_tarball:463` — `.any(|c| c.name.contains("exists"))`
- `test_verify_bad_schema_version:499` — `.any(|c| c.name.contains("schema_version"))`
- `test_verify_size_mismatch:536` — `.any(|c| c.name.contains("size") || c.name.contains("Size"))`
- `test_verify_missing_checksums_file:556` — `.any(|c| c.name.contains("checksums"))`
- `test_verify_malformed_manifest:577` — `.any(|c| c.name.contains("manifest"))`

All these use `.contains()` substring matching, so exact name changes are safe as long as the substring is preserved.

### ChecksumLine Integration (After Phase 8)

```rust
// Source: ARCHITECTURE.md Pattern 2 / verify.rs:140-168 (current inline parsing)
// After Phase 8, check_checksums_file uses:
use crate::checksum::ChecksumLine;

fn check_checksums_file(bundle_dir: &Path) -> Result<(CheckResult, Option<ChecksumLine>), BundleError> {
    let checksums_path = bundle_dir.join("checksums.sha256");
    if !checksums_path.exists() {
        return Ok((CheckResult {
            name: "checksums.sha256 well-formed".to_string(),
            passed: false,
            detail: "checksums.sha256 not found".to_string(),
        }, None));
    }
    let raw = fs::read_to_string(&checksums_path).map_err(BundleError::Io)?;
    let line = raw.lines().next().unwrap_or("").to_string();
    match ChecksumLine::parse(&line) {
        Ok(cs) => {
            Ok((CheckResult {
                name: "checksums.sha256 well-formed".to_string(),
                passed: true,
                detail: format!("{} file(s) listed",
                    raw.lines().filter(|l| !l.is_empty()).count()),
            }, Some(cs)))
        }
        Err(_) => {
            Ok((CheckResult {
                name: "checksums.sha256 well-formed".to_string(),
                passed: false,
                detail: format!("malformed checksums.sha256: {:?}", line),
            }, None))
        }
    }
}
```

### CKSM-03 Cross-Reference (Inline in Orchestrator)

```rust
// Source: verify.rs:171 — _checksum_filename already extracted, just suppressed
// After cs_line is returned from check_checksums_file, before Check 4:
if cs_line.filename != manifest.image.file {
    checks.push(CheckResult {
        name: "checksums.sha256 well-formed".to_string(),
        passed: false,
        detail: format!(
            "filename mismatch: checksums.sha256 lists '{}', manifest expects '{}'",
            cs_line.filename, manifest.image.file
        ),
    });
    return Ok(VerifyResult { valid: false, checks, manifest: Some(manifest) });
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Monolithic 230-line `run_verify()` | Six `check_*` functions + ~20-line orchestrator | Phase 9 | Adding Check 7 becomes: write one function, add one line in orchestrator |
| Three divergent `format_bytes`/`format_size` | Single `crate::format::format_bytes` with TiB | Phase 8 (consumed in Phase 9) | All commands show consistent size formatting |
| `_checksum_filename` extracted but unused | `cs_line.filename` cross-referenced against `manifest.image.file` | Phase 9 (CKSM-03) | Detects manifest/checksum filename mismatch (tamper indicator) |

## Open Questions

1. **Phase 8 completion state**
   - What we know: Phase 8 is not yet planned or executed (phases directory empty for both 08 and 09)
   - What's unclear: Which exact form `ChecksumLine` takes — specifically whether `parse` returns `Result<Self, BundleError>` or uses a different error type
   - Recommendation: Plan Phase 9 assuming `ChecksumLine { hex: String, filename: String }` with `parse(line: &str) -> Result<Self, BundleError>` as documented in ARCHITECTURE.md. Phase 9 planner should add a precondition task: "verify Phase 8 modules exist and compile before beginning Phase 9 work."

2. **VRFY-03 "without modification" — does it permit adding assertions?**
   - What we know: The 9 test function signatures and all existing assertion lines must remain. The requirement language is "pass without modification."
   - What's unclear: Whether adding named-check assertions to `test_verify_valid_bundle` counts as "modification"
   - Recommendation: Interpret "without modification" conservatively — do not change any existing assertion or test signature. Instead, add the named-check assertions as an additional `#[test]` function (`test_verify_check_names`) that runs after the decomposition. This keeps existing tests byte-for-byte identical while providing the named-assertion safety net.

3. **Check 5 error handling — `compute_sha256` returns `Err` for IO failures**
   - What we know: The current monolithic function handles `compute_sha256` errors by pushing a failed `CheckResult` and returning `Ok(VerifyResult { valid: false })` — not `Err`. This is a local logical failure, not a fatal IO error.
   - What's unclear: When extracting `check_sha256`, should it return `Result<CheckResult, BundleError>` (propagating IO errors as fatal) or `CheckResult` (absorbing IO errors into a failed check)?
   - Recommendation: Follow the current monolithic behavior — return `Result<CheckResult, BundleError>` where `Err` is reserved for truly fatal IO failure (disk read error), but hash computation errors on accessible files are surfaced as a failed `CheckResult`. The existing test `test_verify_corrupted_checksum` verifies this: a bad hash returns `Ok(VerifyResult { valid: false })`, not `Err`.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Rust built-in test (`cargo test`) |
| Config file | none — standard `cargo test` |
| Quick run command | `cargo test -p bundle-cli --lib verify` |
| Full suite command | `cargo test -p bundle-cli` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VRFY-01 | 6 `check_*` functions exist, each returns `CheckResult` | unit | `cargo test -p bundle-cli --lib verify` | Existing tests cover behavior; structure verified by compiler |
| VRFY-02 | `run_verify()` body ~30 lines; composes checks in loop | unit (implicit) | `cargo test -p bundle-cli --lib verify` | ✅ 9 existing test cases |
| VRFY-03 | All 9 verify tests pass without modification | unit | `cargo test -p bundle-cli --lib verify` | ✅ verify.rs:406–615 |
| CKSM-03 | Filename mismatch detected as verify failure | unit | `cargo test -p bundle-cli --lib verify::tests::test_verify_checksum_filename_mismatch` | Wave 0 gap — needs new test |

### Sampling Rate

- **Per task commit:** `cargo test -p bundle-cli --lib verify`
- **Per wave merge:** `cargo test -p bundle-cli`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `verify.rs::tests::test_verify_checksum_filename_mismatch` — covers CKSM-03; asserts that a bundle where `checksums.sha256` lists a filename different from `manifest.image.file` fails verification with a checksums-related check failure
- [ ] `verify.rs::tests::test_verify_check_names` — covers VRFY-01 regression guard; asserts all 6 named checks are present by name in a valid bundle result (see Pattern 2 above)

*(All other verify tests exist; format module tests already live in format.rs if Phase 8 created them)*

## Sources

### Primary (HIGH confidence)

- Direct source audit of `crates/bundle-cli/src/verify.rs` (617 lines) — 2026-03-13
- Direct source audit of `crates/bundle-cli/src/create.rs` (251 lines) — 2026-03-13
- Direct source audit of `crates/bundle-cli/src/inspect.rs` (254 lines) — 2026-03-13
- Direct source audit of `crates/bundle-cli/src/error.rs` (101 lines) — 2026-03-13
- Direct source audit of `crates/bundle-cli/src/main.rs` (117 lines) — 2026-03-13
- `.planning/research/ARCHITECTURE.md` — architecture build order and check function signatures
- `.planning/research/PITFALLS.md` — Pitfall 4 (check count), Pitfall 5 (double-space format)
- `.planning/REQUIREMENTS.md` — VRFY-01, VRFY-02, VRFY-03, CKSM-03 requirement text

### Secondary (MEDIUM confidence)

- `.planning/research/SUMMARY.md` — Phase 7 roadmap description (run_verify decomposition)
- `.planning/research/FEATURES.md` — feature prioritization, ChecksumLine cross-reference description
- [Rust Book ch12-03](https://doc.rust-lang.org/book/ch12-03-improving-error-handling-and-modularity.html) — extract-function refactoring pattern

### Tertiary (LOW confidence)

- None — all claims are grounded in direct source analysis.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; direct Cargo.toml audit confirms existing versions
- Architecture: HIGH — all line numbers verified against live source files
- Pitfalls: HIGH — pitfalls derived from direct analysis of test assertions and control flow
- CKSM-03 implementation: HIGH — `_checksum_filename` is already parsed at verify.rs:171; the implementation is one equality check

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable codebase; no external library research)
