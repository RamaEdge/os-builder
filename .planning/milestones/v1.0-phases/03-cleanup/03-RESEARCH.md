# Phase 3: Cleanup - Research

**Researched:** 2026-03-01
**Domain:** Shell scripting, Makefile simplification, file deletion, K3s removal
**Confidence:** HIGH

## Summary

Phase 3 is a pure deletion and simplification phase. No new code is introduced — the work consists entirely of removing K3s files, stripping K3s references from surviving files, and simplifying the build toolchain to a single MicroShift-only variant. The MICROSHIFT_MIGRATION.md document already specifies every file to delete and every line to remove in surviving files, which makes this a high-confidence, well-scoped phase.

The key insight is that CLEAN-01 and CLEAN-02 are separate concerns: CLEAN-01 deletes entire K3s files, while CLEAN-02 removes K3s code from files that survive into the MicroShift build. SIMP-01 through SIMP-04 each target a specific artifact (edge-setup.sh, Makefile, build.sh, versions.txt) and have precise before/after content defined in MICROSHIFT_MIGRATION.md.

One important dependency to keep in mind: Phase 3 depends on Phase 2 completing first. The `os/systemd/microshift.service` in the repo is a custom service being removed — but the replacement comes from the MicroShift RPM installed in Phase 1. Deleting it in Phase 3 is safe only because Phase 1+2 have already established the RPM-provided service. Additionally, `edge-setup.sh` currently calls `firewall-cmd` at runtime; the new version should NOT include those firewall rules because `Containerfile.microshift` already runs `firewall-offline-cmd` at build time.

**Primary recommendation:** Execute as two discrete plans: (1) delete K3s files + remove K3s references, (2) simplify Makefile + build.sh. Each plan is independently verifiable with a `grep -r k3s .` check.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CLEAN-01 | All K3s files deleted — Containerfile.k3s, configs/k3s/, scripts/k3s-*.sh, systemd/k3s/, os/systemd/microshift.service | Exact file list confirmed by repository enumeration; MICROSHIFT_MIGRATION.md §What to Remove specifies every path |
| CLEAN-02 | K3s references removed from edge-setup.sh (lines 47-51, 93-168), versions.txt (K3S_VERSION, CNI_VERSION), build.sh (K3s detection branch) | Current file content read and confirms all three targets; migration guide specifies exact lines |
| SIMP-01 | edge-setup.sh contains only OS-level first-boot config (hostname, SSH, journald, log rotation, auto-update, NTP) | Target content fully defined in MICROSHIFT_MIGRATION.md §Refactored edge-setup.sh |
| SIMP-02 | Makefile has single `build` target using `Containerfile.microshift`, no K3s/MicroShift version variables | Target Makefile defined in MICROSHIFT_MIGRATION.md §Simplified Makefile targets |
| SIMP-03 | build.sh has no K3s detection branch | Lines 87-95 in build.sh (`if [[ "$CONTAINERFILE" == *"microshift"* ]]`) must be removed; K3S_VERSION/CNI_VERSION/MICROSHIFT_IMAGE_BASE refs removed |
| SIMP-04 | versions.txt contains only OTEL_VERSION, FEDORA_VERSION, BOOTC_VERSION | Target content defined in MICROSHIFT_MIGRATION.md §Refactored versions.txt |
</phase_requirements>

## Standard Stack

### Core

This phase uses no external libraries or tools beyond standard Unix utilities and git.

| Tool | Purpose | Notes |
|------|---------|-------|
| `git rm` | Remove tracked files | Preferred over `rm` — stages deletion for commit |
| `bash` | Shell scripting for edge-setup.sh | Already in use |
| GNU make | Makefile | Already in use |

### No Installation Required

All tools are already present. This is a deletion/simplification phase.

## Architecture Patterns

### Recommended Project Structure (After Phase 3)

