# Phase 8: Shared Utilities - Research

**Researched:** 2026-03-13
**Domain:** Rust module extraction — new utility files with full test coverage, no existing code modified
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DEDUP-01 | Shared `format.rs` module provides single `format_bytes()` function with TiB support used by all commands | `inspect.rs:format_size` (lines 36-53) is the canonical TiB-capable implementation to promote; `create.rs:format_bytes` and `verify.rs:format_bytes` both top out at GiB — they must not be the model |
| DEDUP-02 | Duplicate `format_bytes` in create.rs and verify.rs replaced with import from `crate::format` | Phase 8 creates the module only; caller replacement is Phase 9 per roadmap — but REQUIREMENTS.md assigns DEDUP-02 to Phase 8, so the module must be ready to import |
| DEDUP-03 | `format_size` in inspect.rs replaced with import from `crate::format` | Same note as DEDUP-02 — module must exist with the TiB-capable implementation |
| VALID-01 | Image reference validated against allowlist before passing to skopeo (rejects shell metacharacters) | `create.rs:113` passes user-supplied image ref directly to skopeo with no char check; new `image_ref.rs` provides the validation |
| VALID-02 | `ImageRef` struct or `parse_image_tag()` function extracts version tag with proper validation | `create.rs:71-86` uses inline `rfind(':')` with no char validation; `ImageRef::parse()` must use `rfind` semantics to correctly handle `registry:5000/repo:tag` |
| VALID-03 | Port-containing registry hosts (`registry:5000/repo:tag`) pass validation | Allowlist must include `:` as a valid character; tag extraction must use `rfind` not `find` |
| CKSM-01 | `ChecksumLine` struct encapsulates parsing of `checksums.sha256` lines | `verify.rs:140-168` performs inline `splitn(2, "  ")` parsing; new `checksum.rs` extracts this into a named struct |
| CKSM-02 | Two-space delimiter contract preserved (not `split_whitespace`) | `verify.rs:144` uses `splitn(2, "  ")` — the `ChecksumLine::parse()` method must replicate this exactly, with an explicit failing test for single-space input |
</phase_requirements>

## Summary

Phase 8 creates three new utility source files (`format.rs`, `image_ref.rs`, `checksum.rs`) with full test coverage. No existing source file is modified in this phase. The phase ends with three standalone, tested modules that compile cleanly alongside the existing codebase — the caller switchover (replacing private functions in create.rs, verify.rs, inspect.rs) happens in Phase 9.

The central constraint is that all three utility modules must work correctly in isolation before any caller touches them. Each module has exactly one correctness risk: `format.rs` must promote the TiB-capable `format_size` from inspect.rs as canonical (not the GiB-limited versions in create.rs or verify.rs); `checksum.rs` must use `splitn(2, "  ")` with a two-space literal, not `split_whitespace()`; and `image_ref.rs` must accept port-containing registries by including `:` in the allowed character set and using `rfind` semantics for tag extraction.

No new Cargo.toml dependencies are needed. All three modules use only Rust stdlib plus `crate::error::BundleError` for error returns. The `BundleError::InvalidImageRef` variant must be added to `error.rs` as the sole change to an existing file — all other changes in this phase are new file creation only.

**Primary recommendation:** Create the three utility files in dependency order (format.rs first — pure function, no error type; checksum.rs second; image_ref.rs third — requires new BundleError variant). Run `cargo test` after each file is created. Do not touch any existing caller module until Phase 9.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rust stdlib | built-in | String parsing, character validation, module system | Zero deps; sufficient for all three utility modules |
| `thiserror` | 2 (already in Cargo.toml) | `BundleError::InvalidImageRef` variant for image_ref.rs | Already the project's error model; no new dep needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `serde_json` | 1 (already in Cargo.toml) | Not needed by the three new utility modules directly | Not applicable in Phase 8 |
| `tempfile` | already in dev-deps | Temporary directories in unit tests | Used in existing tests; available for new tests too |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Stdlib char allowlist for ImageRef | `oci-client 0.16.1` | oci-client pulls reqwest + tokio (~17-38 MB dep tree); async runtime in a sync CLI is architectural mismatch |
| Stdlib char allowlist for ImageRef | `docker-image 0.2.1` | EUPL-1.2 license incompatible with project; adds `regex` + `lazy_static` deps |
| `splitn(2, "  ")` in ChecksumLine | `split_whitespace()` | split_whitespace silently accepts single-space checksum files, breaking external `sha256sum -c` compatibility |

