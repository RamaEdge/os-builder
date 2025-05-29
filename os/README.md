# Fedora bootc Container Image for Edge OS

This directory contains the configuration and build scripts for creating Fedora-based bootc container images designed for edge computing deployments with K3s.

## Overview

This bootc (boot container) image is based on Fedora and provides:

- Immutable OS updates via container images
- Container runtime (Podman) pre-installed
- **K3s Kubernetes Distribution**: Lightweight Kubernetes for edge deployments
- **Offline Container Support**: Pre-loaded container images for air-gapped deployments
- **Observability Stack**: OpenTelemetry Collector for metrics, logs, and traces
- SSH access with security hardening
- Automatic updates capability
- Edge-specific optimizations

## K3s Edge OS Features

**Features:**
- **Lightweight**: ~50MB binary, minimal resource footprint
- **Offline Ready**: All container images embedded for air-gapped operation
- **Simple**: Single binary, easy maintenance
- **Fast Builds**: 8-12 minutes consistently
- **Truly Open Source**: No subscription required

## Files Structure

```
os/
├── Containerfile.k3s               # K3s Kubernetes build
├── build.sh                        # Enhanced build script
├── Makefile                        # Build automation
├── configs/
│   ├── containers/                 # Container runtime configuration
│   └── otelcol/                    # OpenTelemetry Collector configuration
├── manifests/
│   └── observability-stack.yaml    # Kubernetes observability manifests
├── scripts/
│   ├── edge-setup.sh               # Edge-specific setup script
│   └── create-custom-iso.sh        # Interactive ISO configuration creator
├── systemd/                        # Systemd service files
├── config-examples/                # ISO configuration examples
├── kickstart*.ks                   # Interactive installation Kickstart files
└── README.md                       # This file
```

## Quick Start

### Prerequisites

- Container runtime: Docker (macOS) or Podman (Linux)
- At least 4GB free disk space

### Building Images

#### K3s Edge OS

```bash
# Show available targets
make help

# Build K3s image (default)
make build

# Test the image
make test

# Clean up
make clean
```

#### Using the Build Script

```bash
# Make the script executable
chmod +x build.sh

# Build K3s (default)
./build.sh

# Build with custom settings
IMAGE_NAME=my-registry/edge-os IMAGE_TAG=v1.0.0 ./build.sh
```

#### Manual Build

```bash
# K3s build
podman build -t localhost/fedora-edge-os:latest -f Containerfile.k3s .
```

## Configuration

### Environment Variables

- `IMAGE_NAME`: Container image name (default: localhost/fedora-edge-os)
- `IMAGE_TAG`: Container image tag (default: auto-detected via git)
- `CONTAINERFILE`: Containerfile to use (default: Containerfile.k3s)
- `CONTAINER_RUNTIME`: Container runtime (auto-detected: docker on macOS, podman on Linux)

### Installed Packages

**System Components:**
- **System Tools**: openssh-server, sudo, systemd-resolved, chrony
- **Container Runtime**: podman, containerd (K3s embedded), cri-o (MicroShift)
- **Observability**: OpenTelemetry Collector (otelcol) via official RPM package
- **Networking**: NetworkManager, firewalld
- **Security**: policycoreutils-python-utils

**K3s Components:**
- **Kubernetes**: K3s binary, kubectl
- **Container Images**: Pre-loaded with skopeo for offline operation

### Default User

- Username: `fedora`
- Groups: `wheel` (sudo access)
- Home: `/home/fedora`
- Shell: `/bin/bash`
- Password: Disabled (SSH key authentication only)

## Deployment

### Converting to Disk Image

```bash
# Using make target
make disk-image

# Manual conversion using bootc-image-builder
sudo podman run --rm -it --privileged \
  --pull=newer \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  localhost/fedora-edge-os:latest
```

### Supported Output Formats

- `qcow2` - QEMU disk image
- `vmdk` - VMware disk image
- `raw` - Raw disk image
- `iso` - ISO installer image

## Features

### Offline Container Support

K3s images are embedded using skopeo for complete air-gapped operation:

```bash
# Container images are pre-loaded to /var/lib/rancher/k3s/agent/images/
# K3s automatically uses these images when starting

# Check embedded images
sudo ls -la /var/lib/rancher/k3s/agent/images/
```

### System Updates

```bash
# Check current image
sudo bootc status

# Update to latest image
sudo bootc upgrade

# Rollback if needed
sudo bootc rollback
```

## Usage Examples

### SSH Access

```bash
# Copy your public key during deployment or use cloud-init
ssh fedora@<ip-address>
```

### Container Operations

```bash
# Run a container (example with httpd)
podman run -d --name web-server -p 8080:80 httpd

# Check container status
podman ps

# Stop and remove container
podman stop web-server
podman rm web-server
```

### Kubernetes Operations

```bash
# Check cluster status
kubectl get nodes

# Deploy a simple web service
kubectl create deployment hello-world --image=httpd --port=80
kubectl expose deployment hello-world --type=NodePort --port=80

# Check deployments and services
kubectl get deployments,services

# K3s-specific commands
sudo systemctl status k3s
```

## Customization

### Adding Packages

Edit the Containerfile and add packages to the `dnf install` command:

```dockerfile
RUN dnf install -y \
    # ... existing packages ...
    your-package-name \
    && dnf clean all
```

### Custom Configuration

1. Add configuration files to the appropriate directories
2. Copy them in the Containerfile:

```dockerfile
COPY your-config.conf /etc/your-service/
```

## Testing

### Running Tests

```bash
# Basic functionality tests
make test

# Interactive testing
podman run --rm -it localhost/fedora-edge-os:latest /bin/bash
```

## Troubleshooting

### Build Issues

1. **Permission denied**: Ensure build script is executable
   ```bash
   chmod +x build.sh
   ```

2. **Out of space**: Clean up old images
   ```bash
   make clean
   podman system prune -a
   ```

### K3s-Specific Issues

1. **K3s not starting**: Check systemd service status
   ```bash
   sudo systemctl status k3s
   sudo journalctl -u k3s -f
   ```

2. **Images not loading**: Verify embedded images
   ```bash
   sudo ls -la /var/lib/rancher/k3s/agent/images/
   ```

## Support

For issues related to:

- **bootc**: Visit [bootc-dev/bootc](https://github.com/bootc-dev/bootc)
- **Fedora bootc**: Visit [Fedora bootc documentation](https://docs.fedoraproject.org/en-US/bootc/)
- **K3s**: Visit [K3s Documentation](https://docs.k3s.io/)
- **This configuration**: Open an issue in this repository
