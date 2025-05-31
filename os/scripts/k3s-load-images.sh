#!/bin/bash
# Load embedded K3s container images for offline operation
set -euo pipefail

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | systemd-cat -t k3s-load-images
}

log "Starting K3s airgap image loading..."

# Check if airgap images exist
AIRGAP_IMAGES="/var/lib/rancher/k3s/agent/images/k3s-airgap-images-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').tar.zst"
IMAGE_LIST="/var/lib/rancher/k3s/agent/images/images.txt"

if [ -f "$AIRGAP_IMAGES" ]; then
    log "Loading K3s airgap images from: $AIRGAP_IMAGES"
    
    # Load airgap images into containerd (K3s default runtime)
    if command -v ctr >/dev/null 2>&1; then
        log "Loading images into containerd..."
        if command -v skopeo >/dev/null 2>&1 && command -v zstd >/dev/null 2>&1; then
            # Use skopeo to load images (preferred method)
            log "Using skopeo to load compressed airgap images..."
            zstd -d "$AIRGAP_IMAGES" -c | skopeo copy --all oci-archive:/dev/stdin containers-storage: || {
                log "Warning: Failed to load images with skopeo, trying direct containerd import"
                # Fallback: extract and load with ctr directly
                cd /tmp
                zstd -d "$AIRGAP_IMAGES" -c | tar -xf - 2>/dev/null || true
                for img in *.tar 2>/dev/null; do
                    [ -f "$img" ] && ctr -n k8s.io images import "$img" 2>/dev/null || true
                done
                rm -f *.tar 2>/dev/null || true
            }
        else
            log "Skopeo or zstd not available, using direct containerd import"
            # Direct containerd import (K3s will handle decompression)
            cd /tmp
            if command -v zstd >/dev/null 2>&1; then
                zstd -d "$AIRGAP_IMAGES" -c | tar -xf - 2>/dev/null || true
            else
                # Try to extract directly (may fail for .zst files)
                tar -xf "$AIRGAP_IMAGES" 2>/dev/null || true
            fi
            for img in *.tar 2>/dev/null; do
                [ -f "$img" ] && ctr -n k8s.io images import "$img" 2>/dev/null || true
            done
            rm -f *.tar 2>/dev/null || true
        fi
    else
        log "containerd ctr not available, K3s will load images automatically on startup"
    fi
    
    log "K3s airgap images loaded successfully"
else
    log "Warning: Airgap images not found at $AIRGAP_IMAGES"
    # Also check for generic name without architecture suffix
    GENERIC_AIRGAP="/var/lib/rancher/k3s/agent/images/k3s-airgap-images.tar.zst"
    if [ -f "$GENERIC_AIRGAP" ]; then
        log "Found generic airgap images at $GENERIC_AIRGAP, loading those instead..."
        AIRGAP_IMAGES="$GENERIC_AIRGAP"
        # Repeat the loading process with the generic file
        if command -v ctr >/dev/null 2>&1 && command -v zstd >/dev/null 2>&1; then
            cd /tmp
            zstd -d "$AIRGAP_IMAGES" -c | tar -xf - 2>/dev/null || true
            for img in *.tar 2>/dev/null; do
                [ -f "$img" ] && ctr -n k8s.io images import "$img" 2>/dev/null || true
            done
            rm -f *.tar 2>/dev/null || true
            log "Generic airgap images loaded successfully"
        fi
    fi
fi

# Verify core images are available
if [ -f "$IMAGE_LIST" ]; then
    log "Verifying core K3s images are available..."
    while IFS= read -r image || [ -n "$image" ]; do
        # Skip comments and empty lines
        [[ "$image" =~ ^#.*$ ]] || [[ -z "$image" ]] && continue
        
        if ctr -n k8s.io images list -q | grep -q "$(echo "$image" | cut -d: -f1)"; then
            log "✓ Image available: $image"
        else
            log "⚠ Image missing: $image (will be pulled on demand)"
        fi
    done < "$IMAGE_LIST"
else
    log "Warning: Image list not found at $IMAGE_LIST"
fi

log "K3s image loading completed"
exit 0 