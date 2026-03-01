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

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 1 | 3 | Phase merge for parallel execution; integrated plan verification loop |

### Top Lessons (Verified Across Milestones)

1. Phase-level parallelism via file ownership analysis is a high-value optimization
2. Plan checker iteration catches real blockers before wasting execution time
