# Phase 10: Error Hardening - Research

**Researched:** 2026-03-13
**Domain:** Rust error propagation — replacing silent `unwrap_or_else` fallbacks with typed `Result` propagation through thiserror/serde_json
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ERR-01 | JSON serialization failures propagate as `BundleError::JsonSerialize` instead of returning empty `{}` | `thiserror` `#[from] serde_json::Error` pattern is confirmed compatible with existing dep versions; `BundleError::JsonSerialize` variant must be added to `error.rs` |
| ERR-02 | All `unwrap_or_else(\|_\| "{}".to_string())` patterns removed from create.rs, verify.rs, and inspect.rs | 4 distinct sites (create.rs:222, create.rs:244, inspect.rs:93, verify.rs:351), each requires individual treatment; two are terminal `.unwrap()` calls, two return `String` that must change to `Result<String, BundleError>` |
</phase_requirements>

---

## Summary

Phase 10 targets four `unwrap_or_else(|_| "{}".to_string())` (and `.unwrap()`) sites that silently swallow JSON serialization errors and emit empty `{}` output. The fix has two parts: (1) add a `BundleError::JsonSerialize(#[from] serde_json::Error)` variant to `error.rs`, and (2) treat each site individually because their error-handling contexts differ.

Two sites in `create.rs` (lines 222 and 244) are terminal calls inside `run()` that invoke `serde_json::to_string_pretty` on structs (`CreateOutput` and a `json!({})` literal). Line 222 serializes a `CreateOutput` struct and can be changed to `?` with proper propagation. Line 244 serializes an inline `json!({...})` literal — this is infallible by construction and should use `expect()` not `?`. The `format_inspect_json` function in `inspect.rs:93` and `format_verify_json` in `verify.rs:351` currently return `String`; both must be changed to `Result<String, BundleError>` so their callers in `main.rs` can handle the error explicitly.

The primary risk is the `main.rs` exit-code contract (exit 0/1/2). Inspect errors and verify errors flow through separate match arms in `main.rs`. When `format_inspect_json` and `format_verify_json` change signatures, `main.rs` must be updated to propagate the error with the correct exit code — a JSON serialization failure during inspect or verify should exit 1 (logic failure), not 2 (path not found). This mapping must be explicitly coded, not left to the catch-all arm. An integration test asserting numeric exit codes closes the gap that currently exists (no integration test currently verifies numeric exit codes).

**Primary recommendation:** Add `BundleError::JsonSerialize(#[from] serde_json::Error)` to `error.rs`, change `format_inspect_json` and `format_verify_json` to `Result<String, BundleError>`, update `main.rs` to handle the new return types with correct exit codes, replace `create.rs:222` `.unwrap()` with `?`, and replace `create.rs:244` `.unwrap()` with `.expect("infallible: json literal")`.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `thiserror` | 2 (already in Cargo.toml) | Derive `Error` for `BundleError` variants | Already used for all existing variants; `#[from] serde_json::Error` is a single-line addition |
| `serde_json` | 1 (already in Cargo.toml) | JSON serialization/deserialization | Already used everywhere; `serde_json::Error` is the type being wrapped |

### No New Dependencies

No new entries in `Cargo.toml` are required. All changes use the existing `thiserror 2` and `serde_json 1` that are already present. This was verified directly in `crates/bundle-cli/Cargo.toml` via the prior codebase audit.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `BundleError::JsonSerialize(#[from] serde_json::Error)` | `BundleError::ManifestInvalid(String)` reused | Using `ManifestInvalid` mixes two semantically different errors (malformed input vs serialization failure), making it impossible to distinguish in `main.rs` match arms if separate exit codes are ever needed |
| `expect("infallible: ...")` on json literal | `?` propagation | `json!({...})` literals are infallible; using `?` introduces unnecessary `Result` unwrapping overhead and misleads readers into thinking a legitimate failure path exists |

---

## Architecture Patterns

### Current State (to be changed)

