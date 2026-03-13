# Architecture Research

**Domain:** Rust CLI — bundle-cli tech debt refactoring
**Researched:** 2026-03-13
**Confidence:** HIGH (based on direct source code analysis)

## Standard Architecture

### Current Module Structure

```
crates/bundle-cli/src/
├── main.rs          # CLI arg parsing (clap), subcommand dispatch, exit codes
├── error.rs         # BundleError enum (thiserror)  — shared
├── manifest.rs      # BundleManifest / BundleImage structs (serde) — shared
├── create.rs        # create subcommand: pull, hash, write bundle
├── verify.rs        # verify subcommand: 6 sequential checks + format_bytes
└── inspect.rs       # inspect subcommand: read manifest + format_size
```

### Post-Refactor Module Structure

```
crates/bundle-cli/src/
├── main.rs          # (unchanged) CLI dispatch
├── error.rs         # (unchanged) BundleError enum
├── manifest.rs      # (unchanged) BundleManifest / BundleImage structs
├── format.rs        # NEW — single format_bytes() with TiB support
├── image_ref.rs     # NEW — ImageRef struct: parse + validate OCI reference
├── checksum.rs      # NEW — ChecksumLine struct: parse checksums.sha256 line
├── create.rs        # MODIFIED — use format::format_bytes, image_ref::ImageRef
├── verify.rs        # MODIFIED — use format::format_bytes, checksum::ChecksumLine,
│                   #   decompose run_verify() into check_* functions
└── inspect.rs       # MODIFIED — use format::format_bytes (drop local format_size)
```

### Component Responsibilities

| Component | Responsibility | Status |
|-----------|----------------|--------|
| `main.rs` | CLI parsing, subcommand dispatch, exit code mapping | Unchanged |
| `error.rs` | `BundleError` enum — all error variants | Unchanged |
| `manifest.rs` | `BundleManifest` / `BundleImage` structs, serde round-trip | Unchanged |
| `format.rs` | Single `format_bytes(u64) -> String` with KiB/MiB/GiB/TiB | New |
| `image_ref.rs` | `ImageRef` struct — parse OCI reference, extract tag/version | New |
| `checksum.rs` | `ChecksumLine` struct — parse `<64-hex>  <filename>` line | New |
| `create.rs` | Bundle creation pipeline: skopeo pull, hash, write files | Modified |
| `verify.rs` | 6 integrity checks, JSON + human output formatters | Modified |
| `inspect.rs` | Read manifest, JSON + human output formatters | Modified |

## Recommended Project Structure

```
crates/bundle-cli/src/
├── main.rs            # Entry point — no logic, only dispatch
├── error.rs           # Error types — foundation layer
├── manifest.rs        # Data types — foundation layer
├── format.rs          # Utility — format_bytes(), used by create/verify/inspect
├── image_ref.rs       # Utility — ImageRef, used by create
├── checksum.rs        # Utility — ChecksumLine, used by verify
├── create.rs          # Command — depends on format, image_ref, manifest, error
├── verify.rs          # Command — depends on format, checksum, manifest, error
└── inspect.rs         # Command — depends on format, manifest, error
```

### Structure Rationale

- **Foundation first (error, manifest):** Both exist already, nothing depends on them
  being changed. They are the dependency root — all other modules import them.

- **Utility layer (format, image_ref, checksum):** New modules that have no
  cross-dependencies on each other. Each utility can be written and tested in
  isolation before touching any command module.

- **Command modules last (create, verify, inspect):** Each is modified to use the new
  utility modules. Changes here are purely call-site rewrites — the public function
  signatures (`run`, `run_verify`, `run_inspect`, `format_*`) stay identical.

## Architectural Patterns

### Pattern 1: Utility Module Extraction

**What:** Move duplicated private functions into a dedicated public utility module.
The original private functions are deleted and callers switch to `crate::format::format_bytes`.

**When to use:** Three or more identical or near-identical implementations exist across
modules. The function has no module-specific state or dependencies.

**Trade-offs:** Zero-risk API change because callers inside the same crate use `crate::` paths.
No public API change visible to binary users.

**Example:**
```rust
// format.rs
pub fn format_bytes(bytes: u64) -> String {
    const TIB: u64 = 1024 * 1024 * 1024 * 1024;
    const GIB: u64 = 1024 * 1024 * 1024;
    // ... KiB, MiB, GiB, TiB
}

// create.rs — before
fn format_bytes(bytes: u64) -> String { /* local duplicate */ }

// create.rs — after
use crate::format::format_bytes;
```

### Pattern 2: Parsing Struct (Parse-Don't-Validate)

**What:** Replace inline string manipulation with a struct that owns parsed fields.
The constructor returns `Result` and encodes format invariants at parse time.
Downstream code works with the validated struct, not raw strings.

