# Testing Patterns

**Analysis Date:** 2026-03-11

## Test Framework

**Runner:**
- `cargo test` (Rust standard test runner)
- Framework: Rust built-in test framework (no external test runner)

**Configuration:**
- `Cargo.toml` specifies test dependencies:
  - `tempfile = "3"` — temporary test directories
  - `assert_cmd = "2"` — integration test command assertions
  - `predicates = "3"` — test predicates for output validation

**Run Commands:**
```bash
# All tests
cargo test --manifest-path crates/bundle-cli/Cargo.toml

# Watch mode (requires cargo-watch, not configured)
cargo watch -x "test --manifest-path crates/bundle-cli/Cargo.toml"

# Via Makefile
make bundle-cli-test

# Specific test
cargo test --manifest-path crates/bundle-cli/Cargo.toml test_verify_valid_bundle

# Integration tests only
cargo test --manifest-path crates/bundle-cli/Cargo.toml --test create_integration

# Ignored tests (e2e with skopeo, requires manual run)
cargo test --manifest-path crates/bundle-cli/Cargo.toml test_create_e2e_with_skopeo -- --ignored
```

## Test File Organization

**Location Patterns:**
- **Unit tests**: Co-located in same file as implementation
- **Integration tests**: Separate files in `tests/` directory

**Structure:**
- Unit tests in `#[cfg(test)] mod tests { ... }` at bottom of each `.rs` file
- Integration tests as standalone `.rs` files in `tests/` directory

**File Listing:**
- `src/error.rs` — 2 unit tests for error message validation
- `src/manifest.rs` — 5 unit tests for JSON serialization/deserialization
- `src/verify.rs` — 11 unit tests covering all verification checks
- `src/inspect.rs` — 8 unit tests for manifest inspection and formatting
- `tests/create_integration.rs` — 6 integration tests for CLI argument parsing and error handling

## Test Structure

**Unit Test Suite Pattern (from `manifest.rs`):**
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    fn make_manifest() -> BundleManifest {
        BundleManifest {
            schema_version: "1.0".to_string(),
            created_at: Utc::now(),
            // ...
        }
    }

    #[test]
    fn manifest_round_trip() {
        let manifest = make_manifest();
        let json = serde_json::to_string(&manifest).unwrap();
        let parsed: BundleManifest = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.schema_version, manifest.schema_version);
    }
}
```

**Integration Test Pattern (from `tests/create_integration.rs`):**
```rust
use assert_cmd::cargo::cargo_bin_cmd;
use predicates::prelude::*;
use std::fs;

fn setup_test_dir() -> tempfile::TempDir {
    tempfile::TempDir::new().expect("failed to create temp dir")
}

#[test]
fn test_create_missing_skopeo() {
    let tmp = setup_test_dir();
    cargo_bin_cmd!("edgeworks-bundle")
        .env("PATH", "")
        .args([...])
        .assert()
        .failure()
        .stderr(predicates::str::contains("skopeo").normalize());
}
```

**Organization Patterns:**

1. **Imports at top** of test module: `use super::*;` brings in all parent module items
2. **Setup functions** (helper factories): `make_manifest()`, `make_valid_bundle()`, `setup_test_dir()`
3. **Test functions** use descriptive names: `test_verify_valid_bundle()`, `test_verify_corrupted_checksum()`
4. **Assertions** use inline asserts or structured comparisons

## Mocking & Test Fixtures

**Framework:** `tempfile` crate for temporary directories, no dedicated mocking framework

**Patterns:**

**File System Fixtures:**
```rust
fn make_valid_bundle() -> (TempDir, String, String, u64) {
    let dir = TempDir::new().unwrap();
    let tarball_name = "edge-os-1.2.0.oci.tar".to_string();
    let tarball_path = dir.path().join(&tarball_name);

    // Write test payload
    let payload = b"fake oci tar content for testing";
    fs::write(&tarball_path, payload).unwrap();

    // Compute real SHA256
    let mut hasher = Sha256::new();
    hasher.update(payload);
    let hex = format!("{:x}", hasher.finalize());
    let size = payload.len() as u64;

    // Write checksums.sha256 and manifest.json
    let checksum_line = format!("{}  {}\n", hex, tarball_name);
    fs::write(dir.path().join("checksums.sha256"), checksum_line).unwrap();

    let manifest = BundleManifest { /* ... */ };
    let json = serde_json::to_string_pretty(&manifest).unwrap();
    fs::write(dir.path().join("manifest.json"), json).unwrap();

    (dir, tarball_name, hex, size)
}
```

**Environment Mocking (in integration tests):**
```rust
cargo_bin_cmd!("edgeworks-bundle")
    .env("PATH", "")  // Simulate missing skopeo
    .args([...])
    .assert()
    .failure()
```

**What to Mock:**
- File system state: create temporary directories with test fixtures
- Environment variables: use `.env()` in `assert_cmd`
- External tool availability: use `PATH` manipulation to simulate missing `skopeo`

**What NOT to Mock:**
- Actual file I/O when testing read/write logic
- Actual hash computation (use real SHA256)
- JSON serialization (test actual serde behavior)
- Core error conditions (intentionally induce them)

## Fixtures and Factories

**Test Data Location:**
- Helper functions in test modules: `make_manifest()`, `make_valid_bundle()`, `setup_test_dir()`
- No separate fixtures directory; factories are private functions in the test module

**Factory Pattern Example (from `verify.rs` tests):**
```rust
fn make_valid_bundle() -> (TempDir, String, String, u64) {
    // Creates a fully valid bundle with correct checksums and manifest
    // Returns (temp_dir, tarball_name, hex_digest, file_size)
    // ... 40 lines of setup
}

