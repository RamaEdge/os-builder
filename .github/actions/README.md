# GitHub Actions

This directory contains reusable GitHub Actions for the OS Builder project.

## Available Actions

### 🏷️ calculate-version

**Purpose**: Calculate semantic version based on Git history and branch information.

**Usage**:

```yaml
- name: Calculate version
  id: version
  uses: ./.github/actions/calculate-version
```

**Outputs**:

- `version`: Calculated semantic version
- `branch`: Current branch name
- `sha`: Short commit SHA
- `repository-owner`: Repository owner in lowercase

**Version Strategy**:

- **Main Branch**: `1.2.3` (release) or `1.2.3-dev.5+abc1234` (pre-release)
- **Release Branch**: `1.3.0-rc.2+abc1234` (release candidate)
- **Pull Request**: `1.2.3-pr.42.feature-branch` (clean PR version)
- **Feature Branch**: `1.2.3-feature-branch.3+abc1234` (feature version)

### 📦 build-container

**Purpose**: Build container image with Podman and proper OCI labeling.

**Usage**:

```yaml
- name: Build container image
  id: build
  uses: ./.github/actions/build-container
  with:
    containerfile: 'Containerfile.k3s'
    image-name: 'my-app'
    version: ${{ steps.version.outputs.version }}
    sha: ${{ steps.version.outputs.sha }}
    registry: 'ghcr.io'
    repository-owner: 'myorg'
    working-path: './os'
    microshift-version: 'release-4.19'  # optional
```

**Inputs**:

- `containerfile` (required): Path to Containerfile
- `image-name` (required): Container image name
- `version` (required): Version tag for the image
- `sha` (required): Git commit SHA
- `registry` (required): Container registry
- `repository-owner` (required): Repository owner
- `working-path` (optional): Working directory (default: `./os`)
- `microshift-version` (optional): MicroShift version for MicroShift builds

**Outputs**:

- `image-id`: Built image ID
- `local-tag`: Local image tag
- `version-tag`: Version tag

**Features**:

- Builds versioned and latest tags
- OCI-compliant labels
- Supports K3s and MicroShift builds
- Podman-based building
- Optimized for caching (no BUILD_DATE)

### 🛡️ trivy-scan (Unified Security Scanning)

**Purpose**: Comprehensive security scanning for all types - filesystem, config, secrets, and container images.

**Usage**:

```yaml
# Container scanning with SBOM generation
- name: Container security scan
  uses: ./.github/actions/trivy-scan
  with:
    scan-type: 'container'
    scan-ref: 'myregistry/myimage:latest'
    severity: 'CRITICAL,HIGH'
    generate-sbom: 'true'
    upload-sarif: 'true'
    sarif-category: 'trivy-container'

# Filesystem scanning
- name: Source code scan
  uses: ./.github/actions/trivy-scan
  with:
    scan-type: 'fs'
    scan-ref: '.'
    upload-sarif: 'true'
    sarif-category: 'trivy-filesystem'
```

**Supported Scan Types**:

- `fs` - Filesystem scanning (source code, dependencies)
- `config` - Configuration files (Dockerfile, YAML, etc.)
- `secret` - Secret detection (API keys, tokens)
- `image` - Direct container image scanning
- `container` - **NEW**: Container image with automatic tar export

**Key Inputs**:

- `scan-type` (required): Type of scan to perform
- `scan-ref` (required): Target to scan (path, image reference, etc.)
- `severity` (optional): Vulnerability levels (default: `CRITICAL,HIGH`)
- `generate-sbom` (optional): Generate SBOM for containers (default: `false`)
- `upload-sarif` (optional): Upload to GitHub Security tab (default: `false`)
- `sarif-category` (optional): Category for GitHub Security organization

**Features**:

- **All-in-one solution**: Replaces separate security-scan action
- **Automatic container handling**: Tar export, scanning, and cleanup
- **SBOM generation**: Software Bill of Materials for containers
- **SARIF integration**: Direct upload to GitHub Security tab
- **Runtime detection**: Auto-detects podman/docker
- **Smart cleanup**: Automatic temp file removal

### 🧪 test-container

**Purpose**: Comprehensive testing of built container images for K3s, MicroShift, and bootc functionality.

**Usage**:

```yaml
# K3s container testing
- name: Test K3s container
  uses: ./.github/actions/test-container
  with:
    image-ref: 'myregistry/k3s-image:latest'
    test-type: 'k3s'
    parallel: 'true'

# MicroShift container testing
- name: Test MicroShift container
  uses: ./.github/actions/test-container
  with:
    image-ref: 'myregistry/microshift-image:latest'
    test-type: 'microshift'
    parallel: 'false'
```

**Supported Test Types**:

- `k3s` - K3s-specific tests (binary, kubectl, otelcol, manifests)
- `microshift` - MicroShift-specific tests (binary, kubectl, observability)
- `bootc` - Base bootc tests only (bootc status, systemd)

**Key Inputs**:

- `image-ref` (required): Container image reference to test
- `test-type` (required): Type of tests to run
- `parallel` (optional): Run tests in parallel (default: `true`)

