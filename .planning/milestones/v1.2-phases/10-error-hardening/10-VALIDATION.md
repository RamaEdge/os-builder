---
phase: 10
slug: error-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Rust built-in `#[cfg(test)]` + `assert_cmd` integration tests |
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
| 10-01-01 | 01 | 1 | ERR-01, ERR-02 | unit | `cargo test` | ✅ | ⬜ pending |
| 10-01-02 | 01 | 1 | ERR-01, ERR-02 | integration | `cargo test --test exit_codes` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `crates/bundle-cli/tests/exit_codes.rs` — integration tests asserting numeric exit codes (0/1/2) on known inputs

*Wave 0 test is created as part of Plan 10-01 Task 2.*

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
