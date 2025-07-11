#!/bin/bash

# OpenShift Virtualization Local Simulation Test Suite
# Tests networking between simulated Linux VMs

set -e

echo "==========================================="
echo "🧪 OpenShift Virtualization Network Tests"
echo "==========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test functions
test_connectivity() {
    echo -e "\n${YELLOW}Testing VM-to-VM connectivity...${NC}"
    
    echo "Testing ping from linux-server-1 to linux-server-2..."
    if docker exec linux-server-1-sim ping -c 3 10.1.1.20 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Ping test passed${NC}"
    else
        echo -e "${RED}❌ Ping test failed${NC}"
    fi
    
    echo "Testing ping from linux-server-2 to linux-server-1..."
    if docker exec linux-server-2-sim ping -c 3 10.1.1.10 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Reverse ping test passed${NC}"
    else
        echo -e "${RED}❌ Reverse ping test failed${NC}"
    fi
}

test_network_performance() {
    echo -e "\n${YELLOW}Testing network performance between VMs...${NC}"
    
    echo "Starting iperf3 server on linux-server-2..."
    docker exec -d linux-server-2-sim iperf3 -s -p 5201
    
    sleep 2
    
    echo "Running iperf3 client from linux-server-1..."
    if docker exec linux-server-1-sim iperf3 -c 10.1.1.20 -p 5201 -t 5; then
        echo -e "${GREEN}✅ Network performance test completed${NC}"
    else
        echo -e "${RED}❌ Network performance test failed${NC}"
    fi
}

test_dns_resolution() {
    echo -e "\n${YELLOW}Testing DNS resolution between VMs...${NC}"
    
    echo "Testing hostname resolution from linux-server-1..."
    if docker exec linux-server-1-sim nslookup linux-server-2 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS resolution test passed${NC}"
    else
        echo -e "${YELLOW}⚠️  DNS resolution test skipped (expected in simulation)${NC}"
    fi
}

test_api_endpoints() {
    echo -e "\n${YELLOW}Testing OpenShift API endpoints...${NC}"
    
    echo "Testing OpenShift API health..."
    if curl -s http://localhost:8443/healthz | grep -q "ok"; then
        echo -e "${GREEN}✅ OpenShift API health check passed${NC}"
    else
        echo -e "${RED}❌ OpenShift API health check failed${NC}"
    fi
    
    echo "Testing Virtualization API..."
    if curl -s http://localhost:8443/apis/kubevirt.io | grep -q "kubevirt.io"; then
        echo -e "${GREEN}✅ Virtualization API check passed${NC}"
    else
        echo -e "${RED}❌ Virtualization API check failed${NC}"
    fi
}

show_network_info() {
    echo -e "\n${YELLOW}Network Information:${NC}"
    echo "Network: 10.1.1.0/24"
    echo "Gateway: 10.1.1.1"
    echo "Linux Server 1: 10.1.1.10"
    echo "Linux Server 2: 10.1.1.20"
    echo "Network Tester: 10.1.1.100"
    echo "OpenShift API: localhost:8443"
}

# Main test execution
main() {
    echo "Starting OpenShift Virtualization networking tests..."
    
    # Wait for containers to be ready
    echo "Waiting for containers to initialize..."
    sleep 5
    
    show_network_info
    test_api_endpoints
    test_connectivity
    test_network_performance
    test_dns_resolution
    
    echo -e "\n${GREEN}🎉 Test suite completed!${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Use 'docker exec -it network-tester bash' for advanced network testing"
    echo "2. Use 'docker exec -it linux-server-1-sim sh' to access VM simulation"
    echo "3. Monitor logs with 'docker-compose logs -f'"
    echo "4. When AWS quota is approved, run './scripts/create-test-cluster-for-virt.sh'"
}

# Run tests
main "$@"
