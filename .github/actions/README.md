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

### 🛡️ security-scan

**Purpose**: Run comprehensive security scans on container images via tar export.

**Usage**:
```yaml
- name: Security scan
  uses: ./.github/actions/security-scan
  with:
    image-ref: ${{ steps.build.outputs.local-tag }}
    severity: 'CRITICAL,HIGH'
    build-mode: 'k3s'
    sha: ${{ steps.version.outputs.sha }}
```

**Inputs**:
- `image-ref` (required): Container image reference to scan
- `severity` (optional): Scan severity level (default: `CRITICAL,HIGH`)
- `build-mode` (required): Build mode for artifact naming
- `sha` (required): Git commit SHA

**Outputs**:
- `sbom-artifact`: SBOM artifact name
- `tar-file`: Exported tar file path

**Features**:
- **Tar-based scanning**: Exports container images to tar files before scanning for better reproducibility
- **Trivy vulnerability scanning**: SARIF and table formats for comprehensive reporting
- **SBOM generation**: Software Bill of Materials with Anchore Syft
- **Automatic cleanup**: Removes tar files after scanning to save disk space
- **Optional archival**: Can optionally upload tar files as artifacts (disabled by default)
- **Multi-runtime support**: Works with both Podman and Docker

**Scanning Process**:
1. Detects available container runtime (Podman preferred, Docker fallback)
2. Exports container image to tar file with clean filename
3. Runs Trivy scans on tar file (SARIF + table output)
4. Generates SBOM from tar file
5. Uploads SBOM artifact
6. Cleans up tar file to save space

### 🔍 trivy-scan

**Purpose**: Standardized Trivy security scanning for multiple scan types and tar files.

**Usage**:
```yaml
- name: Run Trivy scan
  uses: ./.github/actions/trivy-scan
  with:
    scan-type: 'image'
    scan-ref: 'container-image.tar'
    output-format: 'sarif'
    severity: 'CRITICAL,HIGH'
```

**Features**:
- Supports filesystem, configuration, secret, and image scans
- **Enhanced tar support**: Optimized for scanning exported container tar files
- Multiple output formats (SARIF, table, JSON)
- **Runtime-agnostic**: Works without container runtime dependencies for tar files
- Used by both security-scan action and security workflows

## Workflow Integration

### K3s Build Workflow (`build-and-security-scan.yaml`)
- **Simplified**: Single job with embedded version calculation
- **Automated**: Triggers on push, PR, and schedule
- **Efficient**: Matrix ISO builds only for dispatch, single "user" config for regular builds
- **Testing**: Container testing only for PRs

### MicroShift Build Workflow (`build-microshift.yaml`)
- **Streamlined**: Two jobs (build-and-scan, build-iso)
- **Manual**: Workflow dispatch only with default MicroShift version
- **Simplified**: No complex version mapping, direct user input

### Security Scan Workflow (`security-scan.yaml`)
- **Matrix-based**: Single job handles all scan types (filesystem, config, secrets)
- **Consolidated**: Parallel execution with shared patterns
- **Efficient**: Streamlined summary generation

### Dependency Update Workflow (`dependency-update.yaml`)
- **Matrix strategy**: Single job handles both K3s and OTEL version checks
- **Automated PRs**: GitHub CLI-based PR creation
- **Consolidated**: Shared logic for version checking and updates

## Design Benefits

### 🚀 Performance
- **Reduced complexity**: 70-80% fewer lines in workflows
- **Faster execution**: Consolidated jobs and streamlined processes
- **Better caching**: Removed BUILD_DATE and optimized layers

### 🔧 Maintainability
- **Single source of truth**: Centralized action logic
- **Matrix strategies**: Reduced code duplication
- **Simplified patterns**: Consistent structure across workflows

### 📊 Standardization
- **Consistent versioning**: Unified version calculation
- **Standardized scanning**: Shared security scan patterns
- **Uniform labeling**: OCI-compliant container labels

## Migration Benefits

The simplified action-based approach provides:

1. **Dramatic Simplification**: 70-80% reduction in workflow complexity
2. **Better Performance**: Faster builds and reduced resource usage
3. **Easier Maintenance**: Centralized logic in reusable actions
4. **Matrix Efficiency**: Single jobs handle multiple configurations
5. **Streamlined Testing**: Focused testing only where needed 