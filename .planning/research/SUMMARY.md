# Project Research Summary

**Project:** edgeworks-bundle CLI — v1.2 tech debt milestone
**Domain:** Rust CLI refactoring (internal tooling)
**Researched:** 2026-03-13
**Confidence:** HIGH

## Executive Summary

The `edgeworks-bundle` CLI is a mature, working Rust tool entering a focused tech-debt milestone (v1.2). The baseline stack — clap 4, serde_json 1, sha2 0.10, indicatif 0.17, thiserror 2, chrono 0.4 — is locked and production-validated. No new dependencies are required for this milestone. All six tech-debt items identified in `.planning/codebase/CONCERNS.md` are resolved through pure code-structure changes: extracting shared utilities, encapsulating parsing in structs, decomposing a monolithic verification function, and replacing silent error swallowing with proper propagation.

The recommended approach is a strict incremental build order: extract utility modules first (format, checksum, image_ref), migrate callers second, and save the largest change (run_verify decomposition) for a later step when the pattern is proven. Each step must compile and pass all existing tests independently. This sequencing minimises risk to the exit-code contract in `main.rs`, which is a public API that downstream CI pipelines depend on.

The primary risks are all preventable with targeted tests written before each refactor: output regression in `format_bytes` (TiB tier), exit code changes from error propagation, overly narrow image reference validation rejecting legitimate OCI refs with port-containing registries, and semantic drift in `ChecksumLine` parsing (single-space vs double-space). None of these require architectural rethinking — they require discipline in test coverage before touching existing code.

## Key Findings

### Recommended Stack

No Cargo.toml changes are needed. The existing dependency set fully supports all six refactoring items. The three external libraries evaluated for image reference validation (`oci-client`, `docker-image`, `docker-image-reference`) were all rejected: `oci-client` pulls in tokio and reqwest (17-38MB dep tree, async runtime in a sync CLI); `docker-image` carries an EUPL-1.2 license incompatible with the project's error model; `docker-image-reference` has thin maintenance and uses `anyhow` (conflicts with the `thiserror`-based error model). The correct approach is a stdlib character-allowlist validator.

**Core technologies (all existing):**
- `thiserror 2`: extend `BundleError` with two new variants (`InvalidImageRef`, `JsonSerialize`) — `#[from] serde_json::Error` pattern confirmed compatible
- `serde_json 1`: replace `unwrap_or_else(|_| "{}".to_string())` fallbacks with `?` propagation — serialization of plain Rust structs cannot fail in practice, but silent swallowing hides future regressions
- Rust stdlib: image reference validation via explicit character allowlist — zero deps, zero license risk, sufficient for the shell-safety goal

### Expected Features

All six items are P1 table stakes for the v1.2 milestone. They are not optional enhancements; absent these changes, the maintenance burden compounds and the next contributor to add a verification check faces a 230-line monolithic function.

**Must have (table stakes — v1.2 milestone):**
- Extract `format.rs` shared utility — eliminates three divergent `format_bytes`/`format_size` implementations; promotes TiB-capable version as canonical
- Replace silent JSON fallbacks — four `unwrap_or_else(|_| "{}")` sites become `?` propagation; operators get diagnostics instead of silent empty JSON
- Validate image reference format — `validate_image_ref()` + `InvalidImageRef` error variant; clear user-facing error instead of confusing skopeo failure
- Decompose `run_verify()` — extract 6 named `check_*` functions; orchestrator shrinks from 230 to ~20 lines; adding a 7th check becomes one function + one call
- Create `ChecksumLine` struct — encapsulate double-space SHA256 format parsing; isolated, testable, enforces format contract
- Extract `parse_image_tag` / `ImageRef` — isolate tag extraction from `create_bundle`; enables testing port-containing registry references independently

**Should have (enabled by P1 work — v1.2+):**
- Cross-reference `ChecksumLine.filename` against `manifest.image.file` — one equality check, one new error variant; enabled once `ChecksumLine` struct exists
- Increase SHA256 read buffer 8 KiB → 1 MiB — reduces syscall overhead on large bundles; two-line change with measurable impact on 2+ GiB files
- Edge-case unit tests for `ChecksumLine` (single-space rejection, invalid hex, empty filename)
- Edge-case unit tests for `parse_image_tag` (ports, digests, multiple colons)

**Defer (v2+):**
- `--force` overwrite flag for incomplete bundles
- `--hash-algorithm` flag (major manifest schema change)
- GPG signing support (explicitly out-of-scope in design doc)
- `cargo audit` / `cargo-deny` CI integration

