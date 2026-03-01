# EdgeWorks Bundle CLI — Design Document

> **Repo:** `os-builder`
> **Tool name:** `edgeworks-bundle`
> **Linear Issue:** [THE-738](https://linear.app/theedgeworks/issue/THE-738) — Bundle Creation CLI Tool (os-builder)
> **Consumer:** `update-agent` — USB Bundle Detection & Import ([THE-736](https://linear.app/theedgeworks/issue/THE-736))
> **Companion doc:** [update-agent design.md §8](../../../edgeworks-update-agent/docs/design.md) — USB bundle format contract

---

## 1. Overview

`edgeworks-bundle` is a Rust CLI tool for creating, verifying, and inspecting offline update bundles. These bundles are copied onto USB media and physically carried to air-gapped edge devices, where the Update Agent detects and imports them.

**Single image model:** Each bundle contains exactly one bootc OCI archive. The bootc image is the single unit of delivery — it contains the host OS, all application container images (baked in), the update agent binary (installed via RPM), and k8s manifests. There is no multi-image concept.

**Relationship to os-builder:** This tool lives here because it pulls and packages bootc OS images — the same images this repo builds. It is a build-time / operator-workstation tool, not a runtime component.

**Relationship to update-agent:** The bundle format produced by this tool is the contract consumed by the update-agent's `usb.rs` module. The `manifest.json` schema and `checksums.sha256` format defined here are shared contracts between the two repos.

---

## 2. Bundle Format Specification

This is the authoritative definition of the bundle format. The update-agent's `usb.rs` module must accept any bundle conforming to this spec.

### 2.1 Directory Structure

```
edgeworks-bundle-<version>/
├── manifest.json              # Bundle metadata (see §2.2)
├── checksums.sha256           # SHA256 checksum file (see §2.3)
└── edge-os-<version>.oci.tar  # Single bootc OCI archive
```

- Directory name: `edgeworks-bundle-<version>` where `<version>` matches the image tag (e.g., `edgeworks-bundle-1.2.0`)
- Exactly one `.oci.tar` file per bundle
- No subdirectories (`os/`, `apps/`, `agent/` do not exist)

### 2.2 manifest.json

```json
{
  "schema_version": "1.0",
  "created_at": "2026-03-01T12:00:00Z",
  "created_by": "edgeworks-bundle v0.1.0",
  "image": {
    "reference": "harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0",
    "file": "edge-os-1.2.0.oci.tar",
    "digest": "sha256:abc123def456...",
    "size_bytes": 2147483648,
    "version": "1.2.0"
  },
  "target_device": "any",
  "notes": ""
}
```

**Field definitions:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | string | Yes | Bundle format version. Currently `"1.0"`. |
| `created_at` | string (ISO 8601) | Yes | Timestamp of bundle creation. |
| `created_by` | string | Yes | Tool name + version that created the bundle. |
| `image.reference` | string | Yes | Full OCI image reference (registry/repo:tag). |
| `image.file` | string | Yes | Filename of the OCI tarball within the bundle directory. |
| `image.digest` | string | Yes | `sha256:<hex>` digest of the OCI tarball. |
| `image.size_bytes` | integer | Yes | Exact byte size of the OCI tarball. |
| `image.version` | string | Yes | Semver version extracted from the image tag. |
| `target_device` | string | Yes | Device filter. `"any"` means all devices. Future: device ID or fleet group. |
| `notes` | string | No | Operator-provided free-text notes. |

### 2.3 checksums.sha256

Standard GNU coreutils `sha256sum` format:

```
abc123def456...  edge-os-1.2.0.oci.tar
```

- One line per file (currently always exactly one line)
- Two-space separator between hash and filename
- Verifiable with `sha256sum -c checksums.sha256`

### 2.4 OCI Archive Format

The `.oci.tar` file is an OCI image archive produced by `skopeo copy`. It must be loadable by `podman load -i <file>`.

---

## 3. CLI Commands

### 3.1 `edgeworks-bundle create`

Creates a new bundle directory from a registry image.

```bash
edgeworks-bundle create \
  --image harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0 \
  --output /media/usb/edgeworks-bundle-1.2.0/ \
  [--notes "Hotfix for OPC-UA adapter timeout"] \
  [--target-device any] \
  [--json]
```

**Flags:**

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--image` | Yes | — | Full OCI image reference to pull |
| `--output` | Yes | — | Output directory path (created if not exists) |
| `--notes` | No | `""` | Free-text notes included in manifest |
| `--target-device` | No | `"any"` | Device filter for the bundle |
| `--json` | No | off | Machine-readable JSON output instead of human-friendly |

**Steps:**

1. Validate `--image` is a valid OCI reference
2. Create output directory if it doesn't exist
3. Pull and export image:
   ```
   skopeo copy \
     docker://<image> \
     oci-archive:<output>/edge-os-<version>.oci.tar
   ```
4. Compute SHA256 of the tarball (streaming, using `sha2` crate)
5. Get image size in bytes
6. Write `checksums.sha256`
7. Write `manifest.json` with all fields populated
8. Print summary (or JSON if `--json`)

**Output (human):**

```
Bundle created successfully.
  Directory: /media/usb/edgeworks-bundle-1.2.0/
  Image:     harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0
  Size:      2.0 GiB
  Digest:    sha256:abc123...
  Files:     3 (manifest.json, checksums.sha256, edge-os-1.2.0.oci.tar)
```

**Output (JSON):**

```json
{
  "status": "ok",
  "directory": "/media/usb/edgeworks-bundle-1.2.0/",
  "image": "harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0",
  "version": "1.2.0",
  "digest": "sha256:abc123...",
  "size_bytes": 2147483648,
  "files": ["manifest.json", "checksums.sha256", "edge-os-1.2.0.oci.tar"]
}
```

**Progress:** Display a progress bar during `skopeo copy` and SHA256 computation using `indicatif`.

### 3.2 `edgeworks-bundle verify`

Verifies an existing bundle's integrity.

```bash
edgeworks-bundle verify /media/usb/edgeworks-bundle-1.2.0/ [--json]
```

**Checks:**

1. `manifest.json` exists and is valid JSON conforming to schema (§2.2)
2. `checksums.sha256` exists and is well-formed
3. OCI tarball file referenced in manifest exists
4. SHA256 of tarball matches `checksums.sha256` and `manifest.image.digest`
5. File size matches `manifest.image.size_bytes`
6. `schema_version` is a supported version (`"1.0"`)

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0 | Bundle is valid |
| 1 | Verification failed (details in stderr) |
| 2 | Bundle directory not found or not readable |

**Output (human):**

```
Verifying bundle: /media/usb/edgeworks-bundle-1.2.0/

  [OK] manifest.json schema valid
  [OK] checksums.sha256 well-formed
  [OK] edge-os-1.2.0.oci.tar exists (2.0 GiB)
  [OK] SHA256 checksum matches
  [OK] File size matches manifest

Bundle is valid.
  Image:   harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0
  Version: 1.2.0
  Created: 2026-03-01T12:00:00Z
```

### 3.3 `edgeworks-bundle inspect`

Displays bundle metadata without verifying checksums (fast).

```bash
edgeworks-bundle inspect /media/usb/edgeworks-bundle-1.2.0/ [--json]
```

**Output (human):**

```
Bundle: /media/usb/edgeworks-bundle-1.2.0/

  Schema version: 1.0
  Created:        2026-03-01T12:00:00Z by edgeworks-bundle v0.1.0
  Image:          harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0
  Version:        1.2.0
  Size:           2.0 GiB
  Digest:         sha256:abc123...
  Target device:  any
  Notes:          Hotfix for OPC-UA adapter timeout
```

---

## 4. Data Types

### 4.1 Manifest Model

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BundleManifest {
    pub schema_version: String,
    pub created_at: DateTime<Utc>,
    pub created_by: String,
    pub image: BundleImage,
    pub target_device: String,
    #[serde(default)]
    pub notes: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BundleImage {
    pub reference: String,       // full OCI image ref
    pub file: String,            // filename of .oci.tar
    pub digest: String,          // "sha256:<hex>"
    pub size_bytes: u64,
    pub version: String,         // semver from image tag
}
```

### 4.2 Error Types

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum BundleError {
    #[error("image pull failed: {0}")]
    PullFailed(String),

    #[error("skopeo not found — install skopeo to create bundles")]
    SkopeoNotAvailable,

    #[error("output directory already contains a bundle")]
    OutputExists,

    #[error("manifest.json not found in {0}")]
    ManifestNotFound(String),

    #[error("invalid manifest: {0}")]
    ManifestInvalid(String),

    #[error("unsupported schema version: {0}")]
    UnsupportedSchema(String),

    #[error("checksum mismatch: expected {expected}, got {actual}")]
    ChecksumMismatch { expected: String, actual: String },

    #[error("size mismatch: expected {expected}, got {actual}")]
    SizeMismatch { expected: u64, actual: u64 },

    #[error("referenced file not found: {0}")]
    FileNotFound(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}
```

---

## 5. Directory & Module Layout

```
os-builder/
├── ...                          # existing os-builder files
├── crates/
│   └── bundle-cli/
│       ├── Cargo.toml
│       └── src/
│           ├── main.rs          # clap CLI entry point
│           ├── create.rs        # Bundle creation (skopeo copy, hash, manifest)
│           ├── verify.rs        # Bundle integrity verification
│           ├── inspect.rs       # Bundle metadata display
│           ├── manifest.rs      # Manifest types + parsing
│           └── error.rs         # Error types
├── docs/
│   └── bundle-cli-design.md    # this document
```

**Note:** If the os-builder repo doesn't use a Cargo workspace yet, the `crates/bundle-cli/` directory can be a standalone Cargo project. The Makefile should add a `bundle-cli` target.

---

## 6. Dependencies

### Rust Crates

| Crate | Purpose |
|-------|---------|
| `clap` | CLI argument parsing (derive API) |
| `serde` + `serde_json` | Manifest serialization/deserialization |
| `chrono` | Timestamps |
| `sha2` | SHA256 digest computation |
| `indicatif` | Progress bars for long operations |
| `thiserror` | Error type derivation |

### Host Dependencies

| Binary | Purpose |
|--------|---------|
| `skopeo` | Pull + export OCI images to archive format |

**Why skopeo over podman?** `skopeo copy docker:// oci-archive:` is a single-step pull-and-export. With podman you'd need `podman pull` + `podman save`, and `podman save --format oci-archive` output differs subtly from skopeo's. Since the update-agent uses `podman load` to import, and `podman load` accepts both formats, either works — but skopeo is simpler and doesn't pollute the local podman store.

---

## 7. CI/CD Integration

### Build

Add to existing os-builder Makefile:

```makefile
.PHONY: bundle-cli
bundle-cli:
	cargo build --release --manifest-path crates/bundle-cli/Cargo.toml

.PHONY: bundle-cli-test
bundle-cli-test:
	cargo test --manifest-path crates/bundle-cli/Cargo.toml
```

### Release

The bundle CLI binary can be:
- Published alongside the OS image as a build artifact
- Packaged as a standalone RPM (optional — it's a workstation tool, not a device tool)
- Distributed as a plain binary download from Forgejo releases

---

## 8. Usage Scenarios

### 8.1 Operator Creates Bundle for Field Update

```bash
# On a workstation with Harbor access
edgeworks-bundle create \
  --image harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0 \
  --output /media/usb-stick/edgeworks-bundle-1.2.0/ \
  --notes "Scheduled maintenance update for plant floor A"

# Verify before shipping
edgeworks-bundle verify /media/usb-stick/edgeworks-bundle-1.2.0/

# Physically carry USB to air-gapped device
# Update agent detects and imports automatically
```

### 8.2 CI Creates Bundle Alongside Image Build

```yaml
# In os-builder CI pipeline, after pushing to Harbor:
- name: Create offline bundle
  run: |
    edgeworks-bundle create \
      --image ${{ env.IMAGE_REF }} \
      --output .build/bundle/ \
      --json > .build/bundle-result.json

- name: Upload bundle as artifact
  uses: actions/upload-artifact@v4
  with:
    name: edgeworks-bundle-${{ env.VERSION }}
    path: .build/bundle/
```

### 8.3 QA Verifies Bundle Integrity

```bash
edgeworks-bundle verify /path/to/bundle/ --json | jq '.status'
# "ok" or "failed"
```

---

## 9. Future Considerations (Phase 2)

| Feature | Description |
|---------|-------------|
| GPG signing | Sign `manifest.json` with a GPG key. Update-agent verifies signature before import. Prevents USB bundle tampering. |
| Version enforcement | Include `min_version` field in manifest. Update-agent rejects bundles targeting a version older than currently booted (prevents downgrade attacks). |
| Multi-arch bundles | Support `--arch` flag for cross-architecture bundles (e.g., ARM64 bundles built on x86). |
| Delta bundles | Only ship changed layers instead of full OCI archive. Requires OCI layer diffing. |

---

## 10. Acceptance Criteria

- [ ] `edgeworks-bundle create` pulls image via skopeo and produces valid bundle directory
- [ ] `manifest.json` conforms to schema (§2.2) with all required fields
- [ ] `checksums.sha256` matches GNU coreutils format, verifiable with `sha256sum -c`
- [ ] `edgeworks-bundle verify` validates all integrity checks (§3.2)
- [ ] `edgeworks-bundle inspect` displays metadata without full checksum verification
- [ ] `--json` flag on all commands for machine-readable output
- [ ] Progress bar during image pull and checksum computation
- [ ] Proper exit codes (0 = success, 1 = verification failure, 2 = input error)
- [ ] Unit tests (≥ 80% coverage)
- [ ] Bundle produced by this tool is successfully imported by update-agent's `usb.rs`
