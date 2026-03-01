# Phase 1: Foundation - Research

**Researched:** 2026-03-01
**Domain:** Containerfile authoring — DNF COPR package installation, bootc image compliance, MicroShift RPM packaging
**Confidence:** HIGH

## Summary

Phase 1 is a focused Containerfile authoring task: create `os/Containerfile.microshift` that installs MicroShift from the upstream COPR nightly repository instead of pulling a custom pre-built builder image. The current file (`Containerfile.fedora.optimized`) uses a multi-stage build that copies a binary and a `release-images.json` from `ghcr.io/ramaedge/microshift-builder`. This entire mechanism is replaced by a single `dnf copr enable` call followed by `dnf install` of the upstream RPM packages.

The migration guide (`MICROSHIFT_MIGRATION.md`) provides a complete, project-specific reference Containerfile. The upstream `microshift-io/microshift` project has moved away from Red Hat payload images to OKD-based images, making them subscription-free. RPM packages are published to the `@microshift-io/microshift-nightly` COPR on a nightly basis. Phase 1 must also add `skopeo` to the package list and declare `VOLUME /var` — both are upstream-mandated requirements.

Phase 1 is intentionally scope-limited: it does NOT implement offline image embedding (Phase 2) or kustomize manifest deployment (Phase 2). It only establishes the working Containerfile foundation that subsequent phases extend. The deliverable is a Containerfile that builds cleanly with the five COPR packages, contains `VOLUME /var`, has no multi-stage builder reference, and has no custom `microshift.service` file.

**Primary recommendation:** Write `os/Containerfile.microshift` following the structure in `MICROSHIFT_MIGRATION.md` section "Refactored Containerfile", installing packages `microshift microshift-release-info microshift-kindnet microshift-kindnet-release-info microshift-topolvm microshift-topolvm-release-info` via `dnf copr enable @microshift-io/microshift-nightly`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BUILD-01 | New Containerfile.microshift installs MicroShift via upstream COPR packages (`@microshift-io/microshift-nightly`) | COPR enable command and package list are documented in MICROSHIFT_MIGRATION.md with high confidence; upstream README confirms COPR availability |
| BUILD-02 | Containerfile includes kindnet and TopoLVM packages with release-info RPMs | `microshift-kindnet`, `microshift-kindnet-release-info`, `microshift-topolvm`, `microshift-topolvm-release-info` are upstream spec-file packages; kindnet is mandatory on Fedora (OVN-K not supported) |
| BUILD-03 | Containerfile adds skopeo and VOLUME /var for kubelet idmap support | skopeo is needed for Phase 2 image embedding (install now); VOLUME /var is the upstream-mandated pattern for kubelet idmap; both are in the migration guide reference Containerfile |
| BUILD-04 | Custom microshift.service and multi-stage builder image removed | The custom `os/systemd/microshift.service` must not be COPYed into the new Containerfile; the multi-stage `FROM ${MICROSHIFT_IMAGE_BASE}` is simply not present in the new file |
</phase_requirements>

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `quay.io/fedora/fedora-bootc` | `${FEDORA_VERSION}` (42) | Base bootc OS image | Upstream mandated base for Fedora edge deployments |
| `@microshift-io/microshift-nightly` COPR | nightly | COPR repository providing MicroShift RPMs | Official upstream distribution channel for community MicroShift |
| `microshift` RPM | nightly | Core binary, systemd service, CRI-O dependency | Required; provides the microshift binary and microshift.service |
| `microshift-release-info` RPM | nightly | Release image manifests at `/usr/share/microshift/release/` | Required for Phase 2 offline image embedding |
| `microshift-kindnet` RPM | nightly | Kindnet CNI + kube-proxy; only supported CNI on Fedora | Mandatory — OVN-K is not supported on Fedora; mutually exclusive with microshift-networking |
| `microshift-kindnet-release-info` RPM | nightly | Per-arch JSON image refs for kindnet+kube-proxy | Required for Phase 2 offline embedding of networking images |
| `microshift-topolvm` RPM | nightly | TopoLVM CSI + cert-manager for LVM-backed PVCs | Required — edgeworks workloads use PVCs (`edgeworks/overlays/edge/pvc-patch.yaml`) |
| `microshift-topolvm-release-info` RPM | nightly | Per-arch JSON image refs for topolvm | Required for Phase 2 offline embedding of storage images |
| `skopeo` | distro version | OCI image copying tool | Required by Phase 2 embed script; install in Phase 1 to keep the Containerfile stable |

