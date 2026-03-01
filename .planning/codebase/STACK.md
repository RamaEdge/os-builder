# Technology Stack

**Analysis Date:** 2026-03-01

## Languages

**Primary:**
- Bash - Build scripts and automation (`os/build.sh`, `scripts/`, Makefile)
- YAML - Configuration and orchestration (Containerfile, GitHub Actions, K3s/MicroShift configs, Kubernetes manifests)

**Secondary:**
- Makefile - Build automation and task running (`Makefile`, `os/Makefile`)

## Runtime

**Environment:**
- Linux container runtime (Fedora bootc image base)
- systemd - Process and service management in container
- Podman or Docker - Container runtime for building and running images

**Package Manager:**
- dnf - Fedora package manager (used in Containerfiles for package installation)
- Git - Version control and source management

## Frameworks

**Core:**
- Fedora bootc - Bootable container OS framework (base: `quay.io/fedora/fedora-bootc:${FEDORA_VERSION}`)
  - Purpose: Immutable OS management with transactional updates
  - Version: Fedora 42 (configurable via `FEDORA_VERSION` in `versions.txt`)

**Kubernetes Distributions:**
- K3s - Lightweight Kubernetes distribution
  - Version: v1.32.5+k3s1 (configurable in `versions.txt`)
  - Binary download: GitHub releases
  - Containerfile: `os/Containerfile.k3s`
  - Configuration: `os/configs/k3s/config.yaml`

- MicroShift - Red Hat's edge-optimized Kubernetes
  - Version: release-4.19 (configurable in `versions.txt`)
  - Source: GitHub OpenShift MicroShift project
  - Pre-built binary from: `ghcr.io/ramaedge/microshift-builder`
  - Containerfile: `os/Containerfile.fedora.optimized`
  - Configuration: `os/configs/microshift/config.yaml`

**Observability & Telemetry:**
- OpenTelemetry Collector - Metrics, traces, and logs collection
  - Version: 0.127.0 (configurable in `versions.txt`)
  - Binary download: GitHub opentelemetry-collector-releases
  - Configuration: `os/configs/otelcol/config.yaml`
  - Receivers: hostmetrics, OTLP (gRPC/HTTP), Prometheus
  - Exporters: logging, OTLP, file exporters for traces/logs

**Container Networking:**
- Flannel - Container network interface (CNI)
  - K3s uses Flannel VXLAN backend
  - Configuration: `os/configs/k3s/config.yaml` (flannel-backend: vxlan)

- CNI Plugins - Network plugin binaries
  - Version: v1.7.1 (configurable in `versions.txt`)
  - Binary download: GitHub containernetworking/plugins
  - Installation path: `/opt/cni/bin`

**Build/Dev:**
- bootc-image-builder - Container to disk/ISO image conversion
  - Source: `quay.io/centos-bootc/bootc-image-builder:latest`
  - Purpose: Convert container images to deployable formats (qcow2, ISO)

- Trivy - Vulnerability scanning
  - Installed via: `make install-trivy`
  - Configuration: `.trivy.yaml`
  - Purpose: Container image security scanning (CRITICAL, HIGH, MEDIUM severities)

- Syft - SBOM generation
  - Installed via: `make install-syft`
  - Purpose: Software Bill of Materials (SPDX JSON format)

- skopeo - Container image management
  - Used in build pipeline for image operations
  - Installed via: `make install-deps`

## Key Dependencies

**Critical:**
- kubernetes-client - kubectl CLI for Kubernetes management
- podman - Container runtime for privileged operations
- openssh-server - SSH access to edge devices
- sudo - Privilege escalation
- NetworkManager - Network configuration and management
- firewalld - Firewall management
- systemd-resolved - DNS resolution
- chrony - Time synchronization
- containerd - Container runtime
- jq - JSON parsing and manipulation
- curl - HTTP client for downloading binaries and files
- tar - Archive extraction
- zstd - Zstandard compression/decompression
- cri-o - Container runtime (MicroShift builds only)

**Infrastructure:**
- bootc - Bootable container compliance and validation
- ostree - Immutable OS updates
- policycoreutils-python-utils - SELinux utilities
- cronie - Scheduled task execution
- OpenTelemetry Collector - Telemetry data collection and export

## Configuration

**Environment:**
Environment variables passed through build process for version control and parameterization:
- Build-time: Passed via Makefile to build scripts as environment variables
- Runtime: Can be customized via `.env` files or GitHub Actions secrets for CI/CD

**Key Configuration Files:**
- `versions.txt` - Centralized version definitions (K3S_VERSION, OTEL_VERSION, MICROSHIFT_VERSION, FEDORA_VERSION, BOOTC_VERSION, CNI_VERSION)
- `Makefile` - Build orchestration with version loading from `versions.txt`
- `os/build.sh` - Build script that accepts environment variables
- `.github/actions/load-versions/action.yml` - GitHub Actions version loader
- `.trivy.yaml` - Trivy scanner configuration
- `.github/dependabot.yml` - Automated dependency updates

**Build Metadata:**
- Git SHA: `$(git rev-parse --short HEAD)` - Source code commit reference
- Build Date: `$(date -u +%Y-%m-%dT%H:%M:%SZ)` - ISO 8601 format timestamp
- Git Repository URL: Extracted from git remote origin

## Platform Requirements

**Development:**
- Linux system (Fedora, RHEL, or compatible recommended)
- Podman or Docker container runtime
- Git for source control
- Make for build automation
- At least 4GB free disk space
- Network access for:
  - GitHub releases (K3s, CNI plugins, OTel Collector, OpenShift MicroShift)
  - Quay.io (Fedora bootc images)
  - GitHub Container Registry (ghcr.io - MicroShift pre-built binaries)
- Optional for macOS: Docker Desktop via Homebrew

**Production/Deployment:**
- x86_64 (amd64) or ARM64 (aarch64/arm64) architecture support
- Edge device capable of running bootc-based container images
- Minimum 2GB RAM for K3s deployment
- Minimum 4GB RAM for MicroShift deployment
- Persistent storage for:
  - `/var/lib/rancher/k3s/` - K3s cluster data
  - `/var/lib/microshift/` - MicroShift cluster data
  - `/var/lib/otelcol/` - OpenTelemetry Collector data
  - Container image storage (`/usr/share/containers/storage` for offline support)

## Architecture Support

**Multi-Architecture Builds:**
- amd64 (x86_64) - Primary
- arm64 (aarch64) - ARM64 systems

**Architecture Detection Logic:**
- Automatic detection in Containerfiles via `uname -m`
- Mapping: `aarch64` → `arm64`, `x86_64` → `amd64`
- K3s binary naming convention: `amd64` uses `k3s`, others use `k3s-{ARCH}` suffix
- All external binaries (K3s, CNI plugins, OTel Collector) support both architectures

---

*Stack analysis: 2026-03-01*