```
os/
├── Containerfile.microshift    # The only build target (was Containerfile.k3s too)
├── build.sh                    # Simplified — no K3s detection branch
├── configs/
│   ├── containers/             # Stays
│   ├── otelcol/                # Stays
│   └── microshift/             # Stays
│   # configs/k3s/ DELETED
├── scripts/
│   ├── edge-setup.sh           # OS-only, no K3s blocks
│   ├── embed-microshift-images.sh  # From Phase 2
│   └── health-check.sh         # Stays
│   # k3s-load-images.sh DELETED
│   # setup-k3s-kubeconfig.sh DELETED
└── systemd/
    ├── edge-setup.service      # Stays
    ├── microshift-kubeconfig-setup.service  # Stays
    ├── otelcol.service         # Stays
    ├── observability-deploy.service  # Stays
    └── bootc-fetch-apply-updates.timer.d/  # Stays
    # systemd/k3s/ DELETED (k3s.service, k3s-load-images.service, k3s-kubeconfig-setup.service)
    # systemd/microshift.service DELETED (RPM provides this)

versions.txt                    # Only 3 lines: OTEL_VERSION, FEDORA_VERSION, BOOTC_VERSION
Makefile                        # Single `build` target, no K3s/MicroShift version vars
```

### Pattern 1: File Deletion via git rm

**What:** Use `git rm` to delete tracked files so the removal is staged for commit.
**When to use:** All K3s file deletions in CLEAN-01.
**Example:**
```bash
git rm os/Containerfile.k3s
git rm os/configs/k3s/config.yaml
git rm os/configs/k3s/registries.yaml
git rm os/scripts/k3s-load-images.sh
git rm os/scripts/setup-k3s-kubeconfig.sh
git rm os/systemd/k3s/k3s.service
git rm os/systemd/k3s/k3s-load-images.service
git rm os/systemd/k3s/k3s-kubeconfig-setup.service
git rm os/systemd/microshift.service
```

### Pattern 2: In-File K3s Reference Removal

**What:** Edit surviving files to remove K3s blocks while preserving all MicroShift/OS content.
**When to use:** CLEAN-02 across edge-setup.sh, versions.txt, build.sh.

#### edge-setup.sh — What to Remove

The current `edge-setup.sh` has these K3s-specific sections:

- **Lines 44-60 (firewall block):** The entire `firewall-cmd` section. Rationale: `Containerfile.microshift` already handles firewall rules via `firewall-offline-cmd` at build time. Re-running `firewall-cmd` at runtime is redundant and potentially conflicting. Port 10251 (kube-scheduler) is K3s-specific and not needed for MicroShift.
- **Lines 93-168 (K3s config block):** The `if systemctl is-enabled k3s` block that inline-generates `setup-kubeconfig.sh` and `deploy-observability.sh`. Both scripts are K3s-specific.
- **Lines 171-178 (otel-collector block):** The `if systemctl is-enabled otel-collector` block. The otelcol service name is `otelcol` in MicroShift images, not `otel-collector`. This stale block should be removed.

The surviving content (what SIMP-01 says to keep):
- Hostname configuration (lines 15-19)
- SSH key directory setup (lines 22-24)
- SSH hardening config (lines 27-42)
- Log rotation (lines 63-73)
- Journald limits (lines 76-83)
- Container auto-update (lines 86-87)
- NTP (lines 90-91)

**Reference implementation from MICROSHIFT_MIGRATION.md:**
```bash
#!/bin/bash
# Edge deployment first-boot setup (variant-agnostic)
set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | systemd-cat -t edge-setup
}

log "Starting edge setup..."

# Hostname
if [ "$(hostname)" = "localhost.localdomain" ] || [ "$(hostname)" = "fedora" ]; then
    hostnamectl set-hostname "edge-$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)"
    log "Set hostname to: $(hostname)"
fi

# SSH hardening
mkdir -p /home/fedora/.ssh && chown fedora:fedora /home/fedora/.ssh && chmod 700 /home/fedora/.ssh
if [ ! -f /etc/ssh/sshd_config.d/99-edge-security.conf ]; then
    cat > /etc/ssh/sshd_config.d/99-edge-security.conf << 'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
EOF
    log "SSH hardened"
fi

# Journald limits for edge
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/edge.conf << 'EOF'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
MaxRetentionSec=1week
EOF
systemctl restart systemd-journald

# Log rotation
cat > /etc/logrotate.d/edge-logs << 'EOF'
/var/log/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
}
EOF

# Container auto-update and NTP
systemctl enable --now podman-auto-update.timer
timedatectl set-ntp true

log "Edge setup completed"
```