**When to use:** A string format is parsed in multiple ways inline, or parsing is
mixed with business logic (e.g., checksum line parsing inside `run_verify`).

**Trade-offs:** Slightly more code up front, but test coverage is isolated to the
struct and downstream logic becomes simpler. Avoids the fragile index-access pattern.

**Example for ChecksumLine:**
```rust
// checksum.rs
pub struct ChecksumLine {
    pub hex: String,      // 64-char SHA256 hex
    pub filename: String,
}

impl ChecksumLine {
    pub fn parse(line: &str) -> Result<Self, BundleError> {
        let parts: Vec<&str> = line.splitn(2, "  ").collect();
        if parts.len() != 2
            || parts[0].len() != 64
            || !parts[0].chars().all(|c| c.is_ascii_hexdigit())
        {
            return Err(BundleError::ManifestInvalid(
                format!("malformed checksums.sha256 line: {:?}", line)
            ));
        }
        Ok(Self { hex: parts[0].to_string(), filename: parts[1].to_string() })
    }
}
```

**Example for ImageRef:**
```rust
// image_ref.rs
pub struct ImageRef {
    pub full: String,
    pub tag: String,   // version extracted from tag
}

impl ImageRef {
    pub fn parse(raw: &str) -> Result<Self, BundleError> {
        // Validate character set: alphanumeric, . : / _ - only
        // Extract tag via rfind(':')
        // Return Err if tag missing or empty
    }
}
```

### Pattern 3: Check Function Decomposition

**What:** Break a monolithic sequential function into composable single-responsibility
check functions. Each returns `Option<CheckResult>` (None = passed with detail,
Some with passed=false = failed). The orchestrator function collects them in order,
short-circuiting on fatal failures.

**When to use:** A function exceeds ~100 lines and performs multiple independent
validation steps with their own early-return paths. The current `run_verify()` at
230 lines is the target.

**Trade-offs:** More functions, but each is testable independently. Adding a new check
is one new function + one line in the orchestrator — not a surgery into a 230-line body.

**Example:**
```rust
fn check_manifest(bundle_dir: &Path) -> Result<(CheckResult, Option<BundleManifest>), BundleError> {
    // Returns Ok((check, Some(manifest))) on pass
    // Returns Ok((check, None)) on logical failure
    // Returns Err on IO error (fatal)
}

fn check_schema_version(manifest: &BundleManifest) -> CheckResult { ... }

fn check_checksums_file(bundle_dir: &Path) -> Result<(CheckResult, Option<ChecksumLine>), BundleError> { ... }

pub fn run_verify(bundle_dir: &Path) -> Result<VerifyResult, BundleError> {
    let mut checks = Vec::new();

    let (c1, manifest) = check_manifest(bundle_dir)?;
    checks.push(c1);
    let manifest = match manifest { Some(m) => m, None => return Ok(fail(checks)) };

    let c2 = check_schema_version(&manifest);
    let passed = c2.passed;
    checks.push(c2);
    if !passed { return Ok(fail(checks)); }

    // ... remaining checks follow the same pattern
}
```

### Pattern 4: JSON Error Propagation (replace unwrap)

**What:** Replace `.unwrap_or_else(|_| "{}".to_string())` with `.map_err(|e|
BundleError::ManifestInvalid(e.to_string()))?`. Serialization of first-party structs
(`BundleManifest`, `CreateOutput`) should never fail in practice; masking with `{}` hides
bugs silently. Propagating the error surfaces problems during development.

**When to use:** Every call site that currently swallows a serde_json error.

**Trade-offs:** The function signature for `format_inspect_json` and `format_verify_json`
must change from `-> String` to `-> Result<String, BundleError>`, and callers in `main.rs`
must handle the error. This is a small caller-side change.

**Locations to fix:**
- `create.rs:222` — `serde_json::to_string_pretty(&out).unwrap()` (no fallback needed: struct is serializable)
- `create.rs:244` — `serde_json::to_string_pretty(&err_out).unwrap()` (same)
- `inspect.rs:93` — `format_inspect_json` returns `String` with `unwrap_or_else(|_| "{}".to_string())`
- `verify.rs:351` — `format_verify_json` returns `String` with `unwrap_or_else(|_| "{}".to_string())`

## Data Flow

### Create Command — After Refactoring

```
main.rs: Commands::Create
    |
    v
image_ref::ImageRef::parse(image)     <- NEW: validates & extracts tag
    |
    v
create::create_bundle()
    |-- skopeo copy -> tarball
    |-- sha256 hash tarball
    |-- write checksums.sha256
    |-- write manifest.json
    |
    v
create::run() formats output
    |-- json=true  -> serde_json::to_string_pretty(&out)?   (propagate error)
    |-- json=false -> format::format_bytes(size_bytes)      <- NEW: shared util
```

### Verify Command — After Refactoring

