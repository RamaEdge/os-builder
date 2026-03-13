# Project Milestones: MicroShift Migration

## v1.2 Tech Debt (Shipped: 2026-03-13)

**Delivered:** Eliminated code duplication, hardened input validation, decomposed monolithic verify function, and replaced silent error fallbacks in the bundle CLI.

**Phases completed:** 8-10 (4 plans total)

**Key accomplishments:**
- Extracted shared `format.rs` module with TiB-capable `format_bytes()`, replacing 3 duplicate implementations across create/verify/inspect
- Created `ChecksumLine` parser enforcing GNU coreutils two-space separator contract with 6 validation tests
- Created `ImageRef` parser with character allowlist rejecting shell metacharacters, supporting port-containing registries
- Decomposed 230-line monolithic `run_verify()` into 6 named `check_*` functions with orchestrator pattern
- Added CKSM-03 cross-reference: checksums.sha256 filename validated against manifest.image.file
- Replaced all silent JSON `"{}"` fallbacks with `Result<String, BundleError>` error propagation and exit code integration tests

**Stats:**
- 27 files changed (+3,398 / -323 lines)
- 3 phases, 4 plans, 9 tasks
- 20 commits (f93745e..a1973d3)
- 1,822 LOC Rust (bundle-cli/src/)
- 54 tests (47 unit + 5 integration + 2 exit code)
- ~2 hours from start to ship

**Git range:** `f93745e` → `a1973d3`

---

## v1.0 MicroShift Migration (Shipped: 2026-03-01)

**Delivered:** Migrated os-builder from K3s to MicroShift using upstream COPR packages with full offline boot capability.

**Phases completed:** 1-3 (7 plans total)

**Key accomplishments:**
- Created Containerfile.microshift with upstream COPR packages (microshift, kindnet, topolvm, skopeo)
- Implemented two-phase offline image embedding — build-time skopeo copy + runtime ExecStartPre copy to CRI-O
- Embedded all 15 edgeworks application images for airgap operation
- Configured kustomizePaths manifest auto-deployment, eliminating custom systemd deploy services
- Deleted all K3s files and simplified edge-setup.sh to OS-only (~55 lines)
- Consolidated CI to single MicroShift workflow with artifact validation tests

**Stats:**
- 71 files changed (+10,104 / -1,144 lines)
- 3 phases, 7 plans
- 29 commits (ecb1e17..34864ff)
- 1 day from start to ship

**Git range:** `ecb1e17` → `34864ff`

**Linear Issues:** THE-869 through THE-876 (all Done)

**What's next:** Project complete — focused migration with well-defined scope.

---
