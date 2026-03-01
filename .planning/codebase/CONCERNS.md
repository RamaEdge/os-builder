# Codebase Concerns

**Analysis Date:** 2026-03-01

## Tech Debt

**Dynamic Build Command Construction with eval():**
- Issue: `os/build.sh` line 100 uses `eval "$BUILD_CMD"` to execute a dynamically constructed build command, which could be exploited if variables are not properly sanitized
- Files: `os/build.sh` (lines 62-100)
- Impact: Potential security vulnerability if build arguments contain special shell characters; difficult to debug build failures
- Fix approach: Replace eval with explicit function parameters or use array-based command construction (`podman build "$@"`) instead of string concatenation

**Hardcoded localhost References:**
- Issue: Configuration files and scripts contain hardcoded `localhost` and `127.0.0.1` references that assume services are running on the same host
- Files: `os/configs/otelcol/config.yaml` (lines 35, 39, 44, 79), `os/scripts/edge-setup.sh` (lines 118, 155-156), `os/examples/test-observability.sh` (lines 76-79, 93-95, 108, 115, 117), `os/examples/cloud-init.yaml` (lines 76-77)
- Impact: Configuration will not work in distributed environments; services cannot be accessed from remote nodes; inflexible for multi-node deployments
- Fix approach: Externalize service endpoints as environment variables with sensible defaults; support service discovery patterns (DNS, Kubernetes services)

**Test Script Missing -u Flag:**
- Issue: `.github/actions/test-container/test-container.sh` line 5 uses `set -e` but not `set -u`, meaning undefined variables won't cause failure and could mask configuration problems
- Files: `.github/actions/test-container/test-container.sh` (line 5)
- Impact: Undetected undefined variables in test execution; tests may pass silently with missing required variables
- Fix approach: Change to `set -euo pipefail` for consistent error handling across all shell scripts

**Missing Error Output in test-container.sh:**
- Issue: Test script at line 63 redirects all output to `/dev/null` during test validation, preventing visibility into test failures
- Files: `.github/actions/test-container/test-container.sh` (line 63)
- Impact: Failed tests show no debugging information in first attempt; required second execution to see actual error (line 70)
- Fix approach: Log test output to temporary file; always show output on failure regardless of first attempt

## Known Bugs

**Kubeconfig sed Pattern Replacement Risk:**
- Symptoms: kubeconfig file modification with `sed -i 's/127\.0\.0\.1/localhost/g'` could match unintended patterns in certificate paths or other configuration values
- Files: `os/scripts/edge-setup.sh` (lines 117-118)
- Trigger: Any kubeconfig with embedded IP addresses in non-endpoint configuration sections
- Workaround: Manual kubeconfig editing after deployment; or use kubectl config set-cluster instead of sed

**Test Container Cleanup Race Condition:**
- Symptoms: Container may not fully stop before being removed, leaving orphaned processes
- Files: `.github/actions/test-container/test-container.sh` (lines 46-52)
- Trigger: Rapid successive test runs or slow container shutdown
- Workaround: Manual cleanup with `podman rm -f` and process verification

**Floating Base Image Tag in Makefile:**
- Symptoms: `bootc-image-builder:latest` pulls whatever is current without versioning
- Files: `Makefile` (lines 239, 248)
- Trigger: Latest changes to bootc-image-builder that break compatibility
- Workaround: Manual pin to specific image digest in pull commands

## Security Considerations

**Base Image Vulnerability Scanning Gap:**
- Risk: Fedora bootc base image (`quay.io/fedora/fedora-bootc:${FEDORA_VERSION}`) is pulled but not explicitly scanned; only the built image is scanned
- Files: `os/Containerfile.k3s` (line 7), `.trivy.yaml` (configured for image scanning, not Dockerfile scanning)
- Current mitigation: Weekly builds and scanning detect new vulnerabilities; GitHub security scanning active
- Recommendations: Add explicit Dockerfile scanning to CI pipeline; pin base image to specific digest rather than version tag; add trivy scan of base image before build

**Firewall Configuration in Build Time vs Runtime:**
- Risk: Firewall rules configured at both build time (edge-setup.sh) and Containerfile, but rules applied offline may not match actual deployment firewall state
- Files: `os/Containerfile.k3s` (lines 151-154), `os/scripts/edge-setup.sh` (lines 45-60)
- Current mitigation: Both layers ensure rules are present
- Recommendations: Single source of truth for firewall rules; use systemd-firstboot or cloud-init for runtime configuration; document firewall rule overrides

