# MicroShift Migration

## What This Is

Migrate the os-builder edge computing platform from K3s to MicroShift using upstream COPR packages. This replaces the custom-built MicroShift binary approach with official RPM packages, implements a two-phase offline image embedding pattern for airgap operation, and cleans up all K3s-related code to leave a single, simplified MicroShift-only build.

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

### Active

- [ ] New Containerfile.microshift using upstream COPR packages (THE-869)
- [ ] Two-phase offline image embedding for MicroShift system images (THE-870)
- [ ] Auto-deploy edgeworks manifests via MicroShift kustomizePaths (THE-871)
- [ ] Embed edgeworks application container images for offline operation (THE-872)
- [ ] Remove all K3s files and references (THE-873)
- [ ] Simplify edge-setup.sh to OS-only concerns (THE-874)
- [ ] Simplify Makefile and build.sh to single MicroShift variant (THE-875)
- [ ] Update CI workflows and tests for MicroShift-only build (THE-876)

### Out of Scope

- Multi-node MicroShift clusters — single-node edge deployment only
- OVN-Kubernetes networking — Fedora requires kindnet, OVN-K not supported
- Custom MicroShift binary builds — migrating to upstream COPR packages
- K3s variant maintenance — being fully removed

## Context

The os-builder currently supports two Kubernetes variants (K3s and MicroShift). The MicroShift variant uses a custom-built binary from a multi-stage Docker build (`ghcr.io/ramaedge/microshift-builder`). This migration moves to upstream MicroShift COPR packages (`@microshift-io/microshift-nightly`), which are the official distribution channel.

The current airgap approach uses `podman pull` at build time. The new approach follows upstream's two-phase pattern: build-time embedding via `skopeo copy` into `/usr/lib/containers/storage/`, then runtime copy into CRI-O's `/var` storage via a systemd `ExecStartPre` script.

Edgeworks application manifests are currently deployed via custom systemd services. MicroShift's built-in `kustomizePaths` feature eliminates the need for custom deploy services — manifests placed in `/usr/lib/microshift/manifests.d/` are auto-deployed on every boot.

All Linear issues reference `MICROSHIFT_MIGRATION.md` for detailed implementation guidance; the issues themselves contain sufficient detail for execution.

## Constraints

- **Platform**: Fedora 42 bootc base image (aarch64 primary target)
- **Networking**: kindnet CNI required (OVN-K not supported on Fedora)
- **Storage**: TopoLVM for LVM-backed PVCs (edgeworks workloads need persistent storage)
- **Airgap**: Must function fully offline after initial image deployment
- **Images**: 15 application images + MicroShift system images must be embedded

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use upstream COPR packages instead of custom builds | Official distribution, automatic updates, correct systemd units | — Pending |
| Two-phase image embedding (build → runtime copy) | Matches upstream pattern, works with immutable /usr | — Pending |
| kustomizePaths for manifest deployment | Built-in MicroShift feature, eliminates custom systemd services | — Pending |
| Remove K3s entirely | Simplify to single variant, reduce maintenance burden | — Pending |
| kindnet over OVN-K | Only supported CNI on Fedora MicroShift | — Pending |

---
*Last updated: 2026-03-01 after initialization*
