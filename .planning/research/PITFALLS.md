# Pitfalls Research

**Domain:** Rust CLI refactoring — tech debt elimination in a working bundle tool
**Researched:** 2026-03-13
**Confidence:** HIGH (based on direct codebase analysis) / MEDIUM (general patterns from Rust ecosystem)

---

## Critical Pitfalls

### Pitfall 1: Extracting `format.rs` Changes Output for Large Files

**What goes wrong:**
`create.rs` and `verify.rs` both have `format_bytes()` that tops out at GiB. `inspect.rs` has `format_size()` that adds TiB support. When you consolidate into a single `format.rs`, you must choose one behavior. Picking the richer `format_size()` signature means existing bundles near the TiB boundary suddenly display differently. Picking the simpler `format_bytes()` drops TiB support that `inspect` currently provides. Either choice is a silent output-format change.

**Why it happens:**
The three functions are not identical — they share structure but differ in the TiB tier. Developers see "three copies of the same thing" and merge them without auditing the behavioral delta.

**How to avoid:**
1. Write the unified `format_bytes()` with TiB support (the superset of all three).
2. Run the existing `test_format_size` test suite in `inspect.rs` — it already covers TiB (see `inspect.rs:240`). That test must still pass after the merge.
3. For `create.rs` and `verify.rs` callers, the output changes only for >1 TiB inputs, which is outside current bundle sizes. Document this explicitly.
4. Do NOT silently rename the public function `format_size` to `format_bytes` if `inspect.rs` exports `format_size` — update the call site in `inspect.rs` while keeping the tests green.

**Warning signs:**
- `test_format_size` in `inspect.rs` starts failing.
- Human-readable output changes in CI snapshots for any size in the GiB range.
- The word "TiB" stops appearing anywhere in the format module.

**Phase to address:** Phase that extracts `format.rs` (likely Phase 1 of the tech debt milestone).

---

### Pitfall 2: Error Propagation Changes Exit Codes in `verify` and `inspect`

**What goes wrong:**
`main.rs` has a tightly defined exit-code contract:
- exit 0 = success
- exit 1 = logical failure (invalid bundle, manifest parse error)
- exit 2 = path not found / directory inaccessible

This contract is enforced by explicit `match` arms on error variants (see `main.rs:104-108`). If refactoring changes which `BundleError` variant is returned from `run_verify()` or `run_inspect()` in an error path, the wrong exit code is emitted. Scripts that drive `edgeworks-bundle verify` in CI pipelines distinguish exit 1 vs exit 2 to differentiate "bad bundle" from "missing path." Breaking this silently breaks downstream automation.

**Why it happens:**
When converting an inline `unwrap_or_else(|_| ...)` to a propagated `?`, the implicit error conversion via `From` may produce a different `BundleError` variant than the original fallback logic. For example, replacing a JSON fallback with `?` on a `serde_json::Error` produces `BundleError::ManifestInvalid`, which exits 1 — but if the original fallback was masking a file-not-found `io::Error`, the real error is `BundleError::Io`, which exits 1 via the catch-all in `main.rs:114-116`. Exit code is the same here, but intent diverges and future changes to the match arms will behave unexpectedly.

**How to avoid:**
1. Before changing any error path, write the exit code contract as an explicit test: run the CLI on a known-bad input, assert the exit code numerically.
2. When replacing `unwrap_or_else(|_| "{}")` with `?` propagation, trace through `main.rs` to confirm the resulting `BundleError` variant hits the expected match arm.
3. Specifically check `verify.rs:351` — it uses `unwrap_or_else(|_| "{}".to_string())` inside `format_verify_json`. This function is called from `main.rs` after `run_verify()` already succeeded. Propagating this error would require changing `format_verify_json`'s return type from `String` to `Result<String, BundleError>`, which requires matching in `main.rs`. Do this deliberately, not as a side effect.

