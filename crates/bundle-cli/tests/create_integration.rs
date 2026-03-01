/// Integration tests for `edgeworks-bundle create`.
///
/// These tests cover error paths and CLI argument parsing that work in any environment
/// (no skopeo or network access required). A full end-to-end test that actually pulls
/// an image is included but marked `#[ignore]` — run it manually with skopeo installed:
///
///   cargo test --manifest-path crates/bundle-cli/Cargo.toml test_create_e2e_with_skopeo -- --ignored
use assert_cmd::cargo::cargo_bin_cmd;
use predicates::prelude::*;
use std::fs;

/// Create a temp directory for use in a test.
fn setup_test_dir() -> tempfile::TempDir {
    tempfile::TempDir::new().expect("failed to create temp dir")
}

/// Test 1: when skopeo is not in PATH, CLI prints an error containing "skopeo" and exits non-zero.
#[test]
fn test_create_missing_skopeo() {
    let tmp = setup_test_dir();

    cargo_bin_cmd!("edgeworks-bundle")
        .env("PATH", "") // skopeo not available
        .args(["create", "--image", "registry/repo:1.0", "--output", tmp.path().join("bundle").to_str().unwrap()])
        .assert()
        .failure()
        .stderr(predicates::str::contains("skopeo").normalize());
}

/// Test 2: when output directory already contains manifest.json, CLI returns an error.
#[test]
fn test_create_existing_output_dir() {
    let tmp = setup_test_dir();
    let output_dir = tmp.path().join("bundle");
    fs::create_dir_all(&output_dir).unwrap();
    fs::write(output_dir.join("manifest.json"), "{}").unwrap();

    cargo_bin_cmd!("edgeworks-bundle")
        .args(["create", "--image", "test:1.0", "--output", output_dir.to_str().unwrap()])
        .assert()
        .failure()
        .stderr(
            predicates::str::contains("already contains")
                .or(predicates::str::contains("exists")),
        );
}

/// Test 3: an image reference without a tag produces an error mentioning "tag".
#[test]
fn test_create_invalid_image_ref() {
    let tmp = setup_test_dir();
    let output_dir = tmp.path().join("bundle");

    cargo_bin_cmd!("edgeworks-bundle")
        .args(["create", "--image", "registry/repo", "--output", output_dir.to_str().unwrap()])
        .assert()
        .failure()
        .stderr(predicates::str::contains("tag").normalize());
}

/// Test 4: `--json` mode outputs JSON to stdout on error (not just stderr).
#[test]
fn test_create_json_error_output() {
    let tmp = setup_test_dir();
    let output_dir = tmp.path().join("bundle");
    // Create an existing bundle dir so we get OutputExists error
    fs::create_dir_all(&output_dir).unwrap();
    fs::write(output_dir.join("manifest.json"), "{}").unwrap();

    let output = cargo_bin_cmd!("edgeworks-bundle")
        .args([
            "--json",
            "create",
            "--image", "test:1.0",
            "--output", output_dir.to_str().unwrap(),
        ])
        .output()
        .unwrap();

    // Exit code must be non-zero
    assert!(!output.status.success(), "expected non-zero exit code");

    // stdout must be valid JSON
    let stdout = String::from_utf8_lossy(&output.stdout);
    let parsed: serde_json::Value = serde_json::from_str(&stdout)
        .expect("stdout must be valid JSON in --json error mode");

    assert_eq!(
        parsed["status"].as_str().unwrap(),
        "error",
        "status field must be 'error'"
    );
    assert!(
        !parsed["message"].as_str().unwrap_or("").is_empty(),
        "message field must be non-empty"
    );
}

/// Test 5: `create --help` shows all expected flags.
#[test]
fn test_create_help_shows_flags() {
    cargo_bin_cmd!("edgeworks-bundle")
        .args(["create", "--help"])
        .assert()
        .success()
        .stdout(predicates::str::contains("--image"))
        .stdout(predicates::str::contains("--output"))
        .stdout(predicates::str::contains("--notes"))
        .stdout(predicates::str::contains("--target-device"));
}

/// Test 6 (ignored): Full end-to-end test requiring skopeo and network access.
///
/// To run manually:
///   cargo test --manifest-path crates/bundle-cli/Cargo.toml test_create_e2e_with_skopeo -- --ignored
#[test]
#[ignore]
fn test_create_e2e_with_skopeo() {
    let tmp = setup_test_dir();
    let output_dir = tmp.path().join("alpine-bundle");
    let image = "docker.io/library/alpine:3.19";

    // Pull alpine:3.19 and create a bundle
    cargo_bin_cmd!("edgeworks-bundle")
        .args([
            "create",
            "--image", image,
            "--output", output_dir.to_str().unwrap(),
        ])
        .assert()
        .success();

    // Assert exactly 3 files exist in the output directory
    let entries: Vec<_> = fs::read_dir(&output_dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .collect();
    assert_eq!(entries.len(), 3, "bundle should contain exactly 3 files");

    let expected_files = ["manifest.json", "checksums.sha256", "alpine-3.19.oci.tar"];
    for name in &expected_files {
        assert!(
            output_dir.join(name).exists(),
            "expected file {} not found in bundle",
            name
        );
    }

    // Parse manifest.json and verify required fields
    let manifest_raw = fs::read_to_string(output_dir.join("manifest.json")).unwrap();
    let manifest: serde_json::Value = serde_json::from_str(&manifest_raw).unwrap();
    assert_eq!(manifest["schema_version"].as_str().unwrap(), "1.0");
    assert_eq!(manifest["image"]["version"].as_str().unwrap(), "3.19");
    assert!(
        manifest["image"]["reference"].as_str().unwrap().contains(image),
        "image reference should contain the input image"
    );

    // Verify checksums.sha256 with sha256sum
    let verify_output = std::process::Command::new("sha256sum")
        .arg("-c")
        .arg("checksums.sha256")
        .current_dir(&output_dir)
        .output()
        .expect("sha256sum not available");
    assert!(
        verify_output.status.success(),
        "sha256sum -c failed: {}",
        String::from_utf8_lossy(&verify_output.stderr)
    );

    // Run with --json and verify output structure
    let json_output = cargo_bin_cmd!("edgeworks-bundle")
        .args([
            "--json",
            "create",
            "--image", image,
            "--output", tmp.path().join("alpine-bundle-2").to_str().unwrap(),
        ])
        .output()
        .unwrap();

    let json_stdout = String::from_utf8_lossy(&json_output.stdout);
    let json_result: serde_json::Value = serde_json::from_str(&json_stdout)
        .expect("--json output must be valid JSON");
    assert_eq!(json_result["status"].as_str().unwrap(), "ok");
}