**Installation:**
```bash
# No new dependencies — all three modules use existing crate + stdlib only
```

## Architecture Patterns

### Recommended Project Structure
```
crates/bundle-cli/src/
├── main.rs          # Add: mod format; mod checksum; mod image_ref;
├── error.rs         # Add: BundleError::InvalidImageRef(String) variant
├── manifest.rs      # Unchanged
├── format.rs        # NEW — pub(crate) fn format_bytes(u64) -> String (TiB-capable)
├── image_ref.rs     # NEW — pub(crate) struct ImageRef { pub full, pub tag }
├── checksum.rs      # NEW — pub(crate) struct ChecksumLine { pub hex, pub file }
├── create.rs        # Unchanged in Phase 8 (caller switchover is Phase 9)
├── verify.rs        # Unchanged in Phase 8
└── inspect.rs       # Unchanged in Phase 8
```

### Pattern 1: Utility Module Extraction (format.rs)

**What:** Move the TiB-capable `format_size` implementation from `inspect.rs` into a new `format.rs` module as `pub(crate) fn format_bytes`. Do NOT use the GiB-limited versions from `create.rs` or `verify.rs` as the model.

**When to use:** Duplicated private utility functions exist across multiple modules with behavioral divergence (TiB vs no-TiB).

**Example:**
```rust
// Source: inspect.rs lines 36-53 — this is the canonical implementation to promote
pub(crate) fn format_bytes(bytes: u64) -> String {
    const TIB: u64 = 1024 * 1024 * 1024 * 1024;
    const GIB: u64 = 1024 * 1024 * 1024;
    const MIB: u64 = 1024 * 1024;
    const KIB: u64 = 1024;

    if bytes >= TIB {
        format!("{:.1} TiB", bytes as f64 / TIB as f64)
    } else if bytes >= GIB {
        format!("{:.1} GiB", bytes as f64 / GIB as f64)
    } else if bytes >= MIB {
        format!("{:.1} MiB", bytes as f64 / MIB as f64)
    } else if bytes >= KIB {
        format!("{:.1} KiB", bytes as f64 / KIB as f64)
    } else {
        format!("{} B", bytes)
    }
}
```

Migrate tests from `inspect.rs::test_format_size` (lines 232-241) to `format.rs` module tests. The 8 boundary values in that test (0 B, 512 B, 1023 B, 1.0 KiB, 1.0 MiB, 1.0 GiB, 2.0 GiB, 1.0 TiB) become the canonical test suite for `format_bytes`.

### Pattern 2: Parse-Don't-Validate Struct (checksum.rs)

**What:** Create a `ChecksumLine` struct that owns parsed fields. The constructor enforces format invariants so downstream code works with typed fields, not raw string slices.

**Critical constraint:** Use `splitn(2, "  ")` (two-space literal) — not `split_whitespace()`, not `split(' ')`. This preserves compatibility with GNU coreutils `sha256sum -c`.

**Example:**
```rust
// checksum.rs
/// A parsed line from a GNU coreutils sha256sum file.
/// Format: `<64-hex>  <filename>` (two ASCII spaces, GNU sha256sum standard).
pub(crate) struct ChecksumLine {
    pub hex: String,   // 64-character lowercase SHA256 hex
    pub file: String,  // filename (no path separator expected)
}

impl ChecksumLine {
    pub fn parse(line: &str) -> Result<Self, BundleError> {
        let line = line.trim_end_matches('\n');
        let parts: Vec<&str> = line.splitn(2, "  ").collect(); // two-space literal
        if parts.len() != 2 {
            return Err(BundleError::ManifestInvalid(
                format!("malformed checksums.sha256 line: {:?}", line),
            ));
        }
        let hex = parts[0];
        let file = parts[1];
        if hex.len() != 64 || !hex.chars().all(|c| c.is_ascii_hexdigit()) {
            return Err(BundleError::ManifestInvalid(
                format!("invalid SHA256 hex in checksums.sha256: {:?}", hex),
            ));
        }
        if file.is_empty() {
            return Err(BundleError::ManifestInvalid(
                "empty filename in checksums.sha256".to_string(),
            ));
        }
        Ok(Self { hex: hex.to_string(), file: file.to_string() })
    }
}
```

### Pattern 3: Validated Parsing Struct (image_ref.rs)

**What:** Create an `ImageRef` struct that validates the character set and extracts the tag. The allowlist must include `:` (for port-containing registries) and use `rfind` semantics for tag extraction.