```
main.rs: Commands::Verify
    |
    v
verify::run_verify(bundle_dir)
    |-- check_manifest()             -> (CheckResult, Option<BundleManifest>)
    |-- check_schema_version()       -> CheckResult
    |-- check_checksums_file()       -> (CheckResult, Option<ChecksumLine>)  <- NEW struct
    |-- check_tarball_exists()       -> (CheckResult, Option<u64>)
    |-- check_sha256()               -> CheckResult
    |-- check_size()                 -> CheckResult
    |
    v
main.rs dispatches to format function
    |-- json=true  -> verify::format_verify_json() -> Result<String, BundleError>
    |-- json=false -> verify::format_verify_human() using format::format_bytes()
```

### Inspect Command — After Refactoring

```
main.rs: Commands::Inspect
    |
    v
inspect::run_inspect(bundle_dir)   (unchanged logic)
    |
    v
main.rs dispatches to format function
    |-- json=true  -> inspect::format_inspect_json() -> Result<String, BundleError>
    |-- json=false -> inspect::format_inspect_human()
                        using format::format_bytes()   <- replaces local format_size()
```

## Integration Points

### New Modules — Callers

| New Module | Caller(s) | Integration |
|------------|-----------|-------------|
| `format.rs` — `format_bytes` | `create.rs`, `verify.rs`, `inspect.rs` | Replace 3 private functions with `use crate::format::format_bytes` |
| `image_ref.rs` — `ImageRef::parse` | `create.rs` only | Replace `rfind(':')` block at lines 71–86 |
| `checksum.rs` — `ChecksumLine::parse` | `verify.rs` only | Replace inline `splitn` block at lines 140–168 |

### Modified Public Interfaces

| Function | Current Signature | After Signature | Callers Affected |
|----------|-------------------|-----------------|------------------|
| `inspect::format_inspect_json` | `-> String` | `-> Result<String, BundleError>` | `main.rs:94` |
| `verify::format_verify_json` | `-> String` | `-> Result<String, BundleError>` | `main.rs:73` |

All other public function signatures (`create::run`, `verify::run_verify`,
`inspect::run_inspect`, `verify::format_verify_human`, `inspect::format_inspect_human`)
are **unchanged**. The binary's CLI interface is entirely unchanged.

### Internal Module Dependencies

```
main.rs
  -> create.rs  -> format.rs
              -> image_ref.rs
              -> manifest.rs
              -> error.rs

  -> verify.rs  -> format.rs
              -> checksum.rs
              -> manifest.rs
              -> error.rs

  -> inspect.rs -> format.rs
              -> manifest.rs
              -> error.rs
```

No cycles. Utility modules (`format`, `image_ref`, `checksum`) have zero
cross-dependencies — they only import `error.rs` if they need to return `BundleError`.

## Build Order

Dependencies constrain the order. Each step can be committed and passes `cargo test`
independently.

### Step 1 — Extract `format.rs` (no callers changed yet)

**Action:** Create `crates/bundle-cli/src/format.rs` with `pub fn format_bytes(bytes: u64) -> String`.
Add `mod format;` to `main.rs`. Do not modify any existing module yet.
**Risk:** None. New file, no existing code touched.
**Test:** Add unit tests in `format.rs` covering KiB/MiB/GiB/TiB/B boundaries.
**Verify:** `cargo test` passes with zero changes to existing tests.

### Step 2 — Switch callers to `format::format_bytes`

**Action:** In `create.rs`, `verify.rs`, and `inspect.rs`, replace local `format_bytes`
/ `format_size` functions with `use crate::format::format_bytes`. Delete the now-redundant
private functions.
**Risk:** Low. Behavioral change only if TiB support matters (create/verify were missing TiB;
inspect had it). Existing test `test_format_size` covers TiB boundary and must pass on the
shared function too.
**Verify:** `cargo test` passes. `test_format_size` in `inspect.rs` tests are implicitly
testing the shared function.

### Step 3 — Extract `checksum.rs` with `ChecksumLine`

**Action:** Create `crates/bundle-cli/src/checksum.rs` with `ChecksumLine::parse`.
Add unit tests for well-formed lines, single-space separator (should fail), short hex, non-hex chars.
**Risk:** None. New file, no existing code touched.
**Verify:** `cargo test` passes.

### Step 4 — Use `ChecksumLine` in `verify.rs`

**Action:** Replace the `splitn` parsing block at `verify.rs:140-168` with
`ChecksumLine::parse(line)?` (or push a failed `CheckResult` and return early). Propagate
the struct's fields instead of the raw `(String, String)` tuple.
**Risk:** Low. The parsing logic is identical; tests cover all paths via existing 9 test cases.
**Verify:** All `verify.rs` tests pass unchanged.

### Step 5 — Extract `image_ref.rs` with `ImageRef`