### Architecture Approach

The refactoring follows a three-layer dependency order: foundation (error.rs, manifest.rs — unchanged), utility layer (format.rs, image_ref.rs, checksum.rs — new, no cross-dependencies), and command modules (create.rs, verify.rs, inspect.rs — call-site rewrites only). Two public function signatures change (`format_inspect_json` and `format_verify_json` become `-> Result<String, BundleError>`); all CLI-visible behaviour, output field names, exit codes, and human text format stay identical.

**Major components after refactoring:**
1. `format.rs` (new) — single `pub(crate) fn format_bytes(u64) -> String` with KiB/MiB/GiB/TiB support; used by all three command modules
2. `image_ref.rs` (new) — `ImageRef::parse()` struct; validates character allowlist and requires non-empty tag; used by `create.rs` only
3. `checksum.rs` (new) — `ChecksumLine::parse()` struct; enforces double-space GNU sha256sum format; used by `verify.rs` only
4. `verify.rs` (modified) — `run_verify()` becomes a 20-line orchestrator over 6 extracted `check_*` private functions; `format_verify_json` signature changes to `Result<String, BundleError>`
5. `create.rs`, `inspect.rs` (modified) — call-site rewrites to use shared utilities; no logic changes

### Critical Pitfalls

1. **format.rs TiB regression** — `create.rs` and `verify.rs` format_bytes tops out at GiB; `inspect.rs` format_size adds TiB. Must use the TiB-capable version as canonical and run the existing `test_format_size` suite on the unified function before deleting local copies.

2. **Exit code contract breakage** — `main.rs` maps `BundleError` variants to exit codes 0/1/2; scripts distinguish 1 (bad bundle) from 2 (path not found). When replacing `unwrap_or_else` fallbacks with `?`, trace every new error variant through `main.rs` match arms before committing. Add integration tests asserting numeric exit codes on known-bad inputs.

3. **Overly narrow image reference validation** — a character allowlist that rejects `registry:5000/repo:tag` (port in registry host) or digest references (`@sha256:...`) blocks legitimate production images with no clean recovery path. Minimum safe validation: reject empty strings, missing tags, and shell metacharacters (`$`, backtick, `|`, `;`, `&`, `<`, `>`, newline). Add parameterized tests for port-containing and digest-referencing inputs before shipping.

4. **run_verify() check count assertion** — `test_verify_valid_bundle` asserts `result.checks.len() == 6`; this breaks if extraction merges or splits checks. Preserve exactly one `CheckResult` per extracted function, and augment the count assertion to verify specific named checks, not just the count.

5. **ChecksumLine double-space format** — replacing `splitn(2, "  ")` with `split_whitespace()` silently accepts malformed single-space checksum files and breaks compatibility with external `sha256sum -c` verification. `ChecksumLine::parse()` must use the two-space literal and have an explicit failing test for single-space input.

## Implications for Roadmap

Based on research, all six items fit into a single milestone with a strict step order. The architecture's build-order analysis from ARCHITECTURE.md maps directly to phases.

### Phase 1: Extract Shared Format Utility

**Rationale:** Lowest risk change with no callers modified in this step. Validates the pattern (new module, compile, tests pass) before touching any existing module. Unblocks TiB-consistent output across all three commands.
**Delivers:** `crates/bundle-cli/src/format.rs` with `pub(crate) fn format_bytes(u64) -> String`; unit tests migrated from `inspect.rs::test_format_size`; all existing tests pass.
**Addresses:** "Duplicate format functions" table-stakes item (FEATURES.md); format module extraction (ARCHITECTURE.md Steps 1-2).
**Avoids:** TiB regression pitfall — the TiB tier is the canonical implementation, verified by the existing test suite before any callers switch.

### Phase 2: Switch Callers to format::format_bytes

**Rationale:** Immediately follows Phase 1 as the second half of the format extraction. Keeps the work atomic (extract + migrate in one milestone). Doing this in a separate step from Phase 1 allows verifying the new module compiles before any deletion of existing private functions.
**Delivers:** `create.rs`, `verify.rs`, `inspect.rs` updated to `use crate::format::format_bytes`; local private copies deleted; no unused-function compiler warnings remain.
**Avoids:** Leaving orphaned private copies that could diverge again; confirms no behavioral change for sub-TiB inputs through existing tests.

