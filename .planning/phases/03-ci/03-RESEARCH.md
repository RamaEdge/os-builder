# Phase 4: CI - Research

**Researched:** 2026-03-01
**Domain:** GitHub Actions CI workflows, shell scripting, MicroShift-only build pipeline
**Confidence:** HIGH

## Summary

Phase 4 is a focused cleanup and consolidation of the CI layer. The repository currently has two competing CI workflows: `build-and-security-scan.yaml` (K3s, the active default that triggers on push/PR to `main`) and `build-microshift.yaml` (MicroShift-only, currently `workflow_dispatch` only — never triggered automatically). The work is entirely mechanical: delete the K3s workflow, promote the MicroShift workflow to trigger on push and PR, and strip `test-container.sh` of its K3s test function and multi-variant dispatch logic.

A critical cross-phase dependency exists: Phase 3 removes `K3S_VERSION`, `CNI_VERSION`, and `MICROSHIFT_VERSION` from `versions.txt`, and removes K3s build args from `build.sh`/`Makefile`. The updated CI workflow must not pass those removed build args (k3s-version, cni-version, microshift-version) to the `build-container` action. The `build-container` action already guards these with `[ -n "..." ]` conditionals, so omitting them from the workflow call is sufficient — the action itself does not need to be changed.

A secondary dependency: `dependency-update.yaml` references `os/Containerfile.fedora` (a file that may not exist or will be superseded by `Containerfile.microshift` after Phase 1). That workflow will need its base image extraction step updated to point to `Containerfile.microshift` — this is technically out of Phase 4 scope per the requirements, but worth flagging as a related cleanup item.

**Primary recommendation:** Delete `build-and-security-scan.yaml`, update `build-microshift.yaml` to trigger on push/PR to `main`, update `CONTAINERFILE` env to `Containerfile.microshift`, remove K3s-specific build-arg inputs, and simplify `test-container.sh` to microshift-only.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CI-01 | K3s CI workflow (`.github/workflows/build-and-security-scan.yaml`) removed | File confirmed at that exact path; simple deletion |
| CI-02 | MicroShift CI workflow is the default build workflow | `build-microshift.yaml` exists but is `workflow_dispatch` only; needs `push`/`pull_request` triggers added |
| CI-03 | test-container.sh tests MicroShift variant only | File at `.github/actions/test-container/test-container.sh`; contains K3s test function and multi-type dispatch that must be removed |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| GitHub Actions YAML | N/A | Workflow definition | Project already uses it throughout `.github/workflows/` |
| Composite Actions | N/A | Reusable action steps | Already used via `.github/actions/` (build-container, trivy-scan, test-container, etc.) |
| Bash | system | test-container.sh scripting | Script is already bash; no change to language |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `.github/actions/build-container` | Container image build with cache | Already used by both workflows; keep as-is |
| `.github/actions/trivy-scan` | Security scan | Already used; keep as-is |
| `.github/actions/test-container` | Runs test-container.sh | Already used; action.yml does not need changes |
| `.github/actions/load-versions` | Reads versions.txt | Already used; outputs k3s-version/cni-version will be empty after Phase 3 but the action still functions |
| `.github/actions/harbor-auth` | Registry auth | Keep as-is |
| `.github/actions/calculate-version` | Semver calculation | Keep as-is |
| `.github/actions/build-iso` | ISO build | Keep as-is |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Renaming build-microshift.yaml | Deleting K3s + promoting existing MicroShift file | Renaming preserves history but is identical in outcome; promoting existing file is cleaner |

## Architecture Patterns

### Recommended Project Structure (after Phase 4)

