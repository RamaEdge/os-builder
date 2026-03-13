# MicroShift Migration

## What This Is

The os-builder edge computing platform uses MicroShift via upstream COPR packages to produce immutable bootc images that boot fully functional — with all Kubernetes system pods and edgeworks application pods running offline. Includes the `edgeworks-bundle` CLI tool for creating, verifying, and inspecting offline deployment bundles.

## Core Value

Edge devices boot fully functional with all MicroShift system pods and edgeworks application pods running — without any network connectivity.

## Requirements

### Validated

- ✓ Fedora bootc base image with immutable OS updates — existing
- ✓ Containerized build pipeline with Makefile/build.sh — existing
- ✓ MicroShift configuration and systemd integration — existing
- ✓ OpenTelemetry Collector for observability — existing
- ✓ Edge setup script for first-boot OS configuration — existing
- ✓ Container auto-update support — existing
- ✓ GitHub Actions CI/CD workflows — existing
- ✓ New Containerfile.microshift using upstream COPR packages (THE-869) — v1.0
- ✓ Two-phase offline image embedding for MicroShift system images (THE-870) — v1.0
- ✓ Auto-deploy edgeworks manifests via MicroShift kustomizePaths (THE-871) — v1.0
- ✓ Embed edgeworks application container images for offline operation (THE-872) — v1.0
- ✓ Remove all K3s files and references (THE-873) — v1.0
- ✓ Simplify edge-setup.sh to OS-only concerns (THE-874) — v1.0
- ✓ Simplify Makefile and build.sh to single MicroShift variant (THE-875) — v1.0
- ✓ Update CI workflows and tests for MicroShift-only build (THE-876) — v1.0
- ✓ Extract shared format utility module — v1.2
- ✓ Replace silent JSON serialization fallbacks with error propagation — v1.2
- ✓ Validate image reference format before shell execution — v1.2
- ✓ Decompose run_verify() into composable check functions — v1.2
- ✓ Replace fragile checksum parsing with dedicated struct — v1.2
- ✓ Replace raw string image version extraction with proper parsing — v1.2

### Active

(None — all current requirements shipped)

### Out of Scope

- Multi-node MicroShift clusters — single-node edge deployment only
- OVN-Kubernetes networking — Fedora requires kindnet, OVN-K not supported
- Edgeworks-deploy repo manifests 10-40 — deferred beyond v1.0 (only 05-observability shipped)
- GPG signing of bundles — deferred to future (design doc §9)
- Version enforcement / downgrade prevention — deferred to future
- Multi-arch bundles — deferred to future
- Delta bundles (layer diffing) — deferred to future

## Context

**Current State:** v1.2 shipped. Bundle CLI (`edgeworks-bundle`) is a clean, well-tested Rust codebase with 1,822 LOC across 10 source files and 54 tests. All code duplication eliminated, error handling hardened, monolithic functions decomposed.

**Tech Stack:** Fedora 42 bootc, MicroShift, Rust (clap, serde_json, sha2, thiserror, indicatif, chrono), skopeo.

**Migration Guide:** `MICROSHIFT_MIGRATION.md` in repo root — historical reference for the K3s → MicroShift migration.

**Design Authority:** `docs/bundle-cli-design.md` — canonical reference for bundle CLI features and architecture.

**Linear Issues (v1.0):** THE-869 through THE-876 (all Done).

## Constraints

- **Platform**: Fedora 42 bootc base image (aarch64 primary target)
- **Networking**: kindnet CNI required (OVN-K not supported on Fedora)
- **Storage**: TopoLVM for LVM-backed PVCs (edgeworks workloads need persistent storage)
- **Airgap**: Must function fully offline after initial image deployment
- **Images**: 15 application images + MicroShift system images embedded

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use upstream COPR packages instead of custom builds | Official distribution, automatic updates, correct systemd units | ✓ Good — eliminates multi-stage builder dependency |
| Two-phase image embedding (build → runtime copy) | Matches upstream pattern, works with immutable /usr | ✓ Good — skopeo + ExecStartPre pattern works cleanly |
| kustomizePaths for manifest deployment | Built-in MicroShift feature, eliminates custom systemd services | ✓ Good — removed observability-deploy.service |
| Remove K3s entirely | Simplify to single variant, reduce maintenance burden | ✓ Good — 9 files deleted, scripts halved |
| kindnet over OVN-K | Only supported CNI on Fedora MicroShift | ✓ Good — installed via microshift-kindnet RPM |
| Remove BOOTC_VERSION from versions.txt | No ARG in Containerfile consumed it; FEDORA_VERSION controls base image | ✓ Good — eliminated dead variable |
| inspect.rs TiB implementation as canonical format_bytes | Most complete implementation (B/KiB/MiB/GiB/TiB); create/verify only had GiB | ✓ Good — single source of truth |
| Character allowlist for ImageRef validation | Reject unexpected chars (not blocklist) — safer against novel injection | ✓ Good — prevents shell metacharacter injection |
| ChecksumLine reuses ManifestInvalid error variant | Avoids unnecessary error variant proliferation for parse failures | ✓ Good — keeps error enum focused |
| run_verify() orchestrator pattern with check_* functions | Each check is independently testable; adding a 7th check is one function + one line | ✓ Good — 230 lines → 6 functions + ~30-line coordinator |
| JSON format errors use exit(1) not exit(2) | exit(2) reserved for path-not-found; format errors are logic errors | ✓ Good — preserves exit code contract |
| create.rs Err arm uses .expect() for json! literal | serde_json::Value serialization is infallible; .expect() documents this | ✓ Good — clearer than unnecessary ? |

---
*Last updated: 2026-03-13 after v1.2 milestone completion*
