# GitHub Actions Workflows

This directory contains GitHub Actions workflows for building, testing, and securing the Fedora bootc container image.

## 🚀 Workflows Overview

### 1. Build and Security Scan (`build-and-security-scan.yaml`)

**Main workflow for building and securing the container image.**

**Triggers:**
- Push to `main`, `develop`, or `add-initial-os-build` branches
- Pull requests to `main` or `develop`
- Weekly scheduled runs (Mondays at 2 AM UTC)
- Manual dispatch

**Features:**
- ✅ GitVersion-based semantic versioning
- ✅ Multi-platform container builds (AMD64/ARM64)
- ✅ Comprehensive Trivy security scanning
- ✅ SARIF upload to GitHub Advanced Security
- ✅ SBOM (Software Bill of Materials) generation
- ✅ Container image publishing to GitHub Container Registry
- ✅ Automated testing on pull requests

**Jobs:**
1. **GitVersion**: Determines semantic version
2. **Security Scan Files**: Scans filesystem and configuration files
3. **Build and Scan**: Builds container image and scans for vulnerabilities
4. **Test Container**: Runs functional tests on pull requests
5. **Security Summary**: Generates comprehensive security report

### 2. Security Scan (`security-scan.yaml`)

**Dedicated security scanning workflow for continuous monitoring.**

**Triggers:**
- Push to `main` or `develop` branches
- Daily scheduled runs (3 AM UTC)
- Manual dispatch with customizable options

**Features:**
- ✅ Filesystem vulnerability scanning
- ✅ Configuration security analysis
- ✅ Container image vulnerability assessment
- ✅ Trivy database caching for performance
- ✅ Multiple output formats (SARIF, JSON, Table)
- ✅ Customizable severity levels
- ✅ Detailed security reporting

**Manual Options:**
- Scan type: all, filesystem, config, container
- Severity level: CRITICAL, HIGH, MEDIUM, LOW

### 3. Dependency Security Monitoring (`dependency-update.yaml`)

**Weekly security review of dependencies and base images.**

**Triggers:**
- Weekly scheduled runs (Mondays at 6 AM UTC)
- Manual dispatch
- Changes to Containerfile or Dependabot config

**Features:**
- ✅ Base image vulnerability scanning
- ✅ Package analysis and inventory
- ✅ Security advisory generation
- ✅ Automated reporting

## 🔒 Security Integration

### GitHub Advanced Security Integration

All workflows upload security scan results to GitHub Advanced Security:

- **SARIF Format**: Compatible with GitHub Security tab
- **Multiple Categories**: 
  - `filesystem-scan`: File and dependency vulnerabilities
  - `configuration-scan`: Infrastructure as Code security issues
  - `container-image-scan`: Container vulnerabilities
  - `base-image-scan`: Base image vulnerabilities

### Viewing Security Results

1. **GitHub Security Tab**: Main dashboard for all security findings
2. **Workflow Summaries**: Quick overview in Actions tab
3. **Artifacts**: Detailed reports downloadable from workflow runs
4. **Pull Request Comments**: Security findings on PRs

## 📊 Artifacts Generated

### Security Artifacts
- `trivy-fs-results.sarif` - Filesystem scan results
- `trivy-config-results.sarif` - Configuration scan results
- `trivy-image-results.sarif` - Container image scan results
- `trivy-*-report.json` - Detailed JSON reports
- `security-report.md` - Human-readable security summary

### Build Artifacts
- `sbom.spdx.json` - Software Bill of Materials
- `package-analysis` - Installed package inventory
- `security-advisory.md` - Weekly security review

## 🛠️ Manual Workflow Execution

### Trigger Security Scan

```bash
# Via GitHub CLI
gh workflow run security-scan.yaml

# With custom options
gh workflow run security-scan.yaml \
  -f scan_type=container \
  -f severity=CRITICAL
```

### Trigger Build and Scan

```bash
gh workflow run build-and-security-scan.yaml
```

### View Workflow Status

```bash
# List workflow runs
gh run list

# View specific run
gh run view <run-id>

# Download artifacts
gh run download <run-id>
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `IMAGE_NAME` | Container image name | `fedora-edge-os` |
| `REGISTRY` | Container registry | `ghcr.io` |
| `WORKING_PATH` | Build context path | `./os` |

### Required Permissions

Workflows require the following GitHub token permissions:

- `contents: read` - Repository access
- `packages: write` - Container registry push
- `security-events: write` - SARIF upload
- `actions: read` - Workflow artifacts access

### Repository Settings

Enable the following in repository settings:

1. **GitHub Actions**: Allow workflows to run
2. **Advanced Security**: Enable for SARIF uploads
3. **Container Registry**: Enable GitHub Packages
4. **Dependabot**: Enable for automated updates

## 📅 Schedule Overview

| Workflow | Schedule | Purpose |
|----------|----------|---------|
| Build & Security Scan | Weekly (Mon 2 AM) | CI/CD pipeline with security |
| Security Scan | Daily (3 AM) | Continuous monitoring |
| Dependency Monitoring | Weekly (Mon 6 AM) | Dependency security review |
| Dependabot | Weekly (Various days) | Automated dependency updates |

## 🚨 Security Best Practices

### Immediate Action Required

When security issues are found:

1. **Critical/High Vulnerabilities**: Address within 24-48 hours
2. **Medium Vulnerabilities**: Address within 1 week
3. **Low Vulnerabilities**: Address in next planned maintenance

### Security Workflow

1. **Detection**: Automated scans identify vulnerabilities
2. **Notification**: Results appear in Security tab and workflow summaries
3. **Triage**: Review findings and prioritize based on severity
4. **Remediation**: Update dependencies, packages, or configurations
5. **Verification**: Re-run scans to confirm fixes

### Monitoring

- **Security Tab**: Weekly review of all findings
- **Workflow Alerts**: Subscribe to workflow failure notifications
- **Dependabot PRs**: Review and merge dependency updates promptly
- **Security Advisories**: Monitor upstream security notifications

## 🔗 Related Documentation

- [GitHub Advanced Security](https://docs.github.com/en/code-security)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [SARIF Format](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)
- [Container Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [Dependabot Configuration](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file) 