# Roadmap: MicroShift Migration

## Milestones

- ✅ **v1.0 MicroShift Migration** — Phases 1-3 (shipped 2026-03-01)
- 🚧 **v1.1 Bundle CLI** — Phases 4-7 (in progress)

## Phases

<details>
<summary>✅ v1.0 MicroShift Migration (Phases 1-3) — SHIPPED 2026-03-01</summary>

- [x] Phase 1: Containerfile + Offline Operation (4/4 plans) — completed 2026-03-01
- [x] Phase 2: Cleanup (2/2 plans) — completed 2026-03-01
- [x] Phase 3: CI (1/1 plan) — completed 2026-03-01

See: `.planning/milestones/v1.0-ROADMAP.md` for full details.

</details>

### 🚧 v1.1 Bundle CLI (In Progress)

**Milestone Goal:** Build the `edgeworks-bundle` Rust CLI tool — create, verify, and inspect offline update bundles for air-gapped edge devices.

- [x] **Phase 4: Foundation** - Cargo crate, manifest types, and error handling (2026-03-01)
- [ ] **Phase 5: Create Command** - Pull image via skopeo and write a valid bundle directory
- [ ] **Phase 6: Verify + Inspect Commands** - Validate bundle integrity and display metadata
- [ ] **Phase 7: CI/CD Integration** - Makefile targets, GitHub Actions pipeline, release artifact

## Phase Details

### Phase 4: Foundation
**Goal**: The `edgeworks-bundle` crate compiles with correct types and all error paths produce useful messages
**Depends on**: Nothing (first phase of v1.1)
**Requirements**: SCAF-01, SCAF-02, MNFST-01, MNFST-02, MNFST-03, MNFST-04
**Success Criteria** (what must be TRUE):
  1. `cargo build` succeeds in `crates/bundle-cli/` with no errors
  2. Running the binary with no args shows `create`, `verify`, `inspect` subcommands and `--json` flag
  3. `BundleManifest` and `BundleImage` structs round-trip through `serde_json` (serialize then deserialize without data loss)
  4. All `BundleError` variants format descriptive human-readable messages
  5. Unit tests for manifest parsing pass — valid input, missing fields, unknown schema version
**Plans**: 2 plans
- [x] 04-01-PLAN.md — Cargo crate scaffolding + CLI entry point with subcommands (2026-03-01)
- [x] 04-02-PLAN.md — Manifest types, error types, and unit tests (TDD) (2026-03-01)

### Phase 5: Create Command
**Goal**: Users can run `edgeworks-bundle create` to produce a valid, verifiable bundle directory from an OCI image reference
**Depends on**: Phase 4
**Requirements**: CREATE-01, CREATE-02, CREATE-03, CREATE-04, CREATE-05, CREATE-06
**Success Criteria** (what must be TRUE):
  1. `edgeworks-bundle create <image-ref> <output-dir>` produces a directory with `manifest.json`, `checksums.sha256`, and `<name>.oci.tar`
  2. `sha256sum -c checksums.sha256` exits 0 inside the bundle directory
  3. `edgeworks-bundle create --json ...` outputs machine-readable JSON instead of human text
  4. Progress bars appear during image pull and checksum computation
  5. Meaningful errors are returned for missing skopeo, invalid image reference, or existing output directory
**Plans**: TBD

### Phase 6: Verify + Inspect Commands
**Goal**: Users can validate a bundle's integrity and display its metadata without re-pulling the image
**Depends on**: Phase 5
**Requirements**: VERIFY-01, VERIFY-02, VERIFY-03, VERIFY-04, INSP-01, INSP-02, INSP-03, INSP-04
**Success Criteria** (what must be TRUE):
  1. `edgeworks-bundle verify <bundle-dir>` exits 0 on a valid bundle and exits 1 when a checksum is corrupted or a file is missing
  2. `edgeworks-bundle verify` on a nonexistent path exits 2
  3. `edgeworks-bundle inspect <bundle-dir>` displays all manifest fields in human-readable format instantly (no checksum computation)
  4. Both commands support `--json` for machine-readable output
  5. Verify tests cover: valid bundle passes, corrupted checksum fails, missing tarball fails, bad schema version fails
**Plans**: 2 plans
  - [ ] 06-01-PLAN.md — Implement verify command with 6 integrity checks, exit codes, human/JSON output, and tests
  - [ ] 06-02-PLAN.md — Implement inspect command with fast metadata display, human/JSON output, and tests

### Phase 7: CI/CD Integration
**Goal**: The bundle CLI builds and tests automatically in CI and produces a downloadable release binary
**Depends on**: Phase 6
**Requirements**: CI-01, CI-02, CI-03, CI-04
**Success Criteria** (what must be TRUE):
  1. `make bundle-cli` builds the release binary without errors
  2. `make bundle-cli-test` runs all unit and integration tests
  3. GitHub Actions CI job builds and tests the bundle CLI on every push
  4. CI uploads the compiled binary as a downloadable workflow artifact
**Plans**: TBD

## Progress

**Execution Order:** 4 → 5 → 6 → 7

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Containerfile + Offline | v1.0 | 4/4 | Complete | 2026-03-01 |
| 2. Cleanup | v1.0 | 2/2 | Complete | 2026-03-01 |
| 3. CI | v1.0 | 1/1 | Complete | 2026-03-01 |
| 4. Foundation | v1.1 | 2/2 | Complete | 2026-03-01 |
| 5. Create Command | v1.1 | 0/? | Not started | - |
| 6. Verify + Inspect | v1.1 | 0/2 | Planned | - |
| 7. CI/CD Integration | v1.1 | 0/? | Not started | - |
