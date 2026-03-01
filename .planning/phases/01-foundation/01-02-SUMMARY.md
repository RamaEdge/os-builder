---
plan: 01-02
phase: 01-foundation
status: complete
completed: 2026-03-01
---

# Plan 01-02 Summary: Create embed-microshift-images.sh (Build-Time Half)

## What Was Implemented

Created `os/scripts/embed-microshift-images.sh` — the build-time half of the two-phase offline image embedding pattern. Integrated it into `os/Containerfile.microshift` with the required subuid/subgid setup and `EMBED_CONTAINER_IMAGES` gate.

**Files created/modified:**
- `os/scripts/embed-microshift-images.sh` — new executable bash script (build-time image embedding)
- `os/Containerfile.microshift` — updated with `ARG EMBED_CONTAINER_IMAGES=1`, subuid/subgid RUN, COPY + gated RUN for embed script

## Key Implementation Details

### embed-microshift-images.sh

Implements the upstream `microshift-io/microshift src/image/embed_images.sh` pattern:
- Finds all `*.json` in `/usr/share/microshift/release/`
- Exits gracefully if no manifests found
- Loops over images via `jq -r '.images[]? // empty'`
- Counts TOTAL before skip check; skips `registry.redhat.io` images (SKIPPED++)
- Uses `sha256sum` of image ref as directory name under `/usr/lib/containers/storage/`
- Idempotent: checks for `manifest.json` before re-pulling
- Uses `skopeo copy --all --preserve-digests docker://${img} dir:${DEST}`
- On failure: logs WARN, removes partial dir, continues
- Appends `${img},${SHA}` to `image-list.txt`
- Final log: `"N pulled, N skipped, N total"`

Constants defined (used by Plan 01-03 extension):
- `COPY_SCRIPT="/usr/bin/microshift-copy-images"` (not yet used)
- `DROPIN_DIR="/usr/lib/systemd/system/microshift.service.d"` (not yet used)

### Containerfile Integration

Added in order after MicroShift COPR install block:
1. `ARG EMBED_CONTAINER_IMAGES=1` in ARG section (line 6)
2. `RUN echo "root:1:65536" >> /etc/subuid && echo "root:1:65536" >> /etc/subgid` (line 54)
3. `COPY scripts/embed-microshift-images.sh /tmp/embed-microshift-images.sh` (line 57)
4. `RUN ... if [ "${EMBED_CONTAINER_IMAGES}" = "1" ]; then /tmp/embed-microshift-images.sh; fi ...` (line 59)

## Deviations from Plan

None. Plan followed exactly. COPY_SCRIPT constant is defined in variables section as specified — the runtime script generation is intentionally deferred to Plan 01-03.

## Requirements Satisfied

- **OFFL-01**: Build-time image embedding from release JSON to `/usr/lib/containers/storage/` implemented
