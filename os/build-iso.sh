#!/bin/bash

set -euo pipefail

# =============================================================================
# Build ISO Script
# =============================================================================

# Variables passed from Makefile or defaults
IMAGE_NAME="${IMAGE_NAME:-harbor.local/ramaedge/os-k3s}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
ISO_DIR="${ISO_DIR:-iso-output}"
PWD="${PWD:-$(pwd)}"

echo "📀 Building ISO with embedded kickstart..."

# Check if running as root for bootc-image-builder
if [ "$(id -u)" != "0" ]; then
    echo "❌ bootc-image-builder requires root privileges. Please run with sudo."
    exit 1
fi

# Use rootful container runtime to find images
TARGET_IMAGE=$(podman images "${IMAGE_NAME}:${IMAGE_TAG}" --format "{{.Repository}}:{{.Tag}}" | head -1)
if [ -z "$TARGET_IMAGE" ]; then
    TARGET_IMAGE=$(podman images "${IMAGE_NAME}" --format "{{.Repository}}:{{.Tag}}" | head -1)
fi

if [ -z "$TARGET_IMAGE" ]; then
    echo "❌ No image found! Available images:"
    podman images "${IMAGE_NAME}"
    exit 1
fi

mkdir -p "${ISO_DIR}"
echo "🚀 Building ISO from: $TARGET_IMAGE"

# Handle kickstart configuration
if [ -f "os/kickstart.ks" ]; then
    echo "📋 Found kickstart.ks, embedding into configuration..."
    TEMP_CONFIG="${PWD}/iso-config-temp.toml"
    cp "os/config-examples/user-config.toml" "$TEMP_CONFIG"
    
    # Escape backslashes for TOML multi-line basic string
    echo "" >> "$TEMP_CONFIG"
    echo "[customizations.installer.kickstart]" >> "$TEMP_CONFIG"
    printf 'contents = """\n' >> "$TEMP_CONFIG"
    # Escape backslashes by replacing \ with \\
    sed 's/\\/\\\\/g' "os/kickstart.ks" >> "$TEMP_CONFIG"
    printf '\n"""\n' >> "$TEMP_CONFIG"
    
    CONFIG_MOUNT="-v $TEMP_CONFIG:/config.toml:ro"
    echo "✅ Kickstart embedded into configuration"
else
    CONFIG_MOUNT="-v ${PWD}/os/config-examples/user-config.toml:/config.toml:ro"
    echo "⚠️  No kickstart.ks found, using basic config"
fi

# Pull the bootc image builder
podman pull quay.io/centos-bootc/bootc-image-builder:latest

# Build the ISO
podman run --rm --privileged --security-opt label=type:unconfined_t \
    -v "${PWD}/${ISO_DIR}:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    $CONFIG_MOUNT \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type iso --config /config.toml "$TARGET_IMAGE"

# Clean up temporary config file
if [ -f "iso-config-temp.toml" ]; then
    rm "iso-config-temp.toml"
fi

echo "✅ ISO build completed successfully!" 