# Testing Patterns

**Analysis Date:** 2026-03-01

## Test Framework

**Runner:**
- Custom bash script-based testing - no external test framework
- Primary test runner: `.github/actions/test-container/test-container.sh`
- Makefile orchestration: `make test`, `make test-k3s`, `make test-microshift`, `make test-bootc`, `make test-all`

**Assertion Library:**
- No external assertion library - uses bash conditionals (`if`, `||`)
- Return codes (0 = pass, non-zero = fail) for test status

**Run Commands:**
```bash
make test              # Run default test type (K3s)
make test TEST_TYPE=k3s       # Run K3s tests
make test TEST_TYPE=microshift # Run MicroShift tests
make test TEST_TYPE=bootc      # Run bootc tests
make test-all          # Run all test types sequentially
```

**Local Testing:**
```bash
cd /Users/ravichillerega/sources/os-builder
./.github/actions/test-container/test-container.sh "<image-ref>" "k3s"
./.github/actions/test-container/test-container.sh "<image-ref>" "microshift"
./.github/actions/test-container/test-container.sh "<image-ref>" "bootc"
```

## Test File Organization

**Location:**
- Primary test script: `.github/actions/test-container/test-container.sh`
- Health check tests: `os/scripts/health-check.sh`
- Observability tests: `os/examples/test-observability.sh`
- Tests are co-located with usage context (GitHub Actions, examples)

**Naming:**
- Test scripts use descriptive names: `test-container.sh`, `health-check.sh`, `test-observability.sh`
- Functions named by test category: `run_common_tests()`, `run_k3s_tests()`, `run_microshift_tests()`, `run_bootc_tests()`
- Individual test execution: `run_test()` helper function

**Structure:**
```
.github/
├── actions/
│   └── test-container/
│       └── test-container.sh    # Main container testing script
├── workflows/                   # CI/CD workflow definitions
os/
├── examples/
│   └── test-observability.sh    # Observability stack validation
└── scripts/
    └── health-check.sh          # Health check tests
```

## Test Structure

**Test Suite Organization (Container Tests):**
```bash
# Input validation
if [ $# -ne 2 ]; then
  echo "Usage: $0 <image-ref> <test-type>"
  exit 1
fi

# Container setup
CONTAINER_ID=$($RUNTIME run -d "$IMAGE_REF" sleep infinity)
trap cleanup_container EXIT

# Common tests (run for all image types)
run_common_tests

# Type-specific tests
case "$TEST_TYPE" in
  "k3s") run_k3s_tests ;;
  "microshift") run_microshift_tests ;;
  "bootc") run_bootc_tests ;;
esac

# Results reporting
echo "Total: $TOTAL, Passed: $PASSED, Failed: $FAILED"
exit $([[ $FAILED -eq 0 ]] && echo 0 || echo 1)
```

**Test Execution Pattern:**
```bash
run_test() {
  local test_name="$1"
  local test_cmd="$2"
  echo "🔹 Testing: $test_name"
  if $RUNTIME exec "$CONTAINER_ID" /bin/bash -c "$test_cmd" >/dev/null 2>&1; then
    echo "  ✅ PASSED"
    return 0
  else
    echo "  ❌ FAILED"
    # Show command output for debugging
    $RUNTIME exec "$CONTAINER_ID" /bin/bash -c "$test_cmd" || true
    FAILED_TESTS+=("$test_name")
    return 1
  fi
}
```

**Test Counter Pattern:**
```bash
PASSED=0
FAILED=0
FAILED_TESTS=()

# After each test
if run_test "test name" "test command"; then
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi
```

## Common Test Patterns

**Container Lifecycle Tests:**
- Start single container once for entire test suite
- Run all tests against same container instance
- Cleanup once at end via trap: `trap cleanup_container EXIT`
- Reduces test execution time by avoiding container start overhead

**Command Verification Tests:**
- Test binary exists: `command -v k3s`
- Test binary works: `k3s --version`
- Test help available: `k3s --help | head -1`
- Pattern: `<binary> --version && <binary> --help | head -1`

**File/Directory Existence Tests:**
- Test directory exists: `test -d /etc/rancher/k3s`
- Test file exists: `test -f /etc/otelcol/config.yaml`
- Test content: `find /path -name "*.yaml" | wc -l | grep -v '^0$'`

**Systemd Service Tests:**
- Service exists: `test -f /usr/lib/systemd/system/k3s.service`
- Service active: `systemctl is-active --quiet <service>`
- Service enabled: `systemctl is-enabled <service>`

**Network/Endpoint Tests:**
- HTTP endpoint accessible: `curl -s --max-time 5 http://localhost:9090 > /dev/null`
- Service responding: `check_endpoint "http://localhost:4317" "OTLP gRPC endpoint"`

**Kubernetes Resource Tests:**
- Get resource exists: `kubectl get <resource> -n <namespace>`
- Check readiness: `kubectl get <resource> -n <namespace> -o jsonpath='{.status.readyReplicas}'`
- Wait for ready: `kubectl wait --for=condition=available --timeout=300s deployment/otel-collector`

## Test Types

