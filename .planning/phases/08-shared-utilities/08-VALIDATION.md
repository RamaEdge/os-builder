---
phase: 8
slug: shared-utilities
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 8 — Validation Strategy

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
| 08-01-01 | 01 | 1 | DEDUP-01 | unit | `cargo test format` | ❌ W0 | ⬜ pending |
| 08-01-01 | 01 | 1 | DEDUP-02 | unit | `cargo test` | ✅ | ⬜ pending |
| 08-01-01 | 01 | 1 | DEDUP-03 | unit | `cargo test` | ✅ | ⬜ pending |
| 08-01-02 | 01 | 1 | CKSM-01 | unit | `cargo test checksum` | ❌ W0 | ⬜ pending |
| 08-01-02 | 01 | 1 | CKSM-02 | unit | `cargo test checksum` | ❌ W0 | ⬜ pending |
| 08-01-03 | 01 | 1 | VALID-01 | unit | `cargo test image_ref` | ❌ W0 | ⬜ pending |
| 08-01-03 | 01 | 1 | VALID-02 | unit | `cargo test image_ref` | ❌ W0 | ⬜ pending |
| 08-01-03 | 01 | 1 | VALID-03 | unit | `cargo test image_ref` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `crates/bundle-cli/src/format.rs` — new module with `#[cfg(test)]` tests for format_bytes (TiB boundary, all units)
- [ ] `crates/bundle-cli/src/checksum.rs` — new module with `#[cfg(test)]` tests for ChecksumLine::parse (double-space, single-space rejection, invalid hex)
- [ ] `crates/bundle-cli/src/image_ref.rs` — new module with `#[cfg(test)]` tests for ImageRef::parse (metacharacter rejection, port registry, empty tag)

*All Wave 0 tests are created inline with their modules (TDD approach).*

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
