# Codebase Structure

**Analysis Date:** 2026-03-01

## Directory Layout

```
os-builder/
├── .github/                    # GitHub-specific configuration and CI/CD
│   ├── actions/               # Reusable GitHub Actions
│   │   ├── build-container/   # Container build action
│   │   ├── test-container/    # Container testing action
│   │   ├── trivy-scan/        # Security scanning action
│   │   ├── build-iso/         # ISO generation action
│   │   ├── calculate-version/ # Version calculation action
│   │   ├── harbor-auth/       # Registry authentication
│   │   ├── load-versions/     # Load versions.txt
│   │   └── update-version/    # Update version tracking
│   ├── workflows/             # CI/CD workflow definitions
│   │   ├── build-and-security-scan.yaml
│   │   ├── build-microshift.yaml
│   │   └── dependency-update.yaml
│   └── README.md              # GitHub Actions documentation
├── .planning/                 # Planning and analysis documents
│   └── codebase/             # Generated codebase analysis docs
├── os/                        # Main Fedora bootc OS build
│   ├── Containerfile.k3s      # K3s variant Containerfile
│   ├── Containerfile.fedora.optimized # MicroShift variant Containerfile
│   ├── build.sh              # Build script for container images
│   ├── Makefile              # Build automation targets (local Makefile)
│   ├── kickstart.ks          # Kickstart file for ISO interactive installation
│   ├── README.md             # OS build documentation
│   ├── configs/              # Service configuration files
│   │   ├── k3s/              # K3s configuration
│   │   │   ├── config.yaml   # K3s cluster configuration
│   │   │   └── registries.yaml # K3s container registry configuration
│   │   ├── microshift/       # MicroShift configuration
│   │   │   └── config.yaml   # MicroShift cluster configuration
│   │   ├── otelcol/          # OpenTelemetry Collector configuration
│   │   │   └── config.yaml   # OTel metrics, logs, traces pipeline
│   │   └── containers/       # Container runtime configuration
│   ├── scripts/              # Runtime setup and utility scripts
│   │   ├── edge-setup.sh     # First-boot edge deployment setup
│   │   ├── health-check.sh   # Health verification script
│   │   ├── k3s-load-images.sh # Load airgap K3s images
│   │   └── setup-k3s-kubeconfig.sh # Configure kubeconfig access
│   ├── manifests/            # Kubernetes manifest files
│   │   └── observability-stack.yaml # OTel Kubernetes deployment
│   ├── systemd/              # Systemd service and timer files
│   │   ├── edge-setup.service # Edge deployment initialization
│   │   ├── k3s.service       # K3s service (legacy, see k3s/ subdirectory)
│   │   ├── otelcol.service   # OpenTelemetry Collector service
│   │   ├── observability-deploy.service # Deploy observability stack
│   │   ├── bootc-fetch-apply-updates.timer.d/
│   │   │   └── weekly.conf   # Override bootc update schedule
│   │   ├── microshift.service # MicroShift service
│   │   ├── microshift-kubeconfig-setup.service
│   │   └── k3s/              # K3s-specific systemd files
│   │       ├── k3s.service   # K3s Kubernetes service
│   │       ├── k3s-load-images.service # Load K3s airgap images
│   │       └── k3s-kubeconfig-setup.service # K3s kubeconfig setup
│   ├── examples/             # Example configurations and scripts
│   │   ├── cloud-init.yaml   # Example cloud-init configuration
│   │   └── test-observability.sh # OTel stack testing script
│   └── config-examples/      # ISO configuration examples (directory)
├── scripts/                   # Root-level utility scripts
│   └── fix-trivy-cache.sh    # Trivy cache cleanup utility
├── Makefile                  # Root Makefile with build/test targets
├── versions.txt              # Centralized version configuration
├── GitVersion.yml            # GitVersion configuration for versioning
├── .trivy.yaml               # Trivy security scanner configuration
├── .gitignore                # Git exclusions
├── LICENSE                   # Project license
├── README.md                 # Main project documentation
└── VERSION_MANAGEMENT.md     # Version management documentation
```

## Directory Purposes

**`.github/`:**
- Purpose: GitHub Actions and CI/CD automation
- Contains: Workflow definitions, reusable actions, automation logic
- Key files: `build-and-security-scan.yaml`, `build-microshift.yaml` for CI pipeline

**`.github/actions/`:**
- Purpose: Reusable GitHub Actions for build, test, and deploy operations
- Contains: Action definitions with shell scripts and action metadata
- Each action is self-contained with its own action.yml and scripts

**`os/`:**
- Purpose: Primary Fedora bootc OS build for edge computing
- Contains: Container definitions, configuration, runtime services, scripts, manifests
- Key pattern: Configuration files + scripts + services create complete OS experience