```
create.rs:run()
  └── serde_json::to_string_pretty(&out).unwrap()             // line 222 — struct, should use ?
  └── serde_json::to_string_pretty(&err_out).unwrap()         // line 244 — json! literal, use expect()

inspect.rs
  └── format_inspect_json(&manifest) -> String                // returns String, line 93 uses unwrap_or_else
      serde_json::to_string_pretty(manifest).unwrap_or_else(|_| "{}".to_string())

verify.rs
  └── format_verify_json(&result, path) -> String             // returns String, line 351 uses unwrap_or_else
      serde_json::to_string_pretty(&value).unwrap_or_else(|_| "{}".to_string())

main.rs
  └── print!("{}", verify::format_verify_json(&result, path));   // direct call, no error handling
  └── print!("{}", inspect::format_inspect_json(&manifest));     // direct call, no error handling
```

### Target State (after Phase 10)

```
error.rs
  └── BundleError::JsonSerialize(#[from] serde_json::Error)   // NEW VARIANT

create.rs:run()
  └── serde_json::to_string_pretty(&out)?                     // line 222 — propagates via ?
  └── serde_json::to_string_pretty(&err_out)                  // line 244 — .expect("infallible")
      .expect("infallible: json literal cannot fail")

inspect.rs
  └── format_inspect_json(&manifest) -> Result<String, BundleError>  // signature changes
      serde_json::to_string_pretty(manifest)                         // maps via #[from]
      .map_err(BundleError::JsonSerialize)                           // or just ?

verify.rs
  └── format_verify_json(&result, path) -> Result<String, BundleError>  // signature changes
      serde_json::to_string_pretty(&value)                             // maps via #[from]
      .map_err(BundleError::JsonSerialize)                             // or just ?

main.rs (Inspect arm)
  └── match inspect::run_inspect(path) {
          Ok(manifest) => {
              if cli.json {
                  match inspect::format_inspect_json(&manifest) {
                      Ok(json) => print!("{}", json),
                      Err(e) => { eprintln!("Error: {e}"); std::process::exit(1); }
                  }
              } else { ... }
          }
          Err(e) => { ... }
      }

main.rs (Verify arm)
  └── match verify::run_verify(path) {
          Ok(result) => {
              if cli.json {
                  match verify::format_verify_json(&result, path) {
                      Ok(json) => print!("{}", json),
                      Err(e) => { eprintln!("Error: {e}"); std::process::exit(1); }
                  }
              } else { ... }
          }
          Err(e) => { ... }
      }
```

### Pattern: thiserror `#[from]` for serde_json::Error

```rust
// Source: thiserror documentation, confirmed with existing dep version
// In error.rs:
#[derive(Error, Debug)]
pub enum BundleError {
    // ... existing variants ...

    #[error("JSON serialization failed: {0}")]
    JsonSerialize(#[from] serde_json::Error),
}
```

With `#[from]` in place, call sites can use `?` directly:

```rust
// In inspect.rs:
pub fn format_inspect_json(manifest: &BundleManifest) -> Result<String, BundleError> {
    Ok(serde_json::to_string_pretty(manifest)?)
}
```

### Pattern: `expect()` for Infallible Serialization

```rust
// In create.rs line 244 — json! literal is a serde_json::Value which cannot fail to serialize
let err_out = serde_json::json!({
    "status": "error",
    "message": e.to_string()
});
println!("{}", serde_json::to_string_pretty(&err_out)
    .expect("infallible: serde_json::Value serialization cannot fail"));
```

`serde_json::Value` never contains non-string map keys or unencodable types, so serialization is guaranteed to succeed. Using `.expect()` with a message documents the invariant rather than hiding it.

### Anti-Patterns to Avoid

