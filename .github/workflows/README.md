# GitHub Workflows Documentation

This directory contains automated CI/CD workflows for building and testing K3s edge OS container images.

## 🔄 Available Workflows

- **🔧 K3s Builds**: Automated builds with integrated security scanning (8-12 minutes)
- **🏗️ MicroShift Builds**: MicroShift container builds (manual trigger)

## 📋 Workflow Details

### 1. Build and Security Scan - `build-and-security-scan.yaml`

**🚀 Primary K3s workflow with automated triggers**

- **Triggers**: Push to `main`, pull requests, manual dispatch
- **Duration**: ~8-12 minutes (optimized with layer caching)
- **Outputs**: Container images, ISOs, security reports
- **Features**:
  - ✅ **Version Auto-Detection** - Semantic versioning with git tags
  - ✅ **Fast Builds**: 8-12 minutes using optimized layer caching
  - ✅ **Multi-Config ISO Generation** - Builds ISOs for different use cases
  - ✅ **Security Scanning** - Trivy vulnerability scanning with SARIF reports
  - ✅ **Artifact Management** - Automatic artifact uploads with retention

### 2. MicroShift Build - `build-microshift.yaml`

**🏗️ MicroShift container build workflow**

- **Triggers**: Manual dispatch only
- **Duration**: ~10-15 minutes  
- **Outputs**: MicroShift container images, ISOs, security reports
- **Features**:
  - ✅ **MicroShift Integration** - OpenShift-compatible edge platform
  - ✅ **Security Scanning** - Integrated Trivy vulnerability scanning
  - ✅ **ISO Generation** - Bootable MicroShift ISOs

## 🎯 Workflow Selection Guide

| Workflow | Primary Use | Trigger | Duration | Artifacts |
|----------|------------|---------|----------|-----------|
| Build and Security Scan | K3s production builds | Auto on push, Daily | 8-12 min | ISOs, Images, Reports |
| MicroShift Build | MicroShift builds | Manual only | 10-15 min | ISOs, Images, Reports |

## 🏗️ Build Matrix

The main workflow builds multiple ISO configurations:

| Configuration | Description | Use Case |
|--------------|-------------|----------|
| `minimal` | Basic edge OS | Resource-constrained environments |
| `user` | Pre-configured user setup | Quick deployment with user accounts |
| `advanced` | Enhanced features | Full-featured edge deployments |
| `interactive` | Interactive installation | Custom setup requirements |

## 📊 Artifact Outputs

All workflows generate structured artifacts:

### K3s Build Artifacts

- `k3s-edge-os-iso-[config]-v[version]` - K3s bootable ISOs
- `sbom-k3s-[sha]` - Software Bill of Materials
- `security-scan-report-[sha]` - Vulnerability scan results

## 🚀 Quick Start

### Use K3s Build When:

- 🎯 Building for production edge deployments
- ⚡ Need fast, automated builds
- 🔧 Want lightweight Kubernetes distribution

### Trigger K3s Build

```bash
# Automatic trigger (recommended)
git push origin main

# Manual trigger
gh workflow run build-and-security-scan.yaml

# With custom image name
gh workflow run build-and-security-scan.yaml \
  -f image_name=my-custom-edge-os
```

## ⚙️ Environment Variables

Common environment variables used across workflows:

| Variable | Description | Default | Used In |
|----------|-------------|---------|---------|
| `IMAGE_NAME` | K3s container image name | `ramaedge-os-k3s` | K3s workflow |
| `REGISTRY` | Container registry URL | `ghcr.io` | All workflows |
| `REPO_OWNER` | Repository owner for tagging | `ramaedge` | All workflows |

## 🔐 Required Permissions

Workflows require the following GitHub token permissions:

- `contents: read` - Repository access
- `packages: write` - Container registry push (K3s workflow)
- `security-events: write` - Security scan uploads

## 🛠️ Workflow Configuration

### Build Environment

- **Runner**: `ubuntu-22.04` (GitHub-hosted)
- **Container Runtime**: Podman (Linux optimized)
- **Storage**: Container layer caching enabled
- **Memory**: 8GB RAM minimum
- **Disk**: 20GB available space