### Supporting

| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `openssh-server`, `sudo`, `podman`, etc. | distro | System packages | Carry forward from existing Containerfile |
| `firewall-offline-cmd` | distro (firewalld) | Set firewall rules at build time | Standard bootc pattern; include same port set as existing file |
| `bootc container lint` | bootc | Validates bootc image compliance | Always last RUN instruction |
| `STOPSIGNAL SIGRTMIN+3` + `CMD ["/sbin/init"]` | — | Systemd PID1 support | Required for systemd-based bootc images |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@microshift-io/microshift-nightly` COPR | Red Hat official MicroShift RPMs | Requires RHEL subscription; not accessible in community context |
| `microshift-kindnet` | `microshift-networking` (OVN-K) | OVN-K not supported on Fedora — kindnet is the only option here |
| Single-stage Containerfile | Multi-stage (current approach) | Multi-stage was needed to bring in the custom builder binary; not needed with RPM install |

## Architecture Patterns

### New File Location

```
os/
├── Containerfile.microshift       # NEW — this phase's deliverable
├── Containerfile.fedora.optimized # EXISTING — remains untouched in Phase 1
├── Containerfile.k3s              # EXISTING — removed in Phase 3
└── build.sh                       # EXISTING — no changes in Phase 1
```

Phase 1 creates only `os/Containerfile.microshift`. The existing files remain. Makefile and build.sh are not modified in Phase 1 (those are Phase 3 tasks).

### Pattern 1: COPR Package Installation

**What:** Enable the COPR repo and install packages in a single RUN instruction to minimize layers and ensure cleanup is atomic.

**When to use:** Any time you add a new package source; cleaning `dnf` in the same RUN prevents cache artifacts from persisting in the layer.

**Example:**
```dockerfile
# Source: MICROSHIFT_MIGRATION.md — "Refactored Containerfile" section
RUN dnf copr enable -y @microshift-io/microshift-nightly && \
    dnf install -y \
        microshift \
        microshift-release-info \
        microshift-kindnet \
        microshift-kindnet-release-info \
        microshift-topolvm \
        microshift-topolvm-release-info && \
    dnf clean all
```

### Pattern 2: VOLUME /var Declaration

**What:** Declares `/var` as a volume so the container runtime uses idmapped mounts for kubelet.

**When to use:** Required in all bootc images running MicroShift. Must appear before the final `bootc container lint` check.

**Example:**
```dockerfile
# Source: MICROSHIFT_MIGRATION.md — "What changed vs. current" section
VOLUME /var
```

### Pattern 3: Do NOT enable microshift.service explicitly

**What:** The RPM postinstall script enables `microshift.service` automatically. Adding it to the `systemctl enable` call in the Containerfile is harmless but redundant. More importantly, never COPY the custom `os/systemd/microshift.service` into the new Containerfile — the RPM provides the correct, up-to-date service file.

**When to use:** Always, in this Containerfile.

**Example:**
```dockerfile
# Source: MICROSHIFT_MIGRATION.md comment block
# NOTE: Do NOT enable microshift.service here — the RPM's postinstall already does it.
# Do NOT ship a custom microshift.service — the RPM provides the correct one.
RUN systemctl enable sshd chronyd systemd-resolved podman.socket crio \
                    otelcol edge-setup.service \
                    bootc-fetch-apply-updates.timer 2>/dev/null || true