**Warning signs:**
- Any change to a function's return type from `String` to `Result<String, _>`.
- New `?` operators appearing in formatting functions (format_verify_json, format_inspect_json).
- Integration tests that check `.failure()` without checking the specific exit code number.

**Phase to address:** Phase that replaces JSON fallback patterns (likely Phase 2).

---

### Pitfall 3: Image Reference Validation Rejects Previously-Valid Inputs

**What goes wrong:**
The planned fix adds explicit validation of image reference format (alphanumeric, colons, slashes, underscores, hyphens, dots only). However, real OCI image references can contain characters beyond this set. SHA digest references (`registry/repo@sha256:abc123`), port numbers in registries (`localhost:5000/repo:tag`), and nested repository paths (`registry/org/suborg/image:tag`) are all valid. Adding a regex that is too narrow will reject legitimate production images.

**Why it happens:**
Developers write validation against the happy path they know (`registry.example.com/repo:tag`), not against the full OCI image reference specification. The existing integration test `test_create_invalid_image_ref` only covers the missing-tag case — it does not test any of these valid-but-complex forms, so overly strict validation passes the test suite and ships.

**How to avoid:**
1. Do not hand-roll a character allowlist regex. Use the existing OCI image name validation rules from the OCI Distribution Specification as the authoritative definition.
2. The minimum safe validation is: reject empty string, reject references with no `:` separator (tag required, as today), reject embedded whitespace and shell metacharacters (`$`, `` ` ``, `(`, `)`, `&`, `;`, `|`, `<`, `>`, `\n`). These are the characters that could be misinterpreted by shells — not a length limit or alphanumeric restriction.
3. Add parameterized tests for: bare image name, digest reference (`@sha256:`), registry with port, deeply nested path, image with dots in repo name.
4. If the `oci-spec` crate is introduced, verify its validation accepts all the above forms before replacing the current check.

**Warning signs:**
- New validation that uses `chars().all(|c| c.is_alphanumeric() || ...)` — this pattern is almost certainly too narrow.
- No test for `registry:5000/org/repo:tag` passing validation.
- Any test that accepts a valid image but receives a validation error in CI against a real registry.

**Phase to address:** Phase that adds image reference validation (likely Phase 3).

---

### Pitfall 4: Decomposing `run_verify()` Changes the Check Count Test Assertion

**What goes wrong:**
`verify.rs` test `test_verify_valid_bundle` asserts `result.checks.len() == 6` (line 416). This is a brittle assertion tied to the internal structure of the monolithic `run_verify()`. When the function is decomposed into composable check functions, new checks may be added (or existing ones split) during the restructuring — even if no intentional behavior change is made — causing this assertion to fail or, worse, silently pass with a different number of checks that happen to equal 6.

**Why it happens:**
The count assertion was written to verify the monolithic function's known internals. It becomes incorrect the moment the decomposition changes check granularity — for example, if "checksums.sha256 well-formed" and "SHA256 checksum matches" are merged into one check function, the count drops to 5.

**How to avoid:**
1. Before refactoring, document all 6 check names as named constants or an enum. The count test should check for specific check names, not just the count.
2. Replace `assert_eq!(result.checks.len(), 6)` with `assert!(result.checks.iter().any(|c| c.name == EXPECTED_CHECK_NAME))` for each of the 6 named checks. This survives count changes.
3. The composable check architecture should keep the same 6 logical checks. Each extracted function returns exactly one `CheckResult`. Do not merge checks during extraction.
4. The early-return behavior in the current monolithic function is a semantic contract — if check N fails, checks N+1..6 are not run (and not present in the result). Preserve this behavior in the composed version by returning early from the composition loop, not by always running all checks.

**Warning signs:**
- `result.checks.len()` assertion starts failing.
- Any test that ran previously with 6 checks now has fewer or more.
- The word "early return" disappearing from code comments in the new check composition loop.
- `VerifyResult.valid` returns true when not all checks have been evaluated.

**Phase to address:** Phase that decomposes `run_verify()` (likely Phase 4).

---

### Pitfall 5: `ChecksumLine` Struct Changes the Double-Space Format Contract

**What goes wrong:**
The current parsing uses `splitn(2, "  ")` — two ASCII spaces — which is the GNU coreutils `sha256sum` format. A `ChecksumLine` struct with a cleaner API might use `split_whitespace()` or `split(' ')` internally, which would silently accept single-space-separated checksum files. This is not a correctness disaster — it's a loosening of the format contract. But existing bundles' `checksums.sha256` files use the double-space format, and future code that writes new checksum lines must continue writing double-space. If the parser accepts single-space but the writer still writes double-space, files become inconsistent without any error.

**Why it happens:**
Developers see `splitn(2, "  ")` as "split on whitespace" and reach for the more idiomatic `split_whitespace()`. The test `test_verify_missing_checksums_file` only tests file-not-found, not format edge cases — so single-space acceptance goes untested.

**How to avoid:**
1. `ChecksumLine::parse()` must use the two-space literal `"  "` as the delimiter, not whitespace-agnostic splitting.
2. Add a test for `ChecksumLine::parse("abc...  filename")` passing and `ChecksumLine::parse("abc... filename")` (single space) failing.
3. The struct's `Display` or serialization must round-trip through the same two-space format to ensure writer and parser stay aligned.
4. Document the GNU coreutils two-space convention as a comment on the struct.

**Warning signs:**
- `split_whitespace()` or `split(' ')` anywhere in the checksum parsing path.
- No failing test for single-space checksum lines.
- Missing the "two spaces" contract in the struct's doc comment.

**Phase to address:** Phase that replaces fragile checksum parsing (likely Phase 5).

---

### Pitfall 6: Image Version Extraction Struct Loosens or Tightens Tag Semantics

**What goes wrong:**
The current tag extraction uses `rfind(':')` — the rightmost colon — which correctly handles `registry:5000/repo:tag` by finding the tag colon, not the port colon. If the replacement parsing struct uses `find(':')` (the first colon) or a naive split on `:`, it will extract `5000/repo` as the "tag" from `registry:5000/repo:tag`, producing a version like `5000/repo` and a tarball named `edge-os-5000/repo.oci.tar` — a path with a slash that breaks filesystem writes.

**Why it happens:**
`rfind` is easy to overlook when refactoring. Unit tests typically use simple `registry/repo:tag` references without ports, so the edge case is invisible.

**How to avoid:**
1. The replacement logic, whatever form it takes (struct or library), must handle port-containing registry references. Write a test with `registry:5000/repo:1.2.0` and assert `version == "1.2.0"`.
2. If the `oci-spec` crate is used, verify it exposes a tag accessor, not just raw string splitting.
3. Keep the existing integration test `test_create_invalid_image_ref` and add variants for port-containing and digest-referencing images.
4. The extracted version string is used directly in `format!("edge-os-{}.oci.tar", version)`. Validate that the extracted version does not contain `/`, `:`, or other filesystem-unsafe characters before forming the filename.

**Warning signs:**
- `find(':')` in parsing code where `rfind(':')` was used before.
- No test for image references with port numbers in the registry host.
- Version strings appearing in filenames during tests that contain unexpected characters.

**Phase to address:** Phase that replaces raw string image version extraction (likely Phase 6).

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keeping `format_bytes` private in each module while "sharing" via copy-paste | No module restructuring needed | Three diverging implementations; TiB support inconsistent between commands | Never — this is the debt being fixed |
| Propagating `?` on JSON serialization without updating `main.rs` match arms | Cleaner error handling code | Exit code changes silently; automation breaks | Never in this codebase — exit codes are a public contract |
| Using `split_whitespace()` in `ChecksumLine::parse()` | More idiomatic Rust | Accepts malformed checksum files; format contract silently loosened | Never — format compatibility with `sha256sum` is a correctness requirement |
| Adding `ChecksumLine` struct without adding format edge-case tests | Quick extraction | Bugs re-introduced when format assumptions are violated | Never — the extraction is worthless without the tests |
| Extracting check functions from `run_verify()` without preserving early-return semantics | Simpler individual functions | Verify reports "valid" on incomplete check runs | Never — early-return is a safety property, not an implementation detail |

---

## Integration Gotchas

Common mistakes when connecting to external services or crossing module boundaries.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `skopeo` subprocess | Validating image ref format in Rust before passing to skopeo, but skopeo's own validation is more complete and will still fail | Add validation only for characters that are dangerous at the shell level; let skopeo own OCI format enforcement |
| `sha256sum` external verification | `ChecksumLine` struct that parses correctly but writes single-space in tests, breaking external `sha256sum -c` verification | Ensure `ChecksumLine::display()` always writes the two-space GNU format; run `sha256sum -c` in the E2E test to catch this |
| `format.rs` module extraction | Declaring functions `pub` when they only need to be `pub(crate)` | Use `pub(crate)` for the shared format module; prevents the public API surface from expanding |
| `verify.rs` check composition | Extracted check functions that take `&Path` and `&BundleManifest` parameters but also re-read the manifest from disk | Pass already-loaded data as parameters; avoid re-reading files inside individual check functions |

---

## Performance Traps

Patterns that work at small scale but are affected by refactoring.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `compute_sha256` in `verify.rs` uses default `std::io::copy` buffer (8KB) | Hashing a 4 GiB bundle takes minutes | Increase to 1MB buffer with `BufReader::with_capacity(1 << 20, file)` — do this in the same phase as the refactoring so it does not get deferred again | Every bundle verify on current hardware |
| Progress bar `progress.inc()` called per 8KB chunk during hash in `create.rs` | 256K progress updates for a 2GB file; measurable overhead | Batch updates: only call `progress.inc()` when bytes cross a 10MB threshold | Already present; worsens if buffer size stays at 8KB after refactoring |

---

## Security Mistakes

Domain-specific security issues in this refactoring context.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Loosening image ref validation while "improving" it | Previously-rejected malformed refs with shell metacharacters now pass | Validate that all shell metacharacters (`$`, `` ` ``, `&`, `;`, `|`, newline) are rejected by any new validation, regardless of other changes |
| Making `format.rs` functions `pub` instead of `pub(crate)` | Expands crate's public API; future consumers of the library form could depend on formatting internals | Use `pub(crate)` visibility for all utilities that are not part of the CLI's external contract |
| Losing the "skopeo in PATH" check during create.rs refactoring | If the skopeo check moves to a different call site, a malformed PATH could run a different binary | Keep the PATH check immediately before the `Command::new("skopeo")` call, not in a separate validation phase |
| Replacing `unwrap_or_else` fallbacks with `?` in JSON formatting functions | Callers in `main.rs` that pattern-match on specific error types may hit an unhandled variant | Map new error variants explicitly in `main.rs` rather than relying on the catch-all `Err(e)` path |

