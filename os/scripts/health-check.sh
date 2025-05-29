#!/bin/bash
# Health check script for Edge OS containers
# Inspired by production containerfile practices

set -euo pipefail

# Health check function
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

# Main health checks
main() {
    echo "🏥 Edge OS Health Check"
    echo "======================"
    
    local failures=0
    
    # System health
    check_health "systemd" "systemctl is-system-running --quiet || systemctl is-system-running | grep -E '(running|degraded)'" "System is operational" || ((failures++))
    
    # Network connectivity
    check_health "network" "ip route get 8.8.8.8" "Network routing available" || ((failures++))
    
    # Container runtime
    check_health "podman" "podman version" "Podman runtime available" || ((failures++))
    
    # K3s specific checks (if K3s is installed)
    if command -v k3s >/dev/null 2>&1; then
        check_health "k3s-binary" "k3s --version" "K3s binary available" || ((failures++))
        check_health "k3s-images" "test -f /var/lib/rancher/k3s/agent/images/k3s-airgap-images.tar.gz" "K3s airgap images present" || ((failures++))
    fi
    
    # MicroShift specific checks (if MicroShift is installed)
    if command -v microshift >/dev/null 2>&1; then
        check_health "microshift-binary" "microshift version" "MicroShift binary available" || ((failures++))
        check_health "microshift-config" "test -f /etc/microshift/config.yaml" "MicroShift configuration present" || ((failures++))
    fi
    
    # OpenTelemetry Collector
    check_health "otelcol" "/usr/bin/otelcol --version" "OpenTelemetry Collector available" || ((failures++))
    check_health "otelcol-config" "test -f /etc/otelcol/config.yaml" "OpenTelemetry configuration present" || ((failures++))
    
    # Storage health
    check_health "disk-space" "test $(df / | tail -1 | awk '{print $4}') -gt 1048576" "Sufficient disk space (>1GB free)" || ((failures++))
    
    echo ""
    echo "Health Check Summary:"
    echo "===================="
    
    if [ $failures -eq 0 ]; then
        echo "🎉 All health checks passed!"
        exit 0
    else
        echo "⚠️  $failures health check(s) failed"
        exit 1
    fi
}

# Run health check
main "$@" 