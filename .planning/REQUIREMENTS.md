# Requirements: MicroShift Migration

**Defined:** 2026-03-01
**Core Value:** Edge devices boot fully functional with all MicroShift system pods and edgeworks application pods running — without any network connectivity.

## v1 Requirements

Requirements for MicroShift migration. Each maps to roadmap phases.

### Container Build

- [ ] **BUILD-01**: New Containerfile.microshift installs MicroShift via upstream COPR packages (`@microshift-io/microshift-nightly`)
- [ ] **BUILD-02**: Containerfile includes kindnet and TopoLVM packages with release-info RPMs
- [ ] **BUILD-03**: Containerfile adds skopeo and VOLUME /var for kubelet idmap support
- [ ] **BUILD-04**: Custom microshift.service and multi-stage builder image removed

### Offline Images

- [ ] **OFFL-01**: Build-time embedding reads image refs from `/usr/share/microshift/release/*.json` and copies via skopeo to `/usr/lib/containers/storage/`
- [ ] **OFFL-02**: Runtime `microshift-copy-images` script copies from `/usr/lib` to CRI-O `/var` storage on each boot
- [ ] **OFFL-03**: Systemd drop-in at `/usr/lib/systemd/system/microshift.service.d/` runs microshift-copy-images as ExecStartPre
- [ ] **OFFL-04**: All 15 edgeworks application images embedded at build time from `os/configs/edgeworks-images.txt`
- [ ] **OFFL-05**: Boot without network results in all MicroShift system pods and edgeworks application pods running

### Manifest Deployment

- [ ] **MNFT-01**: Edgeworks manifests placed in `/usr/lib/microshift/manifests.d/` with numbered subdirectories (05-observability through 40-opcua-adapter)
- [ ] **MNFT-02**: MicroShift `config.yaml` kustomizePaths includes `manifests.d/*`
- [ ] **MNFT-03**: Custom deploy systemd services (`deploy-observability.sh`, `observability-deploy.service`) removed

### K3s Removal

- [ ] **CLEAN-01**: All K3s files deleted — Containerfile.k3s, configs/k3s/, scripts/k3s-*.sh, systemd/k3s/, os/systemd/microshift.service
- [ ] **CLEAN-02**: K3s references removed from edge-setup.sh (lines 47-51, 93-168), versions.txt (K3S_VERSION, CNI_VERSION), build.sh (K3s detection branch)

### Script Simplification

- [ ] **SIMP-01**: edge-setup.sh contains only OS-level first-boot config (hostname, SSH, journald, log rotation, auto-update, NTP)
- [ ] **SIMP-02**: Makefile has single `build` target using `Containerfile.microshift`, no K3s/MicroShift version variables
- [ ] **SIMP-03**: build.sh has no K3s detection branch
- [ ] **SIMP-04**: versions.txt contains only OTEL_VERSION, FEDORA_VERSION, BOOTC_VERSION

### CI/CD

- [ ] **CI-01**: K3s CI workflow (`.github/workflows/build-and-security-scan.yaml`) removed
- [ ] **CI-02**: MicroShift CI workflow is the default build workflow
- [ ] **CI-03**: test-container.sh tests MicroShift variant only

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
| BUILD-01 | Phase 1 | Pending |
| BUILD-02 | Phase 1 | Pending |
| BUILD-03 | Phase 1 | Pending |
| BUILD-04 | Phase 1 | Pending |
| OFFL-01 | Phase 2 | Pending |
| OFFL-02 | Phase 2 | Pending |
| OFFL-03 | Phase 2 | Pending |
| OFFL-04 | Phase 2 | Pending |
| OFFL-05 | Phase 2 | Pending |
| MNFT-01 | Phase 2 | Pending |
| MNFT-02 | Phase 2 | Pending |
| MNFT-03 | Phase 2 | Pending |
| CLEAN-01 | Phase 3 | Pending |
| CLEAN-02 | Phase 3 | Pending |
| SIMP-01 | Phase 3 | Pending |
| SIMP-02 | Phase 3 | Pending |
| SIMP-03 | Phase 3 | Pending |
| SIMP-04 | Phase 3 | Pending |
| CI-01 | Phase 4 | Pending |
| CI-02 | Phase 4 | Pending |
| CI-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0

---
*Requirements defined: 2026-03-01*
*Last updated: 2026-03-01 after roadmap creation*
