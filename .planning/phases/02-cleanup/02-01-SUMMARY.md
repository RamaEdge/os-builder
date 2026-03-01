---
phase: 02-cleanup
plan: 01
subsystem: infra
tags: [k3s, edge-setup, versions, cleanup, git-rm]

requires:
  - phase: 01-foundation
    provides: Containerfile.microshift and MicroShift RPM installation established

provides:
  - Zero K3s files in the repository (9 files deleted via git rm)
  - edge-setup.sh reduced to OS-only first-boot config (~55 lines, no K3s/firewall blocks)
  - versions.txt simplified to 3 variables (OTEL_VERSION, FEDORA_VERSION, BOOTC_VERSION)

affects: [02-02, 03-ci-cleanup]

tech-stack:
  added: []
  patterns: [git-rm for staged deletions, OS-agnostic first-boot script pattern]

key-files:
  created: []
  modified:
    - os/scripts/edge-setup.sh
    - versions.txt
  deleted:
    - os/Containerfile.k3s
    - os/configs/k3s/config.yaml
    - os/configs/k3s/registries.yaml
    - os/scripts/k3s-load-images.sh
    - os/scripts/setup-k3s-kubeconfig.sh
    - os/systemd/k3s/k3s.service
    - os/systemd/k3s/k3s-load-images.service
    - os/systemd/k3s/k3s-kubeconfig-setup.service
    - os/systemd/microshift.service

key-decisions:
  - "Deleted custom os/systemd/microshift.service — MicroShift RPM provides the correct replacement; keeping would shadow it"
  - "Removed firewall-cmd block from edge-setup.sh — Containerfile.microshift already runs firewall-offline-cmd at build time"
  - "Removed otel-collector block — stale service name; MicroShift uses otelcol"

patterns-established:
  - "OS-only first-boot pattern: hostname, SSH hardening, journald, log rotation, auto-update, NTP — no workload config"

requirements-completed: [CLEAN-01, CLEAN-02, SIMP-01, SIMP-04]

duration: 15min
completed: 2026-03-01
---

# Phase 02-01: K3s File Deletion and Script Cleanup Summary

**Deleted 9 K3s files via git rm and rewrote edge-setup.sh to OS-only ~55-line script; stripped versions.txt to 3 variables**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-01T00:00:00Z
- **Completed:** 2026-03-01T00:15:00Z
- **Tasks:** 2
- **Files modified/deleted:** 11

## Accomplishments
- Deleted all 9 K3s files/directories using git rm (staged for commit)
- Rewrote edge-setup.sh from 181 lines to ~55 lines — removes firewall-cmd block, K3s kubeconfig setup, inline script generation, stale otel-collector block
- Simplified versions.txt from 7 variables to 3 (OTEL_VERSION, FEDORA_VERSION, BOOTC_VERSION)
- Verified: `grep -r -i k3s` on *.sh, *.yaml, Containerfile*, Makefile, *.txt returns zero results in edge-setup.sh and versions.txt

## Task Commits

1. **Task 1: Delete all K3s files using git rm** - `dd5d791` (feat)
2. **Task 2: Rewrite edge-setup.sh and simplify versions.txt** - `a190c8b` (feat)

## Files Created/Modified
- `os/scripts/edge-setup.sh` - Rewritten to OS-only first-boot config (hostname, SSH, journald, log rotation, auto-update, NTP)
- `versions.txt` - Reduced to 3 version variables + 2 explanatory comments

## Files Deleted
- `os/Containerfile.k3s`
- `os/configs/k3s/config.yaml`
- `os/configs/k3s/registries.yaml`
- `os/scripts/k3s-load-images.sh`
- `os/scripts/setup-k3s-kubeconfig.sh`
- `os/systemd/k3s/k3s-kubeconfig-setup.service`
- `os/systemd/k3s/k3s-load-images.service`
- `os/systemd/k3s/k3s.service`
- `os/systemd/microshift.service`

## Decisions Made
- Used `git rm -r` for directory removal to stage deletions atomically
- Deleted `os/systemd/microshift.service` custom file — the MicroShift RPM provides the correct one; keeping would shadow it
- Removed firewall-cmd block — Containerfile.microshift already handles firewall at build time via `firewall-offline-cmd`

## Deviations from Plan
None — plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- K3s dead code fully removed from os/ directory and versions.txt
- edge-setup.sh is variant-agnostic and ready for production use
- Enables Plan 02-02 (Makefile/build.sh) to complete K3s removal from build toolchain

---
*Phase: 02-cleanup*
*Completed: 2026-03-01*
