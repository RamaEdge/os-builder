# Version Management

This repository uses a centralized version management system to ensure consistency across all build environments (Makefile, GitHub Actions, etc.).

## Version Configuration File

The `versions.txt` file contains all version definitions used throughout the project:

```bash
# K3s version - Kubernetes distribution
K3S_VERSION=v1.33.1+k3s1

# OpenTelemetry Collector version
OTEL_VERSION=0.127.0

# MicroShift version (Red Hat's Kubernetes distribution)
MICROSHIFT_VERSION=release-4.19

# Container image versions
FEDORA_VERSION=42
BOOTC_VERSION=42
```

## Usage

### Makefile

The Makefile automatically loads versions from `versions.txt`:

```bash
# Build with centralized versions
make build

# Override versions via environment variables
K3S_VERSION=v1.33.2+k3s1 make build

# View current versions
make help
```

### GitHub Actions

Workflows use the `load-versions` action to access centralized versions:

```yaml
- name: Load version configuration
  id: versions
  uses: ./.github/actions/load-versions

- name: Build container image
  uses: ./.github/actions/build-container
  with:
    k3s-version: ${{ steps.versions.outputs.k3s-version }}
    otel-version: ${{ steps.versions.outputs.otel-version }}
    # ... other inputs
```

### Container Builds

Versions are passed as build arguments to container builds:

```dockerfile
ARG K3S_VERSION
ARG OTEL_VERSION
ARG MICROSHIFT_VERSION
ARG FEDORA_VERSION

# Use in Containerfile
RUN curl -L https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s > /usr/local/bin/k3s
```

## Updating Versions

To update versions:

1. **Edit `versions.txt`** - Update version numbers
2. **Commit changes** - Create a PR with version updates
3. **Test builds** - Ensure all builds work with new versions
4. **Deploy** - Merge to trigger automated builds

## Benefits

- **Consistency**: Single source of truth for all versions
- **Maintainability**: Easy to update versions across all build systems
- **Traceability**: Clear history of version changes
- **Flexibility**: Can override versions per build if needed
- **Automation**: GitHub Actions automatically use latest versions
- **Dependency Monitoring**: Automated checks and PRs for version updates
- **Security**: Automated vulnerability scanning of version updates

## File Structure

```
├── versions.txt                           # Central version definitions
├── Makefile                              # Loads versions.txt
├── .github/
│   ├── dependabot.yml                   # Dependabot configuration
│   ├── actions/
│   │   ├── load-versions/               # Action to load versions
│   │   ├── update-version/              # Action to update versions
│   │   └── build-container/             # Updated to accept version inputs
│   └── workflows/
│       ├── build-and-security-scan.yaml # Uses centralized versions
│       ├── build-microshift.yaml       # Uses centralized versions
│       └── dependency-update.yaml      # Automated version monitoring
└── os/
    ├── Containerfile.k3s                # Uses version build args
    └── Containerfile.fedora.optimized   # Uses version build args
```

## Version Override Priority

1. **Environment variables** (highest priority)
2. **Makefile defaults** from `versions.txt`
3. **GitHub Action inputs** 
4. **Workflow dispatch inputs**
5. **versions.txt values** (fallback)

This ensures flexibility while maintaining consistency.

## Automated Dependency Management

### Weekly Dependency Updates

The `dependency-update.yaml` workflow runs weekly and:

- **Checks for updates** to K3s, OpenTelemetry, MicroShift, and Fedora
- **Creates pull requests** automatically for version updates
- **Includes security scanning** of new versions
- **Provides detailed release information** and impact analysis

### Dependabot Integration

Dependabot monitors and updates:

- **GitHub Actions** versions in workflows
- **Container base images** (excluding centrally managed versions)
- **Python dependencies** in build scripts

### Manual Version Updates

You can also trigger updates manually:

```bash
# Run dependency check for specific components
gh workflow run dependency-update.yaml \
  -f components="k3s,otel" \
  -f force_update=false

# Force update (create PRs even if no new versions)
gh workflow run dependency-update.yaml \
  -f force_update=true
```

### Security Monitoring

- **Base image scanning** with Trivy
- **Vulnerability tracking** in GitHub Security tab
- **Automated SARIF upload** for security findings
- **Weekly security summaries** as artifacts

This comprehensive approach ensures your container OS images stay secure and up-to-date with minimal manual intervention. 