- **Reusing `BundleError::ManifestInvalid` for JSON serialization errors:** Conflates two distinct failure modes. The exit code semantics in `main.rs` are already matched on variant names. A future requirement to distinguish serialization errors from parse errors becomes impossible if they share a variant.
- **Adding `?` to create.rs line 244 (`json!` literal):** The `?` operator implies a failure path exists. For a `json!` literal, no such path exists. Misleads readers and adds unnecessary `Result` propagation logic.
- **Catching JsonSerialize in main.rs catch-all only:** The `create::run()` function already flows through the `if let Err(e) = result { std::process::exit(1) }` catch-all at line 113. For `inspect` and `verify` commands, the new error must be handled in their respective match arms, not left to a non-existent catch-all (the verify/inspect arms in `main.rs` do not return a `Result` — they call `std::process::exit()` directly).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Wrapping `serde_json::Error` | Custom error struct with String message | `#[from] serde_json::Error` in thiserror | `#[from]` provides automatic `From<serde_json::Error> for BundleError` impl; keeps the original error available for display; zero boilerplate |
| Testing JSON serialization can fail | Mock serde or inject failure | Trust the type system: document infallible sites with `expect()`, propagate fallible sites with `?` | `BundleManifest` and `CreateOutput` are plain Rust structs with string/number fields; they cannot fail to serialize. Testing a false failure path adds confusion. |
| Exit code integration test | Shell script wrapping cargo test | `assert_cmd` crate (already in dev-dependencies via `create_integration.rs`) | `assert_cmd` provides `.code()` predicate for numeric exit code assertions; already a dev-dependency |

---

## Common Pitfalls

### Pitfall 1: Propagating `?` from format_inspect_json / format_verify_json Breaks main.rs

**What goes wrong:** `format_inspect_json` and `format_verify_json` are called inside match arms that call `std::process::exit()` directly (not through `?` propagation). The `main.rs` arms for inspect and verify do not return a `Result`. Changing the function signatures forces those call sites to become `match` expressions, not just `print!` calls. If this is done carelessly, the `Err` arm uses the wrong exit code.

**Why it happens:** The developer changes the function signature, the compiler forces the call site to handle the `Result`, and the simplest fix is `.unwrap()` at the call site — which is precisely the anti-pattern being eliminated.

**How to avoid:** For each changed call site in `main.rs`, explicitly write the `Err` arm with `eprintln!("Error: {e}")` and `std::process::exit(1)`. Do not `.unwrap()` at the call site.

**Warning signs:** `.unwrap()` appearing in `main.rs` after the refactor.

### Pitfall 2: Exit Code Semantics Change for Inspect Errors

**What goes wrong:** `main.rs` already has logic distinguishing `ManifestNotFound` (exit 2) from all other inspect errors (exit 1). A `JsonSerialize` error during inspect formatting should exit 1 (logic failure), not 2 (path not found). If the new error is routed through the outer `Err(e)` inspect arm rather than handled inline after formatting, it could hit the `ManifestNotFound` match and exit 2 incorrectly.

**Why it happens:** The outer inspect `Err(e)` arm only handles errors from `run_inspect()`. The JSON formatting error is a new error from `format_inspect_json()`. These are separate calls; their errors must be handled in separate match arms.

**How to avoid:** Handle the `format_inspect_json` error inline (after the `run_inspect` success arm), not by folding it into the outer `Err(e)` arm. The code structure must be:
```
match run_inspect() {
  Ok(manifest) => {
    // handle format error HERE, exit 1 on failure
  }
  Err(e) => {
    // existing ManifestNotFound -> exit 2 logic
  }
}
```

**Warning signs:** The outer `match e { ManifestNotFound => exit(2), _ => exit(1) }` block handling a `JsonSerialize` variant.

### Pitfall 3: `error.rs` Test Suite Must Cover New Variant

**What goes wrong:** `error.rs` has `all_error_variants_have_descriptive_messages()` — a comprehensive test that constructs every `BundleError` variant and checks its `to_string()`. Adding `JsonSerialize` without updating this test leaves a variant with no message coverage assertion.

**Why it happens:** New variants are added to the enum but the test file is not opened.

**How to avoid:** Add `BundleError::JsonSerialize` to the test vec in `error.rs` tests. Constructing a `serde_json::Error` for the test requires triggering a real parse failure: `serde_json::from_str::<serde_json::Value>("invalid").unwrap_err()`.

**Warning signs:** `error.rs` test vec length stays the same after adding the variant.

### Pitfall 4: create.rs line 222 `run()` Return Type

