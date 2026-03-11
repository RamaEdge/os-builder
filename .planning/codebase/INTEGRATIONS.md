# External Integrations

**Analysis Date:** 2026-03-11

## APIs & External Services

**Image Registries:**
- GitHub Releases (MicroShift) - `https://github.com/microshift-io/microshift/releases/download/`
  - SDK/Client: curl
  - Used for: Downloading prebuilt MicroShift RPM packages
  - Auth: None (public releases)

- GitHub Releases (OpenTelemetry Collector) - `https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/`
  - SDK/Client: curl
  - Used for: Downloading prebuilt OpenTelemetry Collector binaries
  - Auth: None (public releases)

- OpenShift Mirror Repository - `https://mirror.openshift.com/pub/openshift-v4/`
  - SDK/Client: DNF package manager
  - Used for: MicroShift dependency packages (cri-o and related RPMs)
  - Auth: None (public mirror)

**Container Registries:**
- Quay.io (Fedora bootc) - `quay.io/fedora/fedora-bootc`
  - SDK/Client: Podman/Docker
  - Used for: Base OS container image
  - Auth: Public, no authentication required

- Harbor Registry (Internal) - `harbor.theedgeworks.ai` / `harbor.local`
  - SDK/Client: Podman
  - Auth: Environment variables via GitHub Secrets (`REGISTRY_USERNAME`, `REGISTRY_PASSWORD`)
  - Connection: `.github/actions/harbor-auth/action.yml` handles authentication
  - Used for: Pushing built container images, pulling Edgeworks components
  - Implementation: `podman login` with username/password credentials

- Edgeworks Harbor Images:
  - `harbor.theedgeworks.ai/edgeworks/edge-supervisor:latest`
  - `harbor.theedgeworks.ai/edgeworks/edge-governor:latest`
  - `harbor.theedgeworks.ai/edgeworks/event-journal:latest`
  - `harbor.theedgeworks.ai/edgeworks/source-registry:latest`
  - `harbor.theedgeworks.ai/edgeworks/stream-runtime:latest`
  - `harbor.theedgeworks.ai/edgeworks/query-api:latest`
  - `harbor.theedgeworks.ai/edgeworks/edge-management-api:latest`
  - `harbor.theedgeworks.ai/edgeworks/edgeworks-ui:latest`
  - `harbor.theedgeworks.ai/edgeworks/opcua-adapter:latest`

- Infrastructure Container Images:
  - `ghcr.io/dexidp/dex:latest` (Dex OIDC provider)
  - `quay.io/jetstack/cert-manager-controller:v1.19.2` (Certificate management)
  - `quay.io/jetstack/cert-manager-cainjector:v1.19.2` (CA injector)
  - `quay.io/jetstack/cert-manager-webhook:v1.19.2` (Webhook validation)
  - `otel/opentelemetry-collector-contrib:latest` (OpenTelemetry contrib)

## Data Storage

**Databases:**
- etcd (Kubernetes-native) - MicroShift built-in
  - Connection: Local, managed by MicroShift
  - Client: Kubernetes API
  - Config: `os/configs/microshift/config.yaml` - `memoryLimitMB: 128` for edge constraints
  - Purpose: Kubernetes cluster state storage

**File Storage:**
- Local filesystem - Container image storage and offline embedding
  - Location: `/usr/lib/containers/storage` (bootc container dir storage)
  - Purpose: Offline container images for air-gapped deployments
  - Implementation: Container image layers embedded during build via `os/scripts/embed-microshift-images.sh`

**Caching:**
- None detected at infrastructure level
- Podman/Container runtime caching handled natively by Podman

## Authentication & Identity

**Auth Provider:**
- Dex (OIDC) - `ghcr.io/dexidp/dex:latest`
  - Implementation: Kubernetes Deployment via manifests
  - Location: `os/manifests/manifests.d/01-authentication/`
  - Auth Type: OpenID Connect (OIDC) provider for Kubernetes

**Registry Authentication:**
- Harbor Registry - Custom implementation
  - Credentials: GitHub Secrets (`REGISTRY_USERNAME`, `REGISTRY_PASSWORD`)
  - Implementation: Podman login via composite action `.github/actions/harbor-auth/action.yml`
  - Certificate Configuration: `/etc/containers/certs.d/{registry}/ca.crt` required on CI runner

**Service Account Authentication:**
- Kubernetes RBAC
  - Files: `os/manifests/manifests.d/05-observability/observability-stack.yaml`
  - Implementation: `auth_type: serviceAccount` for pod-to-pod communication
  - Used by: OpenTelemetry components, observability stack

## Monitoring & Observability

**Error Tracking:**
- Trivy (vulnerability scanning) - `https://aquasecurity.github.io/trivy/`
  - Config: `.trivy.yaml`
  - Scan types: Container images (vuln scanner), OS and library vulnerabilities
  - Output: SARIF format uploaded to GitHub Security tab
  - Severity levels: CRITICAL, HIGH, MEDIUM

