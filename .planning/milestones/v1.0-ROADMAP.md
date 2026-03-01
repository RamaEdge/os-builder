# Roadmap: MicroShift Migration

## Overview

Migrate os-builder from K3s to MicroShift using upstream COPR packages. Phase 1 builds the new Containerfile with COPR packages and implements offline operation — the two-phase image embedding pattern and kustomizePaths manifest deployment. Phase 2 removes all K3s code and simplifies the build toolchain. Phase 3 updates CI to match the single-variant build. All three phases execute in parallel (no file overlap).

**Reference Document:** `MICROSHIFT_MIGRATION.md` — detailed migration guide with implementation patterns, file-by-file changes, and verification steps. All phases should consult this document during planning and execution.

**Linear Issues:** THE-869 through THE-876 (os-builder project)

## Phases

- [x] **Phase 1: Containerfile + Offline Operation** - New Containerfile.microshift with COPR packages and two-phase image embedding
- [x] **Phase 2: Cleanup** - K3s removal and build toolchain simplification
- [x] **Phase 3: CI** - Update CI workflows and tests for MicroShift-only build

## Phase Details

### Phase 1: Containerfile + Offline Operation
**Goal**: A new Containerfile.microshift installs MicroShift from upstream COPR packages, embeds all system and application images for offline boot, and auto-deploys manifests via kustomizePaths
**Depends on**: Nothing (first phase)
**Requirements**: BUILD-01, BUILD-02, BUILD-03, BUILD-04, OFFL-01, OFFL-02, OFFL-03, OFFL-04, OFFL-05, MNFT-01, MNFT-02, MNFT-03
**Success Criteria** (what must be TRUE):
  1. `podman build -f Containerfile.microshift` completes without error using COPR packages
  2. The built image contains MicroShift, kindnet, TopoLVM, and skopeo installed via RPM
  3. No custom microshift.service or multi-stage builder image reference exists in the Containerfile
  4. VOLUME /var is declared in the Containerfile for kubelet idmap support
  5. `skopeo copy` embeds all MicroShift system images from release JSON into `/usr/lib/containers/storage/` at build time
  6. All 15 edgeworks application images from `os/configs/edgeworks-images.txt` are embedded at build time
  7. On first boot with no network, `microshift-copy-images` runs as ExecStartPre and copies images to CRI-O storage
  8. Edgeworks manifests in `/usr/lib/microshift/manifests.d/` are auto-deployed by MicroShift on boot via kustomizePaths
  9. Custom deploy systemd services are absent from the image

**Plans:** 4 plans in 3 waves

Plans:
- [x] 01-01-PLAN.md — Write os/Containerfile.microshift with COPR packages, kindnet, TopoLVM, skopeo, VOLUME /var (wave 1)
- [x] 01-02-PLAN.md — Implement build-time image embedding script (wave 1)
- [x] 01-03-PLAN.md — Implement runtime microshift-copy-images script, systemd drop-in, and edgeworks image embedding (wave 2)
- [x] 01-04-PLAN.md — Configure kustomizePaths in microshift config.yaml and place manifests in manifests.d/ (wave 3)

### Phase 2: Cleanup
**Goal**: All K3s code is deleted and the build toolchain operates as a single MicroShift-only variant
**Depends on**: Nothing (parallel execution — no file overlap with Phase 1 or 3)
**Requirements**: CLEAN-01, CLEAN-02, SIMP-01, SIMP-02, SIMP-03, SIMP-04
**Success Criteria** (what must be TRUE):
  1. No K3s files exist anywhere in the repository (Containerfile.k3s, configs/k3s/, scripts/k3s-*.sh, systemd/k3s/)
  2. `grep -r k3s .` returns no results in source files
  3. edge-setup.sh contains only OS-level first-boot configuration
  4. `make build` runs a single target against Containerfile.microshift with no K3s/MicroShift version variables
  5. versions.txt contains only OTEL_VERSION, FEDORA_VERSION, BOOTC_VERSION

**Plans:** 2 plans in 1 wave

Plans:
- [x] 02-01-PLAN.md — Delete all K3s files and remove K3s references from edge-setup.sh, versions.txt, build.sh (wave 1)
- [x] 02-02-PLAN.md — Simplify Makefile to single build target and clean up build.sh (wave 1)

### Phase 3: CI
**Goal**: CI builds and tests the MicroShift variant as the one and only workflow
**Depends on**: Nothing (parallel execution — no file overlap with Phase 1 or 2)
**Requirements**: CI-01, CI-02, CI-03
**Success Criteria** (what must be TRUE):
  1. The K3s CI workflow file no longer exists in `.github/workflows/`
  2. The MicroShift CI workflow is the default build workflow and triggers on push to main
  3. test-container.sh tests MicroShift variant only and passes

**Plans:** 1 plan in 1 wave

Plans:
- [x] 03-01-PLAN.md — Remove K3s CI workflow, update MicroShift workflow as default, update test-container.sh (wave 1)

## Progress

**Execution Order:**
All phases execute in parallel (no file overlap between phases).

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Containerfile + Offline | 4/4 | Complete | 2026-03-01 |
| 2. Cleanup | 2/2 | Complete | 2026-03-01 |
| 3. CI | 1/1 | Complete | 2026-03-01 |
