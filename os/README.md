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
├── systemd/                        # Systemd service files
├── examples/                       # Configuration examples and test scripts
│   ├── cloud-init.yaml            # Post-installation configuration (K3s/MicroShift)
│   ├── test-observability.sh      # Observability stack validator
│   └── README.md                   # Examples documentation
├── kickstart.ks                   # Interactive installation Kickstart file
└── README.md                       # This file
```

## Quick Start

### Prerequisites

- Container runtime: Docker (macOS) or Podman (Linux)
- At least 4GB free disk space

### Quick Build Examples

```bash
# From repository root
make build                    # K3s build
make build-microshift         # MicroShift build  
make test                     # Test built image
make build-iso-interactive    # Create bootable ISO
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

## Examples and Templates

The [`examples/`](examples/) directory contains ready-to-use configuration templates and testing scripts:

### 📋 Available Examples

- **`cloud-init.yaml`**: Post-installation system configuration
  - Works with both K3s and MicroShift
  - Automatic kubeconfig setup based on detected distribution
  - Pre-configured aliases and helpful commands
  - SSH key management and user setup

- **`test-observability.sh`**: Comprehensive observability stack validator
  - Auto-detects K3s or MicroShift distributions
  - Tests all observability endpoints and services
  - Provides troubleshooting guidance
  - Colored output for easy reading

### 🚀 Quick Usage

```bash
# Test your observability stack
cd os/examples
chmod +x test-observability.sh
./test-observability.sh

# Use cloud-init for post-installation setup
cp examples/cloud-init.yaml my-config.yaml
# Edit my-config.yaml with your settings
# Deploy with ISO using cloud-init URL
```

See [`examples/README.md`](examples/README.md) for detailed usage instructions and customization guide.

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

## 🔧 Build Process

The build process uses a **Makefile** (located at the repository root) that provides multiple targets for different build scenarios.
