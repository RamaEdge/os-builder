use std::fs;
use std::path::Path;

use sha2::{Digest, Sha256};

use crate::error::BundleError;
use crate::manifest::BundleManifest;

/// Result of a single integrity check.
#[derive(Debug, Clone)]
pub struct CheckResult {
    pub name: String,
    pub passed: bool,
    pub detail: String,
}

/// Aggregated result of all verify checks.
#[derive(Debug)]
pub struct VerifyResult {
    pub valid: bool,
    pub checks: Vec<CheckResult>,
    pub manifest: Option<BundleManifest>,
}

/// Compute the SHA256 hex digest of a file using streaming reads.
fn compute_sha256(path: &Path) -> Result<String, BundleError> {
    let mut file = fs::File::open(path)?;
    let mut hasher = Sha256::new();
    std::io::copy(&mut file, &mut hasher)?;
    Ok(format!("{:x}", hasher.finalize()))
}

/// Format a byte count as a human-readable string (e.g. "2.0 GiB").
fn format_bytes(bytes: u64) -> String {
    const GIB: u64 = 1024 * 1024 * 1024;
    const MIB: u64 = 1024 * 1024;
    const KIB: u64 = 1024;

    if bytes >= GIB {
        format!("{:.1} GiB", bytes as f64 / GIB as f64)
    } else if bytes >= MIB {
        format!("{:.1} MiB", bytes as f64 / MIB as f64)
    } else if bytes >= KIB {
        format!("{:.1} KiB", bytes as f64 / KIB as f64)
    } else {
        format!("{} B", bytes)
    }
}