#[test]
fn test_verify_valid_bundle() {
    let (dir, _tarball, _hex, _size) = make_valid_bundle();
    let result = run_verify(dir.path()).unwrap();
    assert!(result.valid);
}

#[test]
fn test_verify_corrupted_checksum() {
    let (dir, tarball_name, _hex, _size) = make_valid_bundle();
    // Mutate the fixture for this specific test
    let bad_hash = "a".repeat(64);
    fs::write(dir.path().join("checksums.sha256"), format!("{}  {}\n", bad_hash, tarball_name))
        .unwrap();

    let result = run_verify(dir.path()).unwrap();
    assert!(!result.valid);
}
```

**Fixture Mutation Pattern:**
- Create baseline fixture with `make_valid_bundle()`
- Mutate specific files/fields for error-path tests
- Mutate at top of test before assertions

## Coverage

**Requirements:** Not enforced in CI (no coverage gates)

**View Coverage (manual):**
```bash
# Install tarpaulin
cargo install cargo-tarpaulin

# Generate coverage
cargo tarpaulin --manifest-path crates/bundle-cli/Cargo.toml --out Html

# Coverage report
open tarpaulin-report.html
```

**Current Coverage (estimated from line count):**
- Unit tests: ~90% (26 unit tests across 5 modules, comprehensive error path coverage)
- Integration tests: 5 non-e2e tests + 1 ignored e2e test
- Untested: None detected (error handling, JSON output, verification checks all have explicit tests)

## Test Types

**Unit Tests:**

Scope: Single function or small component in isolation

Location: `#[cfg(test)] mod tests` in each source file

Examples from codebase:
- `test_verify_valid_bundle()` — Tests 6-check verification pass path
- `test_verify_corrupted_checksum()` — Tests SHA256 mismatch detection
- `test_verify_bad_schema_version()` — Tests schema version validation
- `test_manifest_round_trip()` — Tests JSON serialization/deserialization
- `test_all_error_variants_have_descriptive_messages()` — Tests error message quality

**Integration Tests:**

Scope: CLI argument parsing, binary invocation, error handling across subcommands

Location: `tests/` directory

Examples from codebase:
- `test_create_missing_skopeo()` — Verifies error when skopeo not in PATH
- `test_create_existing_output_dir()` — Verifies error when output already has manifest
- `test_create_invalid_image_ref()` — Verifies error for image without tag
- `test_create_json_error_output()` — Verifies JSON error format on stdout
- `test_create_help_shows_flags()` — Verifies help text completeness
- `test_create_e2e_with_skopeo()` — Full e2e test (ignored, manual run)

**E2E Tests:**

Scope: Full CLI workflow with real skopeo tool and network access

Status: **Ignored by default** (marked `#[ignore]`)

Run manually with:
```bash
cargo test --manifest-path crates/bundle-cli/Cargo.toml test_create_e2e_with_skopeo -- --ignored
```

Requires: `skopeo`, `sha256sum`, network access to `docker.io/library/alpine:3.19`

## Common Patterns

**Async Testing:** Not used (codebase is synchronous)

**Error Testing Pattern:**
```rust
#[test]
fn test_verify_corrupted_checksum() {
    let (dir, tarball_name, _hex, _size) = make_valid_bundle();
    // Corrupt the checksum
    let bad_hash = "a".repeat(64);
    let bad_checksum = format!("{}  {}\n", bad_hash, tarball_name);
    fs::write(dir.path().join("checksums.sha256"), bad_checksum).unwrap();

    // Test the error path
    let result = run_verify(dir.path()).unwrap();
    assert!(!result.valid, "Expected invalid bundle due to checksum mismatch");
    let failed: Vec<_> = result.checks.iter().filter(|c| !c.passed).collect();
    assert!(
        failed.iter().any(|c| c.name.contains("SHA256")),
        "Expected SHA256 check to fail, got: {:?}",
        failed
    );
}
```

**Output Validation Pattern (integration tests):**
```rust
#[test]
fn test_create_json_error_output() {
    let output = cargo_bin_cmd!("edgeworks-bundle")
        .args([...])
        .output()
        .unwrap();

    assert!(!output.status.success(), "expected non-zero exit code");

    // Parse and validate JSON output
    let stdout = String::from_utf8_lossy(&output.stdout);
    let parsed: serde_json::Value =
        serde_json::from_str(&stdout).expect("stdout must be valid JSON");

    assert_eq!(parsed["status"].as_str().unwrap(), "error");
    assert!(!parsed["message"].as_str().unwrap_or("").is_empty());
}
```

**Fixture Verification Pattern:**
```rust
#[test]
fn test_verify_valid_bundle() {
    let (dir, _tarball, _hex, _size) = make_valid_bundle();
    let result = run_verify(dir.path()).unwrap();
    assert!(result.valid, "Expected valid bundle, checks: {:?}", result.checks);
    assert_eq!(result.checks.len(), 6);
    assert!(result.checks.iter().all(|c| c.passed));
}
```

**Assertion Styles:**
- Simple comparisons: `assert_eq!(result.schema_version, "1.0")`
- Conditional assertions: `assert!(result.valid)` with message
- Collection assertions: `assert!(result.checks.iter().all(|c| c.passed))`
- String containment: `assert!(output.contains("key text"))`

## Test Execution Flow

**Local Development:**
```bash
cargo test --manifest-path crates/bundle-cli/Cargo.toml
```

**CI Pipeline (GitHub Actions):**
```yaml
- name: Check formatting
  run: make bundle-cli-fmt

- name: Lint
  run: make bundle-cli-lint

- name: Run tests
  run: make bundle-cli-test

- name: Build release binary
  run: make bundle-cli
```

**Quality Gates:** All tests must pass before merge to main

---

*Testing analysis: 2026-03-11*