**Action:** Create `crates/bundle-cli/src/image_ref.rs` with `ImageRef::parse`.
Validate character set (alphanumeric, `.`, `:`, `/`, `_`, `-` only) and require a
non-empty tag. Add unit tests for valid refs, missing tag, empty tag, invalid chars.
**Risk:** None. New file.
**Verify:** `cargo test` passes.

### Step 6 — Use `ImageRef` in `create.rs`

**Action:** Replace the `rfind(':')` block at `create.rs:71-86` with
`ImageRef::parse(image)?`. Use `image_ref.tag` as `version`.
**Risk:** Low. Existing integration test `test_create_invalid_image_ref` covers empty tag.
The new validation is strictly tighter (adds char-set check), which is correct behavior.
**Verify:** All `create.rs` tests pass. The new char-set test cases from Step 5 now also
exercise the create code path.

### Step 7 — Decompose `run_verify()` into check functions

**Action:** Extract each of the 6 check blocks in `run_verify()` (lines 65–285) into
a private function: `check_manifest`, `check_schema_version`, `check_checksums_file`,
`check_tarball_exists`, `check_sha256`, `check_file_size`. Rewrite `run_verify` as
an orchestrator calling these in order.
**Risk:** Medium. This is the largest single change. Mitigation: the 9 existing test
cases cover all check paths and must all pass. Run `cargo test` after each extracted
function, not only at the end.
**Verify:** All 9 `verify.rs` test cases pass with no changes to test code.

### Step 8 — Propagate JSON serialization errors

**Action:** Change `inspect::format_inspect_json` and `verify::format_verify_json` from
`-> String` to `-> Result<String, BundleError>`. Update `main.rs` call sites to handle
`Err` (write to stderr and exit 1). Replace `.unwrap_or_else(|_| "{}".to_string())` with
`?`. In `create.rs`, replace `.unwrap()` on `serde_json::to_string_pretty` calls with
`map_err(|e| BundleError::ManifestInvalid(e.to_string()))?`.
**Risk:** Low. These are compile-checked signature changes. If serialization of owned
structs ever fails (which it shouldn't in practice), users now get a clear error message
rather than `{}`.
**Verify:** `cargo test` passes. `test_format_verify_json_valid` and
`test_format_inspect_json_output` must still pass.

## Anti-Patterns

### Anti-Pattern 1: Changing Public CLI Behavior During Debt Fixes

**What people do:** Rename output fields, change exit codes, or alter human output
formatting while refactoring internals.
**Why it's wrong:** This conflates two concerns and makes it hard to isolate regressions.
The v1.2 goal is internal quality only — operators' scripts must not break.
**Do this instead:** Keep all public-facing behavior (output field names, exit codes,
human text format) identical. Only internal module boundaries and private function
signatures change.

### Anti-Pattern 2: Big-Bang Refactor in One Commit

**What people do:** Implement all 6 items in one PR because they feel related.
**Why it's wrong:** A test failure anywhere blocks the entire change. Bisecting is
harder. Review surface is large.
**Do this instead:** Follow the 8-step build order above. Each step compiles and
passes all tests independently. Steps 1-2 (format module) are the simplest and
validate the pattern before the riskier Step 7 (verify decomposition).

### Anti-Pattern 3: Introducing New Dependencies for Parsing

**What people do:** Add the `oci-spec` crate to parse image references properly.
**Why it's wrong:** The CONCERNS.md audit notes this as an option, but the existing
format (`registry/repo:tag`) is simple enough that a focused validation function with a
character whitelist is sufficient and introduces no supply-chain risk. `oci-spec` is a
large crate with its own dependencies.
**Do this instead:** Write `ImageRef::parse` with an explicit character whitelist regex
or manual character check. Document the format assumption in a comment. Reserve
`oci-spec` for if digest references (`@sha256:...`) or multi-platform refs become needed.

## Scaling Considerations

This is a single-binary CLI tool, not a service. Traditional scaling does not apply.
The relevant "scale" axis is codebase maintainability as checks and commands are added.

| Concern | Now (6 checks) | Future (10+ checks) |
|---------|----------------|---------------------|
| Adding a check | Requires editing 230-line `run_verify` body | Add one `check_*` function, one call in orchestrator |
| Adding a command | Add a module, add arm in `main.rs` | Same pattern, `format::format_bytes` already available |
| Supporting new hash algorithm | Hardcoded SHA256 everywhere | `ChecksumLine` struct can add `algorithm` field cleanly |

## Sources

- Direct source analysis: `/Users/ravichillerega/sources/management/os-builder/crates/bundle-cli/src/`
- Tech debt audit: `.planning/codebase/CONCERNS.md` (2026-03-11)
- Project goals: `.planning/PROJECT.md` (v1.2 milestone)

---
*Architecture research for: bundle-cli v1.2 tech debt refactoring*
*Researched: 2026-03-13*