/// Run all 6 bundle integrity checks against the given directory.
///
/// Returns `Err(BundleError)` when the bundle directory itself cannot be
/// accessed (maps to exit code 2 in main.rs).  For logical verification
/// failures the function returns `Ok(VerifyResult { valid: false, … })`,
/// which main.rs maps to exit code 1.
pub fn run_verify(bundle_dir: &Path) -> Result<VerifyResult, BundleError> {
    // Guard: directory must exist and be readable.
    if !bundle_dir.exists() {
        return Err(BundleError::ManifestNotFound(
            bundle_dir.display().to_string(),
        ));
    }

    let mut checks: Vec<CheckResult> = Vec::new();
    // ── Check 1: manifest.json exists and parses ────────────────────────────
    let manifest_path = bundle_dir.join("manifest.json");
    let manifest = if !manifest_path.exists() {
        checks.push(CheckResult {
            name: "manifest.json schema valid".to_string(),
            passed: false,
            detail: BundleError::ManifestNotFound(bundle_dir.display().to_string()).to_string(),
        });
        return Ok(VerifyResult {
            valid: false,
            checks,
            manifest: None,
        });
    } else {
        let content = fs::read_to_string(&manifest_path)
            .map_err(|e| BundleError::ManifestInvalid(e.to_string()))?;
        match serde_json::from_str::<BundleManifest>(&content) {
            Ok(m) => {
                checks.push(CheckResult {
                    name: "manifest.json schema valid".to_string(),
                    passed: true,
                    detail: format!("schema_version {}", m.schema_version),
                });
                m
            }
            Err(e) => {
                checks.push(CheckResult {
                    name: "manifest.json schema valid".to_string(),
                    passed: false,
                    detail: e.to_string(),
                });
                return Ok(VerifyResult {
                    valid: false,
                    checks,
                    manifest: None,
                });
            }
        }
    };
    let manifest_opt = Some(manifest.clone());

    // ── Check 2: schema_version == "1.0" ───────────────────────────────────
    if manifest.schema_version == "1.0" {
        checks.push(CheckResult {
            name: "schema_version is supported".to_string(),
            passed: true,
            detail: "1.0".to_string(),
        });
    } else {
        checks.push(CheckResult {
            name: "schema_version is supported".to_string(),
            passed: false,
            detail: format!("unsupported version: {}", manifest.schema_version),
        });
        return Ok(VerifyResult {
            valid: false,
            checks,
            manifest: manifest_opt,
        });
    }

    // ── Check 3: checksums.sha256 exists and is well-formed ────────────────
    let checksums_path = bundle_dir.join("checksums.sha256");
    let checksum_entry = if !checksums_path.exists() {
        checks.push(CheckResult {
            name: "checksums.sha256 well-formed".to_string(),
            passed: false,
            detail: "checksums.sha256 not found".to_string(),
        });
        return Ok(VerifyResult {
            valid: false,
            checks,
            manifest: manifest_opt,
        });
    } else {
        let raw = fs::read_to_string(&checksums_path).map_err(BundleError::Io)?;
        // Expect at least one line: "<64-hex>  <filename>"
        let line = raw.lines().next().unwrap_or("").to_string();
        // Validate: 64-char hex, two spaces, filename
        let parts: Vec<&str> = line.splitn(2, "  ").collect();
        if parts.len() != 2
            || parts[0].len() != 64
            || !parts[0].chars().all(|c| c.is_ascii_hexdigit())
        {
            checks.push(CheckResult {
                name: "checksums.sha256 well-formed".to_string(),
                passed: false,
                detail: format!("malformed checksums.sha256: {:?}", line),
            });
            return Ok(VerifyResult {
                valid: false,
                checks,
                manifest: manifest_opt,
            });
        }
        checks.push(CheckResult {
            name: "checksums.sha256 well-formed".to_string(),
            passed: true,
            detail: format!(
                "{} file(s) listed",
                raw.lines().filter(|l| !l.is_empty()).count()
            ),
        });
        (parts[0].to_string(), parts[1].to_string()) // (expected_hash, filename)
    };

    let (checksum_hash, _checksum_filename) = checksum_entry;

    // ── Check 4: OCI tarball file exists ───────────────────────────────────
    let tarball_path = bundle_dir.join(&manifest.image.file);
    if !tarball_path.exists() {
        checks.push(CheckResult {
            name: format!("{} exists", manifest.image.file),
            passed: false,
            detail: format!("file not found: {}", manifest.image.file),
        });
        return Ok(VerifyResult {
            valid: false,
            checks,
            manifest: manifest_opt,
        });
    }

    let tarball_size = fs::metadata(&tarball_path)?.len();
    checks.push(CheckResult {
        name: format!("{} exists", manifest.image.file),
        passed: true,
        detail: format_bytes(tarball_size).to_string(),
    });

    // ── Check 5: SHA256 matches checksums.sha256 AND manifest.image.digest ─
    let computed_hash = match compute_sha256(&tarball_path) {
        Ok(h) => h,
        Err(e) => {
            checks.push(CheckResult {
                name: "SHA256 checksum matches".to_string(),
                passed: false,
                detail: format!("failed to compute hash: {}", e),
            });
            return Ok(VerifyResult {
                valid: false,
                checks,
                manifest: manifest_opt,
            });
        }
    };

    // Strip "sha256:" prefix from manifest digest if present.
    let manifest_digest_hex = manifest
        .image
        .digest
        .strip_prefix("sha256:")
        .unwrap_or(&manifest.image.digest);

    if computed_hash != checksum_hash {
        checks.push(CheckResult {
            name: "SHA256 checksum matches".to_string(),
            passed: false,
            detail: format!(
                "checksum mismatch: checksums.sha256 has {}, computed {}",
                checksum_hash, computed_hash
            ),
        });
        return Ok(VerifyResult {
            valid: false,
            checks,
            manifest: manifest_opt,
        });
    }

    if computed_hash != manifest_digest_hex {
        checks.push(CheckResult {
            name: "SHA256 checksum matches".to_string(),
            passed: false,
            detail: format!(
                "digest mismatch: manifest has {}, computed {}",
                manifest_digest_hex, computed_hash
            ),
        });
        return Ok(VerifyResult {
            valid: false,
            checks,
            manifest: manifest_opt,
        });
    }

    checks.push(CheckResult {
        name: "SHA256 checksum matches".to_string(),
        passed: true,
        detail: format!("sha256:{}", computed_hash),
    });

    // ── Check 6: File size matches manifest.image.size_bytes ───────────────
    if tarball_size != manifest.image.size_bytes {
        checks.push(CheckResult {
            name: "File size matches manifest".to_string(),
            passed: false,
            detail: format!(
                "size mismatch: manifest says {} bytes, actual {} bytes",
                manifest.image.size_bytes, tarball_size
            ),
        });
        return Ok(VerifyResult {
            valid: false,
            checks,
            manifest: manifest_opt,
        });
    }

    checks.push(CheckResult {
        name: "File size matches manifest".to_string(),
        passed: true,
        detail: format!("{} bytes", tarball_size),
    });

    Ok(VerifyResult {
        valid: true,
        checks,
        manifest: manifest_opt,
    })
}

