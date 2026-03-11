# Architecture

**Analysis Date:** 2026-03-11

## Pattern Overview

**Overall:** Modular, multi-layer build pipeline with CLI tooling for offline bundle management

**Key Characteristics:**
- Container-native operating system build system using bootc (bootable containers)
- Separation of concerns: OS layer (Containerfile + shell scripts), build orchestration (Makefile), CLI tools (Rust), and CI/CD (GitHub Actions)
- Centralized version management via `versions.json` (single source of truth)
- Offline-capable design with image embedding and air-gapped deployment support
- Three primary runtime components: MicroShift Kubernetes, OpenTelemetry Collector, edge OS base

## Layers

**Build Orchestration:**
- Purpose: Centralize build commands, version management, and artifact handling
- Location: `/Users/ravichillerega/sources/management/os-builder/Makefile`
- Contains: Build targets (build, test, scan, push, pull, clean), CI integration points, dependency installation
- Depends on: Container runtime (podman/docker), jq, tools (trivy, syft)
- Used by: GitHub Actions CI/CD, developers via CLI

**Container Image Layer:**
- Purpose: Define immutable OS image with MicroShift, OTel Collector, and offline container images
- Location: `/Users/ravichillerega/sources/management/os-builder/os/`
- Contains:
  - `Containerfile.microshift` - Multi-stage build (MicroShift installation, OTel binary, configs, image embedding, services)
  - `build.sh` - Orchestrates podman/docker build with git metadata and registry auth
  - Configuration files (`configs/` directory) for containers, microshift, otelcol
  - Kubernetes manifests (`manifests/` directory) auto-deployed at runtime
  - Systemd units (`systemd/` directory) for service management
  - Helper scripts (health-check.sh, embed-microshift-images.sh)
- Depends on: External registries (quay.io, GitHub releases, mirror.openshift.com)
- Used by: Makefile build target, GitHub Actions CI/CD

**Bundle CLI Layer:**
- Purpose: Create, verify, and inspect offline update bundles for air-gapped devices
- Location: `/Users/ravichillerega/sources/management/os-builder/crates/bundle-cli/src/`
- Contains:
  - `main.rs` - Command router (create, verify, inspect subcommands)
  - `create.rs` - Bundle creation with image pull via skopeo, SHA256 checksumming, manifest generation
  - `verify.rs` - 6-point bundle integrity checking (manifest parsing, schema validation, checksum verification, file existence)
  - `inspect.rs` - Metadata-only bundle inspection without validation
  - `manifest.rs` - Data structures for bundle schema (v1.0)
  - `error.rs` - Unified error type with descriptive messages
- Depends on: skopeo, serde/serde_json, sha2, indicatif, chrono, clap
- Used by: Makefile bundle-cli targets, deployment systems for offline updates

**CI/CD Pipeline:**
- Purpose: Automate build, test, security scanning, registry push, and ISO generation
- Location: `/Users/ravichillerega/sources/management/os-builder/.github/workflows/build-microshift.yaml` and `.github/actions/`
- Contains:
  - Main workflow: load-versions → calculate-version → build-container → trivy-scan → test-container → push to Harbor
  - Composite actions: build-container, test-container, trivy-scan, harbor-auth, calculate-version, load-versions, build-iso
  - Triggers: push to main, pull requests, weekly schedule, manual dispatch
- Depends on: Self-hosted runner (`os-builder-runner-set`), Harbor registry, GitHub secrets
- Used by: Automated deployment, pull request validation

## Data Flow

**Container Build Flow:**

1. Makefile loads versions from `versions.json`
2. `build.sh` generates image list from versions.json, detects container runtime
3. Containerfile.microshift builds 5 layers:
   - Layer 1: MicroShift RPMs from GitHub releases (with CRI-O dependencies)
   - Layer 2: OTel Collector binary from GitHub releases
   - Layer 3: Configuration files (containers, microshift, otelcol, manifests)
   - Layer 4: Offline container image embedding via skopeo (using mount=secret for auth)
   - Layer 5: Service setup (systemd, firewall rules, bootc lint)
4. Image tagged with git metadata (VCS_REF, VERSION)

**Bundle Creation Flow:**

1. User calls `edgeworks-bundle create --image <ref> --output <dir>`
2. Validates skopeo availability and image reference format
3. Checks output directory is writable and doesn't exist
4. Pulls image via `skopeo copy docker://<image> oci-archive:<tarball>`
5. Computes SHA256 hash of tarball with progress bar (8KB streaming reads)
6. Writes three files to output directory:
   - `manifest.json` - Schema 1.0 with image metadata, created_at, created_by
   - `checksums.sha256` - GNU coreutils format (64-hex + 2-space + filename)
   - `edge-os-<version>.oci.tar` - OCI archive tarball
7. Returns JSON or human-readable summary

**Bundle Verification Flow:**

1. User calls `edgeworks-bundle verify <path>`
2. Executes 6 checks:
   - Check 1: manifest.json exists and parses as valid JSON
   - Check 2: schema_version == "1.0" (rejects unknown versions)
   - Check 3: checksums.sha256 well-formed (64-hex + 2-spaces + filename)
   - Check 4: OCI tarball file exists and is readable
   - Check 5: SHA256 of tarball matches both checksums.sha256 AND manifest.image.digest
   - Check 6: File size matches manifest.image.size_bytes
