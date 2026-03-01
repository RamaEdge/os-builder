---
phase: 06-verify-inspect
plan: 01
subsystem: bundle-cli/verify
tags: [rust, cli, sha256, integrity-verification, tdd]
dependency_graph:
  requires: [04-foundation, 05-create-command]
  provides: [verify-subcommand, run_verify, format_verify_human, format_verify_json]
  affects: [crates/bundle-cli/src/verify.rs, crates/bundle-cli/src/main.rs]
tech_stack:
  added: []
  patterns: [streaming-sha256-verify, check-result-accumulator, exit-code-dispatch]
key_files:
  created:
    - crates/bundle-cli/src/verify.rs
  modified:
    - crates/bundle-cli/src/main.rs
decisions:
  - "run_verify returns Err only for missing dir (exit 2); Ok(invalid) for logical failures (exit 1)"
  - "VerifyResult accumulates all checks so human/JSON formatters share one source of truth"
  - "Checks abort early on manifest parse/schema failure since later checks depend on a valid manifest"
  - "format_verify_human uses [OK] / [FAIL] tags matching design doc §3.2 exactly"
metrics:
  duration: ~2.5 min
  completed: "2026-03-01T18:21:32Z"
  tasks_completed: 2
  files_changed: 2
---

# Phase 6 Plan 1: Verify Subcommand Implementation Summary

**One-liner:** Bundle integrity verification with 6 checks (manifest, schema, checksums, tarball, SHA256, size) — correct exit codes 0/1/2 and human/JSON output.

---

## What Was Built

The `edgeworks-bundle verify <bundle-dir>` subcommand performs 6 sequential integrity checks against a bundle directory, reporting per-check [OK]/[FAIL] status in both human-readable and JSON formats.

### Files Created/Modified

**`crates/bundle-cli/src/verify.rs`** — Full implementation replacing the `todo!()` stub:

- `CheckResult` struct: name, passed bool, detail string
- `VerifyResult` struct: valid bool, checks Vec, optional manifest reference
- `run_verify(bundle_dir: &Path) -> Result<VerifyResult, BundleError>` implementing all 6 checks:
  1. manifest.json exists and parses as BundleManifest
  2. schema_version == "1.0"
  3. checksums.sha256 exists and has valid `<64-hex>  <filename>` format
  4. OCI tarball file referenced in manifest.image.file exists
  5. SHA256 of tarball matches checksums.sha256 and manifest.image.digest
  6. Actual file size matches manifest.image.size_bytes
- `format_verify_human()` — [OK] / [FAIL] per-check display + summary block with Image/Version/Created
- `format_verify_json()` — `{"status":"ok"|"failed","directory":"...","checks":[...],"errors":[...]}` structure
- 11 unit tests covering all 8 required scenarios plus formatter tests

**`crates/bundle-cli/src/main.rs`** — Verify arm updated from `todo!()` stub:

- Calls `verify::run_verify()` with proper error->exit(2) handling
- Dispatches to `format_verify_json` or `format_verify_human` based on `--json` flag
- `process::exit(0)` for valid, `process::exit(1)` for failed checks, `process::exit(2)` for missing dir

---

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Implement verify.rs with 6 checks + 11 tests | 5d7f4e6 | Done |
| 2 | Wire verify subcommand in main.rs | 6cac1e5 | Done |

---

## Test Results

```
running 11 tests
test verify::tests::test_verify_valid_bundle ... ok
test verify::tests::test_verify_nonexistent_path ... ok
test verify::tests::test_verify_corrupted_checksum ... ok
test verify::tests::test_verify_missing_tarball ... ok
test verify::tests::test_verify_bad_schema_version ... ok
test verify::tests::test_verify_size_mismatch ... ok
test verify::tests::test_verify_missing_checksums_file ... ok
test verify::tests::test_verify_malformed_manifest ... ok
test verify::tests::test_format_verify_human_valid ... ok
test verify::tests::test_format_verify_json_valid ... ok
test verify::tests::test_format_verify_json_failed ... ok

test result: ok. 11 passed; 0 failed; 0 ignored
```

---

## Decisions Made

1. **Early-abort on manifest/schema failures** — Checks 3-6 depend on a parsed manifest. If manifest parse or schema check fails, the function returns immediately with valid=false rather than attempting remaining checks with incomplete data.

2. **Dual hash comparison in Check 5** — The SHA256 check validates against both `checksums.sha256` content AND `manifest.image.digest`. This catches inconsistencies between the two sources.

3. **Error vs Ok(invalid) distinction** — `run_verify` returns `Err` only when the bundle directory itself doesn't exist (maps to exit 2). All logical verification failures return `Ok(VerifyResult { valid: false, … })` (maps to exit 1). This distinction was critical for correct CLI exit code mapping.

4. **Formatter format** — `[OK]` and `[FAIL]` are used as fixed-width tags (`[OK]  ` with trailing spaces for alignment) matching the design doc's intent.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] main.rs called verify::run() which no longer existed**
- **Found during:** Task 1 test compilation
- **Issue:** The stub function was named `run()`. The plan spec named the production function `run_verify()`. main.rs still referenced the old name.
- **Fix:** Updated the Verify match arm in main.rs to call `run_verify()` with full exit-code dispatch. This effectively combined Task 1 compilation fix + Task 2 implementation into one coherent change.
- **Files modified:** crates/bundle-cli/src/main.rs
- **Commit:** 5d7f4e6 (then formalized in 6cac1e5)

**2. [Rule 1 - Bug] format_verify_human produced `[OK  ]` not `[OK]`**
- **Found during:** Task 1 test `test_format_verify_human_valid`
- **Issue:** `format!("[{:<4}]", "OK")` produces `[OK  ]`; the test asserted `contains("[OK]")`.
- **Fix:** Changed to explicit `"[OK]  "` and `"[FAIL]"` string literals for alignment.
- **Files modified:** crates/bundle-cli/src/verify.rs
- **Commit:** 5d7f4e6

**3. [Rule 1 - Bug] Unused import `std::io::Write` in test module**
- **Found during:** Task 1 compilation
- **Issue:** Imported but never used, causing a compiler warning.
- **Fix:** Removed the unused import.
- **Files modified:** crates/bundle-cli/src/verify.rs
- **Commit:** 5d7f4e6