### Phase 3: Extract checksum.rs with ChecksumLine

**Rationale:** New file, zero risk to existing code. Builds the parsing struct in isolation with its own test suite before touching `verify.rs`. Establishes the "parse-don't-validate" pattern that `image_ref.rs` also follows.
**Delivers:** `crates/bundle-cli/src/checksum.rs`; `ChecksumLine::parse()`; tests for double-space pass, single-space fail, non-hex fail, 63-char hash fail, trailing newline pass.
**Addresses:** "Replace fragile checksum parsing" table-stakes item; ARCHITECTURE.md Step 3.
**Avoids:** Double-space format pitfall — the failing single-space test is written in this phase, before integration into `verify.rs`.

### Phase 4: Use ChecksumLine in verify.rs

**Rationale:** Replaces the inline `splitn` block in `verify.rs:140-168` with the now-tested struct. The 9 existing `verify.rs` test cases serve as the regression harness.
**Delivers:** `verify.rs` checksum parsing delegated to `ChecksumLine::parse()`; all 9 verify tests pass.
**Avoids:** Skipping the struct-first step and inlining the parsing again.

### Phase 5: Extract image_ref.rs with ImageRef

**Rationale:** New file, zero risk. Establishes character-allowlist validation and tag extraction in isolation. Critical to write the port-containing registry test here, before integration.
**Delivers:** `crates/bundle-cli/src/image_ref.rs`; `ImageRef::parse()`; tests covering valid refs, missing tag, empty tag, invalid chars, port-containing registry (`registry:5000/repo:tag`), and digest refs.
**Addresses:** "Validate image reference format" and "Extract parse_image_tag" table-stakes items; ARCHITECTURE.md Step 5.
**Avoids:** Validation too-narrow pitfall (Pitfall 3) — the port-in-host test is mandatory in this phase.

### Phase 6: Use ImageRef in create.rs

**Rationale:** Replaces `rfind(':')` block at `create.rs:71-86` with `ImageRef::parse(image)?`. Existing integration test `test_create_invalid_image_ref` serves as regression guard.
**Delivers:** `create.rs` image validation and tag extraction delegated to `ImageRef`; version extraction correctly uses `rfind` semantics (validated in Phase 5 tests).
**Avoids:** Image version extraction port-colon pitfall (Pitfall 6) — `rfind(':')` semantics are verified before this phase.

### Phase 7: Decompose run_verify() into Check Functions

**Rationale:** Largest and highest-risk change; deferred until all simpler patterns are proven. The 9 existing test cases are the full regression harness. Introduces no new public API changes — only internal private functions and `run_verify()` becomes a 20-line orchestrator.
**Delivers:** 6 private `check_*` functions; `run_verify()` refactored to orchestrator pattern; all 9 existing tests pass with identical behaviour; early-return semantics preserved.
**Addresses:** "Decompose run_verify()" table-stakes item; ARCHITECTURE.md Step 7.
**Avoids:** Check count assertion pitfall (Pitfall 4) — each extracted function returns exactly one `CheckResult`; named-check assertions preferred over count assertions.

### Phase 8: Propagate JSON Serialization Errors

**Rationale:** Signature-changing step; done last because it affects `main.rs` call sites and requires tracing exit code implications. Compile-time enforcement means nothing ships broken.
**Delivers:** `format_inspect_json` and `format_verify_json` return `Result<String, BundleError>`; `main.rs` updated to handle `Err`; `create.rs` `.unwrap()` calls replaced with `?`; all existing tests pass.
**Addresses:** "Replace silent JSON fallbacks" table-stakes item; ARCHITECTURE.md Step 8.
**Avoids:** Exit code contract breakage (Pitfall 2) — every new error variant is traced through `main.rs` match arms before commit; integration tests assert numeric exit codes.

### Phase Ordering Rationale

- Utility modules (Phases 1, 3, 5) always precede caller integration (Phases 2, 4, 6) because new files carry zero risk while caller rewrites carry regression risk.
- `format.rs` comes before `checksum.rs` and `image_ref.rs` because it is the simplest extraction (pure function, no error type) and proves the module-extraction pattern cheaply.
- `run_verify()` decomposition (Phase 7) is last among the structural refactors because it is the largest single change (230-line function) and depends on `checksum.rs` integration being stable.
- JSON error propagation (Phase 8) is last because it is the only change that touches `main.rs` and modifies public function signatures — it should not be combined with any structural refactor.

### Research Flags

