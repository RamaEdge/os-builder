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
