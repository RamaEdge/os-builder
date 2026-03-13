# Stack Research

**Domain:** Rust CLI tech debt — bundle-cli refactoring (v1.2)
**Researched:** 2026-03-13
**Confidence:** HIGH

## Context

This is a SUBSEQUENT MILESTONE for an existing Rust CLI (`edgeworks-bundle`). The
baseline stack (clap 4, serde_json 1, sha2 0.10, indicatif 0.17, thiserror 2,
chrono 0.4) is already validated and locked. This document covers ONLY the
additions and patterns needed for the six tech-debt items identified in
`.planning/codebase/CONCERNS.md`.

---

## Recommended Stack

### New Dependencies

None required. All six tech-debt items are resolved through code-structure
changes to the existing codebase. See reasoning in each section below.

### No New Cargo.toml Changes

| Item | Approach | Why No New Dep |
|------|----------|----------------|
| Shared `format.rs` utility | Extract to new source file, update imports | Pure Rust refactoring |
| JSON serialization error propagation | Add `JsonSerialize` variant to `BundleError` using existing `thiserror` | `#[from] serde_json::Error` works with `thiserror` already in use |
| Image reference validation | Stdlib char-set + structural validator (see pattern below) | Avoids heavy `oci-client` (reqwest + tokio) and EUPL-licensed `docker-image` |
| Decompose `run_verify()` | Extract each check into a free function returning `CheckResult` | Pure Rust refactoring |
| `ChecksumLine` struct | Add struct with `FromStr` to `verify.rs` or new `checksum.rs` | Pure Rust refactoring |
| Image version extraction | Use `ChecksumLine`-style struct for image ref components | Pure Rust refactoring |

---

## Supporting Libraries (Evaluated, Not Adopted)

These were researched and explicitly rejected for this milestone.

| Library | Version | What It Does | Why NOT Adopted |
|---------|---------|--------------|-----------------|
| `oci-client` | 0.16.1 | Full OCI Distribution client with `Reference` parsing | ~17-38MB dep tree; pulls in `reqwest`, `tokio`, `jsonwebtoken`. Overkill for char-set validation of a CLI arg. |
| `docker-image` | 0.2.1 | Lightweight `DockerImage` parser (no_std, lazy_static + regex) | EUPL-1.2 license is not Apache-2/MIT; adds `regex` + `lazy_static` transitive deps; validation requirement is modest enough for stdlib implementation. |
| `docker-image-reference` | 0.1.0 | Alternative image ref parser | Thin maintenance history; uses `anyhow` as dep (conflicts with `thiserror`-based error model). |

---

## Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `cargo clippy` | Lint after each extraction step | Already in CI; run locally after each refactor phase |
| `cargo test` | Verify no regressions | 9 existing verify tests, 6+ create tests all must pass |
| `cargo fmt` | Keep style consistent | Already in CI gate |

---

## Implementation Patterns

The following are the concrete patterns to apply. These replace ambiguous
"consider refactoring" advice with decisions.

### Pattern 1: Shared `format.rs` Utility

**File:** `crates/bundle-cli/src/format.rs`

Extract the authoritative `format_bytes` implementation from `inspect.rs`
(the only version with TiB support) as the canonical one:

```rust
/// Format a byte count as a human-readable string (e.g. "2.0 GiB").
pub fn format_bytes(bytes: u64) -> String {
    const TIB: u64 = 1024 * 1024 * 1024 * 1024;
    const GIB: u64 = 1024 * 1024 * 1024;
    const MIB: u64 = 1024 * 1024;
    const KIB: u64 = 1024;
    if bytes >= TIB      { format!("{:.1} TiB", bytes as f64 / TIB as f64) }
    else if bytes >= GIB { format!("{:.1} GiB", bytes as f64 / GIB as f64) }
    else if bytes >= MIB { format!("{:.1} MiB", bytes as f64 / MIB as f64) }
    else if bytes >= KIB { format!("{:.1} KiB", bytes as f64 / KIB as f64) }
    else                 { format!("{} B", bytes) }
}
```

Delete private `format_bytes` in `create.rs`, `verify.rs`, and `format_size`
in `inspect.rs`. Replace all call sites with `crate::format::format_bytes`.
The existing 6 tests in `inspect.rs::test_format_size` become the module's
tests in `format.rs`.

### Pattern 2: JSON Error Propagation

**File:** `crates/bundle-cli/src/error.rs`

Add one variant using `thiserror`'s `#[from]` to auto-implement `From`:

```rust
#[error("JSON serialization failed: {0}")]
JsonSerialize(#[from] serde_json::Error),
```

**At each call site** replace `.unwrap_or_else(|_| "{}".to_string())` and
bare `.unwrap()` on `serde_json::to_string_pretty(...)` with the `?` operator
or `.map_err(BundleError::JsonSerialize)?`. The four locations are:

- `create.rs:222` — `serde_json::to_string_pretty(&out).unwrap()`
- `create.rs:244` — error JSON `.unwrap()`
- `inspect.rs:93` — `format_inspect_json` fallback `.unwrap_or_else(|_| "{}".to_string())`
- `verify.rs:351` — `format_verify_json` fallback `.unwrap_or_else(|_| "{}".to_string())`

**Note on safety:** For plain Rust structs with `String`/`u64`/`bool`/`Vec`
fields derived via `serde::Serialize`, `serde_json::to_string_pretty` cannot
fail in practice. However, swallowing the error silently masks future
regressions if the struct changes. Adding the `BundleError::JsonSerialize`
variant turns a hidden panic or silent `{}` into a proper error propagated
to the user, consistent with the rest of the error model.

### Pattern 3: Image Reference Validation (stdlib only)

**File:** `crates/bundle-cli/src/create.rs` (inline) or extracted to
`crates/bundle-cli/src/image_ref.rs`

Implement a `validate_image_ref` function using only the standard library.
The OCI distribution spec character set for image names and tags is:
`[a-z0-9]` with separators `[.-_]` for name components, `[a-zA-Z0-9._-]`
for tags, with `/` separating path components and `:` separating name from tag.
For the security goal stated in CONCERNS.md (defense-in-depth against shell
special characters before skopeo), a permissive-but-safe allowlist suffices:

```rust
/// Validate that `image` is a structurally sound OCI image reference.
///
/// Accepts: alphanumeric, `/ : . _ -` (OCI name chars + registry separators).
/// Rejects: whitespace, shell metacharacters (`$`, `` ` ``, `|`, `;`, etc.).
/// Also validates that a tag is present and non-empty.
pub fn validate_image_ref(image: &str) -> Result<(), BundleError> {
    if image.is_empty() {
        return Err(BundleError::InvalidImageRef(
            "image reference must not be empty".into(),
        ));
    }
    let allowed = |c: char| {
        c.is_ascii_alphanumeric() || matches!(c, '/' | ':' | '.' | '_' | '-')
    };
    if let Some(bad) = image.chars().find(|c| !allowed(*c)) {
        return Err(BundleError::InvalidImageRef(format!(
            "illegal character '{}' in image reference", bad
        )));
    }
    // Tag must be present and non-empty (existing logic, now a named concern).
    match image.rfind(':') {
        None | Some(_) if image.ends_with(':') => Err(BundleError::InvalidImageRef(
            "image reference must include a tag (e.g., registry/repo:1.2.0)".into(),
        )),
        None => Err(BundleError::InvalidImageRef(
            "image reference must include a tag (e.g., registry/repo:1.2.0)".into(),
        )),
        Some(_) => Ok(()),
    }
}
```

Add `BundleError::InvalidImageRef(String)` to `error.rs`. Call
`validate_image_ref(image)?` at the top of `create_bundle()`, before the
`rfind(':')` version-extraction block. This replaces the inline error handling
in that block.

### Pattern 4: Decompose `run_verify()`

**File:** `crates/bundle-cli/src/verify.rs`

Extract each of the 6 check blocks into a private free function:

```
check_manifest_schema(bundle_dir: &Path) -> Result<(CheckResult, BundleManifest), CheckResult>
check_schema_version(manifest: &BundleManifest) -> CheckResult
check_checksums_file(bundle_dir: &Path) -> Result<(CheckResult, String, String), CheckResult>
check_tarball_exists(bundle_dir: &Path, manifest: &BundleManifest) -> Result<(CheckResult, u64), CheckResult>
check_sha256(tarball_path: &Path, expected_hash: &str, manifest_digest: &str) -> Result<CheckResult, CheckResult>
check_size(actual: u64, expected: u64, filename: &str) -> CheckResult
```

`run_verify()` becomes a 20-line coordinator that calls each function, pushes
the `CheckResult`, and short-circuits on failure with early `return Ok(...)`.
The 9 existing test cases bind to `run_verify()` and remain unchanged — they
test the composed behaviour, which is all that matters for regression coverage.

### Pattern 5: `ChecksumLine` Struct

**File:** `crates/bundle-cli/src/verify.rs` (or extracted `checksum.rs`)

```rust
/// A parsed line from a GNU coreutils sha256sum file.
/// Format: `<64-hex>  <filename>\n`
struct ChecksumLine {
    pub hash: String,   // 64-character lowercase hex
    pub file: String,   // filename (no path components expected)
}

