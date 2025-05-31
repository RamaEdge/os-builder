#!/bin/bash
# Test script for OpenTelemetry observability stack
# This script validates that all components are working correctly
# Works with both K3s and MicroShift distributions

set -euo pipefail

echo "🔍 Testing OpenTelemetry Observability Stack"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect Kubernetes distribution
DISTRO="unknown"
K8S_SERVICE=""
if systemctl is-active --quiet k3s; then
    DISTRO="k3s"
    K8S_SERVICE="k3s"
    echo -e "${BLUE}📦 Detected distribution: K3s${NC}"
elif systemctl is-active --quiet microshift; then
    DISTRO="microshift"
    K8S_SERVICE="microshift"
    echo -e "${BLUE}📦 Detected distribution: MicroShift${NC}"
else
    echo -e "${YELLOW}⚠️  No Kubernetes distribution detected${NC}"
fi

echo ""

# Function to check service status
check_service() {
    local service=$1
    local description=$2
    
    echo -n "Checking $description... "
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}✓ Active${NC}"
        return 0
    else
        echo -e "${RED}✗ Inactive${NC}"
        return 1
    fi
}

# Function to check HTTP endpoint
check_endpoint() {
    local url=$1
    local description=$2
    
    echo -n "Checking $description... "
    if curl -s --max-time 5 $url > /dev/null; then
        echo -e "${GREEN}✓ Accessible${NC}"
        return 0
    else
        echo -e "${RED}✗ Not accessible${NC}"
        return 1
    fi
}

# Function to check Kubernetes resource
check_k8s_resource() {
    local resource=$1
    local namespace=$2
    local description=$3
    
    echo -n "Checking $description... "
    if kubectl get $resource -n $namespace &>/dev/null; then
        local ready_replicas=$(kubectl get $resource -n $namespace -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [[ "$ready_replicas" =~ ^[0-9]+$ ]] && [ "$ready_replicas" -gt 0 ]; then
            echo -e "${GREEN}✓ Ready${NC}"
            return 0
        else
            echo -e "${YELLOW}! Not ready${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Not found${NC}"
        return 1
    fi
}

echo "🖥️  Host-level Services"
echo "----------------------"
check_service "otelcol" "OpenTelemetry Collector"

if [ "$DISTRO" != "unknown" ]; then
    check_service "$K8S_SERVICE" "$DISTRO"
else
    echo -e "${YELLOW}Skipping Kubernetes service check${NC}"
fi

echo ""
echo "🌐 Network Endpoints"
echo "--------------------"
check_endpoint "http://localhost:4317" "OTLP gRPC endpoint"
check_endpoint "http://localhost:4318" "OTLP HTTP endpoint" 
check_endpoint "http://localhost:9090/metrics" "Host Prometheus metrics"
check_endpoint "http://localhost:8888/metrics" "OTel internal metrics"

echo ""
echo "☸️  Kubernetes Resources"
echo "-----------------------"
if kubectl get nodes &>/dev/null; then
    echo -e "$DISTRO cluster: ${GREEN}✓ Active${NC}"
    
    # Check if observability namespace exists
    if kubectl get namespace observability &>/dev/null; then
        check_k8s_resource "deployment/otel-collector" "observability" "OTel Collector deployment"
        check_k8s_resource "deployment/jaeger" "observability" "Jaeger deployment"
    else
        echo -e "${YELLOW}Observability namespace not found - checking default namespace${NC}"
        kubectl get deployments --all-namespaces | grep -E "(otel|jaeger)" || echo -e "${YELLOW}No observability deployments found${NC}"
    fi
    
    echo ""
    echo "🔗 Cluster Endpoints"
    echo "--------------------"
    check_endpoint "http://localhost:30317" "Cluster OTLP gRPC (NodePort)"
    check_endpoint "http://localhost:30464/metrics" "Cluster OTel metrics"
    check_endpoint "http://localhost:30686" "Jaeger UI"
    
else
    echo -e "$DISTRO cluster: ${RED}✗ Not available${NC}"
    echo -e "${YELLOW}Make sure kubectl is configured and cluster is running${NC}"
fi

echo ""
echo "📊 Quick Metrics Test"
echo "---------------------"
echo "Fetching sample metrics..."

# Test host metrics
echo -n "Host CPU metrics: "
if curl -s http://localhost:9090/metrics | grep -q "system_cpu_utilization\|cpu_usage"; then
    echo -e "${GREEN}✓ Available${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
fi

# Test cluster metrics (if available)
if curl -s --max-time 5 http://localhost:30464/metrics &>/dev/null; then
    echo -n "Cluster metrics: "
    if curl -s http://localhost:30464/metrics | grep -q "up\|otelcol"; then
        echo -e "${GREEN}✓ Available${NC}"
    else
        echo -e "${RED}✗ Not found${NC}"
    fi
else
    echo -e "${YELLOW}Cluster metrics endpoint not accessible${NC}"
fi

echo ""
echo "🎯 Summary"
echo "----------"
echo -e "Test completed for ${BLUE}$DISTRO${NC} distribution!"
echo ""
echo "Quick access commands:"
echo "- View Jaeger UI: firefox http://localhost:30686"
echo "- Check OTel logs: sudo journalctl -u otelcol -f"

if [ "$DISTRO" == "k3s" ]; then
    echo "- Monitor cluster: kubectl get pods -A -w"
    echo "- K3s logs: sudo journalctl -u k3s -f"
    echo "- K3s status: sudo systemctl status k3s"
elif [ "$DISTRO" == "microshift" ]; then
    echo "- Monitor cluster: kubectl get pods -n observability -w"
    echo "- MicroShift logs: sudo journalctl -u microshift -f"
    echo "- MicroShift status: sudo systemctl status microshift"
fi

echo ""
echo "For detailed troubleshooting, run:"
if kubectl get nodes &>/dev/null; then
    echo "  kubectl get pods --all-namespaces"
    echo "  kubectl describe pods -n observability"
fi
echo "  sudo systemctl status otelcol"
if [ "$DISTRO" != "unknown" ]; then
    echo "  sudo systemctl status $K8S_SERVICE"
fi 