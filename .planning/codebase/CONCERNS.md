# Codebase Concerns

**Analysis Date:** 2026-03-11

## Tech Debt

**Scattered Utility Functions — Duplicate Implementations:**
- Issue: `format_bytes()` function is implemented twice — once in `create.rs` (lines 27-41) and again in `verify.rs` (lines 34-48). Additionally, `format_size()` in `inspect.rs` (lines 36-53) is a third implementation with TiB support. This creates maintenance burden and inconsistency.
- Files: `crates/bundle-cli/src/create.rs`, `crates/bundle-cli/src/verify.rs`, `crates/bundle-cli/src/inspect.rs`
- Impact: Changes to formatting logic must be made in multiple places. Different precision/scale support between modules may cause unexpected output differences.
- Fix approach: Extract shared utility module `crates/bundle-cli/src/format.rs` with single authoritative `format_bytes()` supporting TiB, use across all modules.

**Repeated JSON Fallback Pattern:**
- Issue: Multiple places use `.unwrap_or_else(|_| "{}".to_string())` for JSON serialization fallback (create.rs:222, inspect.rs:93, verify.rs:351). These mask serialization failures silently by returning empty JSON objects.
- Files: `crates/bundle-cli/src/create.rs` (lines 222, 244), `crates/bundle-cli/src/inspect.rs` (line 93), `crates/bundle-cli/src/verify.rs` (line 351)
- Impact: If JSON serialization fails unexpectedly, users receive empty `{}` output instead of proper error message. Difficult to debug.
- Fix approach: Log the serialization error before returning fallback. Consider propagating error instead of swallowing it.

**Shell Command Injection Risk in Image Reference:**
- Issue: In `create.rs:113`, the image reference is directly interpolated into a `docker://` URL passed to `skopeo copy` without additional escaping: `format!("docker://{}", image)`. While the image string comes from CLI args and is validated for having a tag, there's no defense against special characters.
- Files: `crates/bundle-cli/src/create.rs` (lines 111-114)
- Impact: A malicious or incorrectly formatted image reference with special shell characters could potentially be misinterpreted. Low risk because skopeo URL parsing is strict, but defense-in-depth suggests validation.
- Fix approach: Add explicit validation of image reference format (alphanumeric, colons, slashes, underscores, hyphens, dots only). Consider using a dedicated image-ref parsing library.

## Known Issues

**Progress Bar UI Pollution in JSON Mode:**
- Symptoms: When running with `--json` flag, spinner/progress bars are suppressed via `ProgressBar::hidden()` (create.rs:102-109, 128-140). However, if the operation is very fast or stderr captures are used, there's theoretical risk of progress remnants in output.
- Files: `crates/bundle-cli/src/create.rs` (lines 102-109, 128-140)
- Trigger: Run `edgeworks-bundle --json create ...` and try to capture output with redirects.
- Workaround: Output is isolated to stdout for JSON, stderr for errors, so current implementation is safe in practice.

**Missing skopeo Output Interpretation:**
- Symptoms: When `skopeo copy` fails, error message is captured from stderr but not interpreted. Generic pull errors may be confusing to users (authentication failures, network timeouts, registry not found all look similar).
- Files: `crates/bundle-cli/src/create.rs` (lines 120-123)
- Trigger: Try to pull from a private registry without credentials, or from a non-existent registry.
- Workaround: Error is passed through as-is. Users must interpret skopeo stderr messages.

## Security Considerations

**External Command Execution (skopeo):**
- Risk: `create.rs` executes `skopeo` as a subprocess via `Command::new("skopeo")`. This is intentional but has security surface: if PATH is manipulated, a malicious `skopeo` binary could be run instead.
- Files: `crates/bundle-cli/src/create.rs` (lines 63, 111)
- Current mitigation: `skopeo` is checked to exist in PATH before use. Tool is expected to run in controlled operator environment, not exposed to untrusted users directly.
- Recommendations: In production deployment, use absolute path to skopeo (e.g., `/usr/bin/skopeo` or from sealed container) rather than relying on PATH lookup. Document that operator must ensure skopeo is not compromised on their workstation.

