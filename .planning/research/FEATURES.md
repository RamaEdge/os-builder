# Feature Research

**Domain:** Rust CLI tech debt refactoring — bundle-cli crate
**Researched:** 2026-03-13
**Confidence:** HIGH (based on direct source audit + official Rust/OCI documentation)

## Feature Landscape

### Table Stakes (Users Expect These)

These are the refactoring tasks that constitute the v1.2 milestone. Absent these, the codebase
remains fragile and the maintenance burden compounds.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Extract shared `format.rs` utility module | Duplicate `format_bytes` in `create.rs` and `verify.rs`, divergent `format_size` in `inspect.rs` with TiB support — any change requires three edits. Standard Rust practice is a single authoritative module. | LOW | Move all three implementations to `crates/bundle-cli/src/format.rs`; promote TiB variant as canonical; update `create.rs`, `verify.rs`, `inspect.rs` to import from `crate::format`. No behavioral change. |
| Replace silent JSON fallbacks with proper error propagation | Four `unwrap_or_else(\|_\| "{}".to_string())` calls (`create.rs:222,244`, `inspect.rs:93`, `verify.rs:351`) silently emit empty JSON objects on serialization failure, hiding bugs. Operators get `{}` with no diagnostic. | LOW | `serde_json::to_string_pretty` on a struct with no non-string-keyed maps cannot fail in practice, but the fallback pattern still hides intent. Replace with `?` propagation (propagate to caller) or explicit `eprintln!` before fallback. The `create.rs:244` and `verify.rs:351` cases are in terminal output paths; `inspect.rs:93` returns `String` — each case needs individual treatment. |
| Validate image reference format before skopeo invocation | `create.rs:113` interpolates user-supplied `--image` value directly into a `docker://` URL passed to skopeo with no character-set check. A malformed reference causes confusing skopeo errors rather than a clear `BundleError`. Defense-in-depth for operator ergonomics. | LOW | Add a `validate_image_ref(image: &str) -> Result<(), BundleError>` function in `create.rs` or a new `image_ref.rs`. Regex: `^[A-Za-z0-9][A-Za-z0-9._\-/:@+]*:[A-Za-z0-9._\-]+$` covers the OCI grammar. No new crate dependency required — `std` pattern matching or `regex` crate (already likely transitive). |
| Decompose `run_verify()` into composable check functions | `verify.rs:56–285` is a 230-line function with 6 sequential checks, multiple early-return paths per check, and duplicated `unwrap_or_else` for JSON. Adding a 7th check requires understanding the full function. Each check maps cleanly to an independent unit. | MEDIUM | Extract each check as `fn check_manifest(…) -> CheckResult`, `fn check_schema_version(…) -> CheckResult`, etc. The existing `CheckResult` struct is already the right return type. `run_verify` becomes a 30-line orchestrator: build check list, iterate, short-circuit on failure. Tests remain valid — behavior is identical. |
| Replace fragile checksum parsing with `ChecksumLine` struct | `verify.rs:140–168` parses the `checksums.sha256` line with `splitn(2, "  ")` and manual index access. Logic for reading the file, splitting, validating hex length, and extracting filename is interleaved. Single-space vs double-space error is silent. | LOW | Create `struct ChecksumLine { hash: String, filename: String }` with a `parse(line: &str) -> Result<ChecksumLine, BundleError>` method. Move validation logic (64-char hex, double-space delimiter, non-empty filename) into the struct. Enables cross-referencing filename against `manifest.image.file` as a bonus hardening. |
| Replace raw string ops for image version extraction | `create.rs:70–86` uses `rfind(':')` and substring slicing to extract the version tag from an image reference. The approach is undiscoverable and handles only the missing-colon and empty-tag cases. No validation of tag content. | LOW | Extract `fn parse_image_tag(image: &str) -> Result<String, BundleError>`. Same logic, but isolated, named, and independently testable. Avoids adding an external OCI parsing crate (oci-spec-rs covers image manifest, not reference string parsing; the regex approach in validate_image_ref above is sufficient). |

### Differentiators (Competitive Advantage)

