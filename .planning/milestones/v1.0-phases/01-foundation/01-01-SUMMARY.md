---
plan: 01-01
phase: 01-foundation
status: complete
completed: 2026-03-01
---

# Plan 01-01 Summary: Create os/Containerfile.microshift

## What Was Built

Created `os/Containerfile.microshift` as a clean single-stage bootc Containerfile. This replaces the previous multi-stage build (`Containerfile.fedora.optimized`) that fetched a custom `ghcr.io/ramaedge/microshift-builder` pre-built binary image.

**Key file created:**
- `os/Containerfile.microshift` — 94 lines, single-stage, buildable with `podman build -f os/Containerfile.microshift os/`

## Key Decisions Made

1. **Single-stage FROM** — `quay.io/fedora/fedora-bootc:${FEDORA_VERSION}` only. No `FROM ${MICROSHIFT_IMAGE_BASE}` or `COPY --from` patterns.

2. **COPR package installation** — `dnf copr enable -y @microshift-io/microshift-nightly` installs all 6 RPMs: microshift, microshift-release-info, microshift-kindnet, microshift-kindnet-release-info, microshift-topolvm, microshift-topolvm-release-info. The RPM provides the microshift binary, microshift.service, firewall zones, and kubeconfig symlinks.

3. **No custom microshift.service** — RPM postinstall handles service enablement. Overwriting the RPM-provided service file would break make-rshared integration.

4. **Explicit COPY enumeration** — Named each systemd unit individually (no `COPY systemd/*.service` wildcard). This prevents accidental inclusion of `observability-deploy.service` in future (which will be removed in Plan 01-04).

5. **skopeo installed in system packages** — Required for build-time image embedding (OFFL-01, Plan 01-02).

6. **VOLUME /var** — Declared before `RUN bootc container lint` per bootc upstream mandate for kubelet idmap support.

7. **ARGs removed**: `MICROSHIFT_VERSION`, `MICROSHIFT_IMAGE_BASE`, `MICROSHIFT_REPO`, `EMBED_CONTAINER_IMAGES` (Phase 2 ARG added in Plan 01-02).

## Verification Results (Task 2 Static Checks)

| Check | Result |
|-------|--------|
| File exists, non-empty (94 lines) | PASS |
| Exactly 1 FROM instruction | PASS |
| VOLUME /var (line 89) < bootc lint (line 93) | PASS |
| USER containeruser (line 94) > bootc lint (line 93) | PASS |
| All 6 MicroShift COPR packages present | PASS |
| skopeo in dnf install | PASS |
| No forbidden patterns (multi-stage, MICROSHIFT_VERSION, wildcard systemd COPY) | PASS |
| All referenced scripts/units exist on disk | PASS |

## Requirements Satisfied

- **BUILD-01**: `dnf copr enable -y @microshift-io/microshift-nightly` present
- **BUILD-02**: microshift-kindnet and microshift-topolvm (+ release-info variants) installed
- **BUILD-03**: skopeo in package list; VOLUME /var declared
- **BUILD-04**: No COPY of custom microshift.service; bootc container lint is last RUN instruction

## Open Questions / Notes for Plan 01-02

- Plan 01-02 (Wave 1, parallel) adds `ARG EMBED_CONTAINER_IMAGES=1`, `subuid/subgid` setup, and the embed script COPY+RUN to this Containerfile.
- Plan 01-04 (Wave 3) removes `observability-deploy.service` from COPY and systemctl enable.
- `observability-deploy.service` is currently COPY'd and enabled — this is intentional for now, to be cleaned up in Plan 01-04.
