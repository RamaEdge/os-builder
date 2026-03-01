#!/bin/bash
# Embed MicroShift container images for offline/airgap operation
# Follows upstream microshift-io/microshift src/image/embed_images.sh pattern
#
# Build-time: pulls MicroShift system images into /usr/lib/containers/storage as dir: blobs
# Runtime:    microshift-copy-images (generated) copies them into CRI-O's live storage
#
# Extended in Plan 02-02 to: generate microshift-copy-images script, systemd drop-in,
# and process edgeworks application images from /usr/share/edgeworks/image-list.txt
set -euo pipefail

# --- Constants ---
IMAGE_STORAGE_DIR="/usr/lib/containers/storage"
IMAGE_LIST_FILE="${IMAGE_STORAGE_DIR}/image-list.txt"
RELEASE_DIR="/usr/share/microshift/release"
COPY_SCRIPT="/usr/bin/microshift-copy-images"
DROPIN_DIR="/usr/lib/systemd/system/microshift.service.d"

# --- Logging helper ---
log() {
    echo "[embed-microshift-images] $*"
}

# --- Root check ---
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must run as root" >&2
    exit 1
fi

# --- Find release manifests ---
RELEASE_FILES=$(find "${RELEASE_DIR}" -name '*.json' -type f 2>/dev/null || true)

if [ -z "${RELEASE_FILES}" ]; then
    log "No release manifests found in ${RELEASE_DIR}, skipping"
    exit 0
fi

# --- Prepare storage directory and image list ---
mkdir -p "${IMAGE_STORAGE_DIR}"
: > "${IMAGE_LIST_FILE}"

TOTAL=0
PULLED=0
SKIPPED=0

# --- Process each MicroShift release manifest ---
for manifest in ${RELEASE_FILES}; do
    log "Processing manifest: ${manifest}"

    while IFS= read -r img; do
        # Skip empty lines
        [ -z "${img}" ] && continue

        # Count total BEFORE skip check
        TOTAL=$((TOTAL + 1))

        # Skip registry.redhat.io images (not publicly accessible at build time)
        if echo "${img}" | grep -q "registry.redhat.io"; then
            log "SKIP (registry.redhat.io): ${img}"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        # Use sha256 of image ref as storage directory name (deterministic, collision-free)
        SHA=$(echo -n "${img}" | sha256sum | awk '{print $1}')
        DEST="${IMAGE_STORAGE_DIR}/${SHA}"

        # Idempotent: skip re-pull if already cached
        if [ -d "${DEST}" ] && [ -f "${DEST}/manifest.json" ]; then
            log "CACHED: ${img}"
        else
            log "PULL: ${img}"
            mkdir -p "${DEST}"
            if skopeo copy --all --preserve-digests \
                "docker://${img}" "dir:${DEST}"; then
                PULLED=$((PULLED + 1))
            else
                log "WARN: Failed to pull ${img}, continuing..."
                rm -rf "${DEST}"
                continue
            fi
        fi

        # Record in image list: img,sha
        echo "${img},${SHA}" >> "${IMAGE_LIST_FILE}"

    done < <(jq -r '.images[]? // empty' "${manifest}" 2>/dev/null)
done

log "Embedding complete: ${PULLED} pulled, ${SKIPPED} skipped, ${TOTAL} total"
