# 🚀 Fedora Edge OS Builder

An automated container image builder for creating lightweight, secure edge computing operating systems using **Fedora bootc**. This project generates container images that can be deployed as bootable operating systems on edge devices.

## 🎯 Key Features

- **🔧 Modern Architecture**: Uses Fedora bootc for container-native OS deployments
- **⚡ Lightweight**: Optimized for edge computing environments
- **🔒 Security-First**: SELinux enabled, hardened configurations, automated security scanning
- **📊 Observability**: Built-in OpenTelemetry stack for comprehensive monitoring
- **⚙️ GitOps Ready**: Version-controlled infrastructure with automated builds
- **🌐 Multi-Platform**: Supports x86_64 and ARM64 architectures

## 🏗️ Architecture Overview

### 🎯 K3s Edge OS (Default & Recommended)

**Primary focus with optimized experience:**

- **Fast Builds**: 8-12 minutes with optimized caching
- **Lightweight**: K3s provides a minimal Kubernetes footprint (~50MB binary)
- **Automated Builds**: Triggered on push/PR for continuous integration
- **Production Ready**: Battle-tested in edge environments
- **Offline Support**: Embedded container images for air-gapped deployments

### 🏢 MicroShift Edge OS (Enterprise Alternative)

**Enterprise-focused Kubernetes for edge:**

- **Fast Builds**: 5-8 minutes using pre-built binaries
- **Enterprise Ready**: Based on OpenShift, Red Hat ecosystem
- **Manual Builds**: Triggered via workflow dispatch for controlled deployments
- **Resource Efficient**: Optimized for edge and IoT environments

## 🚀 Quick Start

```bash
git clone https://github.com/RamaEdge/os-builder.git
cd os-builder

# Build K3s image (recommended)
make build

# Build MicroShift image (enterprise)
make build-microshift

# Test the image
make test

# Create ISO
make build-iso
```

### 📁 Repository Structure

```
os-builder/
├── os/
│   ├── Containerfile.k3s                    # K3s optimized build
│   ├── Containerfile.fedora.optimized       # MicroShift build
│   ├── build.sh                             # Build automation script  
│   ├── configs/                             # System configurations
│   ├── scripts/                             # Setup and utility scripts
│   └── Makefile                             # Build targets
├── .github/
│   ├── actions/                             # Reusable GitHub Actions
│   └── workflows/                           # Simplified CI/CD workflows
│       ├── build-and-security-scan.yaml    # K3s workflow (automated)
│       ├── build-microshift.yaml           # MicroShift workflow (manual)
│       └── dependency-update.yaml          # Automated dependency updates
└── README.md                               # This file
```

## 🛠️ Build Targets

### Core Targets

- `make build` - Build K3s edge OS image (default)
- `make build-microshift` - Build MicroShift edge OS image
- `make test` - Test the built image
- `make clean` - Clean up images and containers
- `make push` - Push image to registry
- `make info` - Show image information

### Advanced Targets

- `make install-deps` - Install build dependencies
- `make build-iso` - Build bootable ISO
- `make help` - Show all available targets

### Container Runtime Selection

The build system automatically detects available container runtimes:

- **Prefers**: `podman` (better for rootless operation)
- **Fallback**: `docker` (compatibility)
- **Override**: Force specific runtime

```bash
# Force specific runtime
make build CONTAINER_RUNTIME=docker
make build CONTAINER_RUNTIME=podman
```

## 📋 Workflow Overview

### 🔄 Automated Workflows

#### K3s Build (`build-and-security-scan.yaml`)

- **Triggers**: Push to main, pull requests, weekly schedule
- **Actions**: Build → Security scan → Test (PRs only) → ISO (main only)
- **Default ISO**: `user` configuration for production use

#### Security Scanning (Integrated)

- **Integrated**: Built into build workflows for efficiency
- **Container Focus**: Vulnerability scanning via tar export for consistency
- **Daily Monitoring**: Automated via build-and-security-scan.yaml schedule

