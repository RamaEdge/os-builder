# GitHub Actions Workflows

## Build MicroShift OS (`build-microshift.yaml`)

Main CI/CD pipeline for building, testing, and publishing the edge OS.

**Triggers:**
- Push to `main` with changes to `os/**`
- Pull requests to `main` with changes to `os/**`
- Weekly schedule (Fridays at 1 AM UTC)
- Manual dispatch (with optional ISO build toggle)

**Jobs:**

1. **build-scan-test** - Build container image, Trivy security scan, container tests, push to Harbor
2. **build-iso** - Build bootable ISO (on schedule or manual trigger)

**Required Secrets:**
- `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` - Harbor registry credentials

**Required Permissions:**
- `contents: read`
- `packages: write`
- `security-events: write`

## Running Manually

```bash
# Trigger build
gh workflow run build-microshift.yaml

# Trigger build with ISO
gh workflow run build-microshift.yaml -f build_iso=true

# Check status
gh run list --workflow=build-microshift.yaml
```
