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

- Container runtime: Podman (recommended) or Docker
- At least 4GB free disk space

### Quick Build Examples

```bash
# From repository root - simplified targets
make build                    # K3s build (default)
make build-microshift         # MicroShift build  
make test                     # Test built image
make build-iso               # Create bootable ISO
make clean                   # Clean up images
make info                    # Show image information

# With runtime override
make build CONTAINER_RUNTIME=docker
make build CONTAINER_RUNTIME=podman

# Get help with all targets
make help
```

### Available Make Targets

The build system provides these essential targets:

**Core Targets:**
- `build` - Build K3s edge OS image (default)
- `build-microshift` - Build MicroShift edge OS image
- `test` - Test the built image with comprehensive validation
- `clean` - Clean up images and containers
- `push` - Push image to registry
- `info` - Show image information

**Setup Targets:**
- `install-deps` - Install build dependencies
- `disk-image` - Convert to disk image
- `build-iso` - Build bootable ISO

**Container Runtime:**
- Automatically detects available runtime (podman preferred)
- Override with `CONTAINER_RUNTIME=docker` or `CONTAINER_RUNTIME=podman`

## Configuration

### Environment Variables

- `IMAGE_NAME`: Container image name (default: localhost/fedora-edge-os)
- `IMAGE_TAG`: Container image tag (default: auto-detected via git)
- `CONTAINERFILE`: Containerfile to use (default: Containerfile.k3s)
- `CONTAINER_RUNTIME`: Container runtime (auto-detected: prefers podman, fallback to docker)
- `MICROSHIFT_VERSION`: MicroShift version for MicroShift builds (default: release-4.19)

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

## Testing and Validation

### 🔍 Image Testing

The repository includes comprehensive testing to validate that the edge OS is properly configured:

```bash
# Comprehensive image testing with auto-detection
make test

# Test with specific runtime
make test CONTAINER_RUNTIME=docker
```

### ✅ What the Tests Verify

**Unified Test (`make test`):**
- ✅ Container image functionality (bootc, systemctl)
- ✅ Kubernetes components (kubectl, k3s binaries)
- ✅ OpenTelemetry Collector installation and configuration
- ✅ K3s manifest auto-deploy setup (`/etc/rancher/k3s/manifests/`)
- ✅ OTEL manifest content validation (deployments, services, endpoints)
- ✅ Service port configuration and accessibility
- ✅ Systemd service enablement (k3s, otelcol)
- ✅ Automatic image detection (tries exact tag, clean tag, then latest available)

### 🎯 Auto-Deployment Verification

The tests confirm that:
1. **K3s will automatically deploy** OTEL manifests from `/etc/rancher/k3s/manifests/` on startup
2. **All required endpoints** are configured and will be accessible:
   - OTLP gRPC: `http://localhost:30317`
   - OTLP HTTP: `http://localhost:30318`
   - Prometheus metrics: `http://localhost:30464/metrics`
   - OTEL internal metrics: `http://localhost:30888/metrics`
   - Host OTEL metrics: `http://localhost:8888/metrics`
3. **Both host-level and cluster-level** OpenTelemetry collectors are configured
4. **All required Kubernetes resources** are included (Namespace, ConfigMap, Deployment, Service, RBAC)

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

The build process uses a **simplified Makefile** (located at the repository root) that provides essential targets for container image building and testing.

### Key Features:
- **Smart Runtime Detection**: Automatically detects and uses available container runtime
- **User Override**: Force specific runtime with `CONTAINER_RUNTIME=docker/podman`
- **Intelligent Testing**: Automatically finds the best available image to test
- **Essential Targets**: Focused on core functionality without complexity

### Quick Reference:
```bash
make help           # Show all available targets
make build          # Build K3s image
make test          # Test the image
make clean         # Clean up
make info          # Show image information
```
