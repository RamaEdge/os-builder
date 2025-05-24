# GitVersion Integration

This project uses [GitVersion](https://gitversion.net/) for automatic semantic versioning of container images based on Git history and branch strategy.

## Overview

GitVersion automatically calculates version numbers based on:
- Git tags
- Branch names
- Commit messages
- GitVersion configuration

## Configuration

The GitVersion configuration is defined in [`GitVersion.yml`](../GitVersion.yml):

```yaml
branches:
  main:
    regex: ^master$|^main$
    mode: ContinuousDelivery
    is-release-branch: true
    increment: Patch
    is-mainline: true
  feature:
    regex: ^features?[/-]
    mode: ContinuousDelivery
    tag: Beta
    is-release-branch: false
    increment: Inherit
    source-branches: ['main']
    is-mainline: false
  release:
    regex: ^releases?[/-]
    mode: ContinuousDelivery
    is-release-branch: true
    increment: None
    source-branches: ['main']
    tag: prod
    is-mainline: false
```

## Branch Strategy

### Main Branch (`main`)
- **Mode**: ContinuousDelivery
- **Increment**: Patch
- **Example**: `1.0.1`, `1.0.2`, `1.0.3`

### Feature Branches (`feature/*`)
- **Mode**: ContinuousDelivery
- **Tag**: Beta
- **Example**: `1.0.1-beta.1`, `1.0.1-beta.2`

### Release Branches (`release/*`)
- **Mode**: ContinuousDelivery
- **Tag**: prod
- **Increment**: None
- **Example**: `1.1.0-prod.1`, `1.1.0-prod.2`

## Commit Message Conventions

You can control version increments using commit message prefixes:

```bash
# Major version bump (breaking changes)
git commit -m "feat: new API +semver: major"

# Minor version bump (new features)
git commit -m "feat: add new feature +semver: minor"

# Patch version bump (bug fixes)
git commit -m "fix: resolve issue +semver: patch"
```

## Local Development

### Prerequisites

1. **Install .NET SDK**:
   ```bash
   # macOS
   brew install --cask dotnet
   
   # Fedora/RHEL
   sudo dnf install dotnet-sdk-8.0
   
   # Ubuntu/Debian
   wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
   sudo dpkg -i packages-microsoft-prod.deb
   sudo apt update && sudo apt install dotnet-sdk-8.0
   ```

2. **Install GitVersion Tool**:
   ```bash
   dotnet tool install --global GitVersion.Tool
   ```

### Usage

#### Interactive Demo
```bash
# Run the GitVersion demo script
../scripts/gitversion-demo.sh
```

#### Check Current Version
```bash
# Show all version information
make version

# Get semantic version only
dotnet gitversion -showvariable SemVer
```

#### Build with Automatic Versioning
```bash
# Build with GitVersion-calculated tag
make build

# Build with specific tag (overrides GitVersion)
make build IMAGE_TAG=v1.2.3
```

#### Manual Version Calculation
```bash
# Show all GitVersion variables
dotnet gitversion

# Show specific variable
dotnet gitversion -showvariable Major
dotnet gitversion -showvariable Minor
dotnet gitversion -showvariable Patch
dotnet gitversion -showvariable PreReleaseTag
```

## GitHub Actions Integration

The GitHub Actions workflow automatically uses GitVersion for:

1. **Version Calculation**: The `gitversion` job calculates version information
2. **Container Tagging**: Multiple tags are generated based on version:
   - Semantic version: `1.0.1`
   - Major.Minor: `1.0`
   - Major: `1`
   - Branch-based: `main-abc123-1234567890`
   - Latest (for main branch)

3. **Artifact Naming**: ISO builds and SBOMs include version in artifact names

## Container Image Labels

Built images include OCI-compliant labels with version information:

```bash
# Inspect image labels
docker inspect localhost/fedora-edge-os:1.0.1 | jq '.[0].Config.Labels'
```

Labels include:
- `org.opencontainers.image.version`: Semantic version
- `org.opencontainers.image.created`: Build timestamp
- `org.opencontainers.image.revision`: Git commit hash
- `org.opencontainers.image.source`: Repository URL
- `org.opencontainers.image.branch`: Git branch name

## Troubleshooting

### GitVersion Not Found
```bash
# Check if GitVersion is installed
dotnet tool list -g | grep gitversion

# Install if missing
dotnet tool install --global GitVersion.Tool
```

### Version Calculation Issues
```bash
# Ensure you're in a Git repository
git status

# Fetch all tags and history
git fetch --tags --unshallow

# Check GitVersion configuration
dotnet gitversion -diag
```

### Fallback Behavior

If GitVersion is not available, the build system falls back to:
1. `git describe --tags --always --dirty`
2. `latest` (if not in a Git repository)

## Examples

### Development Workflow
```bash
# Feature branch
git checkout -b feature/new-api
git commit -m "feat: add new API endpoint"
make build
# Builds: localhost/fedora-edge-os:1.0.1-beta.1

# Release branch
git checkout -b release/1.1.0
git commit -m "chore: prepare release 1.1.0"
make build
# Builds: localhost/fedora-edge-os:1.1.0-prod.1

# Main branch (after merge)
git checkout main
git merge release/1.1.0
git tag v1.1.0
make build
# Builds: localhost/fedora-edge-os:1.1.0
```

### CI/CD Integration
```bash
# Check version in CI
echo "Building version: $(dotnet gitversion -showvariable SemVer)"

# Build with version labels
make build IMAGE_NAME=ghcr.io/myorg/fedora-edge-os
```

## References

- [GitVersion Documentation](https://gitversion.net/)
- [Semantic Versioning](https://semver.org/)
- [OCI Image Spec - Annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md) 