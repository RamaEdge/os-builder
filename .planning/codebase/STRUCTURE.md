# Codebase Structure

**Analysis Date:** 2026-03-11

## Directory Layout

```
/Users/ravichillerega/sources/management/os-builder/
├── Makefile                          # Build orchestration (build, test, scan, push, clean, bundle-cli targets)
├── versions.json                     # Single source of truth for all component versions
├── README.md                         # Project overview and quick start
├── LICENSE                           # Project license
├── .trivy.yaml                       # Trivy security scanner configuration
├── .gitignore                        # Git ignore patterns
│
├── os/                               # Container image source and build scripts
│   ├── Containerfile.microshift      # Multi-layer bootc image definition (MicroShift + OTel)
│   ├── build.sh                      # Build orchestration script (runtime detection, git metadata, auth)
│   ├── iso-config.toml               # bootc-image-builder configuration for Anaconda ISO
│   ├── kickstart.ks                  # Anaconda kickstart for bare-metal ISO installation
│   │
│   ├── configs/                      # Configuration files for image layers
│   │   ├── edgeworks-images.txt      # Generated: list of offline container images
│   │   ├── containers/               # Podman/CRI-O container configuration
│   │   ├── microshift/               # MicroShift configuration files
│   │   └── otelcol/                  # OpenTelemetry Collector configuration
│   │
│   ├── manifests/                    # Kubernetes manifests auto-deployed by MicroShift
│   │   ├── manifests.d/              # Additional manifests subdirectory
│   │   │   └── 05-observability/     # Observability-related manifests
│   │   └── [manifest YAML files]
│   │
│   ├── systemd/                      # Systemd service units
│   │   └── otelcol.service           # OpenTelemetry Collector service unit
│   │
│   └── scripts/                      # Helper scripts for image building
│       ├── health-check.sh           # Container health verification
│       └── embed-microshift-images.sh # Offline image embedding for air-gapped deployment
│
├── crates/                           # Rust projects (workspace)
│   └── bundle-cli/                   # edgeworks-bundle CLI tool
│       ├── Cargo.toml                # Rust project manifest and dependencies
│       ├── src/                      # Rust source code
│       │   ├── main.rs               # CLI entry point, command routing
│       │   ├── create.rs             # Bundle creation (image pull, checksum, manifest)
│       │   ├── verify.rs             # Bundle integrity verification (6-check validation)
│       │   ├── inspect.rs            # Bundle metadata inspection without validation
│       │   ├── manifest.rs           # Bundle schema (v1.0) data structures
│       │   └── error.rs              # Unified error type
│       │
│       └── tests/                    # Integration tests (if present)
│           └── [test files]
│
├── .github/                          # GitHub Actions CI/CD
│   ├── workflows/                    # Workflow definitions
│   │   └── build-microshift.yaml     # Main CI/CD pipeline (build, test, scan, push, ISO)
│   │
│   └── actions/                      # Reusable composite actions
│       ├── build-container/          # Build container image with cache and auth
│       ├── test-container/           # Run container validation tests
│       ├── trivy-scan/               # Security scanning with Trivy
│       ├── harbor-auth/              # Harbor registry authentication
│       ├── build-iso/                # ISO generation via bootc-image-builder
│       ├── calculate-version/        # Git-based semantic versioning
│       ├── load-versions/            # Load versions from versions.json
│       └── update-version/           # Update versions.json during release
│
├── scripts/                          # Repository-level utility scripts
│   └── [utility scripts]
│
├── docs/                             # Documentation
│   └── bundle-cli-design.md          # Bundle CLI design document
│
├── .build/                           # Build artifacts (gitignored)
│   ├── scan-results/                 # Trivy scan output and SBOM files
│   ├── output/                       # Disk images (qcow2 format)
│   ├── iso-output/                   # Bootable ISO files
│   └── registry-auth.json            # Temporary registry auth (copied at build time)
│
├── .planning/                        # Planning and analysis documents
│   ├── codebase/                     # Codebase analysis (ARCHITECTURE.md, STRUCTURE.md, etc.)
│   ├── milestones/                   # Project milestone definitions
│   └── phases/                       # Phase execution plans
│
└── [supporting files]
```

## Directory Purposes

**`os/`:**
- Purpose: Container image source, build orchestration, configuration, and deployment manifests
- Contains: Containerfile, shell scripts, configs, manifests, systemd units, helper scripts
- Key files: `Containerfile.microshift` (image definition), `build.sh` (orchestration), `iso-config.toml` (bootc-image-builder config)

**`crates/bundle-cli/`:**
- Purpose: Offline bundle management tool for air-gapped deployments
- Contains: Rust project with CLI, bundle operations (create/verify/inspect), manifest schema
- Key files: `src/main.rs` (entry point), `src/create.rs` (bundle creation logic), `src/verify.rs` (integrity checks)

**`.github/workflows/`:**
- Purpose: Automated build, test, security, and deployment pipeline
- Contains: GitHub Actions workflow definition and composite action implementations
- Key files: `build-microshift.yaml` (main pipeline)

**`.github/actions/`:**
- Purpose: Reusable workflow steps for common CI/CD operations
- Contains: Shell scripts and action metadata for build, test, scan, auth, version management
- Key files: `build-container/action.yml`, `trivy-scan/action.yml`, `test-container/action.yml`