**What goes wrong:** `create::run()` returns `Result<(), BundleError>`. Adding `?` at line 222 (`serde_json::to_string_pretty(&out)?`) inside the `Ok(result)` arm inside the `match create_bundle(...)` block works correctly — the `?` propagates up through the `Ok` arm and out of `run()`. However, line 244 is inside the `Err(e)` arm which calls `std::process::exit(1)` — that arm cannot use `?` propagation because the function exits unconditionally. Using `.expect()` there is correct.

**Why it happens:** Both lines look similar but are in different code paths with different exit semantics.

**How to avoid:** Line 222 uses `?`; line 244 uses `.expect("infallible: ...")`. These are not symmetric changes.

---

## Code Examples

### Adding BundleError::JsonSerialize to error.rs

```rust
// Source: thiserror docs + direct analysis of existing error.rs
use thiserror::Error;

#[derive(Error, Debug)]
#[allow(dead_code)]
pub enum BundleError {
    // ... all existing variants unchanged ...

    #[error("JSON serialization failed: {0}")]
    JsonSerialize(#[from] serde_json::Error),
}
```

The `#[from]` attribute generates `impl From<serde_json::Error> for BundleError` automatically. No explicit conversion code needed at call sites.

### Updated format_inspect_json in inspect.rs

```rust
// Before (line 92-94):
pub fn format_inspect_json(manifest: &BundleManifest) -> String {
    serde_json::to_string_pretty(manifest).unwrap_or_else(|_| "{}".to_string())
}

// After:
pub fn format_inspect_json(manifest: &BundleManifest) -> Result<String, BundleError> {
    Ok(serde_json::to_string_pretty(manifest)?)
}
```

### Updated format_verify_json in verify.rs

```rust
// Before (line 322, return on line 351):
pub fn format_verify_json(result: &VerifyResult, bundle_dir: &Path) -> String {
    // ... builds `value` serde_json::Value ...
    serde_json::to_string_pretty(&value).unwrap_or_else(|_| "{}".to_string())
}

// After:
pub fn format_verify_json(result: &VerifyResult, bundle_dir: &Path) -> Result<String, BundleError> {
    // ... builds `value` serde_json::Value (unchanged) ...
    Ok(serde_json::to_string_pretty(&value)?)
}
```

### Updated main.rs Inspect arm

```rust
// Before (main.rs lines 91-109):
Commands::Inspect { path } => {
    match inspect::run_inspect(path) {
        Ok(manifest) => {
            if cli.json {
                print!("{}", inspect::format_inspect_json(&manifest));
            } else {
                print!("{}", inspect::format_inspect_human(&manifest, path));
            }
            std::process::exit(0);
        }
        Err(e) => {
            eprintln!("Error: {e}");
            match e {
                crate::error::BundleError::ManifestNotFound(_) => std::process::exit(2),
                _ => std::process::exit(1),
            }
        }
    }
}

// After:
Commands::Inspect { path } => {
    match inspect::run_inspect(path) {
        Ok(manifest) => {
            if cli.json {
                match inspect::format_inspect_json(&manifest) {
                    Ok(json) => print!("{}", json),
                    Err(e) => {
                        eprintln!("Error: {e}");
                        std::process::exit(1);
                    }
                }
            } else {
                print!("{}", inspect::format_inspect_human(&manifest, path));
            }
            std::process::exit(0);
        }
        Err(e) => {
            eprintln!("Error: {e}");
            match e {
                crate::error::BundleError::ManifestNotFound(_) => std::process::exit(2),
                _ => std::process::exit(1),
            }
        }
    }
}
```

### Updated main.rs Verify arm

```rust
// Before (main.rs lines 69-88):
Commands::Verify { path } => {
    match verify::run_verify(path) {
        Ok(result) => {
            if cli.json {
                print!("{}", verify::format_verify_json(&result, path));
            } else {
                print!("{}", verify::format_verify_human(&result, path));
            }
            if result.valid {
                std::process::exit(0);
            } else {
                std::process::exit(1);
            }
        }
        Err(e) => {
            eprintln!("Error: {e}");
            std::process::exit(2);
        }
    }
}

// After:
Commands::Verify { path } => {
    match verify::run_verify(path) {
        Ok(result) => {
            if cli.json {
                match verify::format_verify_json(&result, path) {
                    Ok(json) => print!("{}", json),
                    Err(e) => {
                        eprintln!("Error: {e}");
                        std::process::exit(1);
                    }
                }
            } else {
                print!("{}", verify::format_verify_human(&result, path));
            }
            if result.valid {
                std::process::exit(0);
            } else {
                std::process::exit(1);
            }
        }
        Err(e) => {
            eprintln!("Error: {e}");
            std::process::exit(2);
        }
    }
}
```

