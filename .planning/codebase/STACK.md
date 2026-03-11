# Technology Stack

**Analysis Date:** 2026-03-11

## Languages

**Primary:**
- Rust 1.x (edition 2021) - Bundle CLI tool, command-line utilities
- Bash/Shell - Build scripts, deployment automation
- YAML - GitHub Actions workflows, configuration

**Secondary:**
- Containerfile/OCI - Container image definitions (`os/Containerfile.microshift`)
- TOML - Rust Cargo manifests, bootc ISO configuration

## Runtime

**Environment:**
- Container Runtime: Podman 4.0+ (primary) or Docker (compatible)
- Base OS: Fedora 43 (bootc container base)
- Target Platform: x86_64 and aarch64 (ARM64)

**Package Manager:**
- Cargo (Rust package manager)
- DNF (Fedora package manager for OS-level packages)
- jq (JSON query tool, required for build scripts)

## Frameworks

**Core:**
- Fedora bootc - Bootable container technology for immutable OS images
- MicroShift 4.21.0 - Lightweight Kubernetes for edge computing
- OpenTelemetry Collector 0.127.0 - Observability and telemetry collection

**CLI Framework:**
- clap 4.x (Rust) - Command-line argument parsing with derive macros
- serde/serde_json 1.x (Rust) - Serialization and JSON handling

**Testing:**
- cargo (built-in test runner)
- assert_cmd 2.x (Rust) - Command assertion testing
- tempfile 3.x (Rust) - Temporary file handling for tests
- predicates 3.x (Rust) - Assertion predicate library

**Build/Dev:**
- Makefile - Build automation and task orchestration
- GitHub Actions - CI/CD pipeline
- Trivy - Container vulnerability scanning
- Syft - Software Bill of Materials (SBOM) generation
- bootc-image-builder - ISO image generation from bootc containers
- Anaconda kickstart - Interactive ISO installation configuration

## Key Dependencies

**Critical:**
- clap 4.x - CLI argument parsing (edgeworks-bundle command-line tool)
- serde 1.x with derive - Manifest serialization for bundle metadata
- serde_json 1.x - JSON manifest and version configuration parsing
- sha2 0.10 - SHA256 hashing for bundle integrity verification
- chrono 0.4 with serde - Timestamp handling in bundle manifests

**Infrastructure:**
- indicatif 0.17 - Progress bars for bundle operations and image downloads
- thiserror 2.x - Error type derivation for custom error handling
- microshift (external) - MicroShift Kubernetes edge platform (RPMs)
- otelcol (external) - OpenTelemetry Collector binary (compiled download)

## Configuration

**Environment:**
- `versions.json` - Single source of truth for all component versions:
  - Base Fedora version
  - MicroShift version
  - OpenTelemetry Collector version
  - Container image references (Edgeworks suite, infrastructure components)
- Build variables read from `versions.json` via `jq` and passed to container builds
- Registry authentication via GitHub Secrets: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`
- Optional OTEL external endpoint via environment variables: `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION`

**Build:**
- `os/Containerfile.microshift` - Multi-layer container definition
- `os/iso-config.toml` - bootc-image-builder configuration for ISO generation
- `os/kickstart.ks` - Anaconda installer interactive configuration
- `.trivy.yaml` - Container vulnerability scanning configuration
- `Makefile` - Build targets and automation
- `.github/workflows/build-microshift.yaml` - Main CI/CD workflow
- `.github/workflows/bundle-cli.yml` - Rust CLI build and test workflow
- `.github/actions/` - Composite actions for build steps (harbor-auth, build-container, trivy-scan, test-container, build-iso)

## Platform Requirements

**Development:**
- Podman 4.0+ or Docker (container runtime)
- jq (JSON query tool)
- Rust 1.x with stable toolchain (for bundle-cli)
- rustfmt and clippy (Rust formatting and linting)
- 8GB+ free disk space for image builds
- Network access to pull base images from registries

**Production:**
- Deployment Target: Edge computing devices with x86_64 or aarch64 architecture
- Bootable ISO images generated via `bootc-image-builder`
- MicroShift cluster running on Fedora bootc container
- OpenTelemetry Collector daemon for observability

---

*Stack analysis: 2026-03-11*