/// Format verify result as human-readable text matching the design doc §3.2.
pub fn format_verify_human(result: &VerifyResult, bundle_dir: &Path) -> String {
    let mut out = String::new();
    out.push_str(&format!("Verifying bundle: {}\n\n", bundle_dir.display()));

    for check in &result.checks {
        let tag = if check.passed { "[OK]  " } else { "[FAIL]" };
        out.push_str(&format!("  {} {}\n", tag, check.name));
    }

    out.push('\n');

    if result.valid {
        out.push_str("Bundle is valid.\n");
        if let Some(ref m) = result.manifest {
            out.push_str(&format!("  Image:   {}\n", m.image.reference));
            out.push_str(&format!("  Version: {}\n", m.image.version));
            out.push_str(&format!("  Created: {}\n", m.created_at.to_rfc3339()));
        }
    } else {
        out.push_str("Bundle verification FAILED.\n");
        let failed: Vec<&CheckResult> = result.checks.iter().filter(|c| !c.passed).collect();
        for f in failed {
            out.push_str(&format!("  ERROR: {} — {}\n", f.name, f.detail));
        }
    }

    out
}

/// Format verify result as JSON matching the design doc §3.2.
///
/// ```json
/// {"status":"ok"|"failed", "directory":"...", "checks":[...], "errors":[...]}
/// ```
pub fn format_verify_json(result: &VerifyResult, bundle_dir: &Path) -> String {
    let status = if result.valid { "ok" } else { "failed" };

    let checks_json: Vec<serde_json::Value> = result
        .checks
        .iter()
        .map(|c| {
            serde_json::json!({
                "name": c.name,
                "passed": c.passed,
                "detail": c.detail,
            })
        })
        .collect();

    let errors_json: Vec<serde_json::Value> = result
        .checks
        .iter()
        .filter(|c| !c.passed)
        .map(|c| serde_json::json!({"check": c.name, "detail": c.detail}))
        .collect();

    let value = serde_json::json!({
        "status": status,
        "directory": bundle_dir.display().to_string(),
        "checks": checks_json,
        "errors": errors_json,
    });

    serde_json::to_string_pretty(&value).unwrap_or_else(|_| "{}".to_string())
}