#### versions.txt — What to Remove

Remove these 3 lines:
```
K3S_VERSION=v1.32.5+k3s1
MICROSHIFT_VERSION=release-4.19
CNI_VERSION=v1.7.1
```

Keep these 3 lines (+ the comment about MicroShift being COPR-managed):
```
OTEL_VERSION=0.127.0
FEDORA_VERSION=42
BOOTC_VERSION=42
# MicroShift installed from COPR — version tracked by dnf, not pinned here
# CNI bundled with microshift-kindnet RPM — no separate version needed
```

#### build.sh — What to Remove

The K3s detection branch (lines 87-95) must be removed:
```bash
# REMOVE THIS BLOCK:
if [[ "$CONTAINERFILE" == *"microshift"* ]] || [[ "$CONTAINERFILE" == *"fedora.optimized"* ]]; then
    BUILD_CMD="$BUILD_CMD --build-arg MICROSHIFT_VERSION=${MICROSHIFT_VERSION}"
    BUILD_CMD="$BUILD_CMD --build-arg MICROSHIFT_IMAGE_BASE=${MICROSHIFT_IMAGE_BASE}"
    BUILD_CMD="$BUILD_CMD --label microshift.version=${MICROSHIFT_VERSION}"
    info "MicroShift build: ${MICROSHIFT_VERSION}"
else
    BUILD_CMD="$BUILD_CMD --label k3s.distribution=k3s"
    info "K3s build"
fi
```

Also remove these variable declarations at the top of build.sh:
- `K3S_VERSION="${K3S_VERSION}"` (line 13)
- `MICROSHIFT_VERSION="${MICROSHIFT_VERSION:-release-4.19}"` (line 15)
- `CNI_VERSION="${CNI_VERSION}"` (line 18)
- `MICROSHIFT_IMAGE_BASE="${MICROSHIFT_IMAGE_BASE:-ghcr.io/ramaedge/microshift-builder}"` (line 21)

And remove K3S/CNI build args from the BUILD_CMD construction block:
- `BUILD_CMD="$BUILD_CMD --build-arg K3S_VERSION=${K3S_VERSION}"` (line 75)
- `BUILD_CMD="$BUILD_CMD --build-arg CNI_VERSION=${CNI_VERSION}"` (line 79)

Update the info log on line 54 to remove K3s/CNI references:
```bash
# BEFORE:
info "Versions: K3s=${K3S_VERSION}, OTEL=${OTEL_VERSION}, Fedora=${FEDORA_VERSION}, CNI=${CNI_VERSION}"
# AFTER:
info "Versions: OTEL=${OTEL_VERSION}, Fedora=${FEDORA_VERSION}"
```

Update the default CONTAINERFILE on line 9:
```bash
# BEFORE:
CONTAINERFILE="${CONTAINERFILE:-Containerfile.k3s}"
# AFTER:
CONTAINERFILE="${CONTAINERFILE:-Containerfile.microshift}"
```

### Pattern 3: Makefile Simplification (SIMP-02)

The new Makefile `build` target replaces both the old `build` (K3s) and `build-microshift` targets. Key changes:

- Default `IMAGE_NAME` changes from `harbor.local/ramaedge/os-k3s` to `harbor.local/ramaedge/os-microshift`
- Default `CONTAINERFILE` changes to `os/Containerfile.microshift`
- Remove version variables: `K3S_VERSION`, `CNI_VERSION`, `MICROSHIFT_VERSION`
- Remove `build-microshift` target
- Remove `test-k3s` target (K3s-specific)
- Update `.PHONY` declaration to remove `build-microshift`, `test-k3s`
- Update `help` target to remove K3s references
- Remove K3S/CNI version display from `help` output

