# Common GitHub Actions

This directory contains reusable GitHub Actions for the OS Builder project.

## Available Actions

### 🏷️ calculate-version

**Purpose**: Calculate semantic version based on Git history and branch information.

**Usage**:
```yaml
- name: Calculate Version
  id: version
  uses: ./.github/actions/calculate-version
```

**Outputs**:
- `version`: Calculated semantic version
- `branch`: Current branch name
- `sha`: Short commit SHA
- `repository-owner`: Repository owner in lowercase

**Version Strategy**:
- **Main Branch**: 
  - At tag: Uses tag version (e.g., `1.2.3`)
  - Ahead of tag: Pre-release version (e.g., `1.2.3-dev.5+abc1234`)
- **Release Branch**: Release candidate (e.g., `1.3.0-rc.2+abc1234`)
- **Pull Request**: Clean PR version (e.g., `1.2.3-pr.42.feature-branch`)
- **Feature Branch**: Feature version (e.g., `1.2.3-feature-branch.3+abc1234`)

### 📦 build-container

**Purpose**: Build container image with Podman and proper OCI labeling.

**Usage**:
```yaml
- name: Build Container Image
  id: build
  uses: ./.github/actions/build-container
  with:
    containerfile: 'Containerfile.k3s'
    image-name: 'my-app'
    version: ${{ steps.version.outputs.version }}
    sha: ${{ steps.version.outputs.sha }}
    registry: 'ghcr.io'
    repository-owner: 'myorg'
    working-path: './os'  # optional
    microshift-version: 'main-abc1234'  # optional, for MicroShift builds
```

**Inputs**:
- `containerfile` (required): Path to Containerfile
- `image-name` (required): Container image name
- `version` (required): Version tag for the image
- `sha` (required): Git commit SHA
- `registry` (required): Container registry
- `repository-owner` (required): Repository owner
- `working-path` (optional): Working directory for build (default: `./os`)
- `microshift-version` (optional): MicroShift version for MicroShift builds

**Outputs**:
- `image-id`: Built image ID
- `local-tag`: Local image tag
- `version-tag`: Version tag

**Features**:
- Builds with both versioned and latest tags
- Adds OCI-compliant labels
- Supports both K3s and MicroShift builds
- Uses Podman for container building
- Passes build metadata as build arguments (VCS_REF, VERSION) - BUILD_DATE removed for better caching
- Automatically handles MicroShift build arguments when needed
- Installs OpenTelemetry Collector via official RPM packages for better integration

### 🛡️ security-scan

**Purpose**: Run comprehensive security scans on container images.

**Usage**:
```yaml
- name: Security Scan
  uses: ./.github/actions/security-scan
  with:
    image-ref: ${{ steps.build.outputs.local-tag }}
    severity: 'CRITICAL,HIGH'  # optional
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

**Features**:
- Trivy vulnerability scanning (SARIF and table formats)
- SBOM (Software Bill of Materials) generation
- Artifact upload for SBOM files
- Podman runtime support

## Design Benefits

### 🔄 Reusability
- Actions can be used across multiple workflows
- Consistent implementation across different build types
- Reduces code duplication

### 🧪 Testability
- Actions can be tested independently
- Clear input/output interfaces
- Modular design

### 🛠️ Maintainability
- Single source of truth for common functionality
- Easy to update and improve
- Version tracking for action changes

### 📊 Standardization
- Consistent versioning strategy
- Standardized security scanning
- Uniform container labeling

## Workflow Integration

### Main K3s Workflow (`build-and-security-scan.yaml`)
- Uses all three actions
- Focuses on K3s builds only
- Automatic triggers (push, PR, schedule)

### MicroShift Workflow (`build-microshift.yaml`)
- Uses all three actions
- Manual trigger only (`workflow_dispatch`)
- MicroShift-specific logic and version mapping

### Security Workflow (`security-scan.yaml`)
- Independent repository security scanning
- Filesystem, configuration, and secret scans
- Complementary to container scanning in build workflows

## Migration Benefits

Moving from monolithic workflows to action-based approach provides:

1. **Separation of Concerns**: K3s and MicroShift builds are now separate
2. **Reduced Complexity**: Each workflow focuses on one distribution
3. **Improved Maintenance**: Common logic centralized in actions
4. **Better Testing**: Actions can be tested independently
5. **Flexible Deployment**: Manual MicroShift builds vs automatic K3s builds 