**`os/configs/`:**
- Purpose: Runtime service configuration (externalized from code)
- Contains: YAML configuration files read by K3s, MicroShift, OpenTelemetry Collector
- Access: Copied into container at build time, read from `/etc/` paths at runtime

**`os/scripts/`:**
- Purpose: Setup, initialization, and operational scripts
- Contains: Bash scripts executed at boot or by systemd services
- Execution: Called from systemd services (edge-setup.service, k3s-load-images.service, etc.)

**`os/systemd/`:**
- Purpose: Systemd service and timer definitions for service orchestration
- Contains: Service files defining startup sequence, dependencies, restart policies
- Pattern: Services define `After=`, `Wants=` to establish startup order

**`os/manifests/`:**
- Purpose: Kubernetes manifests for cluster-level components
- Contains: YAML manifests for observability stack (Prometheus, Jaeger, OTel operators)
- Deployment: Applied to running Kubernetes cluster via `kubectl apply`

**`os/examples/`:**
- Purpose: Example configurations for common deployment scenarios
- Contains: cloud-init configuration, testing scripts
- Use: Templates for user-provided customization

**`.planning/codebase/`:**
- Purpose: Generated codebase analysis documents
- Contains: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, STACK.md, INTEGRATIONS.md, CONCERNS.md
- Generated: By GSD orchestrator tools, consumed by planning/execution phases

**`scripts/`:**
- Purpose: Root-level utility scripts for entire project
- Contains: Helper scripts (Trivy cache fixes, etc.)
- Usage: Invoked by developers or CI/CD as needed

## Key File Locations

**Entry Points:**
- `Makefile` (root): Primary entry point for builds, tests, image operations
- `/os/build.sh`: Containerfile build execution with version management
- `/os/systemd/edge-setup.service`: First systemd service at boot time
- `/usr/local/bin/k3s`: K3s binary entry point (installed in container)

**Configuration:**
- `versions.txt`: Centralized version declarations (K3S_VERSION, MICROSHIFT_VERSION, FEDORA_VERSION, OTEL_VERSION, CNI_VERSION)
- `GitVersion.yml`: Semantic versioning configuration for image tagging
- `/os/configs/k3s/config.yaml`: K3s cluster configuration (copied to `/etc/rancher/k3s/config.yaml` in image)
- `/os/configs/otelcol/config.yaml`: OpenTelemetry pipeline configuration
- `.trivy.yaml`: Trivy scanner configuration for security scanning

**Core Logic:**
- `/os/Containerfile.k3s`: K3s variant OS build definition (245+ lines, multi-stage)
- `/os/Containerfile.fedora.optimized`: MicroShift variant OS build definition
- `/os/scripts/edge-setup.sh`: Edge-specific initialization (hostname, SSH, firewall, journald)
- `/os/scripts/k3s-load-images.sh`: Load airgap container images into K3s

**Testing:**
- `.github/actions/test-container/test-container.sh`: Container image testing script
- `/os/examples/test-observability.sh`: OpenTelemetry stack testing

**CI/CD:**
- `.github/workflows/build-and-security-scan.yaml`: Main CI pipeline
- `.github/workflows/build-microshift.yaml`: MicroShift-specific CI
- `.github/workflows/dependency-update.yaml`: Automated dependency updates

**Documentation:**
- `README.md` (root): Project overview, quick start, use cases
- `/os/README.md`: OS build detailed documentation
- `.github/actions/README.md`: GitHub Actions documentation
- `VERSION_MANAGEMENT.md`: Versioning and release documentation

## Naming Conventions

**Files:**
- `Containerfile.*`: Container image definitions (suffix indicates variant: `.k3s`, `.fedora.optimized`)
- `*.sh`: Executable shell scripts (scripts/ and root level)
- `*.yaml`: Configuration files (configs/ and examples/)
- `*.service`: Systemd service files (systemd/)
- `*.timer`: Systemd timer files (systemd/)
- `*.ks`: Kickstart installer configuration (root os/ directory)
- `*.yml`: YAML configuration (GitVersion.yml, .trivy.yaml)

**Directories:**
- `config-*`: Configuration-related directories (e.g., `config-examples/`)
- `*-examples/`: Example files and templates
- Kubernetes-related: `manifests/` for Kubernetes YAML, `systemd/k3s/` for K3s services

**Systemd Services:**
- Pattern: `<component>[-<subcomponent>].service`
- Examples: `edge-setup.service`, `k3s.service`, `k3s-kubeconfig-setup.service`, `otelcol.service`
- Pattern allows grouping: `k3s/k3s.service`, `k3s/k3s-load-images.service`

**Build Arguments:**
- UPPERCASE names with underscores: `K3S_VERSION`, `MICROSHIFT_VERSION`, `FEDORA_VERSION`, `OTEL_VERSION`
- Passed via environment variables → build arguments → image labels

