# Requirements: MicroShift Migration

**Defined:** 2026-03-01
**Core Value:** Edge devices boot fully functional with all MicroShift system pods and edgeworks application pods running — without any network connectivity.

## v1 Requirements

Requirements for MicroShift migration. Each maps to roadmap phases.

### Container Build

- [x] **BUILD-01**: New Containerfile.microshift installs MicroShift via upstream COPR packages (`@microshift-io/microshift-nightly`)
- [x] **BUILD-02**: Containerfile includes kindnet and TopoLVM packages with release-info RPMs
- [x] **BUILD-03**: Containerfile adds skopeo and VOLUME /var for kubelet idmap support
- [x] **BUILD-04**: Custom microshift.service and multi-stage builder image removed

### Offline Images

- [x] **OFFL-01**: Build-time embedding reads image refs from `/usr/share/microshift/release/*.json` and copies via skopeo to `/usr/lib/containers/storage/`
- [x] **OFFL-02**: Runtime `microshift-copy-images` script copies from `/usr/lib` to CRI-O `/var` storage on each boot
- [x] **OFFL-03**: Systemd drop-in at `/usr/lib/systemd/system/microshift.service.d/` runs microshift-copy-images as ExecStartPre
- [x] **OFFL-04**: All 15 edgeworks application images embedded at build time from `os/configs/edgeworks-images.txt`
- [x] **OFFL-05**: Boot without network results in all MicroShift system pods and edgeworks application pods running

### Manifest Deployment

- [x] **MNFT-01**: Observability manifests placed in `/usr/lib/microshift/manifests.d/05-observability/` with kustomization.yaml (in-repo manifests only; edgeworks-deploy repo manifests 10-40 deferred)
- [x] **MNFT-02**: MicroShift `config.yaml` kustomizePaths includes `manifests.d/*`
- [x] **MNFT-03**: Custom deploy systemd services (`deploy-observability.sh`, `observability-deploy.service`) removed

### K3s Removal

- [x] **CLEAN-01**: All K3s files deleted — Containerfile.k3s, configs/k3s/, scripts/k3s-*.sh, systemd/k3s/, os/systemd/microshift.service
- [x] **CLEAN-02**: K3s references removed from edge-setup.sh (lines 47-51, 93-168), versions.txt (K3S_VERSION, CNI_VERSION), build.sh (K3s detection branch)

### Script Simplification

- [x] **SIMP-01**: edge-setup.sh contains only OS-level first-boot config (hostname, SSH, journald, log rotation, auto-update, NTP)
- [x] **SIMP-02**: Makefile has single `build` target using `Containerfile.microshift`, no K3s/MicroShift version variables
- [x] **SIMP-03**: build.sh has no K3s detection branch
- [x] **SIMP-04**: versions.txt contains only OTEL_VERSION, FEDORA_VERSION, BOOTC_VERSION

### CI/CD

- [x] **CI-01**: K3s CI workflow (`.github/workflows/build-and-security-scan.yaml`) removed
- [x] **CI-02**: MicroShift CI workflow is the default build workflow
- [x] **CI-03**: test-container.sh tests MicroShift variant only

## v2 Requirements

None — this is a focused migration with well-defined scope.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-node MicroShift clusters | Single-node edge deployment only |
| OVN-Kubernetes networking | Not supported on Fedora; kindnet required |
| Custom MicroShift binary builds | Migrating to upstream COPR packages |
| K3s variant maintenance | Being fully removed |
| MicroShift version pinning | Version tracked by dnf/COPR, not versions.txt |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUILD-01 | Phase 1 | Done |
| BUILD-02 | Phase 1 | Done |
| BUILD-03 | Phase 1 | Done |
| BUILD-04 | Phase 1 | Done |
| OFFL-01 | Phase 1 | Done |
| OFFL-02 | Phase 1 | Done |
| OFFL-03 | Phase 1 | Done |
| OFFL-04 | Phase 1 | Done |
| OFFL-05 | Phase 1 | Done |
| MNFT-01 | Phase 1 | Done |
| MNFT-02 | Phase 1 | Done |
| MNFT-03 | Phase 1 | Done |
| CLEAN-01 | Phase 2 | Done |
| CLEAN-02 | Phase 2 | Done |
| SIMP-01 | Phase 2 | Done |
| SIMP-02 | Phase 2 | Done |
| SIMP-03 | Phase 2 | Done |
| SIMP-04 | Phase 2 | Done |
| CI-01 | Phase 3 | Done |
| CI-02 | Phase 3 | Done |
| CI-03 | Phase 3 | Done |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0

---
*Requirements defined: 2026-03-01*
*Last updated: 2026-03-01 — all requirements complete*