**Reference implementation from MICROSHIFT_MIGRATION.md:**
```makefile
IMAGE_NAME ?= harbor.local/ramaedge/os-microshift
CONTAINERFILE ?= os/Containerfile.microshift

build:
    @cd os && \
    CONTAINER_RUNTIME="$(CONTAINER_RUNTIME)" \
    IMAGE_NAME="$(IMAGE_NAME)" \
    IMAGE_TAG="$(IMAGE_TAG)" \
    CONTAINERFILE="Containerfile.microshift" \
    OTEL_VERSION="$(OTEL_VERSION)" \
    FEDORA_VERSION="$(FEDORA_VERSION)" \
    GIT_SHA="$(GIT_SHA)" \
    ./build.sh
```

### Anti-Patterns to Avoid

- **Partial K3s removal:** Leaving K3s references in comments or disabled code. The success criterion is `grep -r k3s .` returns zero results in source files.
- **Removing the firewall section from edge-setup.sh and adding it back differently:** The firewall is already handled at build time in the Containerfile. Do not duplicate runtime firewall configuration.
- **Keeping MICROSHIFT_VERSION in versions.txt:** The migration guide explicitly removes it — MicroShift version is tracked by COPR/dnf, not pinned in versions.txt.
- **Keeping the `build-microshift` target:** It becomes the only `build` target. Having both creates confusion.
- **Forgetting `os/systemd/microshift.service`:** This custom service file must be deleted. The MicroShift RPM (installed in Phase 1) provides the correct service. MICROSHIFT_MIGRATION.md explicitly lists it in the delete table.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Verifying K3s removal | Custom validation script | `grep -r -i k3s . --include="*.sh" --include="*.yaml" --include="Containerfile*" --include="Makefile" --include="*.txt"` | Single command, no tooling needed |
| Deleting multiple files | Shell loop | `git rm <file1> <file2> ...` in one command | Atomic, staged, correct |

## Common Pitfalls

### Pitfall 1: Firewall Rules in edge-setup.sh

**What goes wrong:** Keeping the `firewall-cmd` block in edge-setup.sh "just in case" or only removing the K3s-specific port (10251).
**Why it happens:** The existing script adds firewall rules at runtime; it seems logical to keep them. But the Containerfile already runs `firewall-offline-cmd` at build time for all needed ports.
**How to avoid:** Remove the entire firewall block (lines 44-60). The migration guide explicitly states "firewall rules are already handled in the Containerfile via `firewall-offline-cmd`. Don't duplicate them here at runtime."
**Warning signs:** Any `firewall-cmd` call remaining in edge-setup.sh.

### Pitfall 2: Leaving MICROSHIFT_VERSION in versions.txt

**What goes wrong:** Treating `MICROSHIFT_VERSION` as analogous to other retained versions.
**Why it happens:** The variable currently exists and it seems like it might be needed.
**How to avoid:** SIMP-04 requires versions.txt to contain ONLY `OTEL_VERSION`, `FEDORA_VERSION`, `BOOTC_VERSION`. MicroShift version is managed by dnf/COPR, not pinned.
**Warning signs:** Any line in versions.txt other than the three required.

### Pitfall 3: Forgetting the Custom microshift.service

**What goes wrong:** Deleting K3s systemd files but leaving `os/systemd/microshift.service`.
**Why it happens:** The file is in `os/systemd/` (not `os/systemd/k3s/`) so it doesn't appear with the K3s files.
**How to avoid:** CLEAN-01 explicitly lists `os/systemd/microshift.service` as a file to delete. The RPM provides the correct replacement.
**Warning signs:** `os/systemd/microshift.service` still exists after the cleanup plan.

### Pitfall 4: Leaving K3s Comments in Makefile/build.sh

**What goes wrong:** Removing K3s logic but leaving comments that reference K3s.
**Why it happens:** Comments seem harmless.
**How to avoid:** The success criterion is `grep -r k3s .` returns zero results in source files. Comments count.
**Warning signs:** Any `k3s` string remaining in Makefile, build.sh, versions.txt, or edge-setup.sh.

