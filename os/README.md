# Fedora bootc Container Image for Edge OS

This directory contains the configuration and build scripts for creating a Fedora-based bootc container image designed for edge computing deployments.

## Overview

This bootc (boot container) image is based on Fedora and provides:

- Immutable OS updates via container images
- Container runtime (Podman) pre-installed
- **MicroShift Kubernetes built from source** for edge workloads
- **Offline Container Support**: Pre-loaded MicroShift container images for air-gapped deployments
- **Supply Chain Security**: SHA digest-based immutable container references
- **Observability Stack**: OpenTelemetry Collector for metrics, logs, and traces
- **Performance Optimized CI/CD**: Single-build workflow for maximum efficiency
- SSH access with security hardening
- Automatic updates capability
- Edge-specific optimizations

## Files Structure

```
os/
├── Containerfile.fedora       # Multi-stage Containerfile for Fedora bootc image
├── build.sh                   # Build script with error handling
├── Makefile                   # Make targets for building and ISO creation
├── configs/
│   ├── containers/            # Container runtime configuration
│   ├── microshift/            # MicroShift configuration
│   └── otelcol/               # OpenTelemetry Collector configuration
├── manifests/
│   └── observability-stack.yaml # Kubernetes observability manifests
├── scripts/
│   ├── edge-setup.sh         # Edge-specific setup script
│   └── create-custom-iso.sh  # Interactive ISO configuration creator
├── systemd/                   # Systemd service files
├── config-examples/           # ISO configuration examples
├── kickstart*.ks             # Interactive installation Kickstart files
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- Container runtime: Docker (macOS) or Podman (Linux)
- At least 4GB free disk space

### Platform-Specific Setup

- **macOS**: See [macOS Limitations and Solutions](../docs/MACOS_LIMITATIONS.md) for detailed instructions
- **Linux**: Native Podman support with standard package managers

### Building the Image

#### Using Make (Recommended)

```bash
# Show available targets
make help

# Check container runtime availability
make check-runtime

# Install dependencies (auto-detects macOS/Linux)
make install-deps

# Build the image
make build

# Test the image
make test

# Clean up
make clean
```

> **Note**: Local builds are optimized for development. For production deployments, the GitHub Actions CI/CD pipeline provides optimized single-build workflows with integrated security scanning and multi-platform support.

#### Using the Build Script

```bash
# Make the script executable
chmod +x build.sh

# Build with default settings
./build.sh

# Build with custom image name and tag
IMAGE_NAME=my-registry/edge-os IMAGE_TAG=v1.0.0 ./build.sh
```

#### Manual Build

```bash
podman build -t localhost/fedora-edge-os:latest -f Containerfile.fedora .
```

## Configuration

### Environment Variables

- `IMAGE_NAME`: Container image name (default: localhost/fedora-edge-os)
- `IMAGE_TAG`: Container image tag (default: latest)
- `CONTAINERFILE`: Containerfile to use (default: Containerfile.fedora)

### Installed Packages

The image includes essential packages for edge computing:

- **System Tools**: openssh-server, sudo, systemd-resolved, chrony
- **Container Runtime**: podman, cri-o
- **Kubernetes**: MicroShift (built from source), kubernetes-client (kubectl)
- **Observability**: OpenTelemetry Collector (otelcol)
- **Networking**: NetworkManager, firewalld
- **Security**: policycoreutils-python-utils

### Security Features

- **Multi-stage Build**: Build dependencies isolated from runtime image
- **Non-root Container User**: containeruser (UID-based) for container security compliance
- **Supply Chain Security**: Immutable SHA digest references
- **Pre-loaded Container Images**: MicroShift images available offline
- **Security Hardening**: Setuid binary removal, minimal attack surface

### Default User

- Username: `fedora`
- Groups: `wheel` (sudo access)
- Home: `/home/fedora`
- Shell: `/bin/bash`
- Password: Disabled (SSH key authentication only)

## Deployment

### Converting to Disk Image

To deploy the bootc image, you typically need to convert it to a disk image:

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

### Cloud Deployment

The generated disk images can be deployed to:

- VMware vSphere
- KVM/QEMU
- OpenStack
- Cloud providers (AWS, Azure, GCP with proper conversion)

## Features

### Automatic Updates

The image is configured for automatic updates:

- `bootc-fetch-apply-updates.timer` enabled for OS updates
- `podman-auto-update.timer` enabled for container updates

### Offline Container Support

The image includes pre-loaded MicroShift container images for offline deployment:

```bash
# Container images are pre-loaded to /usr/share/containers/storage
# Container storage is configured with additionalImageStores for offline access