```
.github/
├── workflows/
│   ├── build-microshift.yaml   # PRIMARY — triggers on push/PR to main (UPDATED)
│   └── dependency-update.yaml  # Weekly security scan (minor update needed - out of scope)
└── actions/
    ├── test-container/
    │   ├── action.yml           # No change needed
    │   └── test-container.sh   # UPDATED: microshift-only
    ├── build-container/         # No change
    ├── trivy-scan/              # No change
    ├── load-versions/           # No change
    ├── harbor-auth/             # No change
    ├── calculate-version/       # No change
    └── build-iso/               # No change
```

### Pattern 1: Promoting workflow_dispatch to full trigger

**What:** Add `push` and `pull_request` triggers to `build-microshift.yaml` so it runs on every code change to `main`, matching the behavior of the K3s workflow it replaces.

**Current `build-microshift.yaml` trigger (workflow_dispatch only):**
```yaml
on:
  workflow_dispatch:
    inputs:
      microshift_version:
        description: 'MicroShift Version (default: release-4.19)'
        default: 'release-4.19'
      ...
```

**Target trigger (matching K3s workflow pattern + keeping workflow_dispatch for manual runs):**
```yaml
on:
  push:
    branches: ['main']
    paths: ['os/**']
  pull_request:
    branches: ['main']
    paths: ['os/**']
  schedule:
    - cron: '0 1 * * Fri'   # Weekly builds (optional — match K3s cadence)
  workflow_dispatch:
    inputs:
      iso_config:
        description: 'ISO Configuration'
        default: 'user'
        type: choice
        options: ['minimal', 'user', 'advanced', 'interactive', 'production']
      build_iso:
        description: 'Build ISO images'
        default: true
        type: boolean
      force_rebuild:
        description: 'Force rebuild (ignore cache)'
        default: false
        type: boolean
```

**Note:** The `microshift_version` input is no longer needed after Phase 3 since MicroShift version is tracked by dnf/COPR, not versions.txt. Remove it from `workflow_dispatch` inputs.

### Pattern 2: Updating the CONTAINERFILE env variable

**What:** Change the `CONTAINERFILE` env var in `build-microshift.yaml` from the old `Containerfile.fedora.optimized` to `Containerfile.microshift`.

**Current:**
```yaml
env:
  IMAGE_NAME: ramaedge/os-microshift
  REGISTRY: harbor.local
  REPO_OWNER: ramaedge
  CONTAINERFILE: Containerfile.fedora.optimized   # OLD — must change
  SCAN_SEVERITY: CRITICAL,HIGH,MEDIUM
```

**Target:**
```yaml
env:
  IMAGE_NAME: ramaedge/os-microshift
  REGISTRY: harbor.local
  REPO_OWNER: ramaedge
  CONTAINERFILE: Containerfile.microshift         # NEW
  SCAN_SEVERITY: CRITICAL,HIGH,MEDIUM
```

### Pattern 3: Stripping K3s build-arg inputs from build-container call

**What:** The current `build-microshift.yaml` passes `microshift-version` to `build-container`. After Phase 3 removes `MICROSHIFT_VERSION` from `versions.txt` (MicroShift is installed via COPR, no version pinning), the `microshift-version` input should not be passed. Similarly, `k3s-version` and `cni-version` are K3s-only and must not be passed.

**Current build-container call in build-microshift.yaml:**
```yaml
- name: Build container image
  id: build
  uses: ./.github/actions/build-container
  with:
    image-name: ${{ env.IMAGE_NAME }}
    version: ${{ steps.version.outputs.version }}
    sha: ${{ steps.version.outputs.sha }}
    containerfile: ${{ env.CONTAINERFILE }}
    registry: ${{ env.REGISTRY }}
    repository-owner: ${{ env.REPO_OWNER }}
    microshift-version: ${{ github.event.inputs.microshift_version || steps.versions.outputs.microshift-version }}
    fedora-version: ${{ steps.versions.outputs.fedora-version }}
```