### Performance Optimizations

- **Layer Caching**: Significantly reduces build times
- **Parallel Builds**: ISO configs built concurrently
- **Optimized Base Images**: Pre-cached Fedora bootc images

## 📈 Build Times

| Build Type | Typical Duration | Factors |
|------------|------------------|---------|
| K3s Build | 8-12 min | Layer caching, base image availability |
| Security Scan | 5-10 min | Repository size, dependency count |

## 🚨 Troubleshooting

### Common Issues

1. **Build timeout**: Check if base images are accessible
2. **Cache miss**: First builds take longer, subsequent builds are faster
3. **Storage space**: Ensure runner has sufficient disk space

### Debugging

```bash
# Check workflow status
gh workflow list

# View workflow run details
gh run view <run-id>

# Download build artifacts
gh run download <run-id>
```

## 📚 Related Documentation

- **Container Building**: See [../actions/README.md](../actions/README.md) for common action documentation
- **ISO Building**: See [../../docs/ISO_BUILDING.md](../../docs/ISO_BUILDING.md) for ISO configuration details
- **K3s Documentation**: [K3s Official Docs](https://k3s.io/) 

## 🔒 Security Scanning

### Simplified Container-Focused Security Scanning

The repository uses a **streamlined security scanning approach** focused on container vulnerability detection:

#### 🎯 **Container-Only Approach**

- **`.trivy.yaml`**: Optimized configuration for container vulnerability scanning
- **Tar Export Method**: Consistent scanning via exported container images
- **Vulnerability Focus**: Only vulnerability scanning - no secrets or misconfiguration
- **Performance Optimized**: 30-minute timeout for large container images

#### 🔧 **Unified Scanning Action**

**`.github/actions/trivy-scan/`**: Container-focused Trivy scanning action

- **Container vulnerability scanning**: Exports image to tar for consistent results
- **Multiple output formats**: `sarif`, `table`, `json`
- **Container runtime agnostic**: Auto-detects podman/docker
- **Automated cleanup**: Temporary tar files automatically removed

**Usage Example:**

```yaml
- name: Scan container image
  uses: ./.github/actions/trivy-scan
  with:
    scan-ref: 'my-image:latest'
    output-format: 'sarif'
    severity: 'CRITICAL,HIGH'
    upload-sarif: 'true'
```

#### 📋 **Integrated Workflow Scanning**

**Build & Security Scan Workflows**:

- **Container vulnerability scanning** - Integrated into all build workflows
- **Daily security monitoring** - Automated via scheduled builds
- **SBOM generation** - Software Bill of Materials for container images
- **SARIF integration** - Results uploaded to GitHub Security tab

**No Separate Security Workflow**:

- **Integrated approach** - Security scanning built into build workflows
- **Efficient scanning** - No duplication, scans happen during builds
- **Consistent methodology** - Same tar export approach everywhere

### 🚀 **Benefits of Simplification**

1. **⚡ Reduced Complexity**: Single scan type focused on containers
2. **🔧 Consistent Results**: Tar export ensures reproducible scans
3. **📊 Better Performance**: No secret scanning timeouts or false positives
4. **🎯 Container Focus**: Scanning what actually gets deployed
5. **🔄 Simplified Maintenance**: Single scanning configuration and approach

### 🛠️ **Configuration**

**Trivy Configuration** (`.trivy.yaml`):

- Vulnerability scanning only (`TRIVY_SCANNERS=vuln`)
- Container-optimized skip patterns
- 30-minute timeout for large images
- CRITICAL, HIGH, MEDIUM severity levels

**Environment Variables**:

- `TRIVY_SCANNERS=vuln` - Ensures only vulnerability scanning
- `TRIVY_CLOUD_DISABLE=true` - Disables cloud provider scanning
- `TRIVY_SKIP_CHECK_UPDATE=true` - Skips update checks for speed

### 📈 **Security Coverage**

Container vulnerability scanning covers:

- **OS packages** - Base image vulnerabilities
- **Application dependencies** - Language-specific package vulnerabilities  
- **Container layers** - All filesystem content security issues
- **SARIF reporting** - GitHub Security tab integration for tracking
