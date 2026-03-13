---
phase: 9
slug: caller-switchover-verify-decomposition
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Rust built-in `#[cfg(test)]` + `#[test]` |
| **Config file** | `crates/bundle-cli/Cargo.toml` |
| **Quick run command** | `cd crates/bundle-cli && cargo test` |
| **Full suite command** | `cd crates/bundle-cli && cargo test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd crates/bundle-cli && cargo test`
- **After every plan wave:** Run `cd crates/bundle-cli && cargo test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | VRFY-03 | unit | `cargo test` | ✅ | ⬜ pending |
| 09-01-02 | 01 | 1 | VRFY-03 | unit | `cargo test` | ✅ | ⬜ pending |
| 09-02-01 | 02 | 1 | VRFY-01, VRFY-02 | unit | `cargo test verify` | ✅ | ⬜ pending |
| 09-02-02 | 02 | 1 | VRFY-03, CKSM-03 | unit | `cargo test verify` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test_verify_check_names` — safety-net test asserting all 6 check names before decomposition
- [ ] `test_verify_checksum_filename_mismatch` — test for CKSM-03 cross-reference

*Both Wave 0 tests are created as part of Plan 09-02 tasks.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
