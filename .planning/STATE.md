---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Tech Debt
status: defining_requirements
last_updated: "2026-03-13T00:00:00.000Z"
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-13)

**Core value:** Edge devices boot fully functional with all MicroShift system pods and edgeworks application pods running — without any network connectivity.
**Current focus:** Defining requirements for v1.2 Tech Debt

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-03-13 — Milestone v1.2 started

## Accumulated Context

### Decisions

All v1.0 decisions logged in PROJECT.md Key Decisions table. All marked Good.

v1.1 design authority: `docs/bundle-cli-design.md` — bundle format, CLI commands, data types, CI integration.

**04-01 decisions:**
- Standalone Cargo project (not workspace) for bundle-cli independence
- Global `--json` flag via `#[arg(long, global = true)]` on top-level Cli struct
- Stub functions use `todo!()` so `cargo build` passes but runtime is obviously incomplete

**04-02 decisions:**
- `BundleManifest.notes` uses `#[serde(default)]` so missing field deserializes to empty string per §2.2
- Removed stub `NotImplemented` variant — replaced with 10 production variants from design doc §4.2
- Unknown schema versions parse via serde successfully — version validation deferred to application logic in create/verify commands
- [Phase 05-01]: Refactored create_bundle() private fn + BundleResult struct instead of duplicating pipeline for JSON/human modes
- [Phase 05-01]: json flag threaded from main.rs Cli struct into create::run() as parameter — avoids global state
- [Phase 05-01]: ProgressBar::new_spinner() for skopeo pull (unbounded) vs ProgressBar::new(file_size) for SHA256 (bounded)

**05-02 decisions:**
- ProgressBar::hidden() chosen to suppress progress bars in JSON mode — cleaner than conditional rendering per-update
- JSON errors go to stdout via process::exit(1) — bypasses main.rs stderr handler so stdout is sole output channel
- assert_cmd::cargo::cargo_bin_cmd! macro used (non-deprecated) instead of Command::cargo_bin()
- std::fs::canonicalize() with fallback for absolute output path in JSON success output

**06-01 decisions:**
- run_verify returns Err only for missing dir (exit 2); Ok(invalid) for logical failures (exit 1)
- VerifyResult accumulates all checks so human/JSON formatters share one source of truth
- Checks abort early on manifest parse/schema failure (later checks depend on a valid manifest)
- format_verify_human uses [OK] / [FAIL] tags matching design doc §3.2 exactly
- [Phase 06-verify-inspect]: run_inspect returns Err(ManifestNotFound) for both nonexistent directory and missing manifest, mapping both to exit 2
- [Phase 06-verify-inspect]: format_size helper duplicated in inspect.rs (not extracted to shared module) - kept self-contained, deferred to future refactor
- [Phase 06-verify-inspect]: Empty notes field displays as '—' for consistency rather than omitting the line

**07-01 decisions:**
- Bundle CLI Makefile section placed after Installation section (end of file) — logical grouping after toolchain install targets
- Single .PHONY line covers both targets, appended to phony block at top of Makefile
- help target updated with "Bundle CLI: bundle-cli, bundle-cli-test" line between Install and Info lines
- [Phase 07-02]: Path-filtered GitHub Actions workflow triggers only when bundle-cli code, Makefile, or workflow file changes
- [Phase 07-02]: Tests run before release build (make bundle-cli-test then make bundle-cli) for fail-fast CI behavior
- [Phase 07-02]: ubuntu-latest runner (not self-hosted) for bundle-cli CI — no registry credentials needed for build and test

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-03-13
Stopped at: Starting v1.2 Tech Debt milestone
Resume file: None