**`.build/`:**
- Purpose: Isolated artifact storage (gitignored)
- Contains: Scan results, disk images, ISO files, temporary auth
- Generated: Created by Makefile targets; safe to delete

**`.planning/`:**
- Purpose: Project documentation and phase planning
- Contains: Codebase analysis (this directory), milestone definitions, phase execution plans
- Key files: `.planning/codebase/` (ARCHITECTURE.md, STRUCTURE.md, etc.)

## Key File Locations

**Entry Points:**
- `Makefile` - Developer/CI entry point for all build operations
- `os/build.sh` - Invoked by Makefile; orchestrates container build
- `crates/bundle-cli/src/main.rs` - CLI tool entry point; command router
- `.github/workflows/build-microshift.yaml` - GitHub Actions entry point

**Configuration:**
- `versions.json` - Single source of truth for all component versions
- `Makefile` - Build parameters, image name, registry, tool detection
- `.github/workflows/build-microshift.yaml` - CI/CD env vars, job dependencies
- `os/iso-config.toml` - bootc-image-builder configuration
- `.trivy.yaml` - Security scanner rules and exclusions

**Core Logic:**
- `os/Containerfile.microshift` - Container image definition (5 layers)
- `os/build.sh` - Container build orchestration
- `crates/bundle-cli/src/create.rs` - Bundle creation and checksumming
- `crates/bundle-cli/src/verify.rs` - Bundle integrity verification
- `crates/bundle-cli/src/manifest.rs` - Bundle schema and serialization

**Testing:**
- `crates/bundle-cli/tests/` - Integration tests (if present)
- `.github/actions/test-container/test-container.sh` - Container validation tests
- `os/scripts/health-check.sh` - Runtime health checks

## Naming Conventions

**Files:**
- Containerfile: Named `Containerfile.microshift` (not .dockerfile) to match rootless podman conventions
- Shell scripts: `*.sh` with kebab-case names (e.g., `health-check.sh`, `embed-microshift-images.sh`)
- Rust source: `*.rs` with snake_case module names (e.g., `verify.rs`, `manifest.rs`)
- Configuration: Descriptive names with extension (e.g., `edgeworks-images.txt`, `iso-config.toml`)
- Manifests: YAML files with descriptive names prefixed with order (e.g., `05-observability/`)
- GitHub Actions: Composite action directories use kebab-case (e.g., `build-container`, `test-container`)

**Directories:**
- Source code: `src/` (Rust convention)
- Tests: `tests/` (Rust convention)
- Configs: `configs/` (clear purpose)
- Manifests: `manifests/` (Kubernetes convention)
- Services: `systemd/` (systemd convention)
- Scripts: `scripts/` (utility scripts)
- Workflows: `.github/workflows/` (GitHub convention)
- Actions: `.github/actions/` (GitHub convention)
- Build artifacts: `.build/` (hidden from VCS via .gitignore)
- Planning: `.planning/` (hidden from VCS but tracked)

## Where to Add New Code

**New Feature:**
- OS-level feature: Add to `os/Containerfile.microshift` as new RUN layer or configuration file
- CLI feature: Add new module in `crates/bundle-cli/src/`, export from `main.rs`, wire subcommand
- Tests: Create alongside source (e.g., `#[cfg(test)] mod tests { ... }` in same file or `tests/*.rs`)

**New Component/Module:**
- Rust module: Create `src/new_module.rs`, declare as `mod new_module;` in `main.rs`
- Configuration: Add to `os/configs/` with descriptive name, COPY in Containerfile
- Systemd service: Add to `os/systemd/`, COPY in Containerfile, enable in Layer 5
- Manifest: Add YAML to `os/manifests/` or `os/manifests/manifests.d/`, will be copied to `/etc/microshift/manifests/`

**Utilities:**
- Shared CLI logic: Define structs/functions in appropriate `crates/bundle-cli/src/` module (e.g., `manifest.rs` for shared data structures)
- Shell utilities: Add to `os/scripts/` with descriptive name and shebang
- GitHub Actions: Add composite action to `.github/actions/` with `action.yml` metadata

## Special Directories

**`.build/`:**
- Purpose: Temporary build artifacts
- Generated: Yes (created by make targets)
- Committed: No (gitignored)
- Safe to delete: Yes (will be regenerated)

**`.github/`:**
- Purpose: GitHub Actions workflows and composite actions
- Generated: No (hand-written)
- Committed: Yes (essential for CI/CD)
- Structure: `workflows/` (main workflow definitions), `actions/` (reusable steps)

**`crates/`:**
- Purpose: Rust workspace (future: may contain multiple crates)
- Generated: No (hand-written source)
- Committed: Yes (source code)
- Buildable: `cargo build --release --manifest-path crates/bundle-cli/Cargo.toml`

**`.planning/`:**
- Purpose: Project planning, analysis, and documentation
- Generated: Partially (codebase analysis in `.planning/codebase/`)
- Committed: Yes (planning documents are valuable history)
- Key subdirectories: `codebase/` (ARCHITECTURE.md, STRUCTURE.md, etc.), `milestones/`, `phases/`

---

*Structure analysis: 2026-03-11*
