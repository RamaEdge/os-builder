# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MicroShift Migration

**Shipped:** 2026-03-01
**Phases:** 3 | **Plans:** 7 | **Sessions:** 1

### What Was Built
- Single-stage Containerfile.microshift with upstream COPR packages (microshift, kindnet, topolvm)
- Two-phase offline image embedding (build-time skopeo + runtime ExecStartPre copy)
- kustomizePaths manifest auto-deployment replacing custom systemd deploy services
- Complete K3s removal (9 files deleted, scripts halved)
- Consolidated CI workflow with MicroShift artifact validation tests

### What Worked
- Merging phases 1+2 enabled all 3 phases to run in parallel — zero file overlap meant zero conflicts
- Planning all phases with research in a single pass caught cross-phase issues early (plan checker found MNFT-01 scope gap and broken verify commands)
- Pre-existing MICROSHIFT_MIGRATION.md in the repo gave planners enough context to skip extensive research

### What Was Inefficient
- Phase executors didn't populate `requirements-completed` in SUMMARY frontmatter — required manual cross-reference during audit
- Post-execution stale K3s reference cleanup found 4+ files missed by plans (otelcol config, health-check, examples README, GitHub actions) — plans should have included a `grep -r k3s` sweep task
- Integration checker found dead BOOTC_VERSION wired through 3 files but consumed nowhere — pre-existing tech debt that should have been caught in Phase 2 planning

### Patterns Established
- Two-phase image embedding: build-time `skopeo copy dir:` + runtime `skopeo copy containers-storage:`
- Embed script generates its own runtime counterpart and systemd drop-in (self-contained)
- kustomizePaths with `manifests.d/*` glob for immutable manifest deployment

### Key Lessons
1. Always include a `grep -r` sweep task in cleanup phases to catch stale references in docs, configs, and examples
2. Phase parallelism works well when file ownership is clearly separated — verify with explicit file lists before merging phases
3. Integration checking after execution catches wiring gaps that per-phase verification misses (NODE_IP, dead build args)

### Cost Observations
- Model mix: ~30% opus (orchestration), ~70% sonnet (execution, research, planning, checking)
- Sessions: 1 (entire migration in single session)
- Notable: Parallel phase execution completed 3 phases in roughly the time of one

---

## Milestone: v1.2 — Tech Debt

**Shipped:** 2026-03-13
**Phases:** 3 | **Plans:** 4 | **Sessions:** 1

### What Was Built
- Shared `format.rs` module replacing 3 duplicate format functions across create/verify/inspect
- `ChecksumLine` parser with GNU coreutils two-space separator contract enforcement
- `ImageRef` parser with character allowlist preventing shell injection in skopeo invocations
- Decomposed 230-line monolithic `run_verify()` into 6 named check functions with orchestrator pattern
- Result-based JSON error propagation replacing all silent `"{}"` fallbacks
- Exit code integration tests for verify and inspect commands

### What Worked
- Parallel planning of all 3 phases in a single pass — phases 8, 9, 10 planned simultaneously, plans verified by checker
- Phase 8 executor proactively wired format.rs into callers ahead of schedule — Plan 09-01 required zero code changes (already done)
- Research agents identified all 6 tech debt items and correct implementation approaches before planning began
- ~2 hours from first commit to milestone audit passed — tight scope with clear requirements enabled fast execution

### What Was Inefficient
- Phase 9 verification initially missed that image_ref was not wired into create.rs — the plan scope said "callers" but verification only checked format.rs and checksum.rs callers, not image_ref
- Plan 08-01 checkbox wasn't updated in ROADMAP.md (still showed `[ ]` after completion) — manual checkbox management is error-prone
- VALIDATION.md files were created as stubs (nyquist_compliant: false) to satisfy plan checker but never completed — Nyquist validation gap

### Patterns Established
- `pub(crate)` utility modules: shared functions in dedicated modules, imported via `use crate::module::fn`
- Character allowlist validation: reject unexpected characters rather than blocklisting known-bad ones
- Orchestrator pattern: decompose monolithic functions into named check functions with coordinator
- `rfind(':')` for image tag extraction to handle port-containing registries

### Key Lessons
1. When verifying "all callers switched," explicitly enumerate every import site from the module's creation commit — don't assume the plan's scope covers all actual callers
2. Proactive executor work (Phase 8 doing Phase 9's wiring) saved time overall but created a verification gap — verification must check actual state, not plan scope
3. Tech debt refactoring milestones execute very fast (~2h) because the scope is well-bounded and the code is already understood from prior milestones

### Cost Observations
- Model mix: ~20% opus (orchestration, audit), ~80% sonnet (execution, research, planning, checking, verification, integration)
- Sessions: 1 (entire milestone in single session)
- Notable: 33 minutes total execution time for 4 plans; most time was in planning/verification cycles, not code changes

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 1 | 3 | Phase merge for parallel execution; integrated plan verification loop |
| v1.2 | 1 | 3 | Parallel planning; proactive executor wiring; ~2h total milestone time |

### Top Lessons (Verified Across Milestones)

1. Phase-level parallelism via file ownership analysis is a high-value optimization
2. Plan checker iteration catches real blockers before wasting execution time
3. Verification must check actual codebase state, not just plan scope — proactive executor work can create gaps between what was planned and what needs verifying (v1.0 stale refs, v1.2 image_ref caller)
