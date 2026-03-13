# Roadmap: MicroShift Migration

## Milestones

- ✅ **v1.0 MicroShift Migration** — Phases 1-3 (shipped 2026-03-01)
- ✅ **v1.1 Bundle CLI** — Phases 4-7 (shipped 2026-03-01)
- 🚧 **v1.2 Tech Debt** — Phases 8-10 (in progress)

## Phases

<details>
<summary>✅ v1.0 MicroShift Migration (Phases 1-3) — SHIPPED 2026-03-01</summary>

- [x] Phase 1: Containerfile + Offline Operation (4/4 plans) — completed 2026-03-01
- [x] Phase 2: Cleanup (2/2 plans) — completed 2026-03-01
- [x] Phase 3: CI (1/1 plan) — completed 2026-03-01

See: `.planning/milestones/v1.0-ROADMAP.md` for full details.

</details>

<details>
<summary>✅ v1.1 Bundle CLI (Phases 4-7) — SHIPPED 2026-03-01</summary>

- [x] **Phase 4: Foundation** - Cargo crate, manifest types, and error handling (2026-03-01)
- [x] **Phase 5: Create Command** - Pull image via skopeo and write a valid bundle directory (2026-03-01)
- [x] **Phase 6: Verify + Inspect Commands** - Validate bundle integrity and display metadata (2026-03-01)
- [x] **Phase 7: CI/CD Integration** - Makefile targets for bundle-cli build and test (2026-03-01)

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
**Plans**: 2 plans
- [x] 05-01-PLAN.md — Core create pipeline (2026-03-01)
- [x] 05-02-PLAN.md — JSON mode, progress bars, error handling (2026-03-01)

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
- [x] 06-01-PLAN.md — Verify command with 6 integrity checks, exit codes, human/JSON output, and tests (2026-03-01)
- [x] 06-02-PLAN.md — Inspect command with fast metadata display, human/JSON output, and tests (2026-03-01)

### Phase 7: CI/CD Integration
**Goal**: The bundle CLI builds and tests automatically in CI and produces a downloadable release binary
**Depends on**: Phase 6
**Requirements**: CI-01, CI-02, CI-03, CI-04
**Success Criteria** (what must be TRUE):
  1. `make bundle-cli` builds the release binary without errors
  2. `make bundle-cli-test` runs all unit and integration tests
  3. GitHub Actions CI job builds and tests the bundle CLI on every push
  4. CI uploads the compiled binary as a downloadable workflow artifact
**Plans**: 2 plans
- [x] 07-01-PLAN.md — Makefile targets for bundle-cli and bundle-cli-test (2026-03-01)
- [x] 07-02-PLAN.md — GitHub Actions CI workflow for bundle CLI (2026-03-01)

</details>

### v1.2 Tech Debt (In Progress)

**Milestone Goal:** Eliminate code duplication, harden input validation, and decompose fragile monolithic functions in the bundle CLI to improve maintainability and extensibility.

- [x] **Phase 8: Shared Utilities** - Extract format.rs, ChecksumLine, and ImageRef as standalone, tested modules; wire format.rs into callers (completed 2026-03-13)
- [x] **Phase 9: Caller Switchover + Verify Decomposition** - Wire new modules into all callers and decompose run_verify() into composable check functions (completed 2026-03-13)
- [x] **Phase 10: Error Hardening** - Replace silent JSON serialization fallbacks with proper error propagation (completed 2026-03-13)

## Phase Details

### Phase 8: Shared Utilities
**Goal**: Three new utility modules exist with full test coverage and format.rs is wired into all callers, replacing duplicate implementations
**Depends on**: Phase 7 (v1.1 complete)
**Requirements**: DEDUP-01, DEDUP-02, DEDUP-03, VALID-01, VALID-02, VALID-03, CKSM-01, CKSM-02
**Success Criteria** (what must be TRUE):
  1. `crates/bundle-cli/src/format.rs` provides a single `format_bytes()` function with TiB support; existing `test_format_size` suite passes against it
  2. `crates/bundle-cli/src/checksum.rs` provides `ChecksumLine::parse()` that accepts double-space GNU sha256sum format and rejects single-space input (explicit failing test exists)
  3. `crates/bundle-cli/src/image_ref.rs` provides `ImageRef::parse()` that rejects shell metacharacters, accepts port-containing registry hosts (`registry:5000/repo:tag`), and requires a non-empty tag
  4. `cargo test` passes with all new unit tests (no existing tests broken)
  5. No local `format_bytes` or `format_size` functions remain in create.rs, verify.rs, or inspect.rs
**Plans**: 1 plan
Plans:
- [ ] 08-01-PLAN.md — Create format.rs, checksum.rs, image_ref.rs modules with tests; wire format.rs into all callers

### Phase 9: Caller Switchover + Verify Decomposition
**Goal**: All three command modules use the shared utilities exclusively and run_verify() is a short orchestrator over named check functions
**Depends on**: Phase 8
**Requirements**: VRFY-01, VRFY-02, VRFY-03, CKSM-03
**Success Criteria** (what must be TRUE):
  1. `create.rs`, `verify.rs`, and `inspect.rs` import from `crate::format`, `crate::checksum`, and `crate::image_ref` — no local duplicate implementations remain
  2. `run_verify()` is a coordinator of ~20 lines calling individual `check_*` private functions, each returning a `CheckResult`
  3. All 9 existing verify tests pass without modification
  4. `ChecksumLine.filename` is cross-referenced against `manifest.image.file` during verification — mismatch produces a failed check result
**Plans**: 2 plans
Plans:
- [x] 09-01-PLAN.md — Switch create.rs and inspect.rs to shared format_bytes (2026-03-13)
- [ ] 09-02-PLAN.md — Decompose run_verify() into check functions with CKSM-03 cross-reference

### Phase 10: Error Hardening
**Goal**: JSON serialization failures surface as diagnostics instead of silently producing empty output
**Depends on**: Phase 9
**Requirements**: ERR-01, ERR-02
**Success Criteria** (what must be TRUE):
  1. `format_inspect_json` and `format_verify_json` return `Result<String, BundleError>` — callers propagate the error via `?`
  2. No `unwrap_or_else(|_| "{}".to_string())` patterns remain in create.rs, verify.rs, or inspect.rs
  3. All new `BundleError` variants are traced through `main.rs` exit code dispatch — exit code contract (0/1/2) is unchanged
  4. All existing tests pass; at least one integration test asserts numeric exit codes on known-bad input
**Plans**: 1 plan
Plans:
- [ ] 10-01-PLAN.md — Add JsonSerialize error variant, replace all unwrap fallbacks, add exit code tests

## Progress

**Execution Order:** 8 → 9 → 10

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Containerfile + Offline | v1.0 | 4/4 | Complete | 2026-03-01 |
| 2. Cleanup | v1.0 | 2/2 | Complete | 2026-03-01 |
| 3. CI | v1.0 | 1/1 | Complete | 2026-03-01 |
| 4. Foundation | v1.1 | 2/2 | Complete | 2026-03-01 |
| 5. Create Command | v1.1 | 2/2 | Complete | 2026-03-01 |
| 6. Verify + Inspect | v1.1 | 2/2 | Complete | 2026-03-01 |
| 7. CI/CD Integration | v1.1 | 2/2 | Complete | 2026-03-01 |
| 8. Shared Utilities | v1.2 | 1/1 | Complete | 2026-03-13 |
| 9. Caller Switchover + Verify Decomposition | v1.2 | Complete    | 2026-03-13 | - |
| 10. Error Hardening | 1/1 | Complete   | 2026-03-13 | - |
