# Project Milestones: MicroShift Migration

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
