# os-builder

This repository contains code for building operating systems that can be deployed on edge devices using bootc (bootable containers) technology.

## Overview

This project provides container-based OS builds for edge computing deployments using bootc technology, which enables:

- Immutable OS updates via container images
- Transactional updates with rollback capability
- Container-native OS management
- Edge-optimized configurations

## Available OS Builds

### Fedora bootc Edge OS (`os/`)

A complete Fedora-based bootc container image optimized for edge deployments.

**Features:**

- Based on Fedora 42 bootc base image
- Container runtime (Podman) pre-installed
- **MicroShift Kubernetes built from source** for latest features and customization
- **Offline Container Support**: Pre-loaded MicroShift container images for offline deployment
- **Observability Stack**: OpenTelemetry Collector for metrics, logs, and traces
- SSH access with security hardening
- Automatic updates capability
- Edge-specific optimizations
- **Supply Chain Security**: SHA digest-based immutable container references
- **Performance Optimized CI/CD**: Single container build per workflow run
  - 80% faster pull request builds
  - 70% faster production builds  
  - Eliminated redundant container builds
  - Integrated build, scan, and test in single job
- **ISO Building**: Create bootable ISOs with user configuration
  - Interactive installation wizard with user prompts
  - User account setup with SSH keys
  - Custom hostname and DNS configuration (DHCP or static IP)
  - Filesystem customizations with multiple layout options
  - Automated via GitHub Actions with optimized builds

**Quick Start:**

```bash
cd os/
make build                              # Build with MicroShift main branch
make build MICROSHIFT_VERSION=release-4.17  # Build with specific MicroShift version
make test
```

**Documentation:** See [os/README.md](os/README.md) for detailed instructions.

**MicroShift Source Build:** MicroShift is built from source for latest features.
See [docs/MICROSHIFT_SOURCE_BUILD.md](docs/MICROSHIFT_SOURCE_BUILD.md) for details.

**Versioning:** Container images are automatically versioned using GitVersion.
See [docs/GITVERSION.md](docs/GITVERSION.md) for details.

**Interactive Installation:** Guide for the interactive ISO installation process.
See [docs/INTERACTIVE_INSTALLATION.md](docs/INTERACTIVE_INSTALLATION.md) for details.

**ISO Building:** Complete guide for building bootable ISOs.
See [docs/ISO_BUILDING.md](docs/ISO_BUILDING.md) for details.

### 🚀 Performance Optimized CI/CD

The project uses an optimized GitHub Actions workflow that builds container images only once per run:

- **Pull Requests**: Single AMD64 build → Security scan → Test → No redundant builds
- **Production**: Single multi-platform build → Security scan → Push → ISO creation from same image
- **Massive Performance Gains**: 70-80% reduction in build times
- **Supply Chain Security**: All artifacts (images, ISOs) built from exact same scanned container

See [.github/workflows/README.md](.github/workflows/README.md) for detailed workflow documentation.

### RHEL bootc (Legacy - `os/Dockerfile`)

The original RHEL-based bootc configuration with MicroShift.

## Project Structure

```
os-builder/
├── os/                          # Fedora bootc edge OS build
│   ├── Containerfile.fedora     # Main multi-stage Containerfile
│   ├── build.sh                 # Build script
│   ├── Makefile                 # Build automation with ISO support
│   ├── configs/                 # Configuration files
│   ├── scripts/                 # Setup and utility scripts
│   ├── systemd/                 # Systemd services
│   ├── manifests/               # Kubernetes manifests
│   ├── config-examples/         # ISO configuration examples
│   ├── kickstart*.ks           # Interactive installation Kickstart files
│   └── README.md                # Detailed documentation
├── .github/                     # GitHub workflows
│   ├── workflows/               # CI/CD workflows
│   └── README.md                # Workflow documentation
├── docs/                        # Documentation
│   ├── GITVERSION.md            # GitVersion integration guide
│   ├── MACOS_LIMITATIONS.md     # macOS limitations and solutions
│   ├── MICROSHIFT_SOURCE_BUILD.md # MicroShift source build guide
│   ├── ISO_BUILDING.md          # ISO building guide
│   └── INTERACTIVE_INSTALLATION.md # Interactive installation guide
├── GitVersion.yml               # Version configuration
├── CHANGELOG.md                 # Project changelog and performance improvements
├── LICENSE                      # License file
└── README.md                    # This file
```

## Getting Started

1. **Clone the repository:**

   ```bash
   git clone <repository-url>
   cd os-builder
   ```

2. **Build the Fedora bootc image:**

   ```bash
   cd os/
   make help  # Show available commands
   make build # Build the container image
   ```

3. **Convert to disk image (for deployment):**

   ```bash
   make disk-image
   ```

4. **Build ISO with user configuration:**

   ```bash
   make build-iso-user         # Pre-configured users (automated)
   make build-iso-minimal      # Pre-configured minimal (automated)
   make build-iso-advanced     # Interactive with basic prompts
   make build-iso-interactive  # Interactive with comprehensive setup wizard
   ```

5. **Deploy to your edge infrastructure**

## Requirements

- Linux system (Fedora, RHEL, or compatible recommended)
- Podman or Docker
- At least 4GB free disk space
- Network access to pull base images

## Use Cases

This OS builder is designed for:

- **Edge Computing**: Deployments at network edge locations
- **IoT Infrastructure**: Internet of Things device management
- **Container Workloads**: Running containerized applications
- **Kubernetes Edge**: Lightweight Kubernetes workloads with MicroShift
- **Immutable Infrastructure**: Infrastructure as code deployments
- **Development/Testing**: Local development environments
- **Offline Deployments**: Pre-loaded container images for air-gapped environments

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

## Support

For support and documentation:

- **Fedora bootc**: [Fedora bootc Documentation](https://docs.fedoraproject.org/en-US/bootc/)
- **bootc project**: [bootc-dev/bootc](https://github.com/bootc-dev/bootc)
- **Issues**: Open an issue in this repository