**SSH Configuration Hardening Incomplete:**
- Risk: SSH keys required but no validation that public keys are present before disabling password auth
- Files: `os/scripts/edge-setup.sh` (lines 21-42)
- Current mitigation: Directory creation and permissions hardening
- Recommendations: Validate SSH key presence before applying restrictive SSH config; provide clear error messages if keys not available; support key injection via cloud-init

**Secrets Not Protected in Build Arguments:**
- Risk: All build arguments (versions, registry names) are visible in container inspect output and build logs
- Files: `.github/actions/build-container/action.yml` (lines 134-146)
- Current mitigation: Only non-secret information passed as build args (no API keys or credentials)
- Recommendations: Use build secrets for any sensitive build-time configuration; audit all build args for accidental credential inclusion

## Performance Bottlenecks

**Repeated Architecture Detection Pattern:**
- Problem: Architecture detection (`uname -m` → ARCH mapping) duplicated in 4+ RUN layers in Containerfile.k3s
- Files: `os/Containerfile.k3s` (lines 50-56, 80-86, 96-102, 114-120)
- Cause: Shell expansion limitations; each RUN layer is a separate shell instance
- Improvement path: Create single base layer that exports ARCH variable; refactor into separate script that sets environment once

**Large Image Build Layers Not Optimized:**
- Problem: K3s binary download, CNI plugin download, and OTEL collector download are separate layers, increasing build time during development
- Files: `os/Containerfile.k3s` (lines 48-77, 79-93, 113-132)
- Cause: Separation for caching strategy, but results in multiple retry sequences
- Improvement path: Combine downloads into single layer with shared retry logic and cleanup; use BuildKit with cache mounts for better layer caching

**Test Image Startup Overhead:**
- Problem: Each test run starts container with `sleep infinity`, taking 5-10 seconds per test execution
- Files: `.github/actions/test-container/test-container.sh` (line 38)
- Cause: Simple but non-optimized container startup
- Improvement path: Use faster test harness (Alpine base); pre-warm containers in parallel; cache container state between test runs

**Trivy Scan Large Image Export:**
- Problem: Full container image exported to tar file for scanning (~2-4GB), then scanned in place
- Files: `Makefile` (lines 192-201)
- Cause: Trivy image scanning requires OCI format; no streaming or incremental scan option
- Improvement path: Use Trivy's registry scanning when available; implement image layer caching for repeated scans

## Fragile Areas

**K3s Airgap Image Layer Completeness Assumption:**
- Files: `os/Containerfile.k3s` (lines 95-111)
- Why fragile: Assumes airgap images tar.zst file contains all required images; no validation of completeness; extraction could fail silently
- Safe modification: Add validation step to verify extracted image count; implement fallback to online image pull if airgap images incomplete
- Test coverage: No test validates airgap image integrity or completeness

**MicroShift Builder Base Image Reference:**
- Files: `os/build.sh` (line 21), `Makefile` (line 147), `.github/actions/build-container/action.yml` (line 145)
- Why fragile: References external registry `ghcr.io/ramaedge/microshift-builder` which may not exist or could be stale
- Safe modification: Add validation that builder image exists and is recent; implement fallback strategy; add image pull error handling
- Test coverage: MicroShift build path not tested in CI for non-MicroShift images

**Test Container Exit Code Handling:**
- Files: `.github/actions/test-container/test-container.sh` (lines 312-318)
- Why fragile: Exit code logic depends on `FAILED` counter being accurate, but counter may not match actual test failures if tests don't follow expected pattern
- Safe modification: Validate exit code independently of counter; implement checksum or hash of test results; add test result validation layer
- Test coverage: No validation of test counter accuracy; assumption-based

**Hostname Configuration Dependency:**
- Files: `os/scripts/edge-setup.sh` (lines 14-19)
- Why fragile: Hostname change assumes `hostnamectl` is available and DNS will update automatically; no verification that hostname took effect
- Safe modification: Verify hostname change succeeded before proceeding; handle cases where hostnamectl unavailable; validate DNS resolution
- Test coverage: No test of hostname changes; cloud-init may override

## Scaling Limits

**Single K3s Instance Architecture:**
- Current capacity: Single node K3s deployment; no high availability (HA) clustering support
- Limit: Cannot achieve data center or edge mesh deployments without external orchestration
- Scaling path: Implement K3s HA mode with embedded etcd for 3+ node clusters; add load balancer configuration; document multi-node deployment patterns