**Image Reference Input from CLI:**
- Risk: Image reference is user-provided via `--image` flag and used in registry operations. Attacker could provide malicious registries or auth parameters.
- Files: `crates/bundle-cli/src/create.rs` (lines 54-57, 70-86)
- Current mitigation: Only the image reference is used; no registry credentials are embedded in the code. Credentials must come from user's container auth config.
- Recommendations: Add validation that image reference conforms to OCI image spec. Warn users that this tool will contact the specified registry (requires network access). Document that registry credentials should be configured separately via podman/docker config.

**Checksum Format Validation:**
- Risk: In `verify.rs:144-148`, checksums.sha256 line is parsed with basic validation (64-char hex, two spaces). No validation of filename format in checksum line.
- Files: `crates/bundle-cli/src/verify.rs` (lines 127-169)
- Current mitigation: Filename is extracted but not used for verification (only the computed hash is compared). Malformed filename won't cause security issue.
- Recommendations: Validate that filename in checksums.sha256 matches the filename in manifest.image.file. This would catch tampering where the manifest points to one file but checksums.sha256 lists a different one.

## Performance Bottlenecks

**Single-threaded SHA256 Computation on Large Files:**
- Problem: In `create.rs:147-154` and `verify.rs:26-31`, SHA256 hashing is done with a single thread and 8KB buffer. For multi-gigabyte tarball files (typical bundle size 2-4 GiB), this can take minutes.
- Files: `crates/bundle-cli/src/create.rs` (lines 142-159), `crates/bundle-cli/src/verify.rs` (lines 26-31)
- Cause: Standard approach using `Sha256::new()` and `update()`. Not inherently slow, but not optimized for large files.
- Improvement path: Increase read buffer size (currently 8192 bytes) to 1MB or more for better I/O performance. Consider parallel hashing using rayon if SHA2 implementation supports it (probably not worth complexity for CLI tool).

**Progress Bar Overhead:**
- Problem: Creating and updating progress bars adds overhead. For network operations (image pull), this is negligible. For large file hashing, there's measurable overhead from `progress.inc()` calls in tight loops.
- Files: `crates/bundle-cli/src/create.rs` (lines 131-154)
- Cause: `progress.inc()` is called once per read chunk (8KB). For a 2GB file, that's 256K calls.
- Improvement path: Batch progress updates (e.g., every 10MB) or sample at fixed time intervals rather than per-chunk. Profile first to confirm this is measurable.

## Fragile Areas

**Verify Function Overstuffed:**
- Files: `crates/bundle-cli/src/verify.rs` (lines 56-285)
- Why fragile: `run_verify()` is 230 lines with 6 sequential checks, early returns at every step, and detailed check logging. It's the largest single function in the codebase. Adding new checks or modifying verification logic is error-prone because:
  - All checks must be added to the `checks` vector in the right order
  - Each check has multiple early return paths
  - Duplicated `unwrap_or_else()` for test JSON formatting
- Safe modification: Extract each check into its own function that returns `CheckResult`. Compose them in a loop. This would reduce function size and make adding checks explicit.
- Test coverage: Good — 9 test cases cover all checks and error paths. But testing is tightly coupled to the monolithic function.

**Checksum Format Parsing Logic:**
- Files: `crates/bundle-cli/src/verify.rs` (lines 127-169, specifically 140-148)
- Why fragile: Checksum line parsing is done with `splitn(2, "  ")` and manual index access. Logic for validating the hash is mixed with file reading. If the format changes (e.g., support comments, multiple algorithms), this code requires careful modification.
- Safe modification: Create a dedicated `ChecksumLine` struct with parsing logic. Use enum for algorithm type.
- Test coverage: One test `test_verify_missing_checksums_file` validates format, but doesn't test edge cases like single space instead of double, or invalid hex characters.

**Image Version Extraction Logic:**
- Files: `crates/bundle-cli/src/create.rs` (lines 70-86)
- Why fragile: Version is extracted from image tag via `rfind(':')` and substring slicing. Assumes valid OCI image reference format. If an image reference is malformed (missing tag, empty tag), error handling happens inline.
- Safe modification: Use a dedicated image reference parsing library (e.g., `oci-spec` crate) instead of string operations.
- Test coverage: Integration test `test_create_invalid_image_ref` covers empty tag case, but no test for other malformations.

## Scaling Limits

**Single-file Bundle Architecture:**
- Current capacity: One OCI tarball per bundle (by design)
- Limit: If future requirements require multi-image bundles (e.g., separate OS + apps), current manifest schema and logic cannot support it without breaking changes
- Scaling path: Schema version would need to bump to 2.0, manifest.image becomes manifest.images array, verification logic duplicates for each image. This is a major change.