### Pitfall 5: Not Updating build.sh Default CONTAINERFILE

**What goes wrong:** build.sh still defaults to `Containerfile.k3s` even after K3s files are deleted.
**Why it happens:** The default is on line 9 and easy to miss.
**How to avoid:** Change `CONTAINERFILE="${CONTAINERFILE:-Containerfile.k3s}"` to `CONTAINERFILE="${CONTAINERFILE:-Containerfile.microshift}"`.
**Warning signs:** Running `./build.sh` without a CONTAINERFILE env var fails because Containerfile.k3s no longer exists.

## Code Examples

### Verification Command After Cleanup

```bash
# Should return zero results (excluding .git and MICROSHIFT_MIGRATION.md which documents what was removed)
grep -r -i "k3s" . \
  --include="*.sh" \
  --include="*.yaml" \
  --include="*.yml" \
  --include="Containerfile*" \
  --include="Makefile" \
  --include="*.txt" \
  --include="*.md" \
  --exclude-dir=".git" \
  --exclude="MICROSHIFT_MIGRATION.md" \
  --exclude="*RESEARCH*" \
  --exclude="*ROADMAP*" \
  --exclude="*REQUIREMENTS*"
```

### Complete File Delete List (CLEAN-01)

```bash
# All K3s files to delete:
git rm os/Containerfile.k3s
git rm os/configs/k3s/config.yaml
git rm os/configs/k3s/registries.yaml
git rm -r os/configs/k3s/     # if README.md in there too
git rm os/scripts/k3s-load-images.sh
git rm os/scripts/setup-k3s-kubeconfig.sh
git rm os/systemd/k3s/k3s.service
git rm os/systemd/k3s/k3s-load-images.service
git rm os/systemd/k3s/k3s-kubeconfig-setup.service
git rm -r os/systemd/k3s/
git rm os/systemd/microshift.service    # Custom service replaced by RPM
```

### Simplified versions.txt

```
# Version Configuration File
OTEL_VERSION=0.127.0
FEDORA_VERSION=42
BOOTC_VERSION=42
# MicroShift installed from COPR — version tracked by dnf, not pinned here
# CNI bundled with microshift-kindnet RPM — no separate version needed
```

### Simplified build.sh (key sections after edit)

```bash
#!/bin/bash
# Build script for Fedora bootc container image
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-localhost/fedora-edge-os}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINERFILE="${CONTAINERFILE:-Containerfile.microshift}"  # Updated default
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"
OTEL_VERSION="${OTEL_VERSION}"
FEDORA_VERSION="${FEDORA_VERSION}"
BOOTC_VERSION="${BOOTC_VERSION}"

# ... (get_git_metadata function stays unchanged) ...

build_image() {
    info "Building: ${IMAGE_NAME}:${IMAGE_TAG}"
    info "Using: ${CONTAINER_RUNTIME}"
    info "Versions: OTEL=${OTEL_VERSION}, Fedora=${FEDORA_VERSION}"  # Updated

    # ... base BUILD_CMD construction stays ...

    BUILD_CMD="$BUILD_CMD --build-arg VCS_REF=${git_commit}"
    BUILD_CMD="$BUILD_CMD --build-arg VERSION=${IMAGE_TAG}"
    BUILD_CMD="$BUILD_CMD --build-arg OTEL_VERSION=${OTEL_VERSION}"
    BUILD_CMD="$BUILD_CMD --build-arg FEDORA_VERSION=${FEDORA_VERSION}"
    BUILD_CMD="$BUILD_CMD --build-arg BOOTC_VERSION=${BOOTC_VERSION}"

    # NO K3s detection branch — single MicroShift path only
    BUILD_CMD="$BUILD_CMD ."
    # ... rest stays ...
}
```

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|-----------------|--------|
| Dual build targets (K3s + MicroShift) | Single MicroShift-only target | Simpler Makefile, no variant confusion |
| K3s version pinned in versions.txt | MicroShift version managed by COPR | Automatic upstream tracking |
| edge-setup.sh configures K3s and firewall at runtime | edge-setup.sh handles OS concerns only | Cleaner separation: build-time config vs first-boot config |
| Custom microshift.service in repo | RPM-provided service | Correct service definition maintained by upstream |