#### Dependency Updates (`dependency-update.yaml`)

- **Triggers**: Weekly schedule, manual
- **Monitors**: K3s versions, OpenTelemetry Collector, base images
- **Automation**: Creates PRs for version updates

### 🎯 Manual Workflows

#### MicroShift Build (`build-microshift.yaml`)
- **Trigger**: Manual dispatch only
- **Default Version**: `release-4.19`
- **ISO**: Optional, user-selected configuration

## 🏗️ Usage Examples

### Local Development

```bash
# Build and test K3s locally
make build
make test

# Build MicroShift locally  
make build-microshift

# Create ISO for deployment
make build-iso
```

### CI/CD Integration

```bash
# Automatic K3s builds
git push origin main                    # Triggers K3s build

# Manual MicroShift build  
gh workflow run build-microshift.yaml

# Security scanning (integrated into build workflows)
gh workflow run build-and-security-scan.yaml
```

### Advanced Usage

```bash
# Custom image configuration
make build IMAGE_NAME=my-edge-os IMAGE_TAG=v2.0.0

# Specific MicroShift version
gh workflow run build-microshift.yaml -f microshift_version=release-4.18

# Specific ISO configuration
gh workflow run build-and-security-scan.yaml -f iso_config=production
```

## 📦 What's Included

### Core Components

- **Base OS**: Fedora Linux with bootc
- **Security**: SELinux enforcing, firewall configured
- **Networking**: NetworkManager, Cockpit web interface
- **Containers**: Podman runtime for workloads
- **Monitoring**: OpenTelemetry Collector for observability
- **Updates**: Automatic system updates via bootc

### K3s Distribution

- **Kubernetes**: K3s lightweight distribution
- **Runtime**: Embedded containerd
- **Networking**: Flannel CNI
- **Storage**: Local path provisioner
- **Ingress**: Traefik reverse proxy
- **Images**: Pre-loaded for offline operation

### MicroShift Distribution

- **Kubernetes**: MicroShift (OpenShift-based)
- **Runtime**: CRI-O with crictl
- **Networking**: OVN-Kubernetes CNI
- **Storage**: CSI host path provisioner
- **Ingress**: HAProxy router

## 🎯 Use Cases

- **Edge Computing**: Distributed computing at network edge
- **IoT Deployments**: Device management and orchestration
- **Development**: Container-native development environments
- **Air-gapped Environments**: Offline Kubernetes deployments

## 🔒 Security Features

- **Vulnerability Scanning**: Container image scanning via tar export for consistent, reproducible results
- **SBOM Generation**: Software Bill of Materials for supply chain security  
- **Version Pinning**: Reproducible builds with pinned dependencies
- **Security Updates**: Automated dependency monitoring and updates
- **Integrated Approach**: Security scanning built into build workflows for efficiency

## 💿 ISO Deployment

### Bootc-Native Approach

The project uses **bootc-embedded ISOs** for efficient deployment:

- **🚀 Efficient**: Smaller ISOs (base Fedora + kickstart)
- **🔄 Updated**: Pulls latest container image during installation  
- **🎯 Flexible**: Different image versions via kernel parameters
- **📦 Native**: Uses intended bootc workflow

### Creating ISOs

```bash
# Build ISO from current image
make build-iso

# GitHub Actions creates ISOs automatically for main branch builds
# Download from workflow artifacts
```

## 📖 Documentation

- **Build System**: See `os/README.md` for detailed build instructions
- **GitHub Actions**: See `.github/actions/README.md` for action documentation
- **Configuration**: See `os/configs/` for system configuration details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test your changes locally
5. Submit a pull request

For major changes, please open an issue first to discuss the proposed changes.

## 📚 References

- **Fedora bootc**: [bootc Project](https://github.com/containers/bootc)
- **K3s**: [K3s Documentation](https://k3s.io/)
- **MicroShift**: [MicroShift Documentation](https://microshift.io/)
- **OpenTelemetry**: [OpenTelemetry Documentation](https://opentelemetry.io/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.