### create.rs line 222 — replace `.unwrap()` with `?`

```rust
// Before (create.rs:222 inside Ok(result) arm):
println!("{}", serde_json::to_string_pretty(&out).unwrap());

// After (? propagates through run() -> Result<(), BundleError>):
println!("{}", serde_json::to_string_pretty(&out)?);
```

### create.rs line 244 — replace `.unwrap()` with `.expect()`

```rust
// Before (create.rs:244 inside Err(e) arm — exits unconditionally with process::exit(1)):
println!("{}", serde_json::to_string_pretty(&err_out).unwrap());

// After (json! literal is infallible — document invariant with expect):
println!("{}", serde_json::to_string_pretty(&err_out)
    .expect("infallible: serde_json::Value cannot fail to serialize"));
std::process::exit(1);
```

### Integration test for exit codes (in create_integration.rs or new file)

```rust
// Source: assert_cmd docs — .code() predicate for numeric exit code
use assert_cmd::cargo::cargo_bin_cmd;

#[test]
fn test_verify_nonexistent_path_exits_2() {
    cargo_bin_cmd!("edgeworks-bundle")
        .args(["verify", "/tmp/definitely-does-not-exist-xyzzy-bundle-99999"])
        .assert()
        .code(2);
}

#[test]
fn test_inspect_nonexistent_path_exits_2() {
    cargo_bin_cmd!("edgeworks-bundle")
        .args(["inspect", "/tmp/definitely-does-not-exist-xyzzy-bundle-99999"])
        .assert()
        .code(2);
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.unwrap_or_else(\|_\| "{}".to_string())` | `?` propagation with typed `BundleError::JsonSerialize` | Phase 10 | Operators see diagnostic messages instead of silent empty JSON |
| Terminal `.unwrap()` on infallible json! literal | `.expect("infallible: ...")` | Phase 10 | Documents invariant, no behavior change |
| `format_inspect_json() -> String` | `format_inspect_json() -> Result<String, BundleError>` | Phase 10 | Enables compile-time enforcement of error handling at call sites |
| `format_verify_json() -> String` | `format_verify_json() -> Result<String, BundleError>` | Phase 10 | Same as above for verify path |

**Nothing deprecated in this phase** — this phase only adds one new `BundleError` variant and changes two function signatures. All existing `BundleError` variants and their error messages remain identical.

---

## Open Questions

1. **Should `create.rs:244` also change to `?`?**
   - What we know: Line 244 serializes `serde_json::json!({...})` — a literal `serde_json::Value`. This cannot fail to serialize because `Value` is always a valid JSON type.
   - What's unclear: Whether the planner should treat this as a second `?` site or explicitly as `expect()`.
   - Recommendation: Use `.expect("infallible: serde_json::Value serialization cannot fail")` — this is the correct Rust idiom for documenting a known-unreachable error path. Using `?` on an infallible path misleads readers and creates unnecessary code paths.

2. **Should the integration test go in `create_integration.rs` or a new `cli_integration.rs`?**
   - What we know: `create_integration.rs` already uses `assert_cmd` and tests CLI exit codes (via `.failure()` not `.code()`). Exit code assertions for verify/inspect need to live somewhere.
   - What's unclear: Whether mixing verify/inspect tests into `create_integration.rs` is appropriate.
   - Recommendation: Create `crates/bundle-cli/tests/exit_codes.rs` as a focused test file for exit code contract assertions. Keeps concerns separate and makes the intent explicit.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Rust built-in (`#[test]`) + `assert_cmd` for CLI integration tests |
