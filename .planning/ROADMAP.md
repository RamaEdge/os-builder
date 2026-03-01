# Roadmap: MicroShift Migration

## Overview

Migrate os-builder from K3s to MicroShift using upstream COPR packages. Phase 1 replaces the Containerfile foundation. Phase 2 implements offline operation — the two-phase image embedding pattern and kustomizePaths manifest deployment that let edge devices boot fully functional without network. Phase 3 removes all K3s code and simplifies the build toolchain to a single variant. Phase 4 updates CI to match the new single-variant build.

**Reference Document:** `MICROSHIFT_MIGRATION.md` — detailed migration guide with implementation patterns, file-by-file changes, and verification steps. All phases should consult this document during planning and execution.

**Linear Issues:** THE-869 through THE-876 (os-builder project)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - New Containerfile.microshift using upstream COPR packages
- [ ] **Phase 2: Offline Operation** - Two-phase image embedding and kustomizePaths manifest deployment
- [ ] **Phase 3: Cleanup** - K3s removal and build toolchain simplification
- [ ] **Phase 4: CI** - Update CI workflows and tests for MicroShift-only build

## Phase Details

### Phase 1: Foundation
**Goal**: A new Containerfile.microshift installs MicroShift from upstream COPR packages and is ready to build
**Depends on**: Nothing (first phase)
**Requirements**: BUILD-01, BUILD-02, BUILD-03, BUILD-04
**Success Criteria** (what must be TRUE):
  1. `podman build -f Containerfile.microshift` completes without error using COPR packages
  2. The built image contains MicroShift, kindnet, TopoLVM, and skopeo installed via RPM
  3. No custom microshift.service or multi-stage builder image reference exists in the Containerfile
  4. VOLUME /var is declared in the Containerfile for kubelet idmap support
**Plans**: TBD

**Plans:** 1 plan

Plans:
- [ ] 01-01-PLAN.md — Write os/Containerfile.microshift with COPR packages, kindnet, TopoLVM, skopeo, VOLUME /var

### Phase 2: Offline Operation
**Goal**: Edge devices boot fully functional with all MicroShift system pods and edgeworks application pods running without network connectivity
**Depends on**: Phase 1
**Requirements**: OFFL-01, OFFL-02, OFFL-03, OFFL-04, OFFL-05, MNFT-01, MNFT-02, MNFT-03
**Success Criteria** (what must be TRUE):
  1. `skopeo copy` embeds all MicroShift system images from release JSON into `/usr/lib/containers/storage/` at build time
  2. All 15 edgeworks application images from `os/configs/edgeworks-images.txt` are embedded at build time
  3. On first boot with no network, `microshift-copy-images` runs as ExecStartPre and copies images to CRI-O storage
  4. Edgeworks manifests in `/usr/lib/microshift/manifests.d/` are auto-deployed by MicroShift on boot via kustomizePaths
  5. Custom deploy systemd services are absent from the image
**Plans**: TBD

Plans:
- [ ] 02-01: Implement build-time image embedding script (reads release JSON, skopeo copy to /usr/lib)
- [ ] 02-02: Implement runtime microshift-copy-images script, systemd drop-in, and edgeworks image embedding
- [ ] 02-03: Configure kustomizePaths in microshift config.yaml and place manifests in manifests.d/

### Phase 3: Cleanup
**Goal**: All K3s code is deleted and the build toolchain operates as a single MicroShift-only variant
**Depends on**: Phase 2
**Requirements**: CLEAN-01, CLEAN-02, SIMP-01, SIMP-02, SIMP-03, SIMP-04
**Success Criteria** (what must be TRUE):
  1. No K3s files exist anywhere in the repository (Containerfile.k3s, configs/k3s/, scripts/k3s-*.sh, systemd/k3s/)
  2. `grep -r k3s .` returns no results in source files
  3. edge-setup.sh contains only OS-level first-boot configuration
  4. `make build` runs a single target against Containerfile.microshift with no K3s/MicroShift version variables
  5. versions.txt contains only OTEL_VERSION, FEDORA_VERSION, BOOTC_VERSION
**Plans**: TBD

Plans:
- [ ] 03-01: Delete all K3s files and remove K3s references from edge-setup.sh, versions.txt, build.sh
- [ ] 03-02: Simplify Makefile to single build target and clean up build.sh

### Phase 4: CI
**Goal**: CI builds and tests the MicroShift variant as the one and only workflow
**Depends on**: Phase 3
**Requirements**: CI-01, CI-02, CI-03
**Success Criteria** (what must be TRUE):
  1. The K3s CI workflow file no longer exists in `.github/workflows/`
  2. The MicroShift CI workflow is the default build workflow and triggers on push to main
  3. test-container.sh tests MicroShift variant only and passes
**Plans**: TBD

Plans:
- [ ] 04-01: Remove K3s CI workflow, update MicroShift workflow as default, update test-container.sh

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/1 | Not started | - |
| 2. Offline Operation | 0/3 | Not started | - |
| 3. Cleanup | 0/2 | Not started | - |
| 4. CI | 0/1 | Not started | - |