These are improvements that go beyond the v1.2 scope but are surfaced by the refactoring work
and represent meaningful quality gains for the project.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Cross-reference checksum filename against manifest | `checksums.sha256` filename field is extracted but never compared to `manifest.image.file`. Mismatched names could indicate tampering or bundle assembly error. Enabled cheaply once `ChecksumLine` struct exists. | LOW | Depends on `ChecksumLine` struct (table stakes above). One additional equality check + new `BundleError` variant if desired. |
| Increase SHA256 read buffer from 8 KiB to 1 MiB | Current 8 KiB buffer causes ~256K `progress.inc()` calls on a 2 GB file. Increasing buffer reduces syscall overhead and progress bar update frequency. No algorithm change needed. | LOW | Change `let mut buffer = [0u8; 8192]` to `[0u8; 1_048_576]` in `create.rs`. Batch progress updates to every 10 MB. No dependency change. |
| Unit tests for `ChecksumLine` edge cases | Current tests don't cover single-space delimiter, empty hex, invalid hex characters, or empty filename in `checksums.sha256`. Once parsing is extracted to a struct, these become trivial unit tests. | LOW | Depends on `ChecksumLine` struct. Add `test_checksum_line_single_space`, `test_checksum_line_invalid_hex`, etc. |
| Unit tests for `parse_image_tag` edge cases | `test_create_invalid_image_ref` covers the empty-tag case but not digest-reference format (`@sha256:...`), ports (`registry:5000/repo:tag`), or images with multiple colons. | LOW | Depends on `parse_image_tag` extraction. Add parameterized test cases for each format variant. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Add `oci-spec-rs` crate for image reference parsing | Seems like the principled solution — use an official OCI crate instead of string operations | `oci-spec-rs` covers OCI image manifests and runtime config, not reference string parsing. The crate does not expose a `parse_image_reference` API. Adding a ~300 KB transitive dependency for a 10-line regex is unjustified. Current Cargo.toml has no regex crate; adding `oci-spec-rs` adds build time and supply chain surface. | Extract `parse_image_tag` and `validate_image_ref` as standalone functions using `std` string methods + optional single-purpose `regex` crate. |
| Rewrite `run_verify` as a `trait`-based pipeline | Sounds extensible — each check implements `VerificationCheck` trait | Over-engineering for 6 checks in a CLI tool. Trait objects add indirection with no concrete benefit at this scale. Existing `CheckResult` struct + free functions compose identically without the abstraction tax. | Extract named free functions, compose them in a loop. Add trait only if/when third-party check plugins become a requirement. |
| Replace `thiserror` with `anyhow` across the codebase | `anyhow` is simpler for application code | `BundleError` is already a well-structured `thiserror` enum with 9 typed variants. `main.rs` matches on variants for exit codes 1 vs 2. Switching to `anyhow` erases that structure, breaks the exit code dispatch logic, and provides no benefit for a tool this size. | Keep `thiserror`. Add new `BundleError` variants as needed (e.g., `InvalidImageRef`). |
| Parallelize verification checks with `rayon` | Checks 4/5/6 (file existence, SHA256, size) seem parallelizable | SHA256 computation is I/O-bound on the same file all checks depend on. Running checks in parallel doesn't improve throughput when bottlenecked by sequential disk reads. Adds `rayon` dependency and complicates the short-circuit-on-failure logic. | Keep sequential checks. If performance matters, increase SHA256 read buffer (LOW complexity, high payoff). |

## Feature Dependencies

```
[parse_image_tag extraction]
    └──enables──> [validate_image_ref]
                      └──enables──> [clear skopeo error messages]

[ChecksumLine struct]
    └──enables──> [filename cross-reference against manifest]
                  [edge-case unit tests for checksum parsing]

[format.rs module extraction]
    └──required by──> [consistent TiB display across create/verify/inspect]
    (no module depends on format.rs existing — it's a lateral extraction)

[run_verify decomposition]
    └──enables──> [per-check unit tests without full bundle fixture]
    └──simplifies──> [adding Check 7+ in future milestones]
```

### Dependency Notes

- **`validate_image_ref` requires `parse_image_tag`:** validation is naturally combined with tag extraction at the same call site in `create_bundle`. Extract both as a single step.
- **`ChecksumLine` enables filename cross-reference:** once the struct owns the filename, the cross-reference is a single `assert_eq!`-style check. Building the struct first avoids retrofitting the inline logic.
- **`format.rs` is independent of all other refactors:** it can be done first, last, or in parallel with no coupling. Good candidate for a standalone PR.
- **`run_verify` decomposition is independent:** the existing `CheckResult` struct and `VerifyResult` type are not changed. Decomposition is purely extracting inner blocks into named functions.

## MVP Definition

### Launch With (v1.2 — all items are the milestone)

The entire v1.2 scope is "table stakes" for the milestone. All six items are small, well-bounded,
and sequenced to avoid rework.

