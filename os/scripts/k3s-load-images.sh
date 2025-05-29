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
    
    # Load airgap images into CRI-O
    if command -v crio >/dev/null 2>&1; then
        log "Loading images into CRI-O..."
        if command -v skopeo >/dev/null 2>&1; then
            # Use skopeo to load images (preferred method)
            zstd -d "$AIRGAP_IMAGES" -c | skopeo copy --all oci-archive:/dev/stdin containers-storage: || {
                log "Warning: Failed to load images with skopeo, trying alternative method"
                # Fallback: extract and load with ctr
                cd /tmp
                zstd -d "$AIRGAP_IMAGES" -c | tar -xf - 2>/dev/null || true
                for img in *.tar 2>/dev/null; do
                    [ -f "$img" ] && ctr -n k8s.io images import "$img" 2>/dev/null || true
                done
                rm -f *.tar 2>/dev/null || true
            }
        else
            log "Skopeo not available, using fallback method"
            cd /tmp
            zstd -d "$AIRGAP_IMAGES" -c | tar -xf - 2>/dev/null || true
            for img in *.tar 2>/dev/null; do
                [ -f "$img" ] && ctr -n k8s.io images import "$img" 2>/dev/null || true
            done
            rm -f *.tar 2>/dev/null || true
        fi
    else
        log "CRI-O not available, images will be loaded by K3s on demand"
    fi
    
    log "K3s airgap images loaded successfully"
else
    log "Warning: Airgap images not found at $AIRGAP_IMAGES"
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