**Unit Tests:**
- Individual component validation
- Focus: Binary availability, version info, configuration files
- Scope: Single container instance
- Example: "k3s binary & help", "podman runtime", "bootc status"

**Component Tests:**
- Group of related functionality
- Focus: K3s-specific features, MicroShift-specific features, bootc-specific features
- Scope: Full system in container
- Test suites: `run_k3s_tests()` (11 tests), `run_microshift_tests()` (9 tests), `run_bootc_tests()` (4 tests)

**Integration Tests:**
- Test interaction between components
- Focus: Configuration propagation, manifest loading, image availability
- Example: "k3s manifests content", "microshift data directory", "CNI config"

**Common Tests Across All Types:**
```bash
run_common_tests() {
  # All image types run:
  # - bootc status
  # - systemd version
  # - podman runtime
  # - basic filesystem structure
  # - bootc container config
  # (5 core tests)
}
```

## Health Check Tests

**Framework:** `os/scripts/health-check.sh`

**Test Pattern:**
```bash
check_health() {
    local component="$1"
    local check_cmd="$2"
    local description="$3"

    echo "Checking $component..."
    if eval "$check_cmd" >/dev/null 2>&1; then
        echo "✅ $description"
        return 0
    else
        echo "❌ $description"
        return 1
    fi
}
```

**Health Check Categories:**
- System health (systemd operational status)
- Network connectivity (routing available)
- Container runtime (podman version)
- K3s-specific (binary, airgap images)
- MicroShift-specific (binary, config)
- Observability (otelcol, config)
- Storage (disk space > 1GB)

**Exit Code:**
- 0 if all checks pass
- 1 if any checks fail

## Observability Stack Tests

**Framework:** `os/examples/test-observability.sh`

**Test Categories:**
- Service status checks: `check_service "otel-collector"`
- Endpoint health: `check_endpoint "http://localhost:4317"`
- Kubernetes resource checks: `check_k8s_resource "deployment" "observability"`

**Test Pattern:**
```bash
check_service() {
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}✓ Active${NC}"
        return 0
    else
        echo -e "${RED}✗ Inactive${NC}"
        return 1
    fi
}
```

## Test Coverage

**Requirements:** No formal coverage requirement - no coverage metrics enforced

**Coverage Areas:**
- Container startup and readiness
- Binary availability and versioning
- Configuration file presence and structure
- Systemd service availability
- Network endpoints (OTLP, Prometheus)
- Kubernetes resource readiness
- Storage and disk space

**Notable Gaps:**
- No functional testing of K3s cluster operations
- No testing of container image pull/push
- No testing of MicroShift cluster provisioning
- No testing of actual workload deployment
- Limited testing of OpenTelemetry data collection

## Test Output and Reporting

**Console Output Format:**
```bash
# Header
🧪 Testing container image: $IMAGE_REF
📋 Test type: $TEST_TYPE

# Per-test output
🔹 Testing: test name
  ✅ PASSED  (or)  ❌ FAILED
  🔍 Debug: [actual command output on failure]

# Summary
📊 Test Results:
  Total: $TOTAL, Passed: $PASSED, Failed: $FAILED
❌ Failed tests:
  - test name 1
  - test name 2
```

**GitHub Actions Integration:**
- Output written to `$GITHUB_OUTPUT` if available
- Format: `test_results=total=$TOTAL,passed=$PASSED,failed=$FAILED`
- Exit code 0 for all tests passed, 1 if any failed

**Debugging Output:**
- Failed tests show actual command output for diagnosis
- Commands run twice: once silently, once verbose on failure
- Color codes distinguish PASSED (green), FAILED (red), warnings (yellow)

## Mocking and Test Isolation

**Container-based Testing:**
- Each test suite runs in isolated container instance
- No mock frameworks - uses actual binaries and configurations
- Container destroyed after test run: `trap cleanup_container EXIT`
- Tests verify actual installed artifacts, not simulated ones

**Image Selection:**
- Tests run against real built images or fallback images
- Makefile `find_image` function locates latest/specified image
- If exact tag not found, falls back to latest image with matching name

**Retry Logic:**
- Download retry logic in Containerfile (curl `--retry 3 --retry-delay 5`)
- No built-in test retry mechanism
- Failed tests stop suite with `set -e` semantics

## Testing Best Practices

**What to Test:**
- Binary availability: Verify tools are installed and accessible
- Version compatibility: Check versions match expectations
- Configuration presence: Ensure required config files exist
- System integration: Validate systemd services are available
- Network readiness: Confirm ports/endpoints are accessible

**What NOT to Test:**
- Complex K3s cluster operations (too heavyweight for image validation)
- Workload deployment functionality (beyond scope of OS image validation)
- Performance metrics (not applicable to image validation)
- Upstream tool functionality (assume tools work as designed)

## CI/CD Test Integration

**GitHub Actions Workflow:**
- Test phase runs after successful build
- Uses Makefile: `make test TEST_TYPE=<type>`
- Runs in container action: `.github/actions/test-container/`
- Can test multiple types: `make test-all`

**Test Conditions:**
- Runs on pull requests for validation
- Runs on main branch after merge for verification
- Can be triggered manually for specific testing

---

*Testing analysis: 2026-03-01*