Phases with well-documented patterns (skip research-phase during planning):
- **Phase 1-2 (format.rs):** Standard Rust module extraction. Established pattern, zero ambiguity.
- **Phase 3-4 (ChecksumLine):** Parse-don't-validate pattern. Well-documented in official Rust guidance.
- **Phase 7 (run_verify decomposition):** Extract-function refactoring. Covered by Rust Book ch12-03.
- **Phase 8 (JSON error propagation):** `thiserror` `#[from]` pattern. Confirmed working with existing dep versions.

Phases needing closer attention during execution (not pre-research, but careful implementation):
- **Phase 5-6 (ImageRef):** The character-allowlist decision requires judgment about which OCI reference formats to accept. The recommended minimum (reject shell metacharacters, not alphanumeric restriction) must be implemented correctly and tested against port-containing registries before shipping.
- **Phase 8 (exit codes):** Exit code mapping in `main.rs` requires manual tracing; no automated tool validates this. Write integration tests asserting numeric exit codes before modifying error propagation.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Based on direct codebase audit + docs.rs verification of all evaluated libraries; no new deps reduces risk to zero |
| Features | HIGH | Derived from direct source code audit; all 6 items are precisely scoped with file and line number references |
| Architecture | HIGH | Build order is based on actual dependency analysis of existing modules; 8 discrete steps each independently testable |
| Pitfalls | HIGH (code-specific) / MEDIUM (general patterns) | 6 pitfalls derived from direct source analysis; recovery strategies are concrete and tested via existing test suite |

**Overall confidence:** HIGH

### Gaps to Address

- **Image reference validation boundary:** The research recommends shell-metacharacter rejection as the minimum, but does not define the exact list exhaustively. During Phase 5 implementation, enumerate all shell metacharacters that could be misinterpreted by the shell layer between Rust and skopeo, and encode them as a constant with a doc comment.
- **`main.rs` exit code test coverage:** No existing integration test asserts numeric exit codes. This gap should be closed in Phase 8 before error propagation changes ship. If the CI environment supports running the compiled binary, add at least two exit code assertions (exit 1 on bad bundle, exit 2 on missing path).
- **SHA256 buffer performance:** FEATURES.md and PITFALLS.md both flag the 8 KiB buffer as a known performance issue. This is a P2 item (not blocking v1.2) but should be filed as a follow-on task immediately after Phase 7 ships, since the refactored structure makes it easier to address.

## Sources

### Primary (HIGH confidence)

- Direct source audit of `crates/bundle-cli/src/` (create.rs, verify.rs, inspect.rs, error.rs, main.rs) — 2026-03-11, per `.planning/codebase/CONCERNS.md`
- [docs.rs oci-client 0.16.1](https://docs.rs/oci-client/0.16.1/oci_client/) — dependency weight confirmed (~17-38MB, reqwest + tokio)
- [docs.rs docker-image 0.2.1](https://docs.rs/docker-image/latest/docker_image/) — EUPL-1.2 license confirmed
- [thiserror + serde_json::Error pattern](https://oneuptime.com/blog/post/2026-01-25-error-types-thiserror-anyhow-rust/view) — `#[from] serde_json::Error` confirmed Jan 2026
- [Rust Book ch12-03](https://doc.rust-lang.org/book/ch12-03-improving-error-handling-and-modularity.html) — extract-function refactoring, exit code contracts

### Secondary (MEDIUM confidence)

- [Rust CLI Book: Exit codes](https://rust-cli.github.io/book/in-depth/exit-code.html) — exit code conventions
- [OCI Image Reference Grammar — containers/image issue #649](https://github.com/containers/image/issues/649) — character set for valid image references
- [Long-term Rust Project Maintenance — corrode.dev](https://corrode.dev/blog/long-term-rust-maintenance/) — public API surface management
- [Rust Forum: when is serde_json::to_string unwrap safe](https://users.rust-lang.org/t/when-is-it-safe-to-call-unwrap-on-the-result-of-serde-json-to-string/121770) — plain struct serialization analysis

### Tertiary (LOW confidence / informational)

- [oci-spec-rs crate](https://github.com/containers/oci-spec-rs) — confirmed: covers image manifest, not reference string parsing
- [Improving Extract Function in Rust Analyzer](https://dorianlistens.com/2022/07/improving-extract-function-in-rust-analyzer/) — semantic divergence during function extraction

---
*Research completed: 2026-03-13*
*Ready for roadmap: yes*
