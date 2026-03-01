# Requirements: Bundle CLI

**Defined:** 2026-03-01
**Core Value:** Edge devices boot fully functional with all MicroShift system pods and edgeworks application pods running — without any network connectivity.

## v1.1 Requirements

Requirements for the `edgeworks-bundle` CLI tool. Each maps to roadmap phases.

### Scaffolding

- [x] **SCAF-01**: Cargo crate at `crates/bundle-cli/` compiles with all dependencies (THE-879)
- [x] **SCAF-02**: CLI entry point shows subcommands (`create`, `verify`, `inspect`) and `--json` global flag (THE-879)

### Manifest & Errors

- [x] **MNFST-01**: `BundleManifest` and `BundleImage` structs round-trip through serde_json (THE-880)
- [x] **MNFST-02**: `manifest.json` output matches schema in design doc §2.2 (THE-880)
- [x] **MNFST-03**: All `BundleError` variants produce descriptive messages (THE-880)
- [x] **MNFST-04**: Unit tests for manifest parsing — valid, missing fields, unknown schema version (THE-880)

### Create Command

- [x] **CREATE-01**: `create` pulls image via skopeo and produces valid bundle directory (THE-881)
- [x] **CREATE-02**: Bundle directory structure matches spec: 3 files (manifest.json, checksums.sha256, .oci.tar) (THE-881)
- [x] **CREATE-03**: `checksums.sha256` verifiable with `sha256sum -c` (THE-881)
- [x] **CREATE-04**: `--json` produces machine-readable output (THE-881)
- [x] **CREATE-05**: Progress bars during pull and checksum computation (THE-881)
- [x] **CREATE-06**: Proper errors for missing skopeo, invalid image ref, existing output dir (THE-881)

### Verify Command

- [x] **VERIFY-01**: All 6 integrity checks implemented (schema, checksums file, tarball exists, SHA256 match, size match, schema version) (THE-882)
- [x] **VERIFY-02**: Correct exit codes — 0 valid, 1 failed, 2 not found (THE-882)
- [x] **VERIFY-03**: Human and JSON output modes (THE-882)
- [x] **VERIFY-04**: Tests: valid bundle passes, corrupted checksum fails, missing file fails, bad schema fails (THE-882)

### Inspect Command

- [x] **INSP-01**: Displays all manifest fields in human-readable format (THE-883)
- [x] **INSP-02**: `--json` outputs manifest as JSON (THE-883)
- [x] **INSP-03**: Fast — no checksum computation (THE-883)
- [x] **INSP-04**: Proper error if manifest missing or malformed (THE-883)

### CI/CD

- [x] **CI-01**: `make bundle-cli` builds the release binary (THE-884)
- [x] **CI-02**: `make bundle-cli-test` runs all tests (THE-884)
- [ ] **CI-03**: CI pipeline builds and tests the bundle CLI (THE-884)
- [ ] **CI-04**: Release binary available as CI artifact (THE-884)

## Future Requirements

### Bundle Security (Phase 2)

- **SEC-01**: GPG signing of manifest.json
- **SEC-02**: Version enforcement / downgrade prevention
- **SEC-03**: Multi-arch bundle support
- **SEC-04**: Delta bundles (layer diffing)

## Out of Scope

| Feature | Reason |
|---------|--------|
| GPG signing | Deferred to future — design doc §9 |
| Version enforcement / downgrade prevention | Deferred to future — design doc §9 |
| Multi-arch bundles | Deferred to future — design doc §9 |
| Delta bundles (layer diffing) | Deferred to future — design doc §9 |
| Runtime component on device | Bundle CLI is a workstation/CI tool only |
| Multi-image bundles | Single bootc image model per design doc §1 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCAF-01 | Phase 4 | Complete |
| SCAF-02 | Phase 4 | Complete |
| MNFST-01 | Phase 4 | Complete |
| MNFST-02 | Phase 4 | Complete |
| MNFST-03 | Phase 4 | Complete |
| MNFST-04 | Phase 4 | Complete |
| CREATE-01 | Phase 5 | Complete |
| CREATE-02 | Phase 5 | Complete |
| CREATE-03 | Phase 5 | Complete |
| CREATE-04 | Phase 5 | Complete |
| CREATE-05 | Phase 5 | Complete |
| CREATE-06 | Phase 5 | Complete |
| VERIFY-01 | Phase 6 | Complete |
| VERIFY-02 | Phase 6 | Complete |
| VERIFY-03 | Phase 6 | Complete |
| VERIFY-04 | Phase 6 | Complete |
| INSP-01 | Phase 6 | Complete |
| INSP-02 | Phase 6 | Complete |
| INSP-03 | Phase 6 | Complete |
| INSP-04 | Phase 6 | Complete |
| CI-01 | Phase 7 | Complete |
| CI-02 | Phase 7 | Complete |
| CI-03 | Phase 7 | Pending |
| CI-04 | Phase 7 | Pending |

**Coverage:**
- v1.1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

---
*Requirements defined: 2026-03-01*
*Last updated: 2026-03-01 after roadmap creation*