// ─────────────────────────────────────────────────────────────────────────────
#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
    use tempfile::TempDir;

    use crate::manifest::{BundleImage, BundleManifest};

    /// Create a minimal valid bundle in a TempDir.
    ///
    /// Returns (TempDir, tarball_filename, hex_digest, file_size).
    fn make_valid_bundle() -> (TempDir, String, String, u64) {
        let dir = TempDir::new().unwrap();
        let tarball_name = "edge-os-1.2.0.oci.tar".to_string();
        let tarball_path = dir.path().join(&tarball_name);

        // Write a small test tarball payload.
        let payload = b"fake oci tar content for testing";
        fs::write(&tarball_path, payload).unwrap();

        // Compute the real SHA256.
        let mut hasher = Sha256::new();
        hasher.update(payload);
        let hex = format!("{:x}", hasher.finalize());
        let size = payload.len() as u64;

        // Write checksums.sha256 (GNU two-space format).
        let checksum_line = format!("{}  {}\n", hex, tarball_name);
        fs::write(dir.path().join("checksums.sha256"), checksum_line).unwrap();

        // Write manifest.json.
        let manifest = BundleManifest {
            schema_version: "1.0".to_string(),
            created_at: Utc::now(),
            created_by: "edgeworks-bundle v0.1.0".to_string(),
            image: BundleImage {
                reference: "harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0".to_string(),
                file: tarball_name.clone(),
                digest: format!("sha256:{}", hex),
                size_bytes: size,
                version: "1.2.0".to_string(),
            },
            target_device: "any".to_string(),
            notes: "".to_string(),
        };
        let json = serde_json::to_string_pretty(&manifest).unwrap();
        fs::write(dir.path().join("manifest.json"), json).unwrap();

        (dir, tarball_name, hex, size)
    }

    #[test]
    fn test_verify_valid_bundle() {
        let (dir, _tarball, _hex, _size) = make_valid_bundle();
        let result = run_verify(dir.path()).unwrap();
        assert!(
            result.valid,
            "Expected valid bundle, checks: {:?}",
            result.checks
        );
        assert_eq!(result.checks.len(), 6);
        assert!(result.checks.iter().all(|c| c.passed));
    }

    #[test]
    fn test_verify_nonexistent_path() {
        let path = std::path::Path::new("/tmp/definitely-does-not-exist-bundle-xyzzy-12345");
        let err = run_verify(path).unwrap_err();
        match err {
            BundleError::ManifestNotFound(_) => {}
            other => panic!("Expected ManifestNotFound, got {:?}", other),
        }
    }

    #[test]
    fn test_verify_corrupted_checksum() {
        let (dir, tarball_name, _hex, _size) = make_valid_bundle();
        // Overwrite checksums.sha256 with a wrong hash.
        let bad_hash = "a".repeat(64);
        let bad_checksum = format!("{}  {}\n", bad_hash, tarball_name);
        fs::write(dir.path().join("checksums.sha256"), bad_checksum).unwrap();

        let result = run_verify(dir.path()).unwrap();
        assert!(
            !result.valid,
            "Expected invalid bundle due to checksum mismatch"
        );
        let failed: Vec<_> = result.checks.iter().filter(|c| !c.passed).collect();
        assert!(
            failed.iter().any(|c| c.name.contains("SHA256")),
            "Expected SHA256 check to fail, got: {:?}",
            failed
        );
    }

    #[test]
    fn test_verify_missing_tarball() {
        let (dir, tarball_name, _hex, _size) = make_valid_bundle();
        // Remove the tarball.
        fs::remove_file(dir.path().join(&tarball_name)).unwrap();

        let result = run_verify(dir.path()).unwrap();
        assert!(
            !result.valid,
            "Expected invalid bundle due to missing tarball"
        );
        let failed: Vec<_> = result.checks.iter().filter(|c| !c.passed).collect();
        assert!(
            failed.iter().any(|c| c.name.contains("exists")),
            "Expected tarball-exists check to fail, got: {:?}",
            failed
        );
    }

    #[test]
    fn test_verify_bad_schema_version() {
        let (dir, _tarball, _hex, _size) = make_valid_bundle();
        // Rewrite manifest with schema_version "2.0".
        let bad_manifest = serde_json::json!({
            "schema_version": "2.0",
            "created_at": "2026-03-01T12:00:00Z",
            "created_by": "edgeworks-bundle v0.1.0",
            "image": {
                "reference": "harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0",
                "file": "edge-os-1.2.0.oci.tar",
                "digest": "sha256:aaaa",
                "size_bytes": 32,
                "version": "1.2.0"
            },
            "target_device": "any",
            "notes": ""
        });
        fs::write(
            dir.path().join("manifest.json"),
            serde_json::to_string_pretty(&bad_manifest).unwrap(),
        )
        .unwrap();

        let result = run_verify(dir.path()).unwrap();
        assert!(
            !result.valid,
            "Expected invalid bundle due to bad schema version"
        );
        let failed: Vec<_> = result.checks.iter().filter(|c| !c.passed).collect();
        assert!(
            failed.iter().any(|c| c.name.contains("schema_version")),
            "Expected schema_version check to fail, got: {:?}",
            failed
        );
    }

    #[test]
    fn test_verify_size_mismatch() {
        let (dir, tarball_name, hex, size) = make_valid_bundle();
        // Write manifest with wrong size_bytes.
        let manifest = BundleManifest {
            schema_version: "1.0".to_string(),
            created_at: Utc::now(),
            created_by: "edgeworks-bundle v0.1.0".to_string(),
            image: BundleImage {
                reference: "harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0".to_string(),
                file: tarball_name,
                digest: format!("sha256:{}", hex),
                size_bytes: size + 9999, // wrong size
                version: "1.2.0".to_string(),
            },
            target_device: "any".to_string(),
            notes: "".to_string(),
        };
        fs::write(
            dir.path().join("manifest.json"),
            serde_json::to_string_pretty(&manifest).unwrap(),
        )
        .unwrap();

        let result = run_verify(dir.path()).unwrap();
        assert!(
            !result.valid,
            "Expected invalid bundle due to size mismatch"
        );
        let failed: Vec<_> = result.checks.iter().filter(|c| !c.passed).collect();
        assert!(
            failed
                .iter()
                .any(|c| c.name.contains("size") || c.name.contains("Size")),
            "Expected size check to fail, got: {:?}",
            failed
        );
    }

    #[test]
    fn test_verify_missing_checksums_file() {
        let (dir, _tarball, _hex, _size) = make_valid_bundle();
        fs::remove_file(dir.path().join("checksums.sha256")).unwrap();

        let result = run_verify(dir.path()).unwrap();
        assert!(
            !result.valid,
            "Expected invalid bundle due to missing checksums.sha256"
        );
        let failed: Vec<_> = result.checks.iter().filter(|c| !c.passed).collect();
        assert!(
            failed.iter().any(|c| c.name.contains("checksums")),
            "Expected checksums check to fail, got: {:?}",
            failed
        );
    }

    #[test]
    fn test_verify_malformed_manifest() {
        let (dir, _tarball, _hex, _size) = make_valid_bundle();
        fs::write(
            dir.path().join("manifest.json"),
            b"{ not valid json !!!" as &[u8],
        )
        .unwrap();

        let result = run_verify(dir.path()).unwrap();
        assert!(
            !result.valid,
            "Expected invalid bundle due to malformed manifest"
        );
        let failed: Vec<_> = result.checks.iter().filter(|c| !c.passed).collect();
        assert!(
            failed.iter().any(|c| c.name.contains("manifest")),
            "Expected manifest check to fail, got: {:?}",
            failed
        );
    }

    #[test]
    fn test_format_verify_human_valid() {
        let (dir, _tarball, _hex, _size) = make_valid_bundle();
        let result = run_verify(dir.path()).unwrap();
        let output = format_verify_human(&result, dir.path());
        assert!(output.contains("Bundle is valid."));
        assert!(output.contains("[OK]"));
        assert!(!output.contains("[FAIL]"));
    }

    #[test]
    fn test_format_verify_json_valid() {
        let (dir, _tarball, _hex, _size) = make_valid_bundle();
        let result = run_verify(dir.path()).unwrap();
        let json_str = format_verify_json(&result, dir.path());
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();
        assert_eq!(parsed["status"], "ok");
        assert!(parsed["checks"].as_array().unwrap().len() > 0);
        assert_eq!(parsed["errors"].as_array().unwrap().len(), 0);
    }

    #[test]
    fn test_format_verify_json_failed() {
        let (dir, _tarball, _hex, _size) = make_valid_bundle();
        fs::remove_file(dir.path().join("checksums.sha256")).unwrap();
        let result = run_verify(dir.path()).unwrap();
        let json_str = format_verify_json(&result, dir.path());
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();
        assert_eq!(parsed["status"], "failed");
        assert!(parsed["errors"].as_array().unwrap().len() > 0);
    }
}