3. Returns VerifyResult with list of passed/failed checks
4. Exits 0 if valid, 1 if logical failure, 2 if I/O error

**State Management:**

- Versions: Centralized in `versions.json` (single source of truth for all component versions)
- Build artifacts: Isolated in `.build/` (gitignored)
  - `.build/scan-results/` - Trivy scan output, SBOM
  - `.build/output/` - Disk images (qcow2)
  - `.build/iso-output/` - Bootable ISO files
  - `.build/registry-auth.json` - Temporary auth copied from system
- Configuration: Environment variables passed through Make → shell script → Containerfile as ARG
- Secrets: Registry auth mounted as build secrets (not baked into image), Harbor credentials via GitHub secrets

## Key Abstractions

**BundleManifest:**
- Purpose: Represent bundle metadata and validation schema
- Examples: `crates/bundle-cli/src/manifest.rs`
- Pattern: Serde-serializable struct with typed fields; schema_version guards forward compatibility

**BundleError:**
- Purpose: Unified error type with descriptive context
- Examples: `crates/bundle-cli/src/error.rs`
- Pattern: thiserror enum with variants for each failure mode; maps to specific exit codes

**Containerfile Layers:**
- Purpose: Separate concerns for reproducibility and caching
- Examples: `os/Containerfile.microshift`
- Pattern: Five explicit layers (dependencies, binaries, configs, offline images, services) for clear intent and build optimization

**CheckResult:**
- Purpose: Atomic verification check with pass/fail status and diagnostic detail
- Examples: `crates/bundle-cli/src/verify.rs`
- Pattern: Lightweight struct with name, passed flag, detail string; aggregated into VerifyResult

## Entry Points

**Makefile targets:**
- Location: `/Users/ravichillerega/sources/management/os-builder/Makefile`
- Triggers: Developer `make build`, `make test`, CI/CD jobs
- Responsibilities: Load versions, invoke build.sh/tests/scan/push, manage artifacts in .build/

**build.sh:**
- Location: `/Users/ravichillerega/sources/management/os-builder/os/build.sh`
- Triggers: Invoked by Makefile build target
- Responsibilities: Runtime detection, git metadata collection, image list generation, container build with auth secrets

**edgeworks-bundle CLI:**
- Location: `crates/bundle-cli/src/main.rs`
- Triggers: User CLI or CI/CD deployment scripts
- Responsibilities: Route subcommands (create/verify/inspect) to handler modules, format output (human/JSON), exit codes

**GitHub Actions workflow:**
- Location: `.github/workflows/build-microshift.yaml`
- Triggers: Push to main, pull request, schedule, manual dispatch
- Responsibilities: Version loading, build orchestration, security scanning, registry push, conditional ISO build

## Error Handling

**Strategy:** Fail-fast with descriptive context; distinct exit codes for different error classes

**Patterns:**

- Bundle CLI: Exit code 0 = success, 1 = logical verification failure, 2 = I/O error (bundle path doesn't exist)
- Containerfile: Set -euo pipefail in build.sh; container build fails immediately on RUN error
- Makefile: Error messages to stderr, clean exit codes; $(call ensure_tool,...) auto-installs missing dependencies
- Verification: Returns VerifyResult with checks list showing which checks passed/failed; human/JSON formatting of failures
- Create command: If skopeo unavailable, returns SkopeoNotAvailable error; if output exists, returns OutputExists error; pull failures include stderr context

## Cross-Cutting Concerns

**Logging:**
- Shell scripts: info() and error() functions with [INFO]/[ERROR] prefix to stderr
- Rust CLI: eprintln!() for errors, println!() for normal output; quiet JSON mode suppresses progress bars
- Containerfile: RUN statements print informational context (layer purpose, version info)
- GitHub Actions: Step names and explicit echo statements for visibility

**Validation:**
- Image reference: Requires tag (extract version from tag in bundle-cli)
- Manifest schema: Strict JSON parsing; unknown schema versions parsed but rejected during verify
- Checksum format: 64-character hex + 2 spaces + filename in checksums.sha256
- File sizes: Size mismatch between manifest and actual file is caught during verify

**Authentication:**
- Container runtime: Registry auth from system keyring (XDG_RUNTIME_DIR, ~/.config/containers, ~/.docker)
- Build secrets: Mounted as build secret (never baked into image) in Containerfile Layer 4
- Harbor registry: Credentials via GitHub secrets (REGISTRY_USERNAME, REGISTRY_PASSWORD)
- skopeo: Inherits REGISTRY_AUTH_FILE environment variable for offline pulls

**Offline Operation:**
- Image embedding: Containerfile Layer 4 pulls images at build-time into /usr/lib/containers/storage
- Air-gapped deployment: Images available locally on device; CRI-O accesses via dir: blobs
- Bundle distribution: OCI tarballs created by skopeo are self-contained; no registry access needed at deployment
- Manifest distribution: JSON manifest travels with tarball; can be verified offline

---

*Architecture analysis: 2026-03-11*
