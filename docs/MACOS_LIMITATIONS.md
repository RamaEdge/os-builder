# macOS Limitations and Solutions

This document outlines the limitations when building disk images and ISOs on macOS and provides working solutions.

## The Issue

The `bootc-image-builder` tool requires direct access to container storage in podman format (`/var/lib/containers/storage`). Docker Desktop on macOS:

1. **Uses a different storage model**: Docker Desktop runs containers in a Linux VM and doesn't expose the underlying storage in the expected format
2. **Missing storage mounts**: The tool expects specific podman storage paths that aren't available in Docker Desktop
3. **Container runtime differences**: bootc-image-builder is designed primarily for podman, not Docker Desktop

## Error Messages You'll See

```bash
# Disk image building
make disk-image
# Results in: cannot build manifest: could not access container storage

# ISO building  
make build-iso-minimal
# Results in: cannot find "/var/lib/containers/storage/overlay"
```

## ✅ Working Solutions

### 1. Use Podman Instead of Docker (Recommended)

Install and configure Podman on macOS:

```bash
# Install podman
brew install podman

# Initialize podman machine
podman machine init

# Start podman machine
podman machine start

# Test podman
podman --version
```

Then build with podman:

```bash
# Build container image with podman
make build CONTAINER_RUNTIME=podman

# Create disk image with podman
make disk-image CONTAINER_RUNTIME=podman

# Create ISO with podman
make build-iso-minimal CONTAINER_RUNTIME=podman
```

### 2. Use GitHub Actions (Automated)

The project includes GitHub Actions workflows that automatically build disk images on Linux runners:

```bash
# Simply push your changes
git add .
git commit -m "Update MicroShift configuration"
git push

# GitHub Actions will automatically:
# 1. Build the container image
# 2. Create disk images (qcow2, vmdk, etc.)
# 3. Create ISO images
# 4. Upload artifacts for download
```

### 3. Use a Linux Environment

#### Option A: Linux VM
- Use UTM, Parallels, VMware, or VirtualBox
- Install Fedora/Ubuntu in the VM
- Clone the repository inside the VM
- Run `make disk-image` in the Linux environment

#### Option B: Docker with Linux Container
```bash
# Run a Linux container for building
docker run -it --privileged \
  -v $(pwd):/workspace \
  -v /var/lib/docker:/var/lib/containers/storage \
  fedora:latest bash

# Inside the container:
cd /workspace
dnf install -y make podman
make build CONTAINER_RUNTIME=podman
make disk-image CONTAINER_RUNTIME=podman
```

### 4. Use Remote Linux Machine

Build on a remote Linux server:

```bash
# Copy source to Linux machine
scp -r . user@linux-machine:~/os-builder/

# SSH to Linux machine
ssh user@linux-machine

# Build on Linux
cd ~/os-builder/os
make build
make disk-image
```

## 📋 Feature Comparison

| Feature | Docker Desktop (macOS) | Podman (macOS) | Linux (any) | GitHub Actions |
|---------|------------------------|----------------|-------------|----------------|
| Container Build | ✅ | ✅ | ✅ | ✅ |
| Container Test | ✅ | ✅ | ✅ | ✅ |
| Disk Image (.qcow2) | ❌ | ✅ | ✅ | ✅ |
| ISO Image | ❌ | ✅ | ✅ | ✅ |
| VMware Image (.vmdk) | ❌ | ✅ | ✅ | ✅ |
| Raw Image (.raw) | ❌ | ✅ | ✅ | ✅ |
| Setup Complexity | Easy | Medium | Easy | Easy |
| Build Speed | Fast | Medium | Fast | Medium |

## 🔧 Troubleshooting

### Docker Desktop Settings

Even with these solutions, you may need to enable:
1. **Settings → Features in Development → Use containerd for pulling and storing images**
2. **Settings → Advanced → Allow privileged containers**

### Podman Common Issues

```bash
# If podman machine fails to start
podman machine stop
podman machine rm
podman machine init --cpus 4 --memory 8192
podman machine start

# If storage access fails
podman system reset
```

### GitHub Actions Not Running

1. Ensure GitHub Actions are enabled in repository settings
2. Check `.github/workflows/` files exist
3. Verify you have push permissions to the repository

## 🎯 Recommended Workflow for macOS

For the best experience on macOS:

1. **Development**: Use Docker Desktop for quick container builds and testing
   ```bash
   make build  # Uses Docker Desktop
   make test   # Tests container functionality
   ```

2. **Disk Images**: Use Podman for image creation
   ```bash
   brew install podman
   podman machine init && podman machine start
   make disk-image CONTAINER_RUNTIME=podman
   ```

3. **Production Builds**: Use GitHub Actions for automated, consistent builds
   ```bash
   git push  # Triggers automated builds
   ```

## 🚀 Quick Start for macOS Users

```bash
# 1. Initial setup with Docker Desktop (for development)
make build
make test

# 2. Install Podman for disk images
brew install podman
podman machine init --cpus 4 --memory 8192
podman machine start

# 3. Build disk image with Podman
make disk-image CONTAINER_RUNTIME=podman

# 4. Or use GitHub Actions
git push  # Automated builds will create disk images
```

This approach gives you the best of both worlds: fast development with Docker Desktop and full functionality with Podman or GitHub Actions. 