**Target (remove microshift-version, keep otel-version and fedora-version):**
```yaml
- name: Build container image
  id: build
  uses: ./.github/actions/build-container
  with:
    image-name: ${{ env.IMAGE_NAME }}
    version: ${{ steps.version.outputs.version }}
    sha: ${{ steps.version.outputs.sha }}
    containerfile: ${{ env.CONTAINERFILE }}
    registry: ${{ env.REGISTRY }}
    repository-owner: ${{ env.REPO_OWNER }}
    otel-version: ${{ steps.versions.outputs.otel-version }}
    fedora-version: ${{ steps.versions.outputs.fedora-version }}
```

### Pattern 4: Simplifying test-container.sh to microshift-only

**What:** Remove the `run_k3s_tests` function, remove the K3s case branch from the case statement, and remove the multi-type argument validation in `test-container.sh`. The script signature can remain `$0 <image-ref> <test-type>` or simplify to `$0 <image-ref>` since only one test type exists.

**Current structure:**
```
test-container.sh <image-ref> <test-type>
  - validates test-type in {k3s, microshift, bootc}
  - run_common_tests
  - run_k3s_tests      # REMOVE
  - run_microshift_tests
  - run_bootc_tests
  case k3s -> run_k3s_tests
  case microshift -> run_microshift_tests
  case bootc -> run_bootc_tests
```

**Target structure — option A (keep test-type param for forward compat):**
```
test-container.sh <image-ref> <test-type>
  - validates test-type in {microshift, bootc}
  - run_common_tests
  - run_microshift_tests
  - run_bootc_tests
  case microshift -> run_microshift_tests
  case bootc -> run_bootc_tests
```

**Target structure — option B (simplify to no test-type, always microshift):**
```
test-container.sh <image-ref>
  - run_common_tests
  - run_microshift_tests
```

Option A is preferred: it preserves the `bootc` test type which has value independent of K3s/MicroShift, and keeps the action.yml interface stable. The CI workflow already calls with `test-type: 'microshift'` — no change needed in `action.yml`.

**MicroShift tests to verify/enhance:** The current `run_microshift_tests` checks:
- `microshift` binary present
- `kubectl` binary present
- `/etc/microshift` config directory
- `/etc/microshift/config.yaml` or `cluster.yaml`
- `/etc/microshift/manifests` directory with yamls
- `microshift.service` systemd unit file
- `crictl` binary
- `/var/lib/microshift` data directory
- CNI config at `/etc/cni/net.d`

After Phase 1-3 changes, consider adding:
- `skopeo` binary present (`command -v skopeo`)
- COPR-installed microshift: `/usr/bin/microshift` exists (RPM path)
- `microshift-copy-images` script at `/usr/bin/microshift-copy-images`
- Systemd drop-in: `/usr/lib/systemd/system/microshift.service.d/microshift-copy-images.conf`
- Embedded image store: `/usr/lib/containers/storage/image-list.txt`
- `manifests.d` directory: `/usr/lib/microshift/manifests.d/`
- VOLUME /var declared (checked via `bootc container lint` already in Containerfile)

These additions are optional enhancements — the minimum for CI-03 is just removing K3s.

### Anti-Patterns to Avoid

- **Leaving microshift-version workflow input:** The `microshift_version` workflow_dispatch input in `build-microshift.yaml` references a versions.txt variable (`MICROSHIFT_VERSION`) that Phase 3 removes. Leaving a dangling input that maps to an empty/missing variable causes confusing behavior — remove it.
- **Forgetting the `local-tag` vs `image-ref` output name mismatch:** The current `build-microshift.yaml` uses `steps.build.outputs.local-tag` for `image-ref` output and `steps.build.outputs.image-ref` for `scan-ref`. The `build-container` action outputs `image-ref` (not `local-tag`) per its `action.yml`. This is an existing bug in the current MicroShift workflow — fix it when updating.
- **Orphaning the K3s CI runner config:** The K3s workflow uses `runs-on: self-hosted` while the MicroShift workflow uses `runs-on: ubuntu-22.04`. The runner is set to `ubuntu-22.04` in the MicroShift workflow — this is the correct target. Do not copy the `self-hosted` runner from the K3s workflow.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image build caching | Custom cache logic | `.github/actions/build-container` (already exists) | Action handles Containerfile hash comparison and registry cache |
| Security scanning | New scan step | `.github/actions/trivy-scan` (already exists) | Already configured with sarif upload and severity levels |
| Container testing | New test runner | `.github/actions/test-container` (already exists) | action.yml wrapper already correct; only test-container.sh content changes |