---

## UX Pitfalls

CLI user experience mistakes specific to this refactoring.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Error messages change wording when error propagation changes | Scripts that `grep` for specific error strings break | Keep the `.to_string()` output of each `BundleError` variant identical before and after refactoring; test this in `error.rs` test |
| `format_inspect_json` returning `{}` on serialization failure changes to returning an error | Users piping `--json` output get no output and no explanation | If propagating the error, emit a proper JSON error object to stdout (consistent with the `--json create` error contract in `create.rs:239-245`) |
| Human-readable size output changes for sub-GiB bundles | Users notice "512 MiB" becoming "0.5 GiB" or similar | Run the full `test_format_size` suite from `inspect.rs` on the new unified function; all boundary values must match |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **format.rs extraction:** Verify `test_format_size` passes — it covers TiB tier that only `inspect.rs` previously supported. All three modules must behave identically for the same input.
- [ ] **JSON fallback replacement:** Confirm `main.rs` exit code assignments still match the documented contract (exit 0/1/2) after any new `BundleError` variants flow through.
- [ ] **Image ref validation:** Confirm `registry:5000/repo:tag` (port in host) is accepted and the extracted version is `tag`, not `5000/repo`.
- [ ] **run_verify() decomposition:** Confirm early-return semantics are preserved — a missing `checksums.sha256` must not execute the SHA256 hash check. Test by asserting `result.checks.len() < 6` when an early check fails.
- [ ] **ChecksumLine struct:** Run `sha256sum -c checksums.sha256` externally on a file produced by the new struct. If it fails, the two-space format was broken.
- [ ] **All modules compile cleanly:** After adding `format.rs`, ensure all three call sites (`create.rs`, `verify.rs`, `inspect.rs`) are updated and the local private copies are removed. Unused-function warnings confirm if an old copy was left behind.

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Output format changed (format_bytes TiB regression) | LOW | Identify which test caught it. Restore the TiB tier to the unified function. Re-run tests. |
| Exit code changed (propagation affected main.rs match) | MEDIUM | Identify which error variant now flows through the catch-all. Add explicit match arm for it with the correct exit code. Add integration test asserting the exact exit code. |
| Validation rejects valid image references | HIGH | The refactoring must be reverted if production images are blocked. Narrow the validation to shell-metacharacter rejection only, re-deploy. |
| run_verify() decomposition changed check ordering | MEDIUM | Restore the check order to match the original 6-check sequence. JSON output consumers may depend on array order. |
| ChecksumLine struct uses single-space | LOW | Fix `parse()` to use `splitn(2, "  ")`. Add format edge-case tests. Re-verify existing bundles pass. |
| Image version extraction broke on port-containing registry | MEDIUM | Restore `rfind(':')` semantics. Add test for port-containing registry hosts before re-implementing. |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| format.rs output change (TiB regression) | Phase: Extract shared format module | `test_format_size` suite passes; human output snapshot unchanged for GiB inputs |
| Exit code change from error propagation | Phase: Replace JSON fallback patterns | Integration test asserts `exit_code == 1` and `exit_code == 2` on known inputs |
| Validation rejects valid OCI image refs | Phase: Add image reference validation | Parameterized test: port in registry, deeply nested path, digest reference all accepted |
| run_verify() check count test breaks | Phase: Decompose run_verify() | Each of 6 named checks present in result; early-return preserved when early check fails |
| ChecksumLine changes two-space format | Phase: Replace checksum parsing struct | `sha256sum -c` external verification passes; single-space input rejected |
| Image version extraction breaks on port in host | Phase: Replace image version extraction | Test with `registry:5000/repo:1.2.0` asserts `version == "1.2.0"` and tarball filename is safe |