## Open Questions

1. **configs/k3s/README.md existence**
   - What we know: `os/configs/k3s/` has `config.yaml` and `registries.yaml` confirmed. The directory listing also showed a `README.md` in the k3s config directory.
   - What's unclear: Whether `git rm -r os/configs/k3s/` is the right approach or individual file removal.
   - Recommendation: Use `git rm -r os/configs/k3s/` to remove the entire directory at once. It is cleaner and catches any additional files.

2. **Makefile test targets — test-microshift and test-bootc**
   - What we know: SIMP-02 says "single build target" and "no K3s/MicroShift version variables." `test-k3s` is clearly K3s-specific.
   - What's unclear: Whether `test-microshift` and `test-bootc` should be kept or simplified.
   - Recommendation: Keep `test-microshift` and `test-bootc` but remove `test-k3s`. `test-all` should be updated to not call `test-k3s`. Phase 4 (CI) handles test-container.sh changes.

3. **Makefile help target — emoji usage**
   - What we know: The current Makefile uses emoji in echo statements.
   - What's unclear: Whether to keep or remove emoji during simplification.
   - Recommendation: Preserve existing emoji style — this is cosmetic and not within scope of SIMP-02.

## Validation Architecture

`workflow.nyquist_validation` is not set in `.planning/config.json` (the key does not exist). Skipping this section.

## Sources

### Primary (HIGH confidence)

- `/Users/ravichillerega/sources/os-builder/MICROSHIFT_MIGRATION.md` — Primary reference; §What to Remove specifies every file and code block. §Refactored edge-setup.sh, §Refactored versions.txt, §Simplified Makefile targets provide exact target content.
- `/Users/ravichillerega/sources/os-builder/os/Containerfile.k3s` — Confirms file exists and is a complete K3s variant to be deleted.
- `/Users/ravichillerega/sources/os-builder/os/scripts/edge-setup.sh` — Confirms K3s blocks at lines 44-60 (firewall) and 93-168 (K3s config), otel block at 171-178.
- `/Users/ravichillerega/sources/os-builder/Makefile` — Confirms `build` (K3s), `build-microshift`, K3s/CNI version vars, `test-k3s` target all exist.
- `/Users/ravichillerega/sources/os-builder/os/build.sh` — Confirms K3s detection branch lines 87-95 and all K3s/CNI variable declarations.
- `/Users/ravichillerega/sources/os-builder/versions.txt` — Confirms K3S_VERSION, MICROSHIFT_VERSION, CNI_VERSION lines exist and must be removed.
- Repository enumeration (bash ls) — Confirmed exact files: `os/configs/k3s/` (config.yaml, registries.yaml, README.md), `os/systemd/k3s/` (3 service files), `os/scripts/` (k3s-load-images.sh, setup-k3s-kubeconfig.sh), `os/systemd/microshift.service`.

### Secondary (MEDIUM confidence)

- `.planning/REQUIREMENTS.md` — Provides requirement IDs CLEAN-01, CLEAN-02, SIMP-01 through SIMP-04 with descriptions; matches migration guide exactly.
- `.planning/ROADMAP.md` — Confirms Phase 3 depends on Phase 2; success criteria give verifiable boolean checks.

## Metadata

**Confidence breakdown:**
- File inventory: HIGH — all files enumerated from actual repository
- Target content (edge-setup.sh, versions.txt, Makefile, build.sh): HIGH — source files read, target content defined in MICROSHIFT_MIGRATION.md
- Deletion completeness: HIGH — confirmed via directory listing
- Pitfalls: HIGH — derived from reading actual file content and noting discrepancies with migration guide

**Research date:** 2026-03-01
**Valid until:** 2026-04-01 (stable — this is deletion work against a fixed codebase)