**Key insight:** Phase 4 is purely subtractive — remove and simplify existing files. No new infrastructure is required.

## Common Pitfalls

### Pitfall 1: `local-tag` Output Reference Bug
**What goes wrong:** The current `build-microshift.yaml` references `steps.build.outputs.local-tag` in the `push` job's `needs.build-scan-test.outputs.image-ref`. The `build-container` action outputs `image-ref`, not `local-tag`. This means the push job currently has a broken output reference.
**Why it happens:** The MicroShift workflow was written with a different version of the action that may have had a `local-tag` output, or was copied/written with an error.
**How to avoid:** Use `steps.build.outputs.image-ref` consistently. The push job should reference `needs.build-scan-test.outputs.image-ref` which maps from `steps.build.outputs.image-ref` in the `outputs:` block.
**Warning signs:** Push job fails with empty image ref at runtime.

### Pitfall 2: load-versions action still outputs k3s-version/cni-version after Phase 3
**What goes wrong:** The `load-versions` action hardcodes `echo "k3s-version=${K3S_VERSION}"` etc. After Phase 3 removes those from `versions.txt`, the outputs will be empty strings (not errors, since bash `source` of a file without those variables just leaves them unset, outputting empty). The `build-container` action conditionally passes them only if non-empty (`[ -n "..." ]`), so this is safe. But the `load-versions` action itself has dead outputs that could confuse future maintainers.
**Why it happens:** load-versions was written when both variants existed.
**How to avoid:** Noted as a cleanup opportunity. Not strictly required for CI-01/02/03 but worth doing in Phase 4's single plan since we're already touching the workflow.
**Warning signs:** load-versions output logs show empty K3s/CNI/MicroShift versions — harmless but misleading.

### Pitfall 3: dependency-update.yaml references Containerfile.fedora
**What goes wrong:** `dependency-update.yaml` line 23 does `grep "^FROM" os/Containerfile.fedora`. After Phase 1 renames to `Containerfile.microshift`, this step silently outputs nothing and the base image scan fails or scans the wrong image.
**Why it happens:** dependency-update.yaml was not updated when MicroShift migration started.
**How to avoid:** Update the `Extract base image` step to reference `Containerfile.microshift`. This is strictly speaking a Phase 4 adjacent change (not covered by CI-01/02/03) but lives in `.github/workflows/` and is a natural inclusion.
**Warning signs:** Dependency scan job "succeeds" but scans an empty/wrong image.

### Pitfall 4: test-container.sh argument count validation
**What goes wrong:** If the script is simplified to remove the `<test-type>` argument (Option B from Pattern 4), the action.yml still passes `test-type` as a second argument. The script's argument count check (`$# -ne 2`) will then fail.
**Why it happens:** Mismatch between script interface and action.yml interface.
**How to avoid:** Keep the `<test-type>` argument (Option A) — the action.yml and calling workflow continue to work with `test-type: 'microshift'` unchanged.

## Code Examples

### K3s workflow file — what exists at the exact deletion target
```
Path: .github/workflows/build-and-security-scan.yaml
Action: DELETE the entire file (CI-01)
```

