# Fedora bootc Container Image for Edge OS

This directory contains the configuration and build scripts for creating a Fedora-based bootc container image designed for edge computing deployments.

## Overview

This bootc (boot container) image is based on Fedora and provides:
- Immutable OS updates via container images
- Container runtime (Podman) pre-installed
- MicroShift Kubernetes for edge workloads
- SSH access with security hardening
- Automatic updates capability
- Edge-specific optimizations

## Files Structure

```
os/
├── Containerfile.fedora       # Main Containerfile for Fedora bootc image
├── build.sh                   # Build script with error handling
├── Makefile                   # Make targets for easy building
├── configs/
│   └── containers/
│       ├── containers.conf    # Container runtime configuration
│       └── registries.conf    # Container registries configuration
├── scripts/
│   └── edge-setup.sh         # Edge-specific setup script
├── systemd/
│   └── edge-setup.service    # Systemd service for edge setup
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
- **Container Runtime**: podman, buildah, skopeo, cri-o
- **Kubernetes**: microshift, kubernetes-client (kubectl)
- **Observability**: otel-collector (OpenTelemetry Collector)
- **Networking**: NetworkManager, firewalld
- **Monitoring**: htop, iotop, tcpdump
- **Development**: git, curl, wget, vim-enhanced
- **Hardware Support**: open-vm-tools
- **Security**: policycoreutils-python-utils

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

### Security Hardening

- SSH key-only authentication
- Firewall pre-configured
- SELinux enabled
- Root login disabled
- Minimal package set

### Edge Optimizations

- Reduced log retention
- Container runtime optimized for edge
- Time synchronization configured
- Hostname auto-generation

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

### Observability and Monitoring

The system includes a comprehensive observability stack with OpenTelemetry:

```bash
# Check OpenTelemetry Collector status (host-level)
sudo systemctl status otel-collector

# View OpenTelemetry Collector logs
sudo journalctl -u otel-collector -f

# Check cluster observability components
kubectl get all -n observability

# Access Jaeger UI for distributed tracing
# Open browser to: http://localhost:30686

# View OpenTelemetry metrics
curl http://localhost:30464/metrics

# View host-level Prometheus metrics
curl http://localhost:9090/metrics

# Check MicroShift metrics collection
kubectl logs -n observability deployment/otel-collector
```

**Observability Architecture:**
- **Host Level**: OpenTelemetry Collector collecting system metrics, logs, and traces
- **Cluster Level**: OpenTelemetry Collector in Kubernetes for cluster metrics
- **Jaeger**: Distributed tracing UI and storage
- **Integration**: Host collector forwards data to cluster collector via NodePort

### System Updates

```bash
# Check current image
sudo bootc status

# Update to latest image
sudo bootc upgrade

# Rollback if needed
sudo bootc rollback
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

- Default user has sudo access - consider restricting in production
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