**Critical constraints:**
- Character allowlist: `c.is_ascii_alphanumeric() || matches!(c, '/' | ':' | '.' | '_' | '-')` — this accepts `registry:5000/repo:tag` correctly
- Tag extraction: `rfind(':')` not `find(':')` — ensures `registry:5000/repo:tag` extracts `tag` not `5000/repo:tag`
- Reject: empty string, no `:`, empty tag after `:`, any character outside the allowlist

**Example:**
```rust
// image_ref.rs
/// A validated OCI image reference.
///
/// Accepted characters: alphanumeric, `/`, `:`, `.`, `_`, `-`.
/// Rejects shell metacharacters: `$`, backtick, `|`, `;`, `&`, `<`, `>`, whitespace, newlines.
/// Tag is required and non-empty.
pub(crate) struct ImageRef {
    pub full: String,  // original validated reference string
    pub tag: String,   // version tag extracted via rfind(':')
}

impl ImageRef {
    pub fn parse(raw: &str) -> Result<Self, BundleError> {
        if raw.is_empty() {
            return Err(BundleError::InvalidImageRef(
                "image reference must not be empty".into(),
            ));
        }
        let allowed = |c: char| {
            c.is_ascii_alphanumeric() || matches!(c, '/' | ':' | '.' | '_' | '-')
        };
        if let Some(bad) = raw.chars().find(|c| !allowed(*c)) {
            return Err(BundleError::InvalidImageRef(format!(
                "illegal character {:?} in image reference", bad
            )));
        }
        // Use rfind to correctly handle port-containing registries (e.g., registry:5000/repo:tag)
        match raw.rfind(':') {
            None => Err(BundleError::InvalidImageRef(
                "image reference must include a tag (e.g., registry/repo:1.2.0)".into(),
            )),
            Some(pos) => {
                let tag = &raw[pos + 1..];
                if tag.is_empty() {
                    Err(BundleError::InvalidImageRef(
                        "image tag must not be empty".into(),
                    ))
                } else {
                    Ok(Self { full: raw.to_string(), tag: tag.to_string() })
                }
            }
        }
    }
}
```

### Pattern 4: Adding BundleError Variant

**What:** Add `InvalidImageRef(String)` to `error.rs`. This is the only modification to an existing file in Phase 8.

**Example:**
```rust
// error.rs — add this variant
#[error("invalid image reference: {0}")]
InvalidImageRef(String),
```

This variant does NOT need `#[from]` — it wraps a `String` message, not a foreign error type.

### Pattern 5: Module Declaration in main.rs

**What:** Add `mod format;`, `mod checksum;`, `mod image_ref;` to main.rs. These declarations make the new modules visible to the crate.

```rust
// main.rs — add alongside existing mod declarations
mod checksum;
mod format;
mod image_ref;
```

### Anti-Patterns to Avoid

- **Using `split_whitespace()` in ChecksumLine::parse:** Silently accepts single-space checksum files, loosening the GNU format contract without any compile or runtime error.
- **Using `find(':')` instead of `rfind(':')` in ImageRef::parse:** Extracts `5000/repo` as the "tag" from `registry:5000/repo:tag`, producing a tarball filename with a path separator.
- **Using `create.rs:format_bytes` or `verify.rs:format_bytes` as the canonical model:** Both lack TiB support. The canonical source is `inspect.rs:format_size` (lines 36-53).
- **Making utility functions `pub` instead of `pub(crate)`:** Widens public API surface unnecessarily; these utilities are crate-internal only.
- **Modifying create.rs, verify.rs, or inspect.rs in Phase 8:** Caller switchover is Phase 9. Phase 8 ends with new files compiled alongside unchanged callers.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image reference parsing | Full OCI reference parser | `image_ref.rs` with stdlib char allowlist | `oci-client` brings tokio + reqwest; `docker-image` has EUPL license; the shell-safety goal needs only metacharacter rejection |
| SHA256 checksum file parsing | Ad-hoc split logic scattered in verify.rs | `ChecksumLine::parse()` struct method | Encapsulates the format contract (two-space, 64-hex) in one place with named, testable invariants |
| Format function duplication | Third copy of `format_bytes` | `format.rs::format_bytes` | Three diverging implementations already exist; a fourth would compound the debt |

**Key insight:** All three utility modules require only stdlib string operations plus `BundleError` for error types. Adding any external crate for these operations is over-engineering.

## Common Pitfalls