**OpenTelemetry Collector Single Scrape Target:**
- Current capacity: Scrapes only localhost targets (localhost:9100, localhost:10250, etc.)
- Limit: Cannot collect metrics from multiple nodes or external services
- Scaling path: Externalize scrape targets via environment variable; support service discovery (Kubernetes SD, DNS SD); implement remote write to centralized backend

**Container Image Size Unchecked:**
- Current capacity: Airgap images can grow unbounded with K3s version updates
- Limit: Large image sizes impact storage, deployment time, and registry bandwidth
- Scaling path: Implement image size monitoring; add compression verification; implement delta/differential updates between versions

## Dependencies at Risk

**Fedora 42 Base Image EOL Timeline:**
- Risk: Fedora versions have ~13 month lifecycle; Fedora 42 will be EOL around December 2025 (already obsolete)
- Impact: Security patches stop; base image becomes unmaintained; downstream deployments vulnerable
- Migration plan: Establish automated update process for base image version in `versions.txt`; add deprecation warnings at build time; create upgrade path for existing deployments

**K3s v1.32 Maintenance Window:**
- Risk: K3s follows upstream Kubernetes which has limited maintenance windows (typically 4 months for patch releases)
- Impact: Support ends for security fixes; requires upgrade path planning
- Migration plan: Implement automated version checking via Dependabot; stage K3s upgrades across versions; add pre-upgrade validation tests

**OpenTelemetry Collector 0.127.0 Deprecation Risk:**
- Risk: OTEL collector moves fast; 0.127.0 may have deprecated receivers/exporters in newer versions
- Impact: Future Fedora upgrades may introduce incompatible otelcol versions
- Migration plan: Pin to exact version in Containerfile; implement deprecation detection in tests; validate config against new versions before upgrade

## Missing Critical Features

**No Health Check Validation:**
- Problem: Container includes many services (k3s, otel, ssh) but no integrated health check endpoint
- Blocks: Cannot implement Kubernetes liveness/readiness probes; cloud-init deployments lack boot verification
- Recommendation: Implement `/health` endpoint (systemd socket?) that validates all critical services; add to Kubernetes probes

**No Automated Rollback After Failed Update:**
- Problem: bootc supports A/B updates but no automatic rollback on boot failure
- Blocks: Deployments cannot recover from bad updates without manual intervention
- Recommendation: Implement systemd watchdog integration; add health check-based rollback; document manual rollback procedure

**No Network Configuration in Image:**
- Problem: Assumes DHCP available or requires cloud-init for network setup
- Blocks: Cannot deploy in air-gapped or strictly controlled networks without external tooling
- Recommendation: Support static IP configuration via kernel args or systemd-firstboot; document network configuration options

**No Observability for Image Build Process:**
- Problem: Build failures provide limited diagnostic information
- Blocks: Debugging build failures requires manual reproduction; no metrics on build performance trends
- Recommendation: Add build time logging; implement structured metadata about build stages; export build metrics

## Test Coverage Gaps

**No K3s Cluster Functionality Test:**
- What's not tested: Actual Kubernetes API server startup and pod scheduling; only binary presence
- Files: `.github/actions/test-container/test-container.sh` (lines 113-175)
- Risk: K3s service could fail to start and be undetected; pod lifecycle untested
- Priority: High

**No Observability Stack Integration Test:**
- What's not tested: End-to-end metrics collection; OTEL exporter functionality; actual prometheus scraping
- Files: `.github/actions/test-container/test-container.sh` (lines 78-110 - common tests only)
- Risk: OTel collector could fail silently; metrics pipeline broken undetected
- Priority: Medium

**No MicroShift Build Validation in K3s Pipeline:**
- What's not tested: MicroShift Containerfile consistency when K3s versions change
- Files: `.github/workflows/build-and-security-scan.yaml` (K3s pipeline), `.github/workflows/build-microshift.yaml` (separate pipeline)
- Risk: MicroShift image could break due to base image changes without detection
- Priority: Medium

**No Boot-to-Ready Time Measurement:**
- What's not tested: Actual deployment and initialization timing; systemd service ordering; cloud-init execution
- Files: `.github/actions/test-container/test-container.sh` - all tests are inline checks only
- Risk: Boot time could degrade unnoticed; startup ordering could be violated
- Priority: Low

**No Airgap Image Completeness Validation:**
- What's not tested: K3s airgap images tar actually contains required artifacts
- Files: `os/Containerfile.k3s` (lines 95-111) - extraction only, no validation
- Risk: Airgap deployment could fail with "image not found" on boot
- Priority: High

---

*Concerns audit: 2026-03-01*