- [ ] Extract `format.rs` — eliminates maintenance burden from triplicate implementations
- [ ] Replace silent JSON fallbacks — each case treated individually (propagate vs. log)
- [ ] Validate image reference format — `validate_image_ref` + `InvalidImageRef` error variant
- [ ] Decompose `run_verify` — extract 6 named check functions, loop-based orchestration
- [ ] Create `ChecksumLine` struct — encapsulate parsing + validation of `checksums.sha256` lines
- [ ] Extract `parse_image_tag` — isolate version extraction from `create_bundle`

### Add After Validation (v1.2+)

- [ ] Cross-reference `ChecksumLine.filename` vs `manifest.image.file` — 1 check, 1 error variant
- [ ] Increase SHA256 buffer to 1 MiB + batch progress updates — measurable improvement for 2+ GiB bundles
- [ ] Unit tests for `ChecksumLine` edge cases — single space, invalid hex, empty filename
- [ ] Unit tests for `parse_image_tag` edge cases — ports, digests, multiple colons

### Future Consideration (v2+)

- [ ] `--force` overwrite flag for incomplete bundles — requires `OutputExists` logic change
- [ ] `--hash-algorithm` flag — major manifest schema change, defer to v2.0
- [ ] GPG signing support — already marked out-of-scope in design doc §9
- [ ] Absolute skopeo path via `--skopeo-path` — operator ergonomics, not blocking
- [ ] `cargo audit` / `cargo-deny` in CI — supply chain hardening, not blocking for v1.2

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Extract `format.rs` | MEDIUM (prevents silent divergence) | LOW (move + import) | P1 |
| Replace JSON fallbacks | HIGH (operator debuggability) | LOW (4 targeted edits) | P1 |
| Validate image reference | HIGH (clear error messages) | LOW (single function + test) | P1 |
| Decompose `run_verify` | HIGH (maintainability, future checks) | MEDIUM (extract + wire) | P1 |
| `ChecksumLine` struct | HIGH (parsing robustness) | LOW (struct + parse method) | P1 |
| Extract `parse_image_tag` | MEDIUM (testability) | LOW (extract + test) | P1 |
| Filename cross-reference | MEDIUM (integrity hardening) | LOW (1 check after struct exists) | P2 |
| SHA256 buffer increase | LOW (marginal perf for large files) | LOW (2-line change) | P2 |
| Edge-case unit tests | MEDIUM (confidence) | LOW (parameterized cases) | P2 |
| `--force` overwrite | MEDIUM (operator UX) | MEDIUM (state management) | P3 |
| `cargo audit` CI | LOW for v1.2 | LOW | P3 |

**Priority key:**
- P1: Required for v1.2 milestone — eliminates active tech debt
- P2: Easy wins enabled by P1 refactors — add in same PR or follow-on
- P3: Future consideration — no dependency on v1.2 work

## Competitor Feature Analysis

Not applicable. This is internal tooling (edgeworks-bundle CLI). The refactoring work targets
code quality, not competitive positioning.

| Quality Metric | Current State | After v1.2 |
|----------------|---------------|-----------|
| Duplicate format functions | 3 (create, verify, inspect) | 1 (format.rs) |
| Silent error swallowing | 4 sites (unwrap_or_else) | 0 |
| Unvalidated shell input | 1 site (image ref) | 0 |
| Monolithic functions >200 lines | 1 (run_verify at 230 lines) | 0 |
| Inline parsing logic | 2 (checksum line, image tag) | 0 (dedicated structs/fns) |
| Functions testable in isolation | 3 of 5 major functions | 5 of 5 |

## Sources

- Direct audit of `crates/bundle-cli/src/` (create.rs, verify.rs, inspect.rs, error.rs) — 2026-03-11 per CONCERNS.md
- [Rust Book — Refactoring for Modularity and Error Handling](https://doc.rust-lang.org/book/ch12-03-improving-error-handling-and-modularity.html) — official guidance on extracting modules and error propagation
- [Serde Error Handling](https://serde.rs/error-handling.html) — JSON serialization failure modes
- [thiserror vs anyhow — Luca Palmieri](https://lpalmieri.com/posts/error-handling-rust/) — when to keep typed error enums
- [OCI Image Reference Grammar — containers/image issue #649](https://github.com/containers/image/issues/649) — character set for valid image references
- [Rust Compose Structs Pattern](https://rust-unofficial.github.io/patterns/patterns/structural/compose-structs.html) — decomposing large structs/functions
- [oci-spec-rs crate](https://github.com/containers/oci-spec-rs) — confirmed: covers image manifest, not reference string parsing

---
*Feature research for: bundle-cli v1.2 tech debt milestone*
*Researched: 2026-03-13*