```

### Pattern 4: bootc container lint as final RUN

**What:** Always run `bootc container lint` as the last `RUN` instruction to verify compliance.

**When to use:** Every bootc Containerfile. Fails the build if compliance is violated.

**Example:**
```dockerfile
# Source: existing os/Containerfile.fedora.optimized line 129
RUN bootc container lint
```

### Anti-Patterns to Avoid

- **Copying the custom microshift.service:** `os/systemd/microshift.service` is a hand-rolled file that the new approach replaces. Do NOT include `COPY systemd/microshift.service /usr/lib/systemd/system/` or `COPY systemd/microshift/ ...` in the new Containerfile. The RPM owns this file.
- **Multi-stage FROM the builder image:** The new Containerfile has a single stage. No `FROM ${MICROSHIFT_IMAGE_BASE}:${MICROSHIFT_VERSION} AS microshift-prebuilt` or `COPY --from=microshift-prebuilt`.
- **Inline image embedding in Phase 1:** Phase 1 does not implement offline embedding (no `skopeo copy`, no `embed-microshift-images.sh`, no `/etc/subuid` mapping). Those belong in Phase 2. Installing `skopeo` here is correct; running it is not.
- **Keeping MICROSHIFT_VERSION ARG:** The new Containerfile does not accept a `MICROSHIFT_VERSION` build argument — the version is managed by DNF/COPR, not pinned in the build.
- **Using `dnf clean packages` instead of `dnf clean all`:** The COPR repo metadata should be cleaned too; use `dnf clean all`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MicroShift binary distribution | Custom builder image + `COPY --from` | `dnf copr enable @microshift-io/microshift-nightly && dnf install microshift` | RPM handles dependencies, service files, kubeconfig symlinks, greenboot checks automatically |
| CNI configuration | Manual CNI configs | `microshift-kindnet` RPM | The RPM installs the correct config dropin at `/etc/microshift/config.d/00-disableDefaultCNI.yaml` and places manifests |
| Storage CSI configuration | Manual CSI manifests | `microshift-topolvm` RPM | The RPM installs greenboot health check, config dropin, and topolvm manifests automatically |
| microshift.service | Custom systemd unit file | RPM-provided service | The RPM's service file handles `microshift-make-rshared.service`, kubeconfig symlinks, and firewall zone configuration correctly |

**Key insight:** The upstream COPR RPMs ship a complete, integrated MicroShift setup. Building on top of the RPM avoids drift between the service file, binary version, and component configs that plagued the custom-builder approach.

## Common Pitfalls

### Pitfall 1: Including COPY of microshift.service

**What goes wrong:** If `COPY systemd/*.service /usr/lib/systemd/system/` or `COPY systemd/microshift/ ...` is included, the custom `microshift.service` overwrites the RPM's service file. The custom file lacks `microshift-make-rshared.service` dependency, correct ExecStop behavior, and other RPM-managed integrations.

**Why it happens:** The existing Containerfile COPYs all systemd units generically. New Containerfile must be selective.

**How to avoid:** Enumerate specific service files to COPY rather than using a wildcard. The new Containerfile should not reference `systemd/microshift.service` or `systemd/microshift/`.

**Warning signs:** `bootc container lint` may not catch this. Check: `podman run --rm <image> systemctl cat microshift.service` — the unit should show `[Unit]` block with MicroShift-specific content, not the hand-rolled version.

### Pitfall 2: Forgetting VOLUME /var

**What goes wrong:** Without `VOLUME /var`, kubelet idmapped mount support may not work correctly on bootc. The upstream explicitly requires this.

**Why it happens:** Easy to omit if copy-pasting selectively from the existing Containerfile (which does not have it).

**How to avoid:** Add `VOLUME /var` after all `RUN` and `COPY` instructions, before `LABEL`/`STOPSIGNAL`/`CMD`.

**Warning signs:** `bootc container lint` may flag this. Runtime symptoms include kubelet failing to start with idmap-related errors.

### Pitfall 3: Triggering Phase 2 work in Phase 1

**What goes wrong:** Adding `/etc/subuid` and `/etc/subgid` lines and the `embed-microshift-images.sh` `COPY`+`RUN` block as part of Phase 1. This couples Phase 1 to Phase 2 and makes the build fail in CI if the embed script doesn't exist yet.

**Why it happens:** MICROSHIFT_MIGRATION.md shows both phases in a single Containerfile example.

**How to avoid:** Treat Phase 1 as building the cleanest possible Containerfile that installs packages and enables services. The embed block, subuid/subgid lines, and `EMBED_CONTAINER_IMAGES` ARG all belong in Phase 2.

**Warning signs:** Containerfile references `scripts/embed-microshift-images.sh` before that file exists.

### Pitfall 4: Keeping K3s/MICROSHIFT_VERSION ARGs

**What goes wrong:** Leaving `ARG MICROSHIFT_VERSION`, `ARG MICROSHIFT_IMAGE_BASE`, or `ARG K3S_VERSION` in the new Containerfile. These are unused in the new approach and may mislead future readers or tooling.

**Why it happens:** Copying the ARG block from the existing file without reviewing each one.

**How to avoid:** Only keep `ARG FEDORA_VERSION`, `ARG OTEL_VERSION`, `ARG VCS_REF`, and `ARG VERSION`.

### Pitfall 5: dnf copr enable may fail without EPEL/copr-cli

**What goes wrong:** `dnf copr enable` requires the `dnf-plugins-core` package (provides the `copr` subcommand). On minimal Fedora bootc images, this may not be pre-installed.

**Why it happens:** Fedora minimal cloud/bootc base images sometimes omit `dnf-plugins-core`.

**How to avoid:** Add `dnf install -y dnf-plugins-core` in the system packages RUN before the COPR RUN, or merge it into the same RUN. Verify by checking whether `quay.io/fedora/fedora-bootc:42` includes `dnf-plugins-core` by default.

**Warning signs:** Build error: `Error: No such command: copr`.

## Code Examples

Verified patterns from `MICROSHIFT_MIGRATION.md` (PRIMARY source — project-specific, HIGH confidence):

### COPR Enable and Package Install

```dockerfile
# Source: MICROSHIFT_MIGRATION.md — "Refactored Containerfile" section
RUN dnf copr enable -y @microshift-io/microshift-nightly && \
    dnf install -y \
        microshift \
        microshift-release-info \
        microshift-kindnet \
        microshift-kindnet-release-info \
        microshift-topolvm \
        microshift-topolvm-release-info && \
    dnf clean all
```

### Volume and Final Compliance Block

```dockerfile
# Source: MICROSHIFT_MIGRATION.md — "Refactored Containerfile" section
# Declare /var as volume for kubelet idmap support (matches upstream)
VOLUME /var

LABEL containers.bootc=1
LABEL ostree.bootable=1
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
RUN bootc container lint
USER containeruser
```

### Services to Enable (selective — not microshift.service)

```dockerfile
# Source: MICROSHIFT_MIGRATION.md — "Refactored Containerfile" section
# NOTE: Do NOT enable microshift.service here — the RPM's postinstall already does it.
RUN systemctl enable sshd chronyd systemd-resolved podman.socket crio \
                    otelcol edge-setup.service \
                    bootc-fetch-apply-updates.timer 2>/dev/null || true
```

### Firewall Ports (carry forward from existing Containerfile)

```dockerfile
# Source: os/Containerfile.fedora.optimized lines 112-114 (existing)
RUN firewall-offline-cmd --add-service=ssh \
    --add-port=6443/tcp --add-port=8080/tcp --add-port=10250/tcp \
    --add-port=4317/tcp --add-port=4318/tcp --add-port=9090/tcp \
    --add-port=8888/tcp --add-port=80/tcp --add-port=443/tcp
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Multi-stage: `FROM ghcr.io/ramaedge/microshift-builder:${MICROSHIFT_VERSION}` + `COPY --from=microshift-prebuilt /microshift /usr/bin/microshift` | Single-stage: `dnf copr enable @microshift-io/microshift-nightly && dnf install microshift` | Upstream MicroShift-IO project now publishes COPR RPMs | No custom builder image required; RPM handles service files, dependencies, kubeconfig, firewall zones |
| `podman pull --root /usr/share/containers/storage` for offline images | `skopeo copy dir:` at build time (Phase 2) | Upstream embed_images.sh pattern | Images survive bootc updates; idmap issues avoided |
| Custom `os/systemd/microshift.service` | RPM-provided microshift.service | RPM packaging became the correct distribution method | Service file is maintained upstream; no drift |
| `MICROSHIFT_VERSION` pinned in versions.txt and passed as ARG | Version managed by COPR/dnf | Upstream COPR nightly replaces explicit version pinning | No version variable needed for MicroShift itself |

**Deprecated/outdated:**

- `ghcr.io/ramaedge/microshift-builder` custom builder image: replaced by upstream COPR RPMs; should not appear in `Containerfile.microshift`
- `os/systemd/microshift.service`: replaced by RPM-provided service; must not be COPYed in new Containerfile
- `MICROSHIFT_VERSION` ARG and env var: version now tracked by dnf/COPR, not pinned

## Open Questions

1. **Does `quay.io/fedora/fedora-bootc:42` include `dnf-plugins-core` by default?**
   - What we know: `dnf copr enable` requires the `copr` subcommand from `dnf-plugins-core`
   - What's unclear: Whether the base image already has it (Fedora bootc images typically include common dnf plugins, but not guaranteed for all variants)
   - Recommendation: Add `dnf install -y dnf-plugins-core` in the system packages RUN as a defensive measure, or test with a quick `podman run quay.io/fedora/fedora-bootc:42 dnf copr enable --help` to verify

2. **Current `observability-deploy.service` COPY — does it belong in Phase 1?**
   - What we know: MICROSHIFT_MIGRATION.md says this service is removed in Phase 2 when kustomizePaths replaces it; the existing Containerfile COPYs it
   - What's unclear: Whether the new Containerfile.microshift should include it as a carry-forward (for compatibility before Phase 2 completes) or omit it immediately
   - Recommendation: Include it in Phase 1 as a carry-forward (same as the existing Containerfile) so the image is functionally equivalent except for the MicroShift source change; Phase 2 removes it with the manifest deployment work

3. **Does `microshift-kubeconfig-setup.service` still apply?**
   - What we know: The existing Containerfile enables `microshift-kubeconfig-setup.service`; the RPM may handle kubeconfig symlinks automatically (`/root/.kube/config` → `/var/lib/microshift/resources/kubeadmin/kubeconfig`)
   - What's unclear: Whether the custom `os/systemd/microshift-kubeconfig-setup.service` is still needed when using the RPM
   - Recommendation: Carry it forward in Phase 1 (low risk, existing behavior); investigate as part of Phase 2 or Phase 3 cleanup

## Validation Architecture

`workflow.nyquist_validation` is not present in `.planning/config.json` (the key does not exist in the config). Skipping this section.

## Sources

### Primary (HIGH confidence)

- `/Users/ravichillerega/sources/os-builder/MICROSHIFT_MIGRATION.md` — Complete project-specific migration guide; Containerfile template, package list, rationale for each change; written by project owner
- `/Users/ravichillerega/sources/os-builder/os/Containerfile.fedora.optimized` — Current implementation being replaced; defines what to keep and what to discard
- `/Users/ravichillerega/sources/os-builder/.planning/REQUIREMENTS.md` — Authoritative requirement definitions for BUILD-01 through BUILD-04
- `/Users/ravichillerega/sources/os-builder/.planning/ROADMAP.md` — Phase scope boundaries confirming Phase 1 = Containerfile only, Phase 2 = offline embedding

### Secondary (MEDIUM confidence)

- `https://github.com/microshift-io/microshift` — Upstream project; confirms COPR availability and RPM package structure referenced in migration guide
- Package breakdown in MICROSHIFT_MIGRATION.md cross-referenced with upstream spec file descriptions

### Tertiary (LOW confidence)

- Assumption that `quay.io/fedora/fedora-bootc:42` includes `dnf-plugins-core` — not verified by direct inspection; flagged as Open Question

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — package names, COPR repo path, and Containerfile structure are explicitly documented in the project's own migration guide
- Architecture: HIGH — clear before/after documented in MICROSHIFT_MIGRATION.md; existing Containerfile provides concrete reference
- Pitfalls: MEDIUM — microshift.service overwrite and VOLUME /var pitfalls are verified; dnf-plugins-core issue is a common Fedora pattern but not explicitly verified for this base image

**Research date:** 2026-03-01
**Valid until:** 2026-03-31 (COPR nightly packages update frequently; package names are stable but verify before implementing)