impl ChecksumLine {
    pub fn parse(line: &str) -> Option<Self> {
        let parts: Vec<&str> = line.splitn(2, "  ").collect();
        if parts.len() != 2 { return None; }
        let hash = parts[0];
        let file = parts[1].trim_end_matches('\n');
        if hash.len() != 64 || !hash.chars().all(|c| c.is_ascii_hexdigit()) {
            return None;
        }
        Some(ChecksumLine {
            hash: hash.to_string(),
            file: file.to_string(),
        })
    }
}
```

Add unit tests covering: double-space format, single-space (rejected),
non-hex characters (rejected), 63-char hash (rejected), trailing newline
(accepted), empty string (rejected). These address the test coverage gap
noted in CONCERNS.md.

### Pattern 6: Image Version Extraction

The existing `rfind(':')` block in `create.rs:70-86` is already made safe by
`validate_image_ref` (Pattern 3). After validation guarantees a `:` exists and
the tag is non-empty, the extraction becomes a one-liner:

```rust
let version = image[image.rfind(':').unwrap() + 1..].to_string();
```

The `unwrap()` is sound because `validate_image_ref` has already returned
`Ok(())` — i.e., this is a post-condition of the validator, not a blind panic.
Add a comment to document this invariant explicitly.

---

## Installation

No Cargo.toml changes needed. All patterns use:
- `thiserror 2` (already present) — for new error variants
- `serde_json 1` (already present) — error type is `serde_json::Error`
- Rust stdlib only — for image reference validation and struct parsing

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Stdlib char-set validator | `docker-image` 0.2.1 | Use `docker-image` if the project needs full round-trip parsing (reconstruct canonical form, normalize docker.io shorthand, etc.). Not needed here. |
| Stdlib char-set validator | `oci-client` 0.16.1 `Reference` | Use `oci-client` only if the project also needs to talk to registries directly (pull manifests, list tags). The `Reference` type is excellent but the tokio + reqwest transitive footprint is unjustified for validation only. |
| `thiserror` `#[from]` variant | `eprintln!` + fallback string | The fallback pattern was already in use; adding a named error variant makes the failure visible to callers and consistent with the existing error model. |
| Extract private free functions | New sub-module per check | Sub-modules add file overhead and pub/priv boilerplate for what are internal implementation details. Private free functions within `verify.rs` are simpler. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `oci-client` for reference validation | Pulls tokio + reqwest + jsonwebtoken (~17-38MB dep tree); async runtime for a sync CLI is architectural mismatch | Stdlib char-set validator (zero deps) |
| `docker-image` crate | EUPL-1.2 license; adds `regex` + `lazy_static` deps; low download volume suggests limited ecosystem adoption | Stdlib char-set validator |
| `unwrap()` on `serde_json::to_string_pretty` | Hides future regressions if struct shape changes; inconsistent with `thiserror`-based error model | `?` operator with `BundleError::JsonSerialize` variant |
| Adding a new error handling crate (`anyhow`, `eyre`) | `thiserror` 2 is already established; mixing strategies increases cognitive overhead | Extend existing `BundleError` enum |

## Version Compatibility

All changes operate within the existing dependency versions. No version
bumps or cross-crate compatibility issues.

| Package | Current Constraint | Notes |
|---------|--------------------|-------|
| `thiserror` | `2` | `#[from]` for `serde_json::Error` is supported in both 1.x and 2.x |
| `serde_json` | `1` | `serde_json::Error` is `std::error::Error`, compatible with `thiserror #[from]` |
| Rust edition | `2021` | All patterns use edition-2021 idioms; no edition change needed |

## Sources

- [oci-client 0.16.1 on docs.rs](https://docs.rs/oci-client/0.16.1/oci_client/) — Reference struct API, dependency weight confirmed (~17-38MB, reqwest + tokio)
- [docker-image 0.2.1 on docs.rs](https://docs.rs/docker-image/latest/docker_image/) — DockerImage struct API, EUPL-1.2 license, lazy_static + regex deps
- [docker-image GitHub (sunsided/docker-image-rs)](https://github.com/sunsided/docker-image-rs) — Last updated Feb 22, 2025; MSRV 1.81.0
- [oci-spec 0.9.0 on docs.rs](https://docs.rs/oci-spec/latest/oci_spec/) — Confirmed: no image reference parsing in public API
- [Rust Forum: when is serde_json::to_string unwrap safe](https://users.rust-lang.org/t/when-is-it-safe-to-call-unwrap-on-the-result-of-serde-json-to-string/121770) — Plain struct serialization won't fail; `.expect()` with message is acceptable for CLI
- [thiserror + serde_json::Error pattern](https://oneuptime.com/blog/post/2026-01-25-error-types-thiserror-anyhow-rust/view) — `#[from] serde_json::Error` confirmed pattern, Jan 2026
- [Rust Book ch12-03: Refactoring for Modularity](https://doc.rust-lang.org/book/ch12-03-improving-error-handling-and-modularity.html) — Extract-function refactoring approach; private free functions over sub-modules

---
*Stack research for: os-builder bundle-cli v1.2 tech debt*
*Researched: 2026-03-13*
