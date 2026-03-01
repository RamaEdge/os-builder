# Architecture

**Analysis Date:** 2026-03-01

## Pattern Overview

**Overall:** Containerized OS Builder with Multi-Stage Container Build Pipeline

This is a container-based operating system builder that uses multi-stage Containerfile builds to produce immutable bootc (bootable container) images optimized for edge computing deployments. The architecture follows a layered approach with separation between build infrastructure, container image composition, configuration management, and runtime services.

**Key Characteristics:**
- Multi-variant container builds (K3s, MicroShift, generic Fedora bootc)
- Immutable OS updates via container images with bootc support
- Built-in Kubernetes orchestration (K3s or MicroShift)
- Air-gapped deployment support with pre-loaded container images
- Systemd-based service orchestration for runtime configuration
- Observability stack integration (OpenTelemetry Collector)

## Layers

**Build Layer:**
- Purpose: Orchestrate container image builds and manage build configuration
- Location: `Makefile`, `/os/build.sh`
- Contains: Build commands, version management, container runtime detection, image tagging
- Depends on: Containerfile variants, configuration files, build scripts
- Used by: GitHub Actions CI/CD workflows, local developer builds

**Container Definition Layer:**
- Purpose: Define container image composition with all packaged software
- Location: `/os/Containerfile.k3s`, `/os/Containerfile.fedora.optimized`
- Contains: Fedora bootc base image, package installation, binary downloads, configuration setup
- Depends on: External package repos, K3s/MicroShift releases, CNI plugins
- Used by: Build layer to produce runnable images

**Configuration Layer:**
- Purpose: Provide runtime configuration for installed services
- Location: `/os/configs/`
- Contains: K3s config, MicroShift config, OpenTelemetry Collector config, container runtime config
- Depends on: Service specifications (K3s, MicroShift, OTel)
- Used by: Containerfile COPY directives, systemd services

**Runtime Service Layer:**
- Purpose: Define systemd services that orchestrate runtime behavior
- Location: `/os/systemd/`
- Contains: Service files for K3s, MicroShift, edge setup, observability deployment
- Depends on: Scripts, configuration files, container images
- Used by: systemd on running instances to start and manage services

**Scripting Layer:**
- Purpose: Execute setup, initialization, and operational tasks
- Location: `/os/scripts/`
- Contains: Edge setup, health checks, Kubernetes kubeconfig setup, image loading
- Depends on: Container runtimes, Kubernetes tools, system utilities
- Used by: Systemd services, manual execution during deployment

**Deployment & Testing Layer:**
- Purpose: Automate image conversion, ISO generation, and validation
- Location: `Makefile` targets, `.github/actions/`, `.github/workflows/`
- Contains: Image conversion logic, test execution, security scanning, CI/CD orchestration
- Depends on: Built container images, test frameworks, scanning tools
- Used by: GitHub Actions, local developers

## Data Flow

**Build Flow:**

1. Developer/CI triggers build (local `make build` or GitHub Actions)
2. Build system reads version configuration from `versions.txt`
3. Container runtime (podman/docker) executes Containerfile
4. Multi-stage build:
   - Base image: Fedora bootc pulled from quay.io
   - Package layer: dnf installs system packages, Podman, Kubernetes tools
   - Binary layer: K3s/CNI plugins downloaded with architecture detection
   - Configuration layer: K3s/MicroShift configs, OpenTelemetry setup copied
   - Service layer: Systemd service files and scripts copied
5. Image tagged and stored in local container registry or pushed to remote registry

**Deployment Flow:**

1. System boots from bootc image (via ISO, disk image, or container runtime)
2. Systemd starts `edge-setup.service` → runs `/os/scripts/edge-setup.sh`
   - Sets hostname, configures SSH security, establishes firewall rules
   - Configures journald and log rotation for edge constraints
3. Systemd starts K3s service (`/os/systemd/k3s/k3s.service`)
   - K3s binary reads config from `/etc/rancher/k3s/config.yaml`
   - K3s initializes cluster, loads pre-loaded images from airgap directory
   - K3s-kubeconfig-setup service creates kubeconfig for local access
4. Systemd starts OpenTelemetry Collector (`/os/systemd/otelcol.service`)
   - Reads config from `/etc/otelcol/config.yaml`
   - Collects host-level metrics, logs, and traces
5. Kubernetes manifests deployed to observability namespace (via Kubernetes)

**Configuration Application:**

1. Containerfile copies configuration files during build to predictable locations
2. Runtime services read configs from well-known paths:
   - K3s: `/etc/rancher/k3s/config.yaml`
   - OpenTelemetry: `/etc/otelcol/config.yaml`
   - Container runtime: `/etc/containers/` and `/etc/crio/`
3. Cloud-init (if used) provides first-boot customization via `/etc/cloud/`

**State Management:**
- Persistent state stored in `/var/lib/` directories (K3s etcd, container images, Kubernetes state)
- Logs written to `/var/log/` with rotation managed by systemd-journald and logrotate
- K3s airgap images stored in `/var/lib/rancher/k3s/agent/images/`
- kubeconfig stored in `/home/fedora/.kube/config` for user access
- Bootc maintains immutable root filesystem; all modifications are transactional

## Key Abstractions

**Containerfile Variants:**
- Purpose: Provide multiple specialized OS builds for different Kubernetes distributions
- Examples: `Containerfile.k3s`, `Containerfile.fedora.optimized` (MicroShift)
- Pattern: Each variant extends Fedora bootc base, installs specific Kubernetes distribution and supporting tools