**Logs:**
- OpenTelemetry Collector - `otelcol` binary + configuration
  - Config: `os/configs/otelcol/config.yaml`
  - Log receivers:
    - OTLP/gRPC: `:4317`
    - OTLP/HTTP: `:4318`
    - Prometheus metrics scraping: `:10250`, `:9100`, `:8888`
  - Log exporters:
    - Local logging (debug): Console output
    - OTLP to MicroShift: `http://localhost:4317` (local cluster)
    - OTLP to external endpoint: `${OTEL_EXPORTER_OTLP_ENDPOINT}` with Bearer token auth
  - Processors: Memory limiter (256MB), resource detection, batch processing
  - Data pipelines:
    - Metrics from hostmetrics and Prometheus scraper
    - Traces from OTLP receiver
    - Logs from OTLP receiver

**Metrics:**
- Prometheus - Integrated via OpenTelemetry Collector
  - Scrape targets: host metrics (CPU, disk, memory, network), MicroShift (kubelet), cAdvisor
  - Collection interval: 10-30 seconds
  - Metrics endpoint: `:8888` (OpenTelemetry Collector metrics)

## CI/CD & Deployment

**Hosting:**
- GitHub Actions (CI/CD orchestration)
  - Runner: Custom runner set (`os-builder-runner-set` for OS builds, `arc-runner-set` for Rust CLI)
  - Workflows: `.github/workflows/build-microshift.yaml`, `.github/workflows/bundle-cli.yml`

**CI Pipeline:**
- Build Pipeline (`build-microshift.yaml`):
  1. Checkout repository
  2. Load version configuration from `versions.json`
  3. Calculate semantic version from git
  4. Authenticate with Harbor registry
  5. Build container image with Podman
  6. Trivy security scan with SARIF output
  7. Run container validation tests
  8. Push to Harbor (main branch only)
  9. Conditionally build ISO image (scheduled or manual trigger)

- Rust CLI Pipeline (`bundle-cli.yml`):
  1. Checkout repository
  2. Install Rust toolchain with rustfmt + clippy
  3. Cache Cargo registry and build artifacts
  4. Format check (`cargo fmt`)
  5. Linting (`cargo clippy`)
  6. Test execution (`cargo test`)
  7. Release build (`cargo build --release`)
  8. Upload binary artifact

**Triggers:**
- Main workflow: Push to main, pull requests, weekly schedule (Fri 1 AM), manual dispatch
- Bundle CLI: Push to crates/bundle-cli/*, pull requests
- Event filters: Path-based (only runs when relevant files change)

## Environment Configuration

**Required env vars:**
- Registry authentication:
  - `REGISTRY_USERNAME` (GitHub Secret)
  - `REGISTRY_PASSWORD` (GitHub Secret)
- OpenTelemetry export (optional):
  - `OTEL_EXPORTER_OTLP_ENDPOINT` - External OTLP endpoint
  - `OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION` - Bearer token for external OTLP

**Build environment vars:**
- `IMAGE_NAME` - Container image name (default: `edgeworks/base-os`)
- `REGISTRY` - Registry hostname (default: `harbor.tjedgeworks.ai`)
- `REPO_OWNER` - Repository owner (default: `ramaedge`)
- `CONTAINERFILE` - Containerfile path (default: `Containerfile.microshift`)
- `OTEL_VERSION` - OpenTelemetry Collector version (from `versions.json`)
- `FEDORA_VERSION` - Base Fedora version (from `versions.json`)
- `MICROSHIFT_VERSION` - MicroShift version (from `versions.json`)
- `CONTAINER_RUNTIME` - Runtime choice: `podman` or `docker`

**Secrets location:**
- GitHub Secrets (`.env` not committed - see `.gitignore`)
- Build secrets mounted: Registry auth file passed as Podman build secret (never baked into image)
- Certificate location: `/etc/containers/certs.d/{registry}/ca.crt` (runner-local)

## Webhooks & Callbacks

**Incoming:**
- GitHub webhook triggers:
  - Push to main branch (auto-build)
  - Pull request events (validate builds)
  - Weekly schedule (Fri 1 AM, automated ISO builds)
  - Manual workflow dispatch (manual ISO builds)

**Outgoing:**
- Harbor registry push callbacks (implicit via podman push)
- GitHub Actions workflow notifications (email/Slack via repository settings)
- Trivy SARIF upload to GitHub Security tab (automatic for vulnerabilities)

## Build Artifact Management

**Output Locations:**
- `.build/output/` - Disk images (qcow2 format)
- `.build/iso-output/` - Bootable ISO files
- `.build/scan-results/` - Trivy scan results and SBOM
- `.build/registry-auth.json` - Temporary registry authentication (gitignored)
- `crates/bundle-cli/target/release/edgeworks-bundle` - Compiled CLI binary

**Artifact Distribution:**
- Container images: Pushed to Harbor registry (on main branch)
- ISO images: Available as workflow artifacts
- Binary artifacts: GitHub Actions artifact storage

---

*Integration audit: 2026-03-11*
