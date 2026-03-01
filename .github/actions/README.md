# Reusable GitHub Actions

## Actions

### calculate-version
Calculate semantic version from Git history.

**Outputs:** `version`, `branch`, `sha`, `repository-owner`

### load-versions
Read version configuration from `versions.json`.

**Outputs:** `otel-version`, `fedora-version`, `microshift-version`

### build-container
Build container image with Podman, including registry auth as a build secret for private image pulls.

**Inputs:** `containerfile`, `image-name`, `version`, `sha`, `registry`, `repository-owner`, `otel-version`, `fedora-version`, `enable-cache`

**Outputs:** `image-id`, `image-ref`

Features:
- Checks registry for existing image before rebuilding
- Containerfile hash comparison to detect changes
- Layer cache optimization
- Registry auth passed as `--secret` (never baked into image)

### trivy-scan
Container vulnerability scanning via tar export (works with Podman and Docker).

**Inputs:** `scan-ref`, `severity`, `output-format`, `upload-sarif`, `sarif-category`

**Outputs:** `results-file`, `tar-file`

Features:
- Exports image to tar with `podman save` / `docker save`
- Scans tar with `trivy image --input` (no Docker daemon dependency)
- SARIF upload to GitHub Security tab

### test-container
Container validation tests using single-instance execution.

**Inputs:** `image-ref`, `test-type` (`microshift` or `bootc`)

**Outputs:** `test_results`

### build-iso
Build bootable ISO from container image using bootc-image-builder.

**Inputs:** `image-ref`, `config`, `config-file`, `output-dir`, `working-path`

**Outputs:** `iso-path`, `iso-size`, `config-used`

### update-version
Update a version in `versions.json` using jq.

**Inputs:** `json-path`, `new-version`, `component-name`

**Outputs:** `updated`, `old-version`

### harbor-auth
Authenticate with Harbor container registry.

**Inputs:** `registry`, `username`, `password`
