#!/bin/bash
# Test script for OpenTelemetry observability stack
# This script validates that all components are working correctly

set -euo pipefail

echo "🔍 Testing OpenTelemetry Observability Stack"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
        if kubectl get $resource -n $namespace -o jsonpath='{.status.readyReplicas}' | grep -q "1"; then
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

echo ""
echo "🖥️  Host-level Services"
echo "----------------------"
check_service "otel-collector" "OpenTelemetry Collector"
check_service "microshift" "MicroShift"

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
    echo -e "MicroShift cluster: ${GREEN}✓ Active${NC}"
    
    check_k8s_resource "deployment/otel-collector" "observability" "OTel Collector deployment"
    check_k8s_resource "deployment/jaeger" "observability" "Jaeger deployment"
    
    echo ""
    echo "🔗 Cluster Endpoints"
    echo "--------------------"
    check_endpoint "http://localhost:30317" "Cluster OTLP gRPC (NodePort)"
    check_endpoint "http://localhost:30464/metrics" "Cluster OTel metrics"
    check_endpoint "http://localhost:30686" "Jaeger UI"
    
else
    echo -e "MicroShift cluster: ${RED}✗ Not available${NC}"
fi

echo ""
echo "📊 Quick Metrics Test"
echo "---------------------"
echo "Fetching sample metrics..."

# Test host metrics
echo -n "Host CPU metrics: "
if curl -s http://localhost:9090/metrics | grep -q "system_cpu_utilization"; then
    echo -e "${GREEN}✓ Available${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
fi

# Test cluster metrics (if available)
if curl -s --max-time 5 http://localhost:30464/metrics &>/dev/null; then
    echo -n "Cluster metrics: "
    if curl -s http://localhost:30464/metrics | grep -q "up"; then
        echo -e "${GREEN}✓ Available${NC}"
    else
        echo -e "${RED}✗ Not found${NC}"
    fi
fi

echo ""
echo "🎯 Summary"
echo "----------"
echo "Test completed! Check the results above."
echo ""
echo "Quick access commands:"
echo "- View Jaeger UI: firefox http://localhost:30686"
echo "- Check OTel logs: sudo journalctl -u otel-collector -f"
echo "- Monitor cluster: kubectl get pods -n observability -w"
echo ""
echo "For detailed troubleshooting, run:"
echo "  kubectl describe pods -n observability"
echo "  sudo systemctl status otel-collector" 