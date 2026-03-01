# External Integrations

**Analysis Date:** 2026-03-01

## APIs & External Services

**GitHub:**
- **Service:** GitHub Releases API
  - What it's used for: Downloading pre-built binaries for K3s, CNI plugins, OpenTelemetry Collector, and MicroShift
  - Downloads from: `https://github.com/{k3s-io,containernetworking,open-telemetry,openshift}/releases`
  - Implementation: Direct curl downloads in Containerfiles with retry logic (3 retries, 5s delay)
  - Files affected: `os/Containerfile.k3s`, `os/Containerfile.fedora.optimized`

- **Service:** GitHub Container Registry (ghcr.io)
  - What it's used for: Pre-built MicroShift builder images
  - Registry: `ghcr.io/ramaedge/microshift-builder`
  - Environment variable: `MICROSHIFT_IMAGE_BASE` (Makefile, build.sh)
  - Used in: Multi-stage Containerfile builds for MicroShift

- **Service:** GitHub Actions
  - What it's used for: CI/CD automation for builds, testing, scanning, and deployments
  - Workflows: `.github/workflows/` directory
  - Self-hosted runners: Configured for image building and testing
  - Secrets used: `HARBOR_USERNAME`, `HARBOR_PASSWORD`, GitHub repository access
  - Workflows: `build-and-security-scan.yaml`, `build-microshift.yaml`, `dependency-update.yaml`

**Quay.io (Red Hat):**
- **Service:** Container Image Registry
  - Base images: `quay.io/fedora/fedora-bootc:${FEDORA_VERSION}` (Fedora 42)
  - Image builder: `quay.io/centos-bootc/bootc-image-builder:latest`
  - Purpose: Fedora bootc base OS and ISO/disk image conversion
  - Download commands: `make pull`, built into Containerfiles

**OpenTelemetry Project:**
- **Service:** OpenTelemetry Collector Releases
  - What it's used for: Telemetry data collection and export
  - Release downloads: `github.com/open-telemetry/opentelemetry-collector-releases`
  - Configuration: `os/configs/otelcol/config.yaml`
  - Architecture support: Both amd64 and arm64
  - System user: `otelcol` (UID/GID created in Containerfile)
  - Service: `os/systemd/otelcol.service`

**Kubernetes/Container Networking:**
- **K3s (CNCF Project)**
  - Release downloads: `github.com/k3s-io/k3s/releases`
  - Versions: Configurable in `versions.txt`
  - Configuration: `os/configs/k3s/config.yaml`
  - Airgap support: Pre-downloads K3s container images (tar.zst format)
  - Systemd services: `os/systemd/k3s/` directory

- **CNI Plugins (CNCF Project)**
  - Release downloads: `github.com/containernetworking/plugins/releases`
  - Installation: `/opt/cni/bin`
  - Version: Configurable in `versions.txt`
  - Used by both K3s and Flannel networking

- **MicroShift (OpenShift/Red Hat)**
  - Repository: `https://github.com/openshift/microshift.git`
  - Pre-built binaries: `ghcr.io/ramaedge/microshift-builder`
  - Configuration: `os/configs/microshift/config.yaml`
  - Systemd services: `os/systemd/microshift/` directory
  - Airgap support: Container images pre-loaded from release-images.json

## Data Storage

**Databases:**
- None configured - Edge OS is stateless at design level
- Persistent state locations:
  - K3s: `/var/lib/rancher/k3s/` (etcd embedded database)
  - MicroShift: `/var/lib/microshift/` (etcd embedded database)
  - OpenTelemetry: `/var/lib/otelcol/`, `/var/log/otelcol/`

**File Storage:**
- Local filesystem only
- Container image storage:
  - Primary: `/usr/share/containers/storage` (MicroShift pre-loaded images)
  - K3s airgap: `/var/lib/rancher/k3s/agent/images/`
  - Storage configuration: `os/configs/containers/storage.conf`

**Caching:**
- dnf package cache - Optimized layer caching in Containerfiles
- Build cache via Podman/Docker - Layer caching for faster rebuilds
- Trivy cache: `~/.cache/trivy` (configurable in `.trivy.yaml`)

## Authentication & Identity

**Auth Provider:**
- SSH-based authentication
  - Service: openssh-server (installed in Containerfile)
  - Configuration: Standard systemd SSH service
  - Hardening: SELinux contexts applied
  - Port: 22/tcp (firewall configured in Containerfile)

- Kubernetes API Server Authentication
  - K3s: Token-based and certificate-based (kubeconfig)
  - MicroShift: Token-based and certificate-based (kubeconfig)
  - Setup scripts: `os/scripts/setup-k3s-kubeconfig.sh`, `os/scripts/microshift-kubeconfig-setup.service`

**Container Registry Authentication:**
- **Harbor Registry (Internal)**
  - Registry URL: `harbor.local` (configurable via Makefile)
  - Authentication: Username/password via GitHub Actions secrets
  - Credentials used in: `.github/actions/harbor-auth/action.yml`
  - Certificate requirement: Self-signed certificates at `/etc/containers/certs.d/harbor.local/ca.crt`
  - Image push destination: `harbor.local/ramaedge/os-k3s:${TAG}`

- **GitHub Container Registry (ghcr.io)**
  - Used for: Pulling pre-built MicroShift images
  - Authentication: Potentially via GitHub Actions default token
  - Image: `ghcr.io/ramaedge/microshift-builder:${MICROSHIFT_VERSION}`

