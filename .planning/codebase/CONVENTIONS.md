# Coding Conventions

**Analysis Date:** 2026-03-11

## Language & Toolchain

**Primary Language:** Rust 2021 edition

**Compiler & Tools:**
- rustc: stable
- rustfmt: enforced via `cargo fmt` (no custom configuration)
- clippy: enforced with `-D warnings` (deny all warnings)

**Build Command:**
```bash
cargo build --release --manifest-path crates/bundle-cli/Cargo.toml
```

## Naming Patterns

**Files:**
- All lowercase with underscores: `manifest.rs`, `create.rs`, `verify.rs`
- Binary entry point: `src/main.rs`
- Tests co-located in same file as implementation

**Functions:**
- Descriptive snake_case: `run_verify()`, `compute_sha256()`, `format_bytes()`
- Async functions and CLI handlers use `run_*()` prefix: `run_verify()`, `run_inspect()`, `run()`
- Helper functions are private and prefixed descriptively: `make_valid_bundle()`, `setup_test_dir()`
- Formatting functions explicitly named: `format_bytes()`, `format_verify_human()`, `format_verify_json()`

**Variables:**
- Snake_case throughout: `bundle_dir`, `tarball_path`, `checksum_hash`
- Abbreviated when context clear: `dir`, `pb` (progress bar), `tmp`
- Field names in structs: lowercase with underscores: `schema_version`, `size_bytes`, `created_at`

**Types & Structs:**
- PascalCase for all types: `BundleManifest`, `BundleImage`, `VerifyResult`, `CheckResult`
- Enum variants: PascalCase: `PullFailed`, `SkopeoNotAvailable`, `ManifestNotFound`
- Error type: `BundleError` using thiserror crate with `#[error(...)]` messages

**Constants:**
- Not heavily used in codebase; when present use SCREAMING_SNAKE_CASE: `GIB`, `MIB`, `KIB`

## Code Style

**Formatting:**
- Tool: `rustfmt` (default stable settings)
- Line length: implicit (rustfmt default ~99 chars)
- Check with: `make bundle-cli-fmt` (runs `cargo fmt --check`)
- Fix with: `cargo fmt`

**Linting:**
- Tool: `clippy` with `-- -D warnings`
- Check with: `make bundle-cli-lint` (runs `cargo clippy --manifest-path ... -- -D warnings`)
- Zero warnings enforced (clippy lint failures become compiler errors)

**Indentation:**
- 4 spaces (standard Rust, enforced by rustfmt)
- No tabs

## Import Organization

**Order:**
1. Standard library: `use std::...`
2. External crates: `use clap::...`, `use serde::...`
3. Local modules: `use crate::...`

**Path Aliases:**
- Not used in this codebase
- Full paths preferred for clarity: `crate::error::BundleError`, `crate::manifest::BundleManifest`

**Module Declaration:**
- Explicit module imports in `main.rs`:
```rust
mod create;
mod error;
mod inspect;
mod manifest;
mod verify;
```

## Error Handling

**Framework:** `thiserror` crate for custom error types

**Pattern:**
- Single error type per module: `BundleError` enum
- Derive `Error` and `Debug` traits
- Use `#[error(...)]` annotations for display messages with interpolation
- Provide structured error variants: not generic strings

**Example from `error.rs`:**
```rust
#[derive(Error, Debug)]
pub enum BundleError {
    #[error("image pull failed: {0}")]
    PullFailed(String),

    #[error("checksum mismatch: expected {expected}, got {actual}")]
    ChecksumMismatch { expected: String, actual: String },

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}
```

**Exit Codes (see `main.rs`):**
- 0: success
- 1: logical error (bundle invalid, verification failed)
- 2: system error (missing directory, missing tool)

**Error Conversion:**
- Use `?` operator for Result types
- Impl `From<std::io::Error>` for BundleError using `#[from]`
- No panic unwrap in production code (allowed in tests with `.unwrap()`)