## Where to Add New Code

**New Feature (e.g., additional service):**
- Primary code: Add Containerfile RUN commands or COPY configuration, create config file in `/os/configs/<service>/`
- Service definition: Add `.service` file to `/os/systemd/` or subdirectory
- Initialization: Add setup to `/os/scripts/edge-setup.sh` if it needs first-boot setup
- Tests: Add test case to `.github/actions/test-container/test-container.sh`

**New Component/Module (e.g., new monitoring tool):**
- Implementation: Create subdirectory under `/os/configs/<component>/` for configuration
- Scripts: Add to `/os/scripts/<component>.sh` if initialization logic needed
- Service: Add `/os/systemd/<component>.service` to integrate with systemd
- Documentation: Add to `/os/README.md` with usage examples

**New Build Variant (e.g., Ubuntu bootc instead of Fedora):**
- Containerfile: Create `/os/Containerfile.<new-variant>` following existing patterns
- Build script: build.sh already supports `CONTAINERFILE` environment variable, no changes needed
- Makefile: Add target `build-<variant>` if frequently used
- CI/CD: Add workflow file `.github/workflows/build-<variant>.yaml` if automating this variant

**Utilities and Helpers:**
- Root-level scripts: `/scripts/` directory for project-wide utilities
- Embedded in scripts: Bash functions within `/os/scripts/` for service-specific logic
- Container build utilities: Inline in Containerfile RUN commands

**Configuration Additions:**
- New K3s settings: Add to `/os/configs/k3s/config.yaml` (YAML format)
- New container runtime settings: Add to `/os/configs/containers/` (containers.conf format)
- New OTel pipeline: Add to `/os/configs/otelcol/config.yaml` (OTel configuration format)

**Testing:**
- Container tests: Add test cases to `.github/actions/test-container/test-container.sh`
- Integration tests: Create new script in `/os/examples/` for specialized testing scenarios

**Documentation:**
- OS features: `/os/README.md` for feature-specific documentation
- Build instructions: `README.md` root level for high-level overview
- CI/CD: `.github/actions/README.md` for GitHub Actions documentation

## Special Directories

**`/var/lib/rancher/k3s/agent/images/`:**
- Purpose: K3s airgap image storage
- Generated: During container build (images downloaded and stored)
- Committed: No (generated content)
- Access: K3s reads from here automatically if images unavailable from registry

**`/etc/rancher/k3s/`:**
- Purpose: K3s configuration and manifests
- Generated: No (configurations copied from `/os/configs/k3s/`)
- Committed: No (but source configs are in repo)
- Access: K3s service reads `config.yaml` from here at startup

**`/etc/containers/systemd/`:**
- Purpose: Systemd container unit files (quadlet format)
- Generated: No (can be created by users at runtime)
- Committed: No
- Access: Systemd reads .container files for pod definitions

**`/var/lib/containers/storage/`:**
- Purpose: Container runtime storage directory
- Generated: Yes (container images, layer storage)
- Committed: No
- Access: Podman/CRI-O reads/writes for image and container management

**`/home/fedora/.kube/`:**
- Purpose: Kubernetes client configuration
- Generated: Yes (by k3s-kubeconfig-setup.service)
- Committed: No
- Access: kubectl/kubeadm reads kubeconfig for cluster access

**`.planning/codebase/`:**
- Purpose: Generated analysis documents for codebase patterns
- Generated: Yes (by GSD orchestrator tools)
- Committed: Yes (documents are version controlled)
- Access: Read by GSD planning and execution phases

## Relationship Between Key Components

```
Makefile (root)
  └── make build
      └── os/build.sh (with env vars from versions.txt)
          └── podman/docker build
              ├── Containerfile.k3s or Containerfile.fedora.optimized
              └── Copies configs/ scripts/ systemd/ manifests/

At Runtime:
Container Start (systemd)
  ├── multi-user.target
  ├── edge-setup.service → /os/scripts/edge-setup.sh
  │   ├── Sets hostname
  │   ├── Configures SSH (/etc/ssh/sshd_config.d/)
  │   └── Sets up firewall
  ├── k3s/k3s.service → /usr/local/bin/k3s
  │   ├── Reads /etc/rancher/k3s/config.yaml
  │   ├── Mounts /var/lib/rancher/k3s/agent/images/ for airgap
  │   └── Starts kubelet
  ├── k3s/k3s-load-images.service → /os/scripts/k3s-load-images.sh
  │   └── Loads images into K3s
  ├── otelcol.service → /usr/local/bin/otel-collector
  │   ├── Reads /etc/otelcol/config.yaml
  │   └── Collects metrics, logs, traces
  └── observability-deploy.service → Kubernetes manifests
      └── Deploys to observability namespace
```

---

*Structure analysis: 2026-03-01*