### Updated build-microshift.yaml trigger section
```yaml
# Source: derived from existing build-and-security-scan.yaml trigger pattern
on:
  push:
    branches: ['main']
    paths: ['os/**']
  pull_request:
    branches: ['main']
    paths: ['os/**']
  schedule:
    - cron: '0 1 * * Fri'
  workflow_dispatch:
    inputs:
      iso_config:
        description: 'ISO Configuration'
        default: 'user'
        type: choice
        options: ['minimal', 'user', 'advanced', 'interactive', 'production']
      build_iso:
        description: 'Build ISO images'
        default: true
        type: boolean
      force_rebuild:
        description: 'Force rebuild (ignore cache)'
        default: false
        type: boolean
```

### test-container.sh — K3s function to remove
```bash
# REMOVE THIS ENTIRE FUNCTION:
run_k3s_tests() {
  echo "🎯 Running K3s comprehensive tests..."
  # ... 9 test assertions ...
}

# REMOVE THIS CASE BRANCH:
case "$TEST_TYPE" in
  "k3s")
    run_k3s_tests   # REMOVE
    ;;
  # ...keep microshift and bootc branches
```

### test-container.sh — updated usage validation
```bash
# Current (supports k3s/microshift/bootc):
if [ $# -ne 2 ]; then
  echo "Usage: $0 <image-ref> <test-type>"
  echo "Test types: k3s, microshift, bootc"
  exit 1
fi

# Updated (microshift + bootc only):
if [ $# -ne 2 ]; then
  echo "Usage: $0 <image-ref> <test-type>"
  echo "Test types: microshift, bootc"
  exit 1
fi
```

### Optional: enhanced microshift tests (new assertions for Phase 1-3 artifacts)
```bash
# Add to run_microshift_tests() after Phase 1-3 completion:
if run_test "skopeo binary" "command -v skopeo && skopeo --version"; then
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi

if run_test "microshift-copy-images script" "test -f /usr/bin/microshift-copy-images && test -x /usr/bin/microshift-copy-images"; then
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi

if run_test "microshift copy-images drop-in" "test -f /usr/lib/systemd/system/microshift.service.d/microshift-copy-images.conf"; then
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi

if run_test "embedded image store" "test -f /usr/lib/containers/storage/image-list.txt"; then
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi

if run_test "manifests.d directory" "test -d /usr/lib/microshift/manifests.d"; then
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi
```

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| Two CI workflows (K3s default + MicroShift manual) | Single MicroShift CI workflow as default | Phase 4 target |
| K3s workflow triggers on push/PR | MicroShift workflow triggers on push/PR | After CI-02 |
| test-container.sh handles k3s/microshift/bootc | test-container.sh handles microshift/bootc | After CI-03 |
| MICROSHIFT_VERSION in versions.txt (Phase 3 removes) | Version tracked by COPR/dnf | No versions.txt input to workflow |
| build-container receives microshift-version/k3s-version/cni-version | build-container receives otel-version/fedora-version only | After Phase 3 + CI update |

**Deprecated/outdated:**
- `K3S_VERSION`, `CNI_VERSION`, `MICROSHIFT_VERSION` in `versions.txt`: Removed in Phase 3; CI must not reference them.
- `CONTAINERFILE: Containerfile.fedora.optimized` in build-microshift.yaml: Must change to `Containerfile.microshift`.
- `runs-on: self-hosted` in K3s workflow: The K3s workflow uses self-hosted runners; MicroShift correctly uses `ubuntu-22.04`. Do not inherit self-hosted.

## Open Questions

1. **Should load-versions action be updated to remove K3s/MicroShift outputs?**
   - What we know: load-versions outputs k3s-version, cni-version, microshift-version. After Phase 3, those values are empty strings. The build-container action only passes them if non-empty, so it is functionally safe to leave as-is.
   - What's unclear: Whether to clean up load-versions.action.yml in Phase 4 or leave for a future cleanup phase.
   - Recommendation: Update load-versions in Phase 4 since we are already modifying CI files. Remove `k3s-version`, `cni-version`, `microshift-version` outputs and their corresponding echo lines. Reduces confusion.