## Logging

**Framework:** `eprintln!` for error output (no structured logging framework)

**Patterns:**
- Errors go to stderr: `eprintln!("Error: {e}")`
- Progress uses `indicatif::ProgressBar` (visual feedback)
- JSON output uses `println!` for stdout compatibility
- Human output uses `println!` with formatted strings

**When to Log:**
- Errors and diagnostics: use `eprintln!`
- User progress: use `indicatif::ProgressBar`
- JSON output: use `println!` and `serde_json::to_string_pretty()`

## Comments

**When to Comment:**
- Document intent, not mechanics
- Explain why, not what the code does
- Used heavily in verification logic to explain 6-step checks

**Line Comments:**
- Descriptive section headers with visual separators:
```rust
// ── Check 1: manifest.json exists and parses ────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
```

**Doc Comments:**
- Not heavily used; prefer clear function names instead
- When used: explain the function's behavior, error conditions, return values

**Example from `verify.rs`:**
```rust
/// Run all 6 bundle integrity checks against the given directory.
///
/// Returns `Err(BundleError)` when the bundle directory itself cannot be
/// accessed (maps to exit code 2 in main.rs).  For logical verification
/// failures the function returns `Ok(VerifyResult { valid: false, … })`,
/// which main.rs maps to exit code 1.
pub fn run_verify(bundle_dir: &Path) -> Result<VerifyResult, BundleError>
```

## Function Design

**Size:** Functions typically 20-150 lines; larger functions (like `verify.rs::run_verify` at 230 lines) are procedural with clear step markers

**Parameters:**
- Use value types for small data: `String`, `u64`
- Use references for larger types: `&Path`, `&str`, `&BundleManifest`
- No default arguments (not available in Rust)

**Return Values:**
- Explicit `Result<T, BundleError>` for fallible operations
- Bare types for infallible: `String`, `VerifyResult`
- `Option<T>` used sparingly: `manifest: Option<BundleManifest>` in VerifyResult

**Example (from `create.rs`):**
```rust
fn create_bundle(
    image: &str,
    output: &Path,
    notes: &str,
    target_device: &str,
    json: bool,
) -> Result<BundleResult, BundleError>
```

## Module Design

**Exports:**
- Public functions start with `pub fn`, use clear names
- Private functions and helpers use no `pub` keyword
- Each module has one public run function: `pub fn run(...)` or `pub fn run_verify(...)`
- Formatting functions are public: `pub fn format_bytes(...)`, `pub fn format_verify_human(...)`

**Barrel Files:**
- Not used; explicit imports preferred

**Module-Level Tests:**
- Tests live in `#[cfg(test)] mod tests { ... }` at end of file
- Helper functions like `make_manifest()`, `make_valid_bundle()` are private functions in the tests module
- 4-15 tests per module depending on complexity

## Serialization

**Framework:** `serde` with `serde_json`

**Patterns:**
- Structs derive `Serialize` and `Deserialize`:
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BundleManifest {
    pub schema_version: String,
    pub created_at: DateTime<Utc>,
    // ...
}
```

- Default values: `#[serde(default)]` (see `BundleManifest::notes`)
- Pretty-printing for human output: `serde_json::to_string_pretty()`
- Tight JSON for data interchange: `serde_json::to_string()`

## CLI Design

**Framework:** `clap` with derive macros

**Pattern (from `main.rs`):**
```rust
#[derive(Parser)]
#[command(name = "...", version, about = "...")]
struct Cli {
    #[arg(long, global = true)]
    json: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Create { /* fields with #[arg] */ },
    Verify { /* fields */ },
    Inspect { /* fields */ },
}
```

**Conventions:**
- Global flags on struct: `--json`
- Subcommands in enum: `create`, `verify`, `inspect`
- All args are `--long-form`, no short flags
- Required args have no `default_value`, optional have it
- Documentation strings as `/// Doc comment`

---

*Convention analysis: 2026-03-11*
