# os-builder

Container-based OS builds for edge computing deployments using bootc (bootable containers) technology.

## Overview

This project builds immutable, container-native operating system images for edge devices:

- Immutable OS updates via container images with rollback capability
- MicroShift (lightweight Kubernetes) for edge workloads
- Offline container image embedding for air-gapped deployments
- OpenTelemetry Collector for observability
- Automated ISO building for bare-metal installation

## Architecture

```
versions.json          # Single source of truth for all versions
Makefile               # Build automation (reads versions.json)
os/
├── Containerfile.microshift  # Fedora 43 bootc + MicroShift
├── build.sh                  # Build script with registry auth
├── configs/                  # Container, MicroShift, OTel configs
├── scripts/                  # Image embedding, health checks
├── manifests/                # Kubernetes manifests (auto-deployed)
├── systemd/                  # Systemd service units
├── kickstart.ks              # Anaconda kickstart for ISO install
└── iso-config.toml           # bootc-image-builder config
.github/
├── workflows/
│   └── build-microshift.yaml # CI/CD pipeline
└── actions/                  # Reusable composite actions
    ├── build-container/      # Build with cache + registry auth
    ├── build-iso/            # ISO generation
    ├── trivy-scan/           # Vulnerability scanning (tar export)
    ├── test-container/       # Container validation tests
    ├── load-versions/        # Read versions.json
    ├── update-version/       # Update versions.json
    ├── calculate-version/    # Git-based semantic versioning
    └── harbor-auth/          # Harbor registry authentication
```

## Quick Start

```bash
# Show available targets and current versions
make help

# Build the container image
make build

# Run tests
make test

# Security scan
make scan

# Build bootable ISO
make build-iso

# Clean all build artifacts
make clean
```

## Version Management

All versions are centralized in `versions.json`:

```json
{
  "base": { "fedora": "43" },
  "components": {
    "microshift": "4.21.0_...",
    "otel_collector": "0.127.0"
  },
  "images": {
    "edgeworks": { ... },
    "infra": { ... }
  }
}
```

Override at build time: `make build FEDORA_VERSION=44`

## CI/CD

The `build-microshift.yaml` workflow:

1. Builds the container image with Podman
2. Runs Trivy vulnerability scanning (via tar export)
3. Runs container validation tests
4. Pushes to Harbor registry (on main branch)
5. Builds bootable ISO (on schedule or manual trigger)

Runs on: push to main, pull requests, weekly schedule, manual dispatch.

## Build Artifacts

All build artifacts are written to `.build/` (gitignored):

- `.build/scan-results/` - Trivy scan results, SBOM
- `.build/output/` - Disk images (qcow2)
- `.build/iso-output/` - Bootable ISO files
- `.build/registry-auth.json` - Temporary auth for builds

## Requirements

- Podman 4.0+ (or Docker)
- jq
- 8GB+ free disk space
- Network access to pull base images

## License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.
