#!/bin/bash
# Container Test Script for os-builder
# Tests bootc container images for K3s, MicroShift, and bootc functionality

set -e

# Input validation
if [ $# -ne 2 ]; then
  echo "Usage: $0 <image-ref> <test-type>"
  echo "Test types: k3s, microshift, bootc"
  exit 1
fi

IMAGE_REF="$1"
TEST_TYPE="$2"

echo "🧪 Testing container image: $IMAGE_REF"
echo "📋 Test type: $TEST_TYPE"

# Detect container runtime
if command -v podman >/dev/null 2>&1; then
  RUNTIME="podman"
elif command -v docker >/dev/null 2>&1; then
  RUNTIME="docker"
else
  echo "❌ No container runtime found!"
  exit 1
fi
echo "🔧 Using runtime: $RUNTIME"

# Test counters
PASSED=0
FAILED=0
FAILED_TESTS=()

# Start container once and keep it running
echo "🚀 Starting test container..."
CONTAINER_ID=$($RUNTIME run -d "$IMAGE_REF" sleep infinity)
if [ $? -ne 0 ] || [ -z "$CONTAINER_ID" ]; then
  echo "❌ Failed to start container"
  exit 1
fi
echo "📦 Container started: $CONTAINER_ID"

# Cleanup function
cleanup_container() {
  if [ -n "$CONTAINER_ID" ]; then
    echo "🧹 Cleaning up container: $CONTAINER_ID"
    $RUNTIME stop "$CONTAINER_ID" 2>/dev/null || true
    $RUNTIME rm "$CONTAINER_ID" 2>/dev/null || true
    echo "🧹 Container cleanup completed"
  fi
}

# Ensure cleanup happens on exit
trap cleanup_container EXIT

# Test execution function
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
    echo "  🔍 Debug: Running command for details..."
    $RUNTIME exec "$CONTAINER_ID" /bin/bash -c "$test_cmd" || true
    # Store failed test name for summary
    FAILED_TESTS+=("$test_name")
    return 1
  fi
}

# Common tests for all image types
run_common_tests() {
  echo "📦 Running common bootc tests..."
  
  if run_test "bootc status" "bootc status"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "systemd version" "systemctl --version | head -1"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "podman runtime" "podman --version"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "basic filesystem" "test -d /usr && test -d /etc && test -d /var"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "bootc container config" "test -f /usr/lib/bootc/install/05-users.toml || test -d /usr/lib/bootc"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
}

# K3s specific tests
run_k3s_tests() {
  echo "🎯 Running K3s comprehensive tests..."
  
  # Core binaries with functionality check
  if run_test "k3s binary & help" "k3s --version && k3s --help | head -1"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "kubectl binary & help" "kubectl version --client --output=json | grep gitVersion || command -v kubectl"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # OpenTelemetry collector
  if run_test "otelcol binary & config" "command -v otelcol && otelcol --version"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "otelcol config file" "test -f /etc/otelcol/config.yaml || test -f /etc/otelcol-contrib/config.yaml"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # K3s configuration and manifests
  if run_test "k3s config directory" "test -d /etc/rancher/k3s"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "k3s manifests content" "test -d /etc/rancher/k3s/manifests && find /etc/rancher/k3s/manifests -name '*.yaml' -o -name '*.yml' | wc -l | grep -v '^0$'"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # Systemd services
  if run_test "k3s systemd service" "test -f /etc/systemd/system/k3s.service || systemctl cat k3s >/dev/null 2>&1"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # Container images (offline capability)
  if run_test "k3s image directory" "test -d /var/lib/rancher/k3s/agent/images || ls /var/lib/rancher/k3s/server/static/charts/ 2>/dev/null | wc -l | grep -v '^0$'"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # CNI and networking
  if run_test "CNI plugins" "test -d /opt/cni/bin && ls /opt/cni/bin/ | wc -l | grep -v '^0$'"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
}

# MicroShift specific tests
run_microshift_tests() {
  echo "🎯 Running MicroShift comprehensive tests..."
  
  # Core binaries with functionality check
  if run_test "microshift binary & version" "microshift version --output=json | grep gitVersion || command -v microshift"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "kubectl binary & help" "kubectl version --client --output=json | grep gitVersion || command -v kubectl"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # MicroShift configuration
  if run_test "microshift config directory" "test -d /etc/microshift"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "microshift config file" "test -f /etc/microshift/config.yaml || test -f /etc/microshift/cluster.yaml"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "microshift manifests content" "test -d /etc/microshift/manifests && find /etc/microshift/manifests -name '*.yaml' -o -name '*.yml' | wc -l | grep -v '^0$'"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # Systemd services
  if run_test "microshift systemd service" "test -f /etc/systemd/system/microshift.service || systemctl cat microshift >/dev/null 2>&1"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # OpenShift/Kubernetes components
  if run_test "crictl binary" "command -v crictl && crictl --version"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # Container images and data
  if run_test "microshift data directory" "test -d /var/lib/microshift || test -d /var/lib/microshift-backups"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  # CNI configuration
  if run_test "CNI config" "test -d /etc/cni/net.d || test -f /etc/cni/net.d/100-crio-bridge.conflist"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
}

# Bootc specific tests
run_bootc_tests() {
  echo "🎯 Running comprehensive bootc tests..."
  
  # Additional bootc-specific tests
  if run_test "bootc install support" "bootc install --help | head -1"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "bootc switch support" "bootc switch --help | head -1"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "ostree support" "command -v ostree && ostree --version"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  
  if run_test "systemd boot support" "test -d /usr/lib/systemd/boot || test -f /usr/lib/systemd/systemd-boot"; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
}

# Run tests based on type
run_common_tests

case "$TEST_TYPE" in
  "k3s")
    run_k3s_tests
    ;;
  "microshift")
    run_microshift_tests
    ;;
  "bootc")
    run_bootc_tests
    ;;
  *)
    echo "❌ Unknown test type: $TEST_TYPE"
    echo "Supported types: k3s, microshift, bootc"
    exit 1
    ;;
esac

# Generate results summary
TOTAL=$((PASSED + FAILED))
echo ""
echo "📊 Test Results:"
echo "  Total: $TOTAL, Passed: $PASSED, Failed: $FAILED"

# Show failed tests if any
if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
  echo "❌ Failed tests:"
  for test in "${FAILED_TESTS[@]}"; do
    echo "  - $test"
  done
fi

# Output for GitHub Actions (if GITHUB_OUTPUT is set)
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "test_results=total=$TOTAL,passed=$PASSED,failed=$FAILED" >> "$GITHUB_OUTPUT"
fi

# Exit with appropriate code
if [ $FAILED -eq 0 ]; then
  echo "✅ All tests passed!"
  exit 0
else
  echo "⚠️ $FAILED test(s) failed"
  exit 1
fi 