### Pitfall 1: TiB Regression in format.rs
**What goes wrong:** Developer copies `format_bytes` from `create.rs` or `verify.rs` instead of `format_size` from `inspect.rs`, producing a unified function that silently drops TiB support.
**Why it happens:** All three source functions look similar; the GiB-limited versions are more numerous (2 vs 1).
**How to avoid:** The canonical source is `inspect.rs` lines 36-53. Verify by running the test boundary `format_bytes(1024u64 * 1024 * 1024 * 1024) == "1.0 TiB"` before finishing the module.
**Warning signs:** The word "TiB" does not appear anywhere in `format.rs`. `test_format_size` boundary tests fail.

### Pitfall 2: Double-Space Contract in ChecksumLine
**What goes wrong:** `split_whitespace()` or `split(' ')` replaces `splitn(2, "  ")`. Single-space checksum files are silently accepted.
**Why it happens:** `split_whitespace()` is idiomatic Rust for whitespace splitting; the two-space format is not obvious.
**How to avoid:** Use `splitn(2, "  ")` explicitly. Write a test: `ChecksumLine::parse("a".repeat(64) + " " + "file.tar")` (single space) must return `Err`.
**Warning signs:** No test for single-space rejection in the test suite. `split_whitespace` or `split(' ')` in the parse method.

### Pitfall 3: Port-Containing Registry Rejected by ImageRef
**What goes wrong:** Character allowlist that excludes `:` or validation logic that uses `find(':')` instead of `rfind(':')`.
**Why it happens:** Simple `registry/repo:tag` test cases pass, masking port-containing registry failure.
**How to avoid:** Include `:` in the allowlist. Use `rfind(':')` for tag extraction. Write a mandatory test: `ImageRef::parse("registry:5000/repo:1.2.0")` must return `Ok` with `tag == "1.2.0"`.
**Warning signs:** No test for `registry:5000/repo:tag` in image_ref.rs tests. `find` instead of `rfind` in the tag extraction logic.

### Pitfall 4: Missing Module Declarations in main.rs
**What goes wrong:** New files compile but are not declared in `main.rs`, causing `cargo build` to ignore them (no error, no compilation of new code).
**Why it happens:** Rust requires explicit `mod` declarations; files are not auto-discovered.
**How to avoid:** Add `mod format;`, `mod checksum;`, `mod image_ref;` to `main.rs` immediately when creating each file.
**Warning signs:** `cargo build` succeeds but `cargo test` shows zero tests from the new modules.

### Pitfall 5: BundleError Test in error.rs Breaks
**What goes wrong:** Adding `InvalidImageRef` variant without adding a corresponding case to the `all_error_variants_have_descriptive_messages` test in `error.rs` causes the test to be incomplete but still pass (the test only checks the entries it lists).
**Why it happens:** The test pattern in error.rs explicitly lists variants — it is not exhaustive by construction.
**How to avoid:** When adding `InvalidImageRef` to error.rs, also add a test case for it in `all_error_variants_have_descriptive_messages`.
**Warning signs:** `error.rs` test passes but the new variant is not in the test vector.

## Code Examples

Verified patterns from direct source audit:

### Canonical format_size (source to extract from)
```rust
// Source: inspect.rs lines 36-53 — THIS is the model for format.rs
pub fn format_size(bytes: u64) -> String {
    const TIB: u64 = 1024 * 1024 * 1024 * 1024;
    const GIB: u64 = 1024 * 1024 * 1024;
    const MIB: u64 = 1024 * 1024;
    const KIB: u64 = 1024;

    if bytes >= TIB {
        format!("{:.1} TiB", bytes as f64 / TIB as f64)
    } else if bytes >= GIB {
        format!("{:.1} GiB", bytes as f64 / GIB as f64)
    } else if bytes >= MIB {
        format!("{:.1} MiB", bytes as f64 / MIB as f64)
    } else if bytes >= KIB {
        format!("{:.1} KiB", bytes as f64 / KIB as f64)
    } else {
        format!("{} B", bytes)
    }
}
```

### Existing checksum parsing to encapsulate
```rust
// Source: verify.rs lines 143-168 — this inline logic moves into ChecksumLine::parse
let line = raw.lines().next().unwrap_or("").to_string();
let parts: Vec<&str> = line.splitn(2, "  ").collect();  // two-space literal
if parts.len() != 2
    || parts[0].len() != 64
    || !parts[0].chars().all(|c| c.is_ascii_hexdigit())
{
    // ... push failed CheckResult and return early
}
// (parts[0], parts[1]) → (expected_hash, filename)
```