**Version Management:**
- Purpose: Centralize version information for reproducible builds
- Examples: `versions.txt` contains K3S_VERSION, MICROSHIFT_VERSION, FEDORA_VERSION, CNI_VERSION
- Pattern: Versions read by Makefile, passed to build.sh as environment variables, used as Containerfile build arguments

**Configuration Files:**
- Purpose: Externalize service configuration for easy modification without rebuilding
- Examples: `/os/configs/k3s/config.yaml`, `/os/configs/otelcol/config.yaml`
- Pattern: YAML files copied into container during build, read by services at runtime

**Systemd Service Orchestration:**
- Purpose: Define startup sequence, dependencies, and runtime behavior
- Examples: `k3s.service` (Kubernetes), `edge-setup.service` (initialization), `observability-deploy.service` (stack deployment)
- Pattern: Services define dependencies (After=, Wants=), startup commands, restart behavior

**Build Arguments Pattern:**
- Purpose: Allow customization of build without modifying Containerfile
- Examples: `K3S_VERSION`, `OTEL_VERSION`, `MICROSHIFT_VERSION` passed as `--build-arg`
- Pattern: Arguments default to specific versions, can be overridden at build time

## Entry Points

**Local Build Entry Point:**
- Location: `Makefile` (root directory)
- Triggers: Developer runs `make build` or CI/CD pipeline executes
- Responsibilities: Parse configuration, detect container runtime, invoke build.sh with proper environment variables, tag and push image

**Build Script Entry Point:**
- Location: `/os/build.sh`
- Triggers: Called by Makefile or directly via shell
- Responsibilities: Validate Containerfile existence, construct container build command, execute build with build arguments, display build status

**Container Initialization Entry Point:**
- Location: Systemd (via multi-user.target)
- Triggers: System boots or container starts
- Responsibilities: Start edge-setup.service, start K3s service, start observability services in proper sequence

**Edge Setup Entry Point:**
- Location: `/os/scripts/edge-setup.sh`
- Triggers: Called by edge-setup.service
- Responsibilities: Set hostname, configure SSH, setup firewall, configure journald, prepare filesystem

**K3s Startup Entry Point:**
- Location: `/usr/local/bin/k3s` with config `/etc/rancher/k3s/config.yaml`
- Triggers: k3s.service started by systemd
- Responsibilities: Initialize Kubernetes cluster, load airgap images, start kubelet, expose API server

## Error Handling

**Strategy:** Fail-fast with clear error messaging during build; graceful degradation during runtime with systemd restart policies

**Build-Time Patterns:**
- Containerfile uses `set -euo pipefail` in shell commands to exit on any error
- Build arguments validated in build.sh before execution
- Container runtime availability checked before build starts
- Network download failures trigger retry logic (curl --retry 3)

**Runtime Patterns:**
- Systemd services configured with `Restart=always` and `RestartSec=5s` for automatic recovery
- Health checks available via `systemctl status` commands
- Logs captured by systemd-journald, viewable via `journalctl -u <service>`
- K3s health check endpoint available at `localhost:6443` for API server status

**Configuration Error Handling:**
- SSH configuration errors handled by edge-setup.sh with logging via systemd-cat
- Firewall configuration errors logged but non-fatal (firewall-cmd --permanent)
- K3s configuration errors visible in K3s logs at `/var/log/k3s/k3s.log`

## Cross-Cutting Concerns

**Logging:**
- Approach: Multi-level logging via systemd-journald (structured), application-specific logs in `/var/log/`, script logging via systemd-cat
- K3s logs: `/var/log/k3s/k3s.log`
- Edge setup: Captured via systemd-cat with tag "edge-setup"
- OpenTelemetry: Collector logs via systemd journal

**Validation:**
- Containerfile validation: `bootc container lint` runs during build
- Configuration validation: YAML files validated by services on startup
- Bootc compliance: Images marked with `containers.bootc=1` and `ostree.bootable=1` labels

**Authentication & Security:**
- Approach: SSH key-based access (passwords disabled), SELinux via policycoreutils, firewall via firewalld
- SSH configuration: `/etc/ssh/sshd_config.d/99-edge-security.conf` (edge-setup.sh manages)
- Kubernetes RBAC: NodeRestriction and ResourceQuota admission plugins enabled
- Supply chain security: SHA digest-based immutable container references

**Observability:**
- Approach: OpenTelemetry Collector (host-level and cluster-level), systemd-journald (logs), Prometheus metrics
- Host metrics: OTel Collector listening on 4317 (gRPC) and 4318 (HTTP)
- Cluster observability: Manifests in `/os/manifests/observability-stack.yaml` deployed via Kubernetes
- Manual health checks: `/os/scripts/health-check.sh`

**Version Management:**
- Approach: Centralized versions.txt file, build arguments propagate through layers
- Reproducibility: Same versions.txt + same Containerfile = same image (deterministic builds)
- Multi-distribution support: Version sets for K3s vs MicroShift variants

**Architecture-Specific Handling:**
- Approach: Runtime detection in Containerfiles with fallback logic
- Pattern: Detect `uname -m`, map to standard names (amd64, arm64), adjust binary names accordingly
- Examples: K3s binary named `k3s` for amd64 but `k3s-arm64` for ARM; handled in Containerfile.k3s lines 49-77

---

*Architecture analysis: 2026-03-01*
