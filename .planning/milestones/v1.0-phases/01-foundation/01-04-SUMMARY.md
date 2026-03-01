---
plan: 01-04
phase: 01-foundation
status: complete
completed: 2026-03-01
---

# Plan 01-04 Summary: kustomizePaths Manifest Auto-deployment + Remove Deploy Service

## What Was Implemented

Three coordinated changes to replace the custom `observability-deploy.service` pattern with MicroShift's native `kustomizePaths` manifest auto-deployment.

**Files created:**
- `os/manifests/manifests.d/05-observability/kustomization.yaml` — kustomize entry point for observability stack
- `os/manifests/manifests.d/05-observability/observability-stack.yaml` — moved from `os/manifests/`

**Files modified:**
- `os/configs/microshift/config.yaml` — kustomizePaths updated from 2 to 4 paths
- `os/Containerfile.microshift` — removed observability-deploy.service COPY/enable, added manifests.d/ COPY

**Files deleted:**
- `os/systemd/observability-deploy.service` — no longer needed; MicroShift handles manifest apply natively

## Key Implementation Details

### config.yaml kustomizePaths Update (MNFT-02)

Changed from:
```yaml
manifests:
  kustomizePaths:
    - /usr/share/microshift/manifests   # was wrong path
    - /etc/microshift/manifests
```

To:
```yaml
manifests:
  kustomizePaths:
    - /usr/lib/microshift/manifests     # correct path for upstream RPM
    - /usr/lib/microshift/manifests.d/* # immutable layer, OS update survivors
    - /etc/microshift/manifests         # mutable config override
    - /etc/microshift/manifests.d/*     # mutable config override (directory glob)
```

Note: `/usr/share/microshift/manifests` → `/usr/lib/microshift/manifests` (path correction for upstream COPR RPM).

### manifests.d/05-observability/ Structure (MNFT-01)

```
os/manifests/manifests.d/05-observability/
├── kustomization.yaml       — kustomize entry: lists observability-stack.yaml as resource
└── observability-stack.yaml — moved from os/manifests/observability-stack.yaml
```

Scope: Only `05-observability` as specified. Manifests 10-40 (from edgeworks-deploy repo) are deferred beyond Phase 1.

### Containerfile Changes (MNFT-03)

- Removed: `COPY systemd/observability-deploy.service /usr/lib/systemd/system/`
- Removed: `observability-deploy.service` from `systemctl enable`
- Added: `COPY manifests/manifests.d/ /usr/lib/microshift/manifests.d/`

Note on benign side-effect: The retained `COPY manifests/ /etc/microshift/manifests/` also copies `manifests.d/` as a subdirectory into `/etc/microshift/manifests/manifests.d/`. This is benign — MicroShift's `kustomizePaths` scans `/etc/microshift/manifests.d/*` (top-level), not subdirectories of `/etc/microshift/manifests/`.

## Deviations from Plan

None. The Containerfile used explicit COPY lines (not wildcards), so removing `observability-deploy.service` required removing only one explicit line — simpler than the wildcard case documented in the plan as a potential pitfall.

## Requirements Satisfied

- **MNFT-01** (scoped to 05-observability): `manifests.d/05-observability/` created with `kustomization.yaml` and `observability-stack.yaml`
- **MNFT-02**: `config.yaml` includes both `manifests.d/*` paths in `kustomizePaths`; path corrected to `/usr/lib/microshift/`
- **MNFT-03**: Custom `observability-deploy.service` removed from image (both unit file and Containerfile references)