### Existing image version extraction to encapsulate
```rust
// Source: create.rs lines 71-86 — this inline logic moves into ImageRef::parse
let version = match image.rfind(':') {   // rfind is critical for port-containing registries
    Some(pos) => {
        let tag = &image[pos + 1..];
        if tag.is_empty() {
            return Err(BundleError::PullFailed(
                "image reference must include a tag (e.g., registry/repo:1.2.0)".into(),
            ));
        }
        tag.to_string()
    }
    None => {
        return Err(BundleError::PullFailed(
            "image reference must include a tag (e.g., registry/repo:1.2.0)".into(),
        ));
    }
};
```

### Existing error.rs structure (to know where to add InvalidImageRef)
```rust
// Source: error.rs lines 1-35 — BundleError currently has 9 variants
// Add after line 14 (after OutputExists variant):
#[error("invalid image reference: {0}")]
InvalidImageRef(String),
```

### Module declaration target in main.rs
```rust
// Source: main.rs lines 4-8 — add the three new mod declarations here
mod create;
mod error;
mod format;      // ADD
mod checksum;    // ADD
mod image_ref;   // ADD
mod inspect;
mod manifest;
mod verify;
```

### Existing format_bytes test coverage to copy/extend
```rust
// Source: inspect.rs lines 232-241 — these 8 assertions become format.rs tests
assert_eq!(format_size(0), "0 B");
assert_eq!(format_size(512), "512 B");
assert_eq!(format_size(1023), "1023 B");
assert_eq!(format_size(1024), "1.0 KiB");
assert_eq!(format_size(1048576), "1.0 MiB");
assert_eq!(format_size(1073741824), "1.0 GiB");
assert_eq!(format_size(2147483648), "2.0 GiB");
assert_eq!(format_size(1024u64 * 1024 * 1024 * 1024), "1.0 TiB");
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline `rfind(':')` in create_bundle | `ImageRef::parse()` struct | Phase 8 | Isolates validation from business logic; enables parameterized tests |
| Inline `splitn(2, "  ")` in run_verify | `ChecksumLine::parse()` struct | Phase 8 | Encapsulates format contract; surfaces single-space rejection |
| Three diverging `format_bytes`/`format_size` | Single `format::format_bytes` with TiB | Phase 8 | Eliminates maintenance burden; TiB consistent across all commands |

**Deprecated/outdated (Phase 9 will remove):**
- `create.rs:format_bytes` (lines 27-41): GiB-limited private copy — caller switchover in Phase 9
- `verify.rs:format_bytes` (lines 34-48): GiB-limited private copy — caller switchover in Phase 9
- `inspect.rs:format_size` (lines 36-53): extracted to format.rs — call-site update in Phase 9
- `create.rs:71-86` inline rfind block: replaced by ImageRef::parse — call-site update in Phase 9
- `verify.rs:140-168` inline splitn block: replaced by ChecksumLine::parse — call-site update in Phase 9

## Open Questions

1. **DEDUP-02 and DEDUP-03 scope in Phase 8**
   - What we know: REQUIREMENTS.md assigns DEDUP-02 (create.rs/verify.rs replacement) and DEDUP-03 (inspect.rs replacement) to Phase 8, but the phase description says "no existing code has been modified yet"
   - What's unclear: Whether the caller switchover is part of Phase 8 or deferred to Phase 9
   - Recommendation: The planner must choose — either Phase 8 includes both module creation AND caller switchover (simpler, fewer phases), or Phase 8 creates modules only and Phase 9 handles all callers. The requirements assignment to Phase 8 suggests the intent is for both to happen in Phase 8. Plan accordingly.

2. **`error.rs` is technically an existing file modification**
   - What we know: Adding `InvalidImageRef` variant requires editing error.rs; the phase constraint says "no existing code has been modified yet"
   - What's unclear: Whether this single-line addition counts as "modifying existing code"
   - Recommendation: Adding a variant to an enum is purely additive (no existing behavior changes); treat it as compatible with the "new files only" intent. Plan the BundleError variant addition as a prerequisite task for image_ref.rs.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Rust built-in test harness (`#[test]`) |