## Monitoring & Observability

**Error Tracking:**
- Trivy vulnerability scanning (security scanning only)
  - Tool: Trivy
  - Configuration: `.trivy.yaml`
  - Output: SARIF format for GitHub Security tab, JSON for reports
  - Triggers: On push to main, PRs, and weekly schedule
  - Action: `.github/actions/trivy-scan/action.yml`

**Logs:**
- systemd journaling for system services
- K3s logs: `/var/log/k3s/k3s.log` (configured in `os/configs/k3s/config.yaml`)
- MicroShift logs: `/var/log/microshift/` (handled by systemd)
- OpenTelemetry Collector logs: `/var/log/otelcol/` and console (loglevel: info)

**Telemetry:**
- OpenTelemetry Collector
  - Receivers: hostmetrics, OTLP (gRPC/HTTP), Prometheus, k8s_cluster, kubeletstats
  - Exporters: logging, OTLP, file (traces/logs)
  - Processors: batch, resource, memory_limiter, resourcedetection
  - Prometheus scrape endpoints: otel-collector (8888), node-exporter (9100), K3s (10250)
  - Configuration: `os/configs/otelcol/config.yaml` and Kubernetes manifests
  - Service: `os/systemd/otelcol.service`

## CI/CD & Deployment

**Hosting:**
- Self-hosted GitHub Actions runners
- Edge device deployment via bootc image

**CI Pipeline:**
- **GitHub Actions Workflows** (`.github/workflows/`)
  - `build-and-security-scan.yaml` - K3s container builds with Trivy scanning
  - `build-microshift.yaml` - MicroShift container builds
  - `dependency-update.yaml` - Automated dependency update checks
  - Triggers: Push to main, PRs, weekly schedule, manual dispatch

- **Build Automation** (Makefile-based)
  - Local targets: `make build`, `make build-microshift`, `make test`, `make scan`
  - Custom GitHub Actions: `.github/actions/` directory
    - `build-container/action.yml` - Container build with caching
    - `test-container/action.yml` - Container testing
    - `trivy-scan/action.yml` - Vulnerability scanning
    - `build-iso/action.yml` - ISO image generation
    - `harbor-auth/action.yml` - Registry authentication
    - `load-versions/action.yml` - Version configuration loading
    - `calculate-version/action.yml` - Git-based version calculation
    - `update-version/action.yml` - Version file updates

**Image Conversion & Deployment:**
- bootc-image-builder (quay.io/centos-bootc/bootc-image-builder)
  - Purpose: Convert container images to disk (qcow2) and ISO formats
  - Runs as privileged container
  - Configuration: ISO kickstart files in `os/kickstart*.ks`
  - Example outputs: ISO files for edge device deployment

## Environment Configuration

**Required env vars (build-time):**
- `IMAGE_NAME` - Container image name (default: harbor.local/ramaedge/os-k3s)
- `IMAGE_TAG` - Version tag (default: git describe or 'latest')
- `CONTAINERFILE` - Dockerfile path (Containerfile.k3s or Containerfile.fedora.optimized)
- `REGISTRY` - Container registry (default: harbor.local)
- `K3S_VERSION` - K3s release version
- `OTEL_VERSION` - OpenTelemetry Collector version
- `MICROSHIFT_VERSION` - MicroShift release version
- `FEDORA_VERSION` - Fedora bootc base version
- `BOOTC_VERSION` - bootc container version
- `CNI_VERSION` - CNI plugins version
- `CONTAINER_RUNTIME` - podman or docker

**Secrets location:**
- GitHub Actions secrets for CI/CD: `HARBOR_USERNAME`, `HARBOR_PASSWORD`
- Environment files (not committed): `.env` files (see `.gitignore`)
- Harbor certificate: `/etc/containers/certs.d/harbor.local/ca.crt` (self-hosted runner requirement)

**Runtime Configuration Files:**
- `os/configs/k3s/config.yaml` - K3s cluster configuration
- `os/configs/k3s/registries.yaml` - K3s container registry configuration
- `os/configs/microshift/config.yaml` - MicroShift cluster configuration
- `os/configs/otelcol/config.yaml` - OpenTelemetry Collector configuration
- `os/configs/containers/` - Container runtime configuration (systemd, storage)

## Webhooks & Callbacks

**Incoming:**
- None detected - Edge OS is passive (no inbound webhooks)
- GitHub webhook events trigger GitHub Actions via push/PR events

**Outgoing:**
- Container image push to Harbor registry (`.github/workflows/build-and-security-scan.yaml`)
- GitHub Security tab update via Trivy SARIF upload (security-events permission)
- GitHub Dependabot automated PR creation (`.github/dependabot.yml`)

## Build & Registry Integration

**Container Registry Operations:**
- Registry: Harbor (harbor.local) - Primary internal registry
- Registry: Quay.io - Base image source
- Registry: GitHub Container Registry (ghcr.io) - Pre-built MicroShift images

**Build Cache Strategy:**
- Layer caching via dnf metadata retention
- Image reuse detection based on Containerfile hash
- Cache tags: `{registry}/{image}:latest`

**Image Tagging:**
- Git-based versioning: `$(git describe --tags --always --dirty)`
- Format: `{registry}/{owner}/{image}:{version}`
- Labels applied: OCI Image metadata (version, revision, source, created)
- Containerfile hash: Tracked for cache invalidation

---

*Integration audit: 2026-03-01*
