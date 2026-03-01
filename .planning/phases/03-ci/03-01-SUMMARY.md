---
plan: 03-01
phase: 03-ci
status: complete
completed: 2026-03-01
requirements: [CI-01, CI-02, CI-03]
---

# Summary: CI Layer Cleanup — K3s Removal and MicroShift Promotion

## What Was Changed

### Deleted
- `.github/workflows/build-and-security-scan.yaml` — K3s default CI workflow removed entirely (CI-01)

### Updated: `.github/workflows/build-microshift.yaml`
- Added `push`, `pull_request`, and `schedule` triggers targeting `main` branch with `os/**` path filter (CI-02)
- Changed `CONTAINERFILE` env from `Containerfile.fedora.optimized` to `Containerfile.microshift`
- Fixed `local-tag` output bug: `build-scan-test` outputs now use `steps.build.outputs.image-ref` (not `steps.build.outputs.local-tag`)
- Removed `microshift-version` from the `Build container image` step inputs
- Removed `microshift_version` workflow_dispatch input
- Added `force_rebuild` dispatch input; expanded `iso_config` options to include `production`
- Updated `build-iso` job condition to trigger on schedule as well as manual dispatch

### Updated: `.github/actions/test-container/test-container.sh`
- Removed `run_k3s_tests()` function entirely (CI-03)
- Removed `"k3s")` case branch from the type dispatch
- Updated usage message and error fallback to list only `microshift, bootc`
- Added 5 Phase 1-3 artifact checks inside `run_microshift_tests()`:
  - `skopeo binary` — verifies skopeo is installed and executable
  - `microshift-copy-images script` — verifies script exists and is executable at `/usr/bin/microshift-copy-images`
  - `microshift copy-images drop-in` — verifies systemd drop-in at `/usr/lib/systemd/system/microshift.service.d/microshift-copy-images.conf`
  - `embedded image store` — verifies `/usr/lib/containers/storage/image-list.txt` exists
  - `manifests.d directory` — verifies `/usr/lib/microshift/manifests.d` exists

### Updated: `.github/actions/load-versions/action.yml`
- Removed dead outputs: `k3s-version`, `microshift-version`, `cni-version`
- Removed corresponding `echo` lines and log lines from the run script
- Retained: `otel-version`, `fedora-version`, `bootc-version`

### Updated: `.github/workflows/dependency-update.yaml`
- Changed all 3 references from `os/Containerfile.fedora` to `os/Containerfile.microshift`
  - `Extract base image` step: grep for FROM line
  - `Extract installed packages` step: two grep lines for dnf install

## Bugs Fixed

- **`local-tag` output reference bug**: `build-scan-test` job was outputting `${{ steps.build.outputs.local-tag }}` but the `build-container` action only outputs `image-ref`. Fixed to `steps.build.outputs.image-ref`. This was a latent bug that would have caused the `push` and `build-iso` jobs to receive an empty image reference.

## Requirements Addressed

- **CI-01**: `.github/workflows/build-and-security-scan.yaml` deleted — K3s CI workflow is gone
- **CI-02**: `build-microshift.yaml` now triggers on push/PR to main and on schedule; `CONTAINERFILE` is `Containerfile.microshift`; `local-tag` bug fixed
- **CI-03**: `test-container.sh` has no K3s references; MicroShift test suite extended with Phase 1-3 artifact checks

## Deviations

- **Task 1 changes were pre-applied**: Commits from Phase 2 (02-02) already included the trigger block changes, `CONTAINERFILE` update, `local-tag` fix, and `microshift-version` removal in `build-microshift.yaml`. The write during this plan execution confirmed the correct final state with no diff vs HEAD. No rework was needed.

## Self-Check

All success criteria verified:
1. `build-and-security-scan.yaml` does not exist — PASS
2. `build-microshift.yaml` has `push:` and `pull_request:` targeting `main` — PASS
3. `CONTAINERFILE: Containerfile.microshift` — PASS
4. Build step has no `microshift-version:` input — PASS
5. `test-container.sh` has no `run_k3s_tests` or `"k3s")` — PASS
6. `test-container.sh` has checks for `microshift-copy-images`, `image-list.txt`, `manifests.d` — PASS
7. `bash -n test-container.sh` exits 0 — PASS
8. `load-versions/action.yml` has no dead version outputs — PASS
9. `dependency-update.yaml` references `Containerfile.microshift` — PASS