| Config file | none — standard `cargo test` |
| Quick run command | `cargo test -p bundle-cli 2>&1 \| tail -20` |
| Full suite command | `cargo test -p bundle-cli` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEDUP-01 | `format_bytes(1024^4) == "1.0 TiB"` | unit | `cargo test -p bundle-cli test_format_bytes` | ❌ Wave 0 — in format.rs |
| DEDUP-01 | All 8 boundary values from test_format_size pass | unit | `cargo test -p bundle-cli test_format_bytes` | ❌ Wave 0 — in format.rs |
| DEDUP-02 | format.rs module compiles and is importable by create.rs | compile | `cargo build -p bundle-cli` | ❌ Wave 0 — format.rs |
| DEDUP-03 | format.rs module compiles and is importable by inspect.rs | compile | `cargo build -p bundle-cli` | ❌ Wave 0 — format.rs |
| VALID-01 | Shell metacharacters (`$`, backtick, `|`, `;`) rejected | unit | `cargo test -p bundle-cli test_image_ref` | ❌ Wave 0 — in image_ref.rs |
| VALID-02 | `ImageRef::parse("registry/repo:1.2.0").tag == "1.2.0"` | unit | `cargo test -p bundle-cli test_image_ref` | ❌ Wave 0 — in image_ref.rs |
| VALID-03 | `ImageRef::parse("registry:5000/repo:1.2.0").tag == "1.2.0"` | unit | `cargo test -p bundle-cli test_image_ref` | ❌ Wave 0 — in image_ref.rs |
| CKSM-01 | `ChecksumLine::parse` extracts hex and filename | unit | `cargo test -p bundle-cli test_checksum_line` | ❌ Wave 0 — in checksum.rs |
| CKSM-02 | Single-space input returns `Err` | unit | `cargo test -p bundle-cli test_checksum_line_single_space` | ❌ Wave 0 — in checksum.rs |

### Sampling Rate
- **Per task commit:** `cargo test -p bundle-cli`
- **Per wave merge:** `cargo test -p bundle-cli`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `crates/bundle-cli/src/format.rs` — covers DEDUP-01/02/03 with `test_format_bytes` matching all 8 boundary values from existing `test_format_size`
- [ ] `crates/bundle-cli/src/checksum.rs` — covers CKSM-01/02 with double-space pass, single-space fail, 63-char hash fail, non-hex fail, empty filename fail, trailing newline pass
- [ ] `crates/bundle-cli/src/image_ref.rs` — covers VALID-01/02/03 with valid ref, missing tag, empty tag, invalid chars, port-containing registry, shell metacharacter rejection

## Sources

### Primary (HIGH confidence)
- Direct source audit: `crates/bundle-cli/src/inspect.rs` lines 36-53 — canonical `format_size` with TiB support confirmed present; 8-case test at lines 232-241 confirmed
- Direct source audit: `crates/bundle-cli/src/verify.rs` lines 140-168 — `splitn(2, "  ")` two-space parsing confirmed; inline `(parts[0], parts[1])` extraction confirmed
- Direct source audit: `crates/bundle-cli/src/create.rs` lines 27-41, 71-86 — GiB-limited `format_bytes` confirmed; `rfind(':')` tag extraction confirmed
- Direct source audit: `crates/bundle-cli/src/error.rs` lines 1-35 — 9 existing variants confirmed; `InvalidImageRef` absent, confirming new variant is needed
- Direct source audit: `crates/bundle-cli/src/main.rs` lines 1-8 — `mod format; mod checksum; mod image_ref;` absent, confirming declarations needed
- `.planning/research/STACK.md` — confirmed no new Cargo.toml deps needed; stdlib-only approach verified
- `.planning/research/PITFALLS.md` — all 6 pitfalls reviewed; Pitfall 1 (TiB), Pitfall 3 (image ref), Pitfall 5 (double-space) are the three directly relevant to Phase 8

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` — build order Steps 1/3/5 map directly to Phase 8 tasks; code examples for all three modules provided
- `.planning/research/SUMMARY.md` — Phase 3 (checksum.rs), Phase 5 (image_ref.rs) from research roadmap align with this phase's scope

### Tertiary (LOW confidence)
- `.planning/codebase/CONCERNS.md` — identifies exact file/line locations for all three extraction targets; analysis date 2026-03-11

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; existing dep set confirmed by Cargo.toml inspection
- Architecture: HIGH — all three utility modules derived from direct source audit of exact current code
- Pitfalls: HIGH — TiB regression, double-space contract, port-registry validation all verified against actual current source code at identified line numbers

**Research date:** 2026-03-13
**Valid until:** Stable — no external dependencies; valid until source files change
