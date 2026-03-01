# MicroShift Migration: K3s → Upstream MicroShift-IO

## Context

The upstream MicroShift project has moved to [microshift-io/microshift](https://github.com/microshift-io/microshift). This is the community (OKD-based) fork that replaces Red Hat payload images with OKD images, removing the need for Red Hat subscriptions. It provides RPMs, DEBs, COPR nightly repos, and a `make image` target that produces bootc container images natively.

---

## Key Findings from Upstream

### How upstream builds bootc images

The upstream repo has `packaging/bootc.Containerfile` which:
1. Uses a multi-stage build: stage 1 is `microshift-okd-rpm:latest` (RPMs built by `make rpm`)
2. Stage 2 is `quay.io/centos-bootc/centos-bootc:stream9`
3. Installs MicroShift via `dnf` from a local repo created from the built RPMs
4. Packages installed: `microshift`, `microshift-kindnet`, `microshift-topolvm` (optional: `microshift-olm`)
5. Optionally embeds container images via `embed_images.sh` (controlled by `EMBED_CONTAINER_IMAGES=1`)
6. Enables `microshift-make-rshared.service` systemd unit
7. The upstream `make image` target orchestrates all of this

### How upstream handles airgap/offline images

Upstream's `src/image/embed_images.sh` implements a two-phase approach:

**Phase 1 — Build-time (inside Containerfile):**
1. Reads image refs from JSON manifests in `/usr/share/microshift/release/`
2. Filters out `registry.redhat.io` images (not available upstream; OKD equivalents used instead)
3. For each image, computes a SHA256 of the reference string as a directory name
4. Runs `skopeo copy --all --preserve-digests docker://${img} dir:/usr/lib/containers/storage/${sha}`
5. Writes an `image-list.txt` CSV mapping `image_ref,sha_dir` for runtime use

**Phase 2 — Runtime (systemd ExecStartPre):**
1. A generated script `/usr/bin/microshift-copy-images` is created during build
2. A systemd drop-in `/usr/lib/systemd/system/microshift.service.d/microshift-copy-images.conf` adds it as `ExecStartPre`
3. On each boot, it reads `image-list.txt` and runs `skopeo copy --preserve-digests dir:/usr/lib/containers/storage/${sha} containers-storage:${img}`
4. This copies from the read-only embedded store into CRI-O's live container storage

This two-phase design is important: the embedded images in `/usr/lib/containers/storage` survive bootc OS updates (they're in the immutable image layer), while CRI-O's runtime storage under `/var` may be wiped. The `ExecStartPre` ensures images are always available before MicroShift starts.

**Key difference from our current approach:** We use `podman pull --root /usr/share/containers/storage` which puts images directly into a secondary store configured via `storage.conf.d/offline.conf`. Upstream instead uses `dir:` format (raw OCI blobs per directory) and copies at runtime. The upstream approach is more robust across bootc updates.

**Required build-time prerequisite:** The Containerfile must configure `/etc/subuid` and `/etc/subgid` before running embed_images.sh (rootless containers need UID mapping even during build):
```dockerfile
RUN echo "root:1:65536" >> /etc/subuid && echo "root:1:65536" >> /etc/subgid
```

### RPM package architecture (from upstream spec files)

Upstream has separate spec files for optional components. From [docs/run.md](https://github.com/microshift-io/microshift/blob/main/docs/run.md), **it is mandatory to install either `microshift-kindnet` or `microshift-networking`** to enable networking.

| Package | Description | Comments |
|---------|-------------|----------|
| `microshift` | Core binary, systemd service, CRI-O dep | Required |
| `microshift-release-info` | Release image manifests (`/usr/share/microshift/release/`) | Required for offline embedding |
| `microshift-kindnet` | Kindnet CNI + kube-proxy | Overrides OVN-K; **required on Fedora** |
| `microshift-kindnet-release-info` | Image refs for kindnet+kube-proxy (per-arch JSON) | Required for offline embedding |
| `microshift-networking` | OVN-K CNI | Alternative to kindnet; **NOT supported on Fedora** |
| `microshift-topolvm` | TopoLVM CSI + cert-manager | Install to enable LVM-backed storage |
| `microshift-topolvm-release-info` | Image refs for topolvm (per-arch JSON) | Required for offline embedding |
| `microshift-olm` | Operator Lifecycle Manager | Optional, see [OKD Operator Hub](https://okd.io/docs/operators/) |

**Kindnet vs Networking — which to use:**
- `microshift-networking` provides OVN-Kubernetes, the full-featured CNI. It requires Open vSwitch (OVS) and `NetworkManager-ovs`. **Not supported on Fedora.**
- `microshift-kindnet` provides Kindnet (lightweight L2 CNI) + kube-proxy. It works by installing a config dropin at `/etc/microshift/config.d/00-disableDefaultCNI.yaml` (`network.cniPlugin: "none"`) to disable OVN-K, then deploys kindnet+kube-proxy via `manifests.d/000-microshift-kindnet/`. It also ships a kindnet-specific `microshift.service` variant and CRI-O config.
- **For our Fedora bootc image: use `microshift-kindnet`.**
- The two packages are mutually exclusive — uninstall kindnet to enable OVN-K, or vice versa.

**How topolvm works:** `microshift-topolvm` installs `/etc/microshift/config.d/01-disable-storage-csi.yaml` to disable the built-in storage CSI, then deploys TopoLVM + cert-manager via `manifests.d/001-microshift-topolvm/`. It also adds a greenboot health check at `/etc/greenboot/check/required.d/50_microshift_topolvm_check.sh`. TopoLVM provides dynamic LVM-backed PersistentVolumes — needed since edgeworks workloads use PVCs (`edgeworks/overlays/edge/pvc-patch.yaml`).

**The `-release-info` packages** are critical for offline embedding — they provide the per-arch JSON files in `/usr/share/microshift/release/` that `embed-microshift-images.sh` reads to know which container images to pull. Without `microshift-kindnet-release-info` and `microshift-topolvm-release-info`, those component images won't be embedded.

### Platform support

- CentOS 9/10 Stream: Full support (OVN-K, Kindnet, TopoLVM, Greenboot)
- **Fedora: RPM support, but NO OVN-K** → must install `microshift-kindnet`
- Architectures: x86_64 and aarch64

### Installation methods

1. **Quick RPM install**: `curl -s https://microshift-io.github.io/microshift/quickrpm.sh | sudo bash`
2. **COPR nightly**: Same script with `RPM_SOURCE=copr-nightly`
3. **Build from source**: `make srpm && make rpm && make image`

---

## What to Remove from os-builder

### Files to delete

| File | Reason |
|------|--------|
| `os/Containerfile.k3s` | Entire K3s variant |
| `os/configs/k3s/config.yaml` | K3s-specific config |
| `os/configs/k3s/registries.yaml` | K3s registry mirrors |
| `os/scripts/k3s-load-images.sh` | K3s airgap loading (upstream handles this) |
| `os/scripts/setup-k3s-kubeconfig.sh` | K3s kubeconfig setup |
| `os/systemd/k3s/k3s.service` | K3s systemd unit |
| `os/systemd/k3s/k3s-load-images.service` | K3s image loading service |
| `os/systemd/k3s/k3s-kubeconfig-setup.service` | K3s kubeconfig service |
| `os/systemd/microshift.service` | **Replace with upstream's service from RPM** |
| `.github/workflows/build-and-security-scan.yaml` | K3s CI workflow |

### Code to remove from remaining files

- **`edge-setup.sh` lines 93-168**: The entire K3s config block that generates `setup-kubeconfig.sh` and `deploy-observability.sh` inline. These are duplicate of existing files and K3s-specific.
- **`edge-setup.sh` lines 47-51**: K3s-specific firewall port comments and kube-scheduler port 10251.
- **`Makefile`**: Remove `build` target (K3s), simplify to single MicroShift build target.
- **`build.sh`**: Remove K3s detection branch and K3S_VERSION references.
- **`versions.txt`**: Remove `K3S_VERSION` and `CNI_VERSION` lines.

---

## Refactored Containerfile

Replace `Containerfile.fedora.optimized` with the following approach aligned to upstream patterns:

```dockerfile
# Fedora bootc with upstream MicroShift for edge computing
ARG FEDORA_VERSION=42

FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION}

ARG OTEL_VERSION
ARG VCS_REF
ARG VERSION
ARG EMBED_CONTAINER_IMAGES=1

LABEL org.opencontainers.image.title="Edge OS - Fedora bootc with MicroShift" \
      org.opencontainers.image.description="Fedora bootc with upstream MicroShift for edge computing" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="RamaEdge" \
      containers.bootc=1 \
      ostree.bootable=1

# --- System packages ---
RUN dnf install -y \
        openssh-server sudo podman cri-o kubernetes-client skopeo \
        NetworkManager firewalld policycoreutils-python-utils \
        systemd-resolved chrony curl jq && \
    find /usr -type f \( \( -perm -4000 -o -perm -2000 \) \
        -a \( -name chfn -o -name chsh -o -name newgrp \) \) \
        -exec chmod u-s {} \; && \
    dnf clean packages && rm -rf /tmp/* /var/tmp/*

# --- MicroShift via COPR (Fedora-native, no custom builder image) ---
# The RPM provides: microshift binary, microshift.service,
#   microshift-make-rshared.service, /usr/share/microshift/release/ manifests,
#   firewall rules, kubeconfig symlinks, and CRI-O dependency
#
# Package breakdown (from upstream spec files):
#   microshift              — core binary, systemd service, CRI-O dependency
#   microshift-release-info — release image manifests in /usr/share/microshift/release/
#   microshift-kindnet      — kindnet CNI + kube-proxy manifests (for Fedora, replaces OVN-K)
#     └ microshift-kindnet-release-info — image refs for kindnet+kube-proxy offline embedding
#   microshift-topolvm      — TopoLVM CSI + cert-manager manifests (LVM-backed PVCs)
#     └ microshift-topolvm-release-info — image refs for topolvm offline embedding
#   microshift-olm          — OLM operator lifecycle (optional, not needed for edge)
#
# NOTE on networking:
#   You MUST install either microshift-kindnet OR microshift-networking (OVN-K).
#   microshift-networking provides OVN-K but is NOT supported on Fedora.
#   microshift-kindnet REPLACES OVN-K by:
#     1. Installing a config dropin /etc/microshift/config.d/00-disableDefaultCNI.yaml
#        which sets network.cniPlugin: "none" (disables built-in OVN-K)
#     2. Deploying kindnet + kube-proxy via /usr/lib/microshift/manifests.d/000-microshift-kindnet/
#   On Fedora, microshift-kindnet is the only option.
#
# NOTE on topolvm:
#   microshift-topolvm installs TopoLVM CSI manifests into
#   /usr/lib/microshift/manifests.d/001-microshift-topolvm/ and a config dropin
#   /etc/microshift/config.d/01-disable-storage-csi.yaml (disables built-in CSI).
#   It also installs a greenboot health check at
#   /etc/greenboot/check/required.d/50_microshift_topolvm_check.sh
#   TopoLVM provides dynamic LVM-backed PersistentVolumes — needed if your
#   edgeworks workloads use PVCs (they do: edgeworks/overlays/edge has pvc-patch.yaml).

RUN dnf copr enable -y @microshift-io/microshift-nightly && \
    dnf install -y \
        microshift \
        microshift-release-info \
        microshift-kindnet \
        microshift-kindnet-release-info \
        microshift-topolvm \
        microshift-topolvm-release-info && \
    dnf clean all

# =============================================================================
# Offline container image embedding (upstream-aligned two-phase approach)
# =============================================================================
# Phase 1: Build-time — pull images into /usr/lib/containers/storage as dir: blobs
# Phase 2: Runtime — microshift-copy-images ExecStartPre copies to CRI-O storage
#
# Why two phases: /usr/lib is in the immutable bootc image layer and survives OS
# updates. CRI-O's /var storage may be wiped on updates. The ExecStartPre ensures
# images are always repopulated before MicroShift starts.
# =============================================================================

# UID/GID mapping required for skopeo during container build
RUN echo "root:1:65536" >> /etc/subuid && \
    echo "root:1:65536" >> /etc/subgid

# Copy the embed script (see scripts/embed-microshift-images.sh below)
COPY scripts/embed-microshift-images.sh /tmp/embed-microshift-images.sh

RUN chmod +x /tmp/embed-microshift-images.sh && \
    if [ "${EMBED_CONTAINER_IMAGES}" = "1" ]; then \
        /tmp/embed-microshift-images.sh; \
    fi && \
    rm -f /tmp/embed-microshift-images.sh

# --- OpenTelemetry Collector ---
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    curl -fsSL --retry 3 --retry-delay 5 \
        "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_linux_${ARCH}.tar.gz" \
        -o /tmp/otelcol.tar.gz && \
    tar -xzf /tmp/otelcol.tar.gz -C /tmp && \
    mv /tmp/otelcol /usr/local/bin/otelcol && \
    chmod +x /usr/local/bin/otelcol && \
    rm -f /tmp/otelcol.tar.gz && \
    useradd -r -s /sbin/nologin -d /var/lib/otelcol -c "OpenTelemetry Collector" otelcol && \
    mkdir -p /var/log/otelcol /var/lib/otelcol /etc/otelcol && \
    chown -R otelcol:otelcol /var/log/otelcol /var/lib/otelcol /etc/otelcol

# --- Directory structure ---
RUN mkdir -p /etc/microshift/manifests /var/lib/microshift \
             /var/log/microshift /var/hpvolumes /var/empty

# --- Configuration files ---
COPY configs/containers/ /etc/containers/
COPY configs/otelcol/ /etc/otelcol/
COPY configs/microshift/ /etc/microshift/
COPY manifests/ /etc/microshift/manifests/
COPY systemd/edge-setup.service /usr/lib/systemd/system/
COPY systemd/otelcol.service /usr/lib/systemd/system/
COPY systemd/observability-deploy.service /usr/lib/systemd/system/
COPY systemd/microshift-kubeconfig-setup.service /usr/lib/systemd/system/
COPY systemd/bootc-fetch-apply-updates.timer.d/ /usr/lib/systemd/system/bootc-fetch-apply-updates.timer.d/
COPY scripts/edge-setup.sh /usr/local/bin/
COPY scripts/deploy-observability.sh /usr/local/bin/
COPY scripts/health-check.sh /usr/local/bin/

# --- Enable services and finalize ---
# NOTE: Do NOT enable microshift.service here — the RPM's postinstall already does it.
# Do NOT ship a custom microshift.service — the RPM provides the correct one.
# The RPM also enables microshift-make-rshared.service automatically.
RUN chmod +x /usr/local/bin/*.sh 2>/dev/null || true && \
    systemctl enable sshd chronyd systemd-resolved podman.socket crio \
                    otelcol edge-setup.service observability-deploy.service \
                    microshift-kubeconfig-setup.service \
                    bootc-fetch-apply-updates.timer 2>/dev/null || true && \
    firewall-offline-cmd --add-service=ssh \
        --add-port=6443/tcp --add-port=8080/tcp --add-port=10250/tcp \
        --add-port=4317/tcp --add-port=4318/tcp --add-port=9090/tcp \
        --add-port=8888/tcp --add-port=80/tcp --add-port=443/tcp && \
    restorecon -R /etc /usr/local/bin 2>/dev/null || true && \
    useradd -r -s /sbin/nologin -d /var/empty -c "Container user" containeruser && \
    chown containeruser:containeruser /var/empty

# Declare /var as volume for kubelet idmap support (matches upstream)
VOLUME /var

LABEL containers.bootc=1
LABEL ostree.bootable=1
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
RUN bootc container lint
USER containeruser
```

---

## New Script: `scripts/embed-microshift-images.sh`

This replaces the inline `podman pull` loop. It follows the upstream `embed_images.sh` pattern:

```bash
#!/bin/bash
# Embed MicroShift container images for offline/airgap operation
# Follows upstream microshift-io/microshift src/image/embed_images.sh pattern
#
# Build-time: pulls images into /usr/lib/containers/storage as dir: blobs
# Runtime:    microshift-copy-images copies them into CRI-O's live storage
set -euo pipefail

IMAGE_STORAGE_DIR="/usr/lib/containers/storage"
IMAGE_LIST_FILE="${IMAGE_STORAGE_DIR}/image-list.txt"
RELEASE_DIR="/usr/share/microshift/release"
COPY_SCRIPT="/usr/bin/microshift-copy-images"
DROPIN_DIR="/usr/lib/systemd/system/microshift.service.d"

log() { echo "[embed-images] $*"; }

# --- Validate ---
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must run as root" >&2
    exit 1
fi

# Find release image manifests
RELEASE_FILES=$(find "${RELEASE_DIR}" -name '*.json' -type f 2>/dev/null || true)
if [ -z "${RELEASE_FILES}" ]; then
    log "No release manifests found in ${RELEASE_DIR}, skipping image embedding"
    exit 0
fi

mkdir -p "${IMAGE_STORAGE_DIR}"
: > "${IMAGE_LIST_FILE}"

# --- Phase 1: Pull images at build time ---
TOTAL=0
PULLED=0
SKIPPED=0

for manifest in ${RELEASE_FILES}; do
    log "Processing manifest: ${manifest}"

    while IFS= read -r img; do
        [ -z "${img}" ] && continue
        TOTAL=$((TOTAL + 1))

        # Skip Red Hat registry images (not available in upstream/OKD)
        if echo "${img}" | grep -q "registry.redhat.io"; then
            log "SKIP (Red Hat registry): ${img}"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        # SHA256 hash of image ref as directory name (deterministic, filesystem-safe)
        SHA=$(echo -n "${img}" | sha256sum | awk '{print $1}')
        DEST="${IMAGE_STORAGE_DIR}/${SHA}"

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

        # Record mapping: image_ref,sha_dir
        echo "${img},${SHA}" >> "${IMAGE_LIST_FILE}"

    done < <(jq -r '.images[]? // empty' "${manifest}" 2>/dev/null)
done

log "Embedding complete: ${PULLED} pulled, ${SKIPPED} skipped, ${TOTAL} total"

# --- Phase 2: Generate runtime copy script ---
cat > "${COPY_SCRIPT}" << 'COPY_EOF'
#!/bin/bash
# Auto-generated: copies pre-loaded images from immutable store to CRI-O storage
# Runs as ExecStartPre before microshift.service on every boot
set -euo pipefail

IMAGE_STORAGE_DIR="/usr/lib/containers/storage"
IMAGE_LIST_FILE="${IMAGE_STORAGE_DIR}/image-list.txt"

if [ ! -f "${IMAGE_LIST_FILE}" ]; then
    echo "[microshift-copy-images] No image list found, skipping"
    exit 0
fi

echo "[microshift-copy-images] Copying embedded images to container storage..."
COPIED=0

while IFS=',' read -r img sha; do
    [ -z "${img}" ] || [ -z "${sha}" ] && continue
    SRC="${IMAGE_STORAGE_DIR}/${sha}"

    if [ ! -d "${SRC}" ]; then
        echo "[microshift-copy-images] WARN: Missing dir for ${img}"
        continue
    fi

    # Copy from dir: format into CRI-O's containers-storage
    if skopeo copy --preserve-digests \
        "dir:${SRC}" "containers-storage:${img}" 2>/dev/null; then
        COPIED=$((COPIED + 1))
    else
        echo "[microshift-copy-images] WARN: Failed to copy ${img}"
    fi
done < "${IMAGE_LIST_FILE}"

echo "[microshift-copy-images] Done: ${COPIED} images copied"
COPY_EOF

chmod +x "${COPY_SCRIPT}"

# --- Phase 3: Create systemd drop-in so it runs before MicroShift ---
mkdir -p "${DROPIN_DIR}"
cat > "${DROPIN_DIR}/microshift-copy-images.conf" << 'DROPIN_EOF'
[Service]
ExecStartPre=/usr/bin/microshift-copy-images
DROPIN_EOF

log "Runtime copy script and systemd drop-in installed"
```

### How it works end-to-end

```
┌─────────────────────────────────────────────────────┐
│  BUILD TIME (Containerfile RUN)                     │
│                                                     │
│  release-images.json                                │
│       │                                             │
│       ▼                                             │
│  for each image:                                    │
│    sha = sha256(image_ref)                          │
│    skopeo copy docker://img dir:/usr/lib/.../sha    │
│    append "img,sha" to image-list.txt               │
│                                                     │
│  Generate /usr/bin/microshift-copy-images            │
│  Generate systemd drop-in (ExecStartPre)            │
└─────────────────────────────────────────────────────┘
                        │
                        │  bootc image layer
                        │  (immutable, survives OS updates)
                        ▼
┌─────────────────────────────────────────────────────┐
│  RUNTIME (every boot, before microshift.service)    │
│                                                     │
│  microshift-copy-images (ExecStartPre):             │
│    read image-list.txt                              │
│    for each img,sha:                                │
│      skopeo copy dir:/usr/lib/.../sha               │
│                  containers-storage:img              │
│                                                     │
│  Images now in CRI-O's /var/lib/containers/storage  │
│  MicroShift starts with all images available        │
└─────────────────────────────────────────────────────┘
```

### Why this matters for bootc

In a bootc system, `/usr/lib` is part of the immutable OS image — it's read-only at runtime and included in every OS update. `/var` is mutable and persists across boots but can be affected by OS updates or resets. By storing the blobs in `/usr/lib/containers/storage` and copying to `/var` on each boot, we guarantee images survive any bootc update scenario.

---

### What changed vs. current `Containerfile.fedora.optimized`

| Aspect | Before | After |
|--------|--------|-------|
| MicroShift source | Custom builder image multi-stage | `dnf copr` install |
| CNI | Not specified | `microshift-kindnet` — disables OVN-K, deploys kindnet+kube-proxy via manifests.d |
| Storage CSI | Not specified | `microshift-topolvm` — LVM-backed PVCs via manifests.d, with greenboot check |
| CRI-O | Installed via dnf separately | Pulled as dependency of microshift RPM |
| Offline images | `podman pull --root` to custom path, `storage.conf.d/offline.conf` | Two-phase: `skopeo copy dir:` at build, `ExecStartPre` copy at runtime |
| Image storage | `/usr/share/containers/storage` (mutable) | `/usr/lib/containers/storage` (immutable image layer, survives bootc updates) |
| Runtime image load | One-shot service with podman | systemd drop-in `ExecStartPre` on microshift.service (upstream pattern) |
| systemd units | Custom `microshift.service` | **Use the one from the RPM** (includes make-rshared, firewall, kubeconfig) |
| Arch detection | 10-line block repeated 4x | Done once or inline |
| /var volume | Not declared | `VOLUME /var` for kubelet idmap support (upstream pattern) |

---

## Refactored `edge-setup.sh`

Strip it to OS-level concerns only. Remove all K3s references and inline script generation:

```bash
#!/bin/bash
# Edge deployment first-boot setup (variant-agnostic)
set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | systemd-cat -t edge-setup
}

log "Starting edge setup..."

# Hostname
if [ "$(hostname)" = "localhost.localdomain" ] || [ "$(hostname)" = "fedora" ]; then
    hostnamectl set-hostname "edge-$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)"
    log "Set hostname to: $(hostname)"
fi

# SSH hardening
mkdir -p /home/fedora/.ssh && chown fedora:fedora /home/fedora/.ssh && chmod 700 /home/fedora/.ssh
if [ ! -f /etc/ssh/sshd_config.d/99-edge-security.conf ]; then
    cat > /etc/ssh/sshd_config.d/99-edge-security.conf << 'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
EOF
    log "SSH hardened"
fi

# Journald limits for edge
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/edge.conf << 'EOF'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
MaxRetentionSec=1week
EOF
systemctl restart systemd-journald

# Log rotation
cat > /etc/logrotate.d/edge-logs << 'EOF'
/var/log/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
}
EOF

# Container auto-update and NTP
systemctl enable --now podman-auto-update.timer
timedatectl set-ntp true

log "Edge setup completed"
```

Note: firewall rules are already handled in the Containerfile via `firewall-offline-cmd`. Don't duplicate them here at runtime.

---

## Refactored `versions.txt`

```
OTEL_VERSION=0.127.0
FEDORA_VERSION=42
# MicroShift installed from COPR — version tracked by dnf, not pinned here
# CNI bundled with microshift-kindnet RPM — no separate version needed
```

---

## Simplified Makefile targets

```makefile
# Single build target
IMAGE_NAME ?= harbor.local/ramaedge/os-microshift
CONTAINERFILE ?= os/Containerfile.microshift

build:
    @cd os && \
    CONTAINER_RUNTIME="$(CONTAINER_RUNTIME)" \
    IMAGE_NAME="$(IMAGE_NAME)" \
    IMAGE_TAG="$(IMAGE_TAG)" \
    CONTAINERFILE="Containerfile.microshift" \
    OTEL_VERSION="$(OTEL_VERSION)" \
    FEDORA_VERSION="$(FEDORA_VERSION)" \
    GIT_SHA="$(GIT_SHA)" \
    ./build.sh
```

Remove: `build-microshift` (now the only variant), `K3S_VERSION`, `CNI_VERSION`, `MICROSHIFT_VERSION` from Makefile.

---

## Auto-deploying edgeworks-deploy Manifests on Boot

MicroShift has built-in kustomize manifest auto-deployment. On every start, it scans configured `kustomizePaths` for `kustomization.yaml` files and runs the equivalent of `kubectl apply -k` automatically. No custom systemd services or deploy scripts needed.

### Default kustomizePaths (from MicroShift config)

```yaml
manifests:
  kustomizePaths:
    - /usr/lib/microshift/manifests
    - /usr/lib/microshift/manifests.d/*
    - /etc/microshift/manifests
    - /etc/microshift/manifests.d/*
```

The two path prefixes serve different purposes:

| Path | Mutability | Use case |
|------|-----------|----------|
| `/usr/lib/microshift/manifests*` | Immutable (baked into bootc image) | Manifests shipped with the OS image |
| `/etc/microshift/manifests*` | Mutable (persists on device) | Site-specific overrides, post-deploy changes |

The `manifests.d/*` glob allows multiple independent kustomization directories — each subdirectory is applied independently.

### Mapping edgeworks-deploy to MicroShift manifest directories

Your edgeworks-deploy repo has 4 core components (with `edge` overlays) plus edge-infra:

```
edgeworks-deploy/
├── edgeworks/overlays/edge/      → core platform (CRDs, supervisor, governor, etc.)
├── management-api/overlays/edge/ → API + Dex auth
├── edgeworks-ui/overlays/edge/   → console UI
├── opcua-adapter/overlays/edge/  → OPC-UA adapter
└── edge-infra/                   → mDNS + TLS (edge-only infra)
```

Use `manifests.d/*` to deploy each as an independent unit. In the Containerfile:

```dockerfile
# --- Edgeworks manifests for auto-deploy ---
# Each component gets its own manifests.d subdirectory so MicroShift
# applies them independently (failure in one doesn't block others)
COPY edgeworks-deploy/edgeworks/overlays/edge/     /usr/lib/microshift/manifests.d/10-edgeworks/
COPY edgeworks-deploy/edgeworks/base/              /usr/lib/microshift/manifests.d/10-edgeworks/base/
COPY edgeworks-deploy/edge-infra/                  /usr/lib/microshift/manifests.d/11-edge-infra/
COPY edgeworks-deploy/management-api/overlays/edge/ /usr/lib/microshift/manifests.d/20-management-api/
COPY edgeworks-deploy/management-api/base/          /usr/lib/microshift/manifests.d/20-management-api/base/
COPY edgeworks-deploy/edgeworks-ui/overlays/edge/  /usr/lib/microshift/manifests.d/30-edgeworks-ui/
COPY edgeworks-deploy/edgeworks-ui/base/           /usr/lib/microshift/manifests.d/30-edgeworks-ui/base/
COPY edgeworks-deploy/opcua-adapter/overlays/edge/ /usr/lib/microshift/manifests.d/40-opcua-adapter/
COPY edgeworks-deploy/opcua-adapter/base/          /usr/lib/microshift/manifests.d/40-opcua-adapter/base/
```

**Why numbered prefixes (10-, 20-, 30-):** MicroShift applies manifests.d directories in alphabetical order. CRDs and namespaces (in `edgeworks/base`) must exist before services that reference them. The numbering ensures correct ordering: infrastructure first, then platform, then applications.

**Why `/usr/lib/` not `/etc/`:** These manifests are part of the OS image definition — they should be immutable and versioned with the bootc image. `/etc/` is for site-specific runtime overrides (like changing a configmap value per-device).

### Important: kustomization.yaml path references

The edge overlay `kustomization.yaml` files use relative paths like `../../base`. Since we're copying both the overlay and base into the same parent directory, the overlay's `kustomization.yaml` needs to reference `./base` instead. Create a build-time script or use sed in the Containerfile:

```dockerfile
# Fix kustomize relative paths for embedded layout
RUN find /usr/lib/microshift/manifests.d/ -name kustomization.yaml -exec \
    sed -i 's|../../base|./base|g' {} \;
```

Or better — create a dedicated `overlays/embedded/` in your edgeworks-deploy repo that uses flat paths, purpose-built for embedding into the OS image.

### Updated MicroShift config.yaml

Your existing `os/configs/microshift/config.yaml` already has `kustomizePaths` but only lists two paths. Update to include `manifests.d/*`:

```yaml
manifests:
  kustomizePaths:
    - /usr/lib/microshift/manifests
    - /usr/lib/microshift/manifests.d/*
    - /etc/microshift/manifests
    - /etc/microshift/manifests.d/*
```

### What this replaces

This eliminates the need for:

- `observability-deploy.service` (systemd oneshot that waited for k8s then ran `kubectl apply`)
- `deploy-observability.sh` script
- Any custom "wait for API then deploy" logic

MicroShift handles all of this internally — it waits for the API server to be ready, then applies kustomize manifests. It's the intended mechanism for embedded workloads.

---

## Embedding edgeworks Application Container Images for Offline

The MicroShift system images are handled by `embed-microshift-images.sh` (above), but your edgeworks application images also need to be available offline. These are hosted on `harbor.theedgeworks.ai/edgeworks/`.

### Application images to embed

From the edgeworks-deploy manifests:

```
# Core edgeworks services (harbor.theedgeworks.ai/edgeworks/)
harbor.theedgeworks.ai/edgeworks/edge-supervisor:latest
harbor.theedgeworks.ai/edgeworks/edge-governor:latest
harbor.theedgeworks.ai/edgeworks/event-journal:latest
harbor.theedgeworks.ai/edgeworks/source-registry:latest
harbor.theedgeworks.ai/edgeworks/stream-runtime:latest
harbor.theedgeworks.ai/edgeworks/query-api:latest
harbor.theedgeworks.ai/edgeworks/edge-management-api:latest
harbor.theedgeworks.ai/edgeworks/edgeworks-ui:latest
harbor.theedgeworks.ai/edgeworks/opcua-adapter:latest

# Infrastructure dependencies
ghcr.io/dexidp/dex:latest
ghcr.io/blake/external-mdns:v0.5.1
quay.io/jetstack/cert-manager-cainjector:v1.19.2
quay.io/jetstack/cert-manager-controller:v1.19.2
quay.io/jetstack/cert-manager-webhook:v1.19.2
otel/opentelemetry-collector-contrib:latest
```

### Approach: extend embed-microshift-images.sh

Add a second image list file for application images. Update `embed-microshift-images.sh` to also process a static list:

```dockerfile
# In Containerfile, after the MicroShift embed step:
COPY configs/edgeworks-images.txt /usr/share/edgeworks/image-list.txt
```

Create `os/configs/edgeworks-images.txt`:

```
harbor.theedgeworks.ai/edgeworks/edge-supervisor:latest
harbor.theedgeworks.ai/edgeworks/edge-governor:latest
harbor.theedgeworks.ai/edgeworks/event-journal:latest
harbor.theedgeworks.ai/edgeworks/source-registry:latest
harbor.theedgeworks.ai/edgeworks/stream-runtime:latest
harbor.theedgeworks.ai/edgeworks/query-api:latest
harbor.theedgeworks.ai/edgeworks/edge-management-api:latest
harbor.theedgeworks.ai/edgeworks/edgeworks-ui:latest
harbor.theedgeworks.ai/edgeworks/opcua-adapter:latest
ghcr.io/dexidp/dex:latest
ghcr.io/blake/external-mdns:v0.5.1
quay.io/jetstack/cert-manager-cainjector:v1.19.2
quay.io/jetstack/cert-manager-controller:v1.19.2
quay.io/jetstack/cert-manager-webhook:v1.19.2
otel/opentelemetry-collector-contrib:latest
```

Then add to `embed-microshift-images.sh` after the MicroShift manifest loop:

```bash
# --- Also embed application images from static list ---
APP_IMAGE_LIST="/usr/share/edgeworks/image-list.txt"
if [ -f "${APP_IMAGE_LIST}" ]; then
    log "Processing application image list: ${APP_IMAGE_LIST}"
    while IFS= read -r img; do
        [ -z "${img}" ] && continue
        [[ "${img}" =~ ^#.*$ ]] && continue
        TOTAL=$((TOTAL + 1))

        SHA=$(echo -n "${img}" | sha256sum | awk '{print $1}')
        DEST="${IMAGE_STORAGE_DIR}/${SHA}"

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

        echo "${img},${SHA}" >> "${IMAGE_LIST_FILE}"
    done < "${APP_IMAGE_LIST}"
fi
```

This uses the same two-phase mechanism: embedded at build time into `/usr/lib/containers/storage`, copied to CRI-O at runtime via `ExecStartPre`. When MicroShift applies the kustomize manifests, all images are already in local storage — no network pulls needed.

### Pin image tags

For reproducible offline builds, replace `:latest` tags with specific digests or version tags in both the manifests and the image list. `:latest` means the embedded image may not match what the manifest resolves to at runtime.

---

## Files to Create

### `scripts/deploy-observability.sh` — No longer needed

With MicroShift's `kustomizePaths` auto-deploy, the observability stack manifest goes into `/usr/lib/microshift/manifests.d/` and is applied automatically. Delete `deploy-observability.sh` and `observability-deploy.service`.

The existing `os/manifests/observability-stack.yaml` should be moved into the manifests.d structure:
```dockerfile
RUN mkdir -p /usr/lib/microshift/manifests.d/05-observability
COPY manifests/observability-stack.yaml /usr/lib/microshift/manifests.d/05-observability/
# Create a kustomization.yaml for it
RUN echo 'apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources:\n  - observability-stack.yaml' \
    > /usr/lib/microshift/manifests.d/05-observability/kustomization.yaml
```

---

## Migration Checklist

### Core migration
- [ ] Enable `@microshift-io/microshift-nightly` COPR in Containerfile
- [ ] Replace custom builder multi-stage with `dnf install microshift microshift-release-info microshift-kindnet`
- [ ] Remove custom `microshift.service` from repo (RPM provides the correct one)
- [ ] Add `skopeo` to dnf install list (required for image embedding)
- [ ] Add `VOLUME /var` to Containerfile (kubelet idmap support, matches upstream)

### Offline image embedding
- [ ] Create `scripts/embed-microshift-images.sh` (see script above)
- [ ] Add `/etc/subuid` and `/etc/subgid` root mapping in Containerfile (required for skopeo during build)
- [ ] Verify `microshift-release-info` RPM installs release manifests to `/usr/share/microshift/release/`
- [ ] Verify embedded images appear in `/usr/lib/containers/storage/` after build
- [ ] Verify `microshift-copy-images` script is generated at `/usr/bin/`
- [ ] Verify systemd drop-in exists at `/usr/lib/systemd/system/microshift.service.d/microshift-copy-images.conf`
- [ ] Remove `os/configs/containers/storage.conf.d/offline.conf` (no longer needed)
- [ ] Test: boot without network, confirm MicroShift starts with all pods running

### Cleanup
- [ ] Delete all K3s files (Containerfile.k3s, configs/k3s/, scripts/k3s-*, systemd/k3s/)
- [ ] Strip `edge-setup.sh` to OS-only concerns (no K3s, no inline script generation)
- [ ] Remove `K3S_VERSION`, `CNI_VERSION` from `versions.txt`
- [ ] Simplify Makefile to single build target
- [ ] Update `build.sh` to remove K3s branch
- [ ] Update CI workflows: remove K3s workflow, update MicroShift workflow
- [ ] Update tests: `test-container.sh` to only test MicroShift variant

### Verification
- [ ] Verify: `microshift-make-rshared.service` is enabled (RPM postinstall does this)
- [ ] Verify: RPM postinstall configures firewall zones for 10.42.0.0/16 and 169.254.169.1
- [ ] Verify: `/root/.kube/config` symlinks to `/var/lib/microshift/resources/kubeadmin/kubeconfig` (RPM does this)
- [ ] Verify: Kindnet pods come up on Fedora (OVN-K is not supported)
- [ ] Test: airgap boot — all MicroShift system pods running without network
- [ ] Test: bootc update — after `bootc upgrade`, images still available (ExecStartPre repopulates)
- [ ] Test: `bootc container lint` passes
- [ ] Test: observability stack deploys to MicroShift after boot