2. **Should dependency-update.yaml be updated in Phase 4?**
   - What we know: It references `os/Containerfile.fedora` which will not exist after Phase 1. This workflow will produce incorrect results or errors.
   - What's unclear: Whether fixing it is in scope (not explicitly covered by CI-01/02/03).
   - Recommendation: Include the fix in Plan 04-01 as a natural CI cleanup — change `Containerfile.fedora` to `Containerfile.microshift` in the extract-base-image step. Small change, same file category.

3. **Should the test-container.sh MicroShift tests be enhanced with Phase 1-3 artifact checks?**
   - What we know: Current run_microshift_tests checks generic paths. Phase 1-3 create specific new artifacts (microshift-copy-images, image-list.txt, manifests.d/).
   - What's unclear: Whether Phase 4 should validate Phase 1-3 artifacts in CI.
   - Recommendation: Add the enhanced checks (skopeo, microshift-copy-images, drop-in, image-list.txt, manifests.d) as optional enhancements in Plan 04-01. They make CI-03 more valuable and validate the full migration.

## Validation Architecture

> `workflow.nyquist_validation` is not set in `.planning/config.json` — section included as informational only.

Phase 4 involves CI workflow files and shell scripts — validation is by inspection and functional workflow execution, not automated unit tests.

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | How to Verify |
|--------|----------|-----------|---------------|
| CI-01 | K3s workflow file no longer exists | File system check | `test ! -f .github/workflows/build-and-security-scan.yaml` |
| CI-02 | MicroShift workflow triggers on push to main | Workflow trigger inspection | Read trigger block; confirm `push: branches: ['main']` present |
| CI-03 | test-container.sh tests MicroShift only | Code inspection + run | Run `bash test-container.sh <image> k3s` → exits with "Unknown test type"; run with `microshift` → passes |

## Sources

### Primary (HIGH confidence)
- `.github/workflows/build-and-security-scan.yaml` — K3s CI workflow, read directly. Confirmed: triggers on push/PR/schedule, uses self-hosted runner, K3s env vars.
- `.github/workflows/build-microshift.yaml` — MicroShift CI workflow, read directly. Confirmed: workflow_dispatch only, ubuntu-22.04 runner, passes microshift-version to build-container.
- `.github/actions/test-container/test-container.sh` — test script, read directly. Confirmed: multi-variant (k3s/microshift/bootc), run_k3s_tests function with 9 assertions.
- `.github/actions/test-container/action.yml` — action wrapper. Confirmed: passes image-ref and test-type to shell script; does not need changes.
- `.github/actions/build-container/action.yml` — build action. Confirmed: conditionally passes k3s-version, cni-version, microshift-version only if non-empty; safe to omit them.
- `.github/actions/load-versions/action.yml` — versions loader. Confirmed: outputs k3s-version, microshift-version, cni-version that will be empty after Phase 3.
- `versions.txt` — confirmed current variables: K3S_VERSION, OTEL_VERSION, MICROSHIFT_VERSION, FEDORA_VERSION, BOOTC_VERSION, CNI_VERSION.
- `MICROSHIFT_MIGRATION.md` — canonical migration guide. Confirmed: `.github/workflows/build-and-security-scan.yaml` listed for deletion in "Files to delete" table.
- `.planning/REQUIREMENTS.md` — CI-01, CI-02, CI-03 confirmed with exact file paths.

### Secondary (MEDIUM confidence)
- `.github/workflows/dependency-update.yaml` — references `os/Containerfile.fedora`; needs update for Containerfile.microshift. Observed directly.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all files read directly from the repository; no external dependencies
- Architecture: HIGH — changes are purely mechanical (delete/update existing files) with no new framework decisions
- Pitfalls: HIGH — the local-tag output bug and Containerfile.fedora reference are verified by reading the actual files

**Research date:** 2026-03-01
**Valid until:** 2026-04-01 (stable — only changes if Phase 1-3 introduce unexpected file moves)