---

## Sources

- Direct codebase audit: `.planning/codebase/CONCERNS.md` (2026-03-11)
- Source files reviewed: `create.rs`, `verify.rs`, `inspect.rs`, `error.rs`, `main.rs`, `create_integration.rs`
- [Rust RFC 1105: API Evolution](https://rust-lang.github.io/rfcs/1105-api-evolution.html) — breaking vs non-breaking change classification
- [Rust Book Ch12: Refactoring to Improve Modularity and Error Handling](https://doc.rust-lang.org/book/ch12-03-improving-error-handling-and-modularity.html) — exit code contract patterns
- [Long-term Rust Project Maintenance — corrode.dev](https://corrode.dev/blog/long-term-rust-maintenance/) — public API surface management
- [Rust CLI Book: Exit codes](https://rust-cli.github.io/book/in-depth/exit-code.html) — exit code conventions
- [sled-rs Error Handling](http://sled.rs/errors.html) — error propagation coupling pitfalls
- [Improving "Extract Function" in Rust Analyzer](https://dorianlistens.com/2022/07/improving-extract-function-in-rust-analyzer/) — semantic divergence during function extraction

---
*Pitfalls research for: Rust CLI tech debt refactoring (bundle-cli v1.2)*
*Researched: 2026-03-13*