**Outputs**:

- `test-results`: Summary of test results (total, passed, failed)

**Features**:

- **Runtime detection**: Auto-detects podman/docker
- **Parallel execution**: Optional parallel test runs for speed
- **Comprehensive testing**: Binary checks, manifest validation, status verification
- **Detailed reporting**: Test summaries and failure tracking
- **Non-blocking**: Reports failures but continues workflow

### 📀 build-iso

**Purpose**: Build bootable ISO images from container images using bootc-image-builder.

**Usage**:

```yaml
# Basic ISO build
- name: Build ISO
  uses: ./.github/actions/build-iso
  with:
    image-ref: 'myregistry/myimage:latest'
    config: 'user'
    output-dir: 'iso-output'

# Custom configuration ISO build
- name: Build custom ISO
  uses: ./.github/actions/build-iso
  with:
    image-ref: 'myregistry/myimage:latest'
    config-file: 'custom-config.toml'
    output-dir: 'custom-iso'
    working-path: './os'
```

**Supported Configurations**:

- `minimal` - Minimal ISO configuration
- `user` - Standard user configuration (default)
- `advanced` - Advanced configuration with extra features
- `interactive` - Interactive installation ISO
- `production` - Production-ready configuration

**Key Inputs**:

- `image-ref` (required): Container image reference to build ISO from
- `config` (optional): ISO configuration type (default: `user`)
- `config-file` (optional): Custom path to configuration TOML file
- `output-dir` (optional): Output directory for ISO files (default: `iso-output`)
- `working-path` (optional): Working directory containing config-examples (default: `./os`)

**Outputs**:

- `iso-path`: Path to generated ISO file
- `iso-size`: Size of generated ISO file
- `config-used`: Configuration file used for build

**Features**:

- **Runtime detection**: Auto-detects podman/docker for building
- **Configuration validation**: Verifies config files exist before building
- **Automatic setup**: Creates output directories and validates environment
- **Local image support**: Handles local and registry images
- **Detailed reporting**: ISO size, location, and build configuration

## Workflow Integration

### K3s Build Workflow (`build-and-security-scan.yaml`)

- **Action-based**: Uses calculate-version, build-container, trivy-scan, test-container, and build-iso actions
- **Parallel execution**: Build, security scan, and test jobs run independently
- **Automated**: Triggers on push, PR, and schedule
- **Efficient**: Matrix ISO builds only for dispatch, single "user" config for regular builds
- **Smart testing**: Container testing only for PRs using test-container action

### MicroShift Build Workflow (`build-microshift.yaml`)

- **Streamlined**: Uses all reusable actions for consistency
- **Action-powered**: build-container, trivy-scan, test-container, and build-iso
- **Manual**: Workflow dispatch only with default MicroShift version
- **Simplified**: No complex version mapping, direct user input

### Security Scan Workflow (`security-scan.yaml`)

- **Matrix-based**: Single job handles all scan types using trivy-scan action
- **Consolidated**: Parallel execution with shared patterns
- **Unified**: Single trivy-scan action for all security scanning needs

### Dependency Update Workflow (`dependency-update.yaml`)

- **Matrix strategy**: Single job handles both K3s and OTEL version checks
- **Automated PRs**: GitHub CLI-based PR creation
- **Consolidated**: Shared logic for version checking and updates

## Design Benefits

### 🚀 Performance

- **Reduced complexity**: 80-90% fewer lines in workflows
- **Faster execution**: Consolidated jobs and streamlined processes
- **Better caching**: Removed BUILD_DATE and optimized layers
- **Parallel testing**: Optional parallel test execution for speed
- **Efficient ISO building**: Streamlined bootc-image-builder usage

### 🔧 Maintainability

- **Single source of truth**: Centralized action logic for all major operations
- **Matrix strategies**: Reduced code duplication across workflows
- **Simplified patterns**: Consistent structure across all workflows
- **Reusable components**: test-container and build-iso actions eliminate duplication
- **Unified interfaces**: Consistent input/output patterns across actions

### 📊 Standardization

- **Consistent versioning**: Unified version calculation
- **Standardized scanning**: Single trivy-scan action for all security needs
- **Uniform labeling**: OCI-compliant container labels
- **Standard testing**: Consistent test patterns across K3s and MicroShift
- **Unified ISO building**: Same action for all configuration types

## Migration Benefits

The comprehensive action-based approach provides:

1. **Dramatic Simplification**: 80-90% reduction in workflow complexity
2. **Better Performance**: Faster builds, parallel testing, and reduced resource usage
3. **Easier Maintenance**: Centralized logic in 5 reusable actions
4. **Matrix Efficiency**: Single jobs handle multiple configurations
5. **Streamlined Testing**: Unified test-container action with parallel execution
6. **Consistent ISO Building**: Single build-iso action for all configurations
7. **Complete Coverage**: All major operations (version, build, scan, test, ISO) in actions
8. **Better Error Handling**: Comprehensive validation and detailed reporting 