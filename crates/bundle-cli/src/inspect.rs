use std::fs;
use std::path::Path;

use crate::error::BundleError;
use crate::manifest::BundleManifest;

/// Load the bundle manifest from the given bundle directory.
///
/// Returns `Err` if:
/// - The directory does not exist (maps to exit 2 in main.rs)
/// - The manifest is missing or malformed (maps to exit 1 in main.rs)
///
/// Does NOT read the OCI tarball or compute any checksums.
pub fn run_inspect(bundle_dir: &Path) -> Result<BundleManifest, BundleError> {
    if !bundle_dir.exists() {
        return Err(BundleError::ManifestNotFound(
            bundle_dir.display().to_string(),
        ));
    }

    let manifest_path = bundle_dir.join("manifest.json");
    if !manifest_path.exists() {
        return Err(BundleError::ManifestNotFound(
            bundle_dir.display().to_string(),
        ));
    }

    let content = fs::read_to_string(&manifest_path)
        .map_err(|e| BundleError::ManifestInvalid(e.to_string()))?;

    serde_json::from_str::<BundleManifest>(&content)
        .map_err(|e| BundleError::ManifestInvalid(e.to_string()))
}

/// Format a byte count as human-readable (e.g. "2.0 GiB").
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

/// Format a manifest as human-readable text matching the design doc §3.3.
///
/// ```
/// Bundle: /media/usb/edgeworks-bundle-1.2.0/
///
///   Schema version: 1.0
///   Created:        2026-03-01T12:00:00Z by edgeworks-bundle v0.1.0
///   Image:          harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0
///   Version:        1.2.0
///   Size:           2.0 GiB
///   Digest:         sha256:abc123...
///   Target device:  any
///   Notes:          Hotfix for OPC-UA adapter timeout
/// ```
pub fn format_inspect_human(manifest: &BundleManifest, bundle_dir: &Path) -> String {
    let notes = if manifest.notes.is_empty() {
        "—".to_string()
    } else {
        manifest.notes.clone()
    };

    format!(
        "Bundle: {}\n\n  Schema version: {}\n  Created:        {} by {}\n  Image:          {}\n  Version:        {}\n  Size:           {}\n  Digest:         {}\n  Target device:  {}\n  Notes:          {}\n",
        bundle_dir.display(),
        manifest.schema_version,
        manifest.created_at.to_rfc3339(),
        manifest.created_by,
        manifest.image.reference,
        manifest.image.version,
        format_size(manifest.image.size_bytes),
        manifest.image.digest,
        manifest.target_device,
        notes,
    )
}

/// Serialize a manifest to pretty-printed JSON.
pub fn format_inspect_json(manifest: &BundleManifest) -> String {
    serde_json::to_string_pretty(manifest).unwrap_or_else(|_| "{}".to_string())
}

