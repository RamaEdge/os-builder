# GitHub Workflows Documentation

This directory contains automated CI/CD workflows for building and testing K3s edge OS container images.

## 🔄 Available Workflows

- **🔧 K3s Builds**: Automated builds triggered on code changes (8-12 minutes)
- **🔒 Security Scanning**: Automated security vulnerability scanning

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

### 2. Security Scan Only - `security-scan.yaml`

**🔒 Standalone security scanning workflow**

- **Triggers**: Daily schedule, manual dispatch, workflow call
- **Duration**: ~5-10 minutes  
- **Outputs**: Security reports, SARIF files
- **Features**:
  - ✅ **Repository Scanning** - Source code security analysis
  - ✅ **Dependency Scanning** - Third-party package vulnerability detection
  - ✅ **SARIF Integration** - GitHub Security tab integration

## 🎯 Workflow Selection Guide

| Workflow | Primary Use | Trigger | Duration | Artifacts |
|----------|------------|---------|----------|-----------|
| Build and Security Scan | Production builds | Auto on push | 8-12 min | ISOs, Images, Reports |
| Security Scan | Security review | Daily/Manual | 5-10 min | Security Reports |

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

### Standardized Security Scanning Architecture

The repository now uses a **standardized security scanning approach** that eliminates duplication and ensures consistency across all workflows:

#### 🎯 **Centralized Configuration**
- **`.trivy.yaml`**: Single source of truth for all Trivy configurations
- **Standardized skip-dirs**: Consistent across all scan types and workflows
- **Unified severity levels**: CRITICAL, HIGH, MEDIUM by default
- **Performance settings**: Optimized timeout and cache settings

#### 🔧 **Reusable Actions**

**`.github/actions/trivy-scan/`**: Standardized Trivy scanning action
- **Supports all scan types**: `fs`, `config`, `secret`, `image`
- **Multiple output formats**: `sarif`, `table`, `json`
- **Consistent configuration**: Uses centralized `.trivy.yaml`
- **Container runtime agnostic**: Works with Docker and Podman

**Usage Example:**
```yaml
- name: Scan container image
  uses: ./.github/actions/trivy-scan
  with:
    scan-type: 'image'
    scan-ref: 'my-image:latest'
    output-format: 'sarif'
    severity: 'CRITICAL,HIGH'
```

#### 📋 **Workflow Integration**

**Security Scan Workflow (`.github/workflows/security-scan.yaml`)**:
- Filesystem scanning
- Configuration scanning  
- Secret detection
- Uploads results to GitHub Security tab

**Build & Security Scan Workflow**:
- Container image vulnerability scanning
- SBOM generation
- Integrated with build process

**Dependency Update Workflow**:
- Base image vulnerability scanning
- Automated security updates

### 🚀 **Benefits of Standardization**

1. **⚡ Reduced Duplication**: Single trivy-scan action used across all workflows
2. **🔧 Consistent Configuration**: All scans use same skip-dirs and settings
3. **📊 Better Maintainability**: Changes to scan settings in one place
4. **🎯 Improved Reliability**: Standardized error handling and output formats
5. **🔄 Easy Updates**: Update Trivy version in one place affects all workflows

### 🛠️ **Configuration Customization**

**Global Settings** (`.trivy.yaml`):
- Skip directories and files
- Scanner types and settings
- Performance configuration
- Secret scanning rules

**Per-Workflow Overrides**:
- Severity levels (via workflow inputs)
- Output formats (sarif, table, json)
- Container runtime settings (for image scans)

### 📈 **Security Metrics**

All security scans automatically:
- Generate SARIF files for GitHub Security tab
- Provide table output in workflow logs
- Upload results for centralized tracking
- Support both scheduled and on-demand execution