# Check pre-loaded images
podman images --storage-driver=overlay --root=/usr/share/containers/storage

# Images are automatically available when MicroShift starts
```

### Observability and Monitoring

The system includes OpenTelemetry Collector for comprehensive observability:

```bash
# Check OpenTelemetry Collector status (host-level)
sudo systemctl status otel-collector

# View OpenTelemetry Collector logs
sudo journalctl -u otel-collector -f

# Check cluster observability components (after MicroShift is enabled)
kubectl get all -n observability

# OpenTelemetry metrics endpoint
curl http://localhost:4317  # OTLP gRPC
curl http://localhost:4318  # OTLP HTTP
```

**Observability Architecture:**

- **Host Level**: OpenTelemetry Collector collecting system metrics, logs, and traces
- **Cluster Level**: OpenTelemetry Collector in Kubernetes for cluster metrics and logs
- **Integration**: Host collector can forward data to cluster collector

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

After deployment, access the system via SSH:

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

# View logs
podman logs web-server

# Stop and remove container
podman stop web-server
podman rm web-server
```

### MicroShift/Kubernetes Operations

```bash
# Check cluster status
kubectl get nodes

# List all pods
kubectl get pods -A

# Deploy a simple test pod
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600

# Check pod status
kubectl get pods

# Example: Deploy a simple web service
kubectl create deployment hello-world --image=httpd --port=80
kubectl expose deployment hello-world --type=NodePort --port=80

# Check deployments and services
kubectl get deployments,services

# Check observability stack
kubectl get pods -n observability
```

## Customization

### Adding Packages

Edit `Containerfile.fedora` and add packages to the `dnf install` command:

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

### Custom Scripts

1. Add scripts to the `scripts/` directory
2. Make them executable
3. Copy and run them in the Containerfile

## Testing

### Running Tests

```bash
# Basic functionality tests
make test

# Interactive testing
podman run --rm -it localhost/fedora-edge-os:latest /bin/bash
```

### Verification

The built image includes `bootc container lint` which validates:

- Bootc compatibility
- Required labels
- System configuration

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

3. **Network issues**: Check container registry access

   ```bash
   podman pull quay.io/fedora/fedora-bootc:42
   ```

### Runtime Issues

1. **SSH access denied**: Ensure SSH keys are properly configured
2. **Container runtime issues**: Check podman service status
3. **Update failures**: Check network connectivity and image registry access

## Advanced Usage

### Multi-architecture Builds

```bash
podman build --platform linux/amd64,linux/arm64 \
  -t localhost/fedora-edge-os:latest \
  -f Containerfile.fedora .
```

### Custom Base Image

To use a different Fedora version, modify the FROM line in Containerfile.fedora:

```dockerfile
FROM quay.io/fedora/fedora-bootc:41  # or desired version
```

### Registry Push

```bash
# Tag for registry
podman tag localhost/fedora-edge-os:latest myregistry.com/fedora-edge-os:latest

# Push to registry
podman push myregistry.com/fedora-edge-os:latest
```

## Security Considerations

- **Container User**: Uses non-root containeruser for container security compliance
- **Supply Chain**: SHA digest-based immutable references prevent tampering
- **Offline Support**: Pre-loaded images reduce dependency on external registries
- **Minimal Attack Surface**: Only essential packages and services included
- **Security Hardening**: Setuid binaries removed, proper file permissions set
- SSH keys should be managed via cloud-init or other secure methods
- Regular updates should be tested before deployment
- Consider implementing image signing for production deployments

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project follows the same license as the main repository.

## Support

For issues related to:

- **bootc**: Visit [bootc-dev/bootc](https://github.com/bootc-dev/bootc)
- **Fedora bootc**: Visit [Fedora bootc documentation](https://docs.fedoraproject.org/en-US/bootc/)
- **This configuration**: Open an issue in this repository 