**No Streaming Support for Manifest/Checksums:**
- Current capacity: Entire checksums.sha256 file is read into memory (verify.rs:140)
- Limit: For bundles with thousands of files (not applicable now with single-file model), checksums file could be large
- Scaling path: Not critical for current use case, but streaming line-by-line parsing would be more robust

## Dependencies at Risk

**No Security Audit for Transitive Dependencies:**
- Risk: `Cargo.toml` specifies `sha2 = "0.10"`, `clap = "4"`, `serde_json = "1"`, etc. without version pinning or audit. Updates could introduce vulnerabilities.
- Impact: Supply chain attack risk is low for a CLI tool (not embedded in runtime), but dependency on `serde_json` for trusted input (manifest) parsing is critical.
- Migration plan: Use `cargo audit` in CI/CD to detect known vulnerabilities. Pin major versions in Cargo.toml to avoid surprises. Consider adding `cargo-deny` to block specific problematic versions.

**skopeo is External Runtime Dependency:**
- Risk: Tool completely depends on `skopeo` being installed and in PATH. No version constraint check — any version of skopeo is accepted.
- Impact: Breaking changes in skopeo command-line interface or output format would break the tool silently.
- Migration plan: Add `--skopeo-path` option to override PATH lookup. Check skopeo version output and validate minimum version (e.g., v1.10+). Document minimum skopeo version requirement in README.

## Missing Critical Features

**No Resume Support for Large Transfers:**
- Problem: If bundle creation is interrupted mid-way (network disconnect, user cancel), the partial tarball is left in output directory. Running create again in same directory fails with "OutputExists" error.
- Blocks: Operators cannot easily retry failed bundle creation without manually cleaning up.
- Fix: Implement `--force` flag to overwrite existing incomplete bundles, or auto-detect incomplete bundles and resume hashing/verification.

**No Checksum Algorithm Negotiation:**
- Problem: SHA256 is hardcoded. If an operator has custom requirements (SHA512, Blake3), tool cannot accommodate.
- Blocks: Organizations with strict hashing requirements cannot use the tool.
- Fix: Make algorithm configurable via `--hash-algorithm` flag, update manifest schema to include algorithm name, update verify logic to read algorithm from manifest.

**No Signature Support:**
- Problem: Bundle authenticity is verified only via checksums. No cryptographic signature on manifest.
- Blocks: Air-gapped edge devices cannot verify that a bundle came from trusted operator (not intercepted/tampered in transit).
- Fix: Add optional `--sign-with-key` flag to create signed bundles. Store signature in manifest.signature field. Verify signatures during inspection.

## Test Coverage Gaps

**Create Function Integration Not Fully Tested Without skopeo:**
- What's not tested: The actual `create_bundle()` function cannot be unit tested in isolation because it depends on skopeo being installed. Only the error path (missing skopeo) is tested. Success path requires full end-to-end test with skopeo.
- Files: `crates/bundle-cli/src/create.rs` (lines 53-194), `crates/bundle-cli/tests/create_integration.rs`
- Risk: Changes to image pulling logic, tarball writing, or manifest generation could have bugs that aren't caught until integration tests run.
- Priority: Medium — E2E test exists but is marked `#[ignore]` and requires skopeo to run. Consider adding a mock skopeo or test fixture.

**No Test for Concurrent Verify Operations:**
- What's not tested: If two processes try to verify the same bundle simultaneously, current implementation has no locking. File reads might be interleaved unexpectedly.
- Files: `crates/bundle-cli/src/verify.rs` (entire verify logic)
- Risk: Low in practice because bundles are on read-only storage, but not tested.
- Priority: Low — would require multi-process test harness.

**No Test for Very Large Files (>2GB):**
- What's not tested: Verify and create logic uses u64 for file sizes, but test payloads are tiny. Integer overflow in progress.inc() or similar edge cases with huge files are untested.
- Files: `crates/bundle-cli/src/verify.rs` (line 188), `crates/bundle-cli/src/create.rs` (line 126)
- Risk: Low — u64 can represent up to 16 exabytes. But if file is exactly u64::MAX, edge case might exist.
- Priority: Low — not a practical concern for current use case (max bundle size ~4GB).

---

*Concerns audit: 2026-03-11*
