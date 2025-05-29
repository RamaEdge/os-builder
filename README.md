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
- **Lightweight**: K3s provides a minimal Kubernetes footprint
- **Automated Builds**: Triggered on every push for continuous integration
- **Smaller Footprint**: ~50MB binary vs complex builds
- **Production Ready**: Battle-tested in edge environments

### 🎯 MicroShift Edge OS (Enterprise Alternative)

**Enterprise-focused Kubernetes for edge with Red Hat ecosystem:**

- **Fast Builds**: 5-8 minutes using pre-built binaries from [microshift-builder](https://github.com/RamaEdge/microshift-builder)
- **Enterprise Ready**: Based on OpenShift, Red Hat support available
- **Manual Builds**: Triggered via workflow_dispatch for controlled deployments
- **Resource Efficient**: Optimized for edge and IoT environments
- **Pre-built Binaries**: Uses container images with compiled MicroShift binaries

**Quick Start:**

```bash
git clone https://github.com/RamaEdge/os-builder.git
cd os-builder/os

# Build K3s locally (recommended)
make build

# Build MicroShift locally (using pre-built binaries)
make build-microshift

# Or use GitHub Actions
# K3s: Automatically triggers on code pushes
# MicroShift: Manual trigger via workflow_dispatch
```

### 📁 Repository Structure

```
os-builder/
├── os/
│   ├── Containerfile.k3s           # K3s optimized build
│   ├── build.sh                    # Build automation script  
│   ├── configs/                    # System configurations
│   │   ├── otelcol/               # OpenTelemetry configs
│   │   └── systemd/               # Service definitions
│   ├── manifests/                 # Kubernetes manifests
│   ├── scripts/                   # Setup and utility scripts
│   └── Makefile                   # Build targets
├── .github/
│   ├── actions/                   # Reusable GitHub Actions
│   └── workflows/                 # CI/CD workflows
│       ├── build-and-security-scan.yaml     # K3s workflow (automated)
│       └── security-scan.yaml               # Security scanning
├── config-examples/               # ISO configuration examples
├── scripts/                       # Build utilities
└── README.md                      # This file
```

## 🚀 Quick Start Guide

### Prerequisites

- **Container Runtime**: Docker (macOS) or Podman (Linux) 
- **Git**: For repository cloning
- **Optional**: Git for version detection

### 🎯 K3s Edge OS (Recommended)

**Choose your build method:**

1. **Local Build (K3s):**
   ```bash
   cd os-builder/os
   make build
   ```

2. **GitHub Actions (automated on push):**
   - Push to repository
   - Select "Build and Security Scan" workflow
   - Download artifacts when complete

## 📋 Build Options

| Feature | K3s Build (Default) | MicroShift Build | Build Time | Trigger | Use Case |
|---------|---------------------|------------------|------------|---------|----------|
| **Automation** | Fully automated | Manual dispatch | 8-12 min / 5-8 min | Auto on push / Manual | Production, CI/CD / Enterprise |
| **Binary Source** | Downloaded during build | Pre-built from [microshift-builder](https://github.com/RamaEdge/microshift-builder) | - | - | Community / Enterprise |

## 🛠️ Usage Examples

### Local Development

```bash
# Build K3s image locally
cd os-builder/os
make build

# Build MicroShift image locally (using pre-built binaries)
make build-microshift

# Test the image
make test

# Create ISO
make build-iso-interactive
```

### Production Deployment

```bash
# Push to trigger automated K3s build
git push origin main

# Manually trigger MicroShift build
gh workflow run build-microshift.yaml

# Download artifacts from GitHub Actions
# Deploy to edge devices via bootc or ISO
```

### Advanced Options

```bash
# Custom image name and tag
make build IMAGE_NAME=my-edge-os IMAGE_TAG=v2.0.0

# MicroShift with specific version
make build-microshift MICROSHIFT_VERSION=release-4.18

# Different Containerfile
make build CONTAINERFILE=Containerfile.custom
```

## 📦 What's Included

### Core Components (All Builds)

- **Base OS**: Fedora Linux with bootc
- **Security**: SELinux enforcing, firewall configured
- **Networking**: NetworkManager, Cockpit web interface
- **Containers**: Podman runtime for workloads
- **Monitoring**: OpenTelemetry Collector for observability
- **Updates**: Automatic system updates via bootc

### K3s Components

- **Kubernetes**: K3s lightweight distribution
- **Runtime**: K3s with embedded containerd (K3s) or CRI-O (MicroShift)
- **Networking**: Flannel CNI
- **Storage**: Local path provisioner
- **Ingress**: Traefik reverse proxy

### MicroShift Components

- **Kubernetes**: MicroShift (OpenShift-based)
- **Runtime**: CRI-O with crictl
- **Networking**: OVN-Kubernetes CNI
- **Storage**: CSI host path provisioner
- **Ingress**: HAProxy router
- **Source**: Pre-built binaries from [microshift-builder](https://github.com/RamaEdge/microshift-builder)

## 🎯 Use Cases

- **Edge Computing**: Distributed computing at network edge
- **IoT Deployments**: Device management and orchestration
- **Kubernetes Edge**: Lightweight Kubernetes workloads with K3s
- **Development**: Container-native development environments

## 📖 Documentation

- **Getting Started**: See individual `os/README.md` for detailed instructions
- **Workflows**: See `.github/workflows/README.md` for CI/CD documentation
- **Configuration**: See `config-examples/` for ISO configuration examples

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

For major changes, please open an issue first to discuss the proposed changes.

## 📚 References

- **Fedora bootc**: [bootc Project](https://github.com/containers/bootc)
- **K3s**: [K3s Documentation](https://k3s.io/)
- **OpenTelemetry**: [OpenTelemetry Documentation](https://opentelemetry.io/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.