// ─────────────────────────────────────────────────────────────────────────────
#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
    use std::fs;
    use tempfile::TempDir;

    use crate::manifest::{BundleImage, BundleManifest};

    fn make_manifest() -> BundleManifest {
        BundleManifest {
            schema_version: "1.0".to_string(),
            created_at: "2026-03-01T12:00:00Z".parse().unwrap(),
            created_by: "edgeworks-bundle v0.1.0".to_string(),
            image: BundleImage {
                reference: "harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0".to_string(),
                file: "edge-os-1.2.0.oci.tar".to_string(),
                digest: "sha256:abc123def456".to_string(),
                size_bytes: 2147483648,
                version: "1.2.0".to_string(),
            },
            target_device: "any".to_string(),
            notes: "Hotfix for OPC-UA adapter timeout".to_string(),
        }
    }

    fn write_manifest(dir: &TempDir, manifest: &BundleManifest) {
        let json = serde_json::to_string_pretty(manifest).unwrap();
        fs::write(dir.path().join("manifest.json"), json).unwrap();
    }

    #[test]
    fn test_inspect_valid_bundle() {
        let dir = TempDir::new().unwrap();
        let manifest = make_manifest();
        write_manifest(&dir, &manifest);

        let result = run_inspect(dir.path()).unwrap();
        assert_eq!(result.schema_version, "1.0");
        assert_eq!(result.created_by, "edgeworks-bundle v0.1.0");
        assert_eq!(result.image.reference, "harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0");
        assert_eq!(result.image.version, "1.2.0");
        assert_eq!(result.image.size_bytes, 2147483648);
        assert_eq!(result.image.digest, "sha256:abc123def456");
        assert_eq!(result.target_device, "any");
        assert_eq!(result.notes, "Hotfix for OPC-UA adapter timeout");
    }

    #[test]
    fn test_inspect_json_output() {
        let manifest = make_manifest();
        let json_str = format_inspect_json(&manifest);

        // Must be valid JSON.
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();
        assert_eq!(parsed["schema_version"], "1.0");
        assert_eq!(parsed["image"]["reference"], "harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0");

        // Must round-trip back to BundleManifest.
        let round_tripped: BundleManifest = serde_json::from_str(&json_str).unwrap();
        assert_eq!(round_tripped.schema_version, manifest.schema_version);
        assert_eq!(round_tripped.image.reference, manifest.image.reference);
        assert_eq!(round_tripped.image.size_bytes, manifest.image.size_bytes);
        assert_eq!(round_tripped.notes, manifest.notes);
    }

    #[test]
    fn test_inspect_human_output() {
        let manifest = make_manifest();
        let dir = TempDir::new().unwrap();
        let output = format_inspect_human(&manifest, dir.path());

        assert!(output.contains("Bundle:"), "Missing Bundle header");
        assert!(output.contains("Schema version: 1.0"), "Missing schema_version");
        assert!(output.contains("2026-03-01"), "Missing created_at date");
        assert!(output.contains("edgeworks-bundle v0.1.0"), "Missing created_by");
        assert!(output.contains("harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0"), "Missing image reference");
        assert!(output.contains("1.2.0"), "Missing version");
        assert!(output.contains("2.0 GiB"), "Missing human-readable size");
        assert!(output.contains("sha256:abc123def456"), "Missing digest");
        assert!(output.contains("any"), "Missing target_device");
        assert!(output.contains("Hotfix for OPC-UA adapter timeout"), "Missing notes");
    }

    #[test]
    fn test_inspect_missing_manifest() {
        let dir = TempDir::new().unwrap();
        // No manifest.json written.
        let err = run_inspect(dir.path()).unwrap_err();
        match err {
            BundleError::ManifestNotFound(_) => {}
            other => panic!("Expected ManifestNotFound, got {:?}", other),
        }
    }

    #[test]
    fn test_inspect_malformed_manifest() {
        let dir = TempDir::new().unwrap();
        fs::write(dir.path().join("manifest.json"), b"{ not valid json !!!").unwrap();

        let err = run_inspect(dir.path()).unwrap_err();
        match err {
            BundleError::ManifestInvalid(_) => {}
            other => panic!("Expected ManifestInvalid, got {:?}", other),
        }
    }

    #[test]
    fn test_inspect_nonexistent_path() {
        let path = Path::new("/tmp/definitely-does-not-exist-inspect-xyzzy-99999");
        let err = run_inspect(path).unwrap_err();
        match err {
            BundleError::ManifestNotFound(_) => {}
            other => panic!("Expected ManifestNotFound, got {:?}", other),
        }
    }

    #[test]
    fn test_format_size() {
        assert_eq!(format_size(0), "0 B");
        assert_eq!(format_size(512), "512 B");
        assert_eq!(format_size(1023), "1023 B");
        assert_eq!(format_size(1024), "1.0 KiB");
        assert_eq!(format_size(1048576), "1.0 MiB");
        assert_eq!(format_size(1073741824), "1.0 GiB");
        assert_eq!(format_size(2147483648), "2.0 GiB");
        assert_eq!(format_size(1024u64 * 1024 * 1024 * 1024), "1.0 TiB");
    }

    #[test]
    fn test_inspect_empty_notes_shows_dash() {
        let mut manifest = make_manifest();
        manifest.notes = "".to_string();
        let dir = TempDir::new().unwrap();
        let output = format_inspect_human(&manifest, dir.path());
        assert!(output.contains("Notes:          —"), "Empty notes should display as '—'");
    }
}