| Config file | `crates/bundle-cli/Cargo.toml` — dev-dependencies include `assert_cmd`, `tempfile`, `predicates` |
| Quick run command | `cargo test --manifest-path crates/bundle-cli/Cargo.toml` |
| Full suite command | `cargo test --manifest-path crates/bundle-cli/Cargo.toml` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ERR-01 | `BundleError::JsonSerialize` variant exists and has descriptive message | unit | `cargo test --manifest-path crates/bundle-cli/Cargo.toml error::tests` | ❌ Wave 0: add variant to `all_error_variants_have_descriptive_messages` in `error.rs` |
| ERR-01 | `format_inspect_json` returns `Result`, not `String` | compile-time | `cargo build --manifest-path crates/bundle-cli/Cargo.toml` | ❌ Wave 0: change signature |
| ERR-01 | `format_verify_json` returns `Result`, not `String` | compile-time | `cargo build --manifest-path crates/bundle-cli/Cargo.toml` | ❌ Wave 0: change signature |
| ERR-02 | No `unwrap_or_else(\|_\| "{}".to_string())` patterns remain | unit (compile + grep) | `cargo test --manifest-path crates/bundle-cli/Cargo.toml` | ❌ Wave 0: all four sites must be replaced |
| ERR-02 | Exit code 2 on nonexistent path to verify | integration | `cargo test --manifest-path crates/bundle-cli/Cargo.toml exit_codes` | ❌ Wave 0: `tests/exit_codes.rs` |
| ERR-02 | Exit code 2 on nonexistent path to inspect | integration | `cargo test --manifest-path crates/bundle-cli/Cargo.toml exit_codes` | ❌ Wave 0: `tests/exit_codes.rs` |
| ERR-01/ERR-02 | All existing inspect tests pass (signature change is backward-compat for unit tests) | unit | `cargo test --manifest-path crates/bundle-cli/Cargo.toml inspect::tests` | ✅ `src/inspect.rs` — existing tests must remain green |
| ERR-01/ERR-02 | All existing verify tests pass | unit | `cargo test --manifest-path crates/bundle-cli/Cargo.toml verify::tests` | ✅ `src/verify.rs` — existing 9 verify tests must remain green |

### Sampling Rate

- **Per task commit:** `cargo test --manifest-path crates/bundle-cli/Cargo.toml`
- **Per wave merge:** `cargo test --manifest-path crates/bundle-cli/Cargo.toml`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `crates/bundle-cli/tests/exit_codes.rs` — covers exit code 2 assertions for verify and inspect on nonexistent paths (ERR-02)
- [ ] `error.rs` test update — add `BundleError::JsonSerialize` to `all_error_variants_have_descriptive_messages` test vec (ERR-01)
- [ ] Framework install: none required — `assert_cmd`, `tempfile`, `predicates` already in dev-dependencies

---

## Sources

### Primary (HIGH confidence)

- Direct source audit of `crates/bundle-cli/src/` — `create.rs`, `verify.rs`, `inspect.rs`, `error.rs`, `main.rs` read in full during this research session (2026-03-13)
- `.planning/codebase/CONCERNS.md` — confirmed line numbers for all 4 unwrap sites (create.rs:222, create.rs:244, inspect.rs:93, verify.rs:351)
- `.planning/research/SUMMARY.md` — architecture analysis confirming `#[from] serde_json::Error` pattern compatibility
- `.planning/research/PITFALLS.md` — Pitfall 2 (exit code contract breakage) directly covers this phase's risk

### Secondary (MEDIUM confidence)

- [thiserror + serde_json::Error pattern](https://oneuptime.com/blog/post/2026-01-25-error-types-thiserror-anyhow-rust/view) — `#[from] serde_json::Error` confirmed Jan 2026
- [Rust Book ch12-03](https://doc.rust-lang.org/book/ch12-03-improving-error-handling-and-modularity.html) — exit code contract patterns, confirmed MEDIUM

### Tertiary (LOW confidence)

None — all findings are based on direct code audit or official sources.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; existing thiserror and serde_json are confirmed in Cargo.toml
- Architecture: HIGH — all 4 sites read directly from source; main.rs exit code contract read directly
- Pitfalls: HIGH — derived from direct source analysis; exit code mapping logic read line-by-line

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable Rust stdlib + thiserror 2 + serde_json 1; no fast-moving ecosystem)
