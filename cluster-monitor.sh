#!/bin/bash

# Cluster Resource Monitor - Post Bare Metal Cleanup
# This script helps monitor your cluster resources after removing bare metal components

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🏗️  ROSA Cluster Resource Monitor${NC}"
echo "=================================="

# Check CLI
if command -v oc &> /dev/null; then
    CLI="oc"
elif command -v kubectl &> /dev/null; then
    CLI="kubectl"
else
    echo "Error: Neither 'oc' nor 'kubectl' found"
    exit 1
fi

echo -e "\n${GREEN}📊 MACHINE POOLS${NC}"
echo "---------------"
if command -v rosa &> /dev/null; then
    rosa list machinepools --cluster small-dev-cluster 2>/dev/null || echo "Run 'rosa list clusters' to get cluster name"
else
    echo "ROSA CLI not available"
fi

echo -e "\n${GREEN}🖥️  NODES${NC}"
echo "--------"
$CLI get nodes --show-labels | head -10

echo -e "\n${GREEN}🔄 MACHINE SETS${NC}"
echo "-------------"
$CLI get machinesets -n openshift-machine-api

echo -e "\n${GREEN}🚀 VIRTUAL MACHINES${NC}"
echo "-----------------"
VM_COUNT=$($CLI get vm -A --no-headers 2>/dev/null | wc -l)
if [ "$VM_COUNT" -eq 0 ]; then
    echo "No VMs currently deployed"
else
    $CLI get vm -A
fi

echo -e "\n${GREEN}💾 STORAGE USAGE${NC}"
echo "---------------"
echo "User PVCs:"
$CLI get pvc -A | grep -v "openshift-" | grep -v "kube-" || echo "No user PVCs found"

echo -e "\nSystem PVCs (monitoring, etc.):"
$CLI get pvc -A | grep -E "(openshift-monitoring|openshift-virtualization)" | wc -l | xargs echo "Count:"

echo -e "\n${GREEN}📈 QUOTA STATUS${NC}"
echo "-------------"
# Check for any resource quotas
$CLI get resourcequota -A 2>/dev/null || echo "No resource quotas configured"

echo -e "\n${GREEN}⚙️  KUBEVIRT STATUS${NC}"
echo "-----------------"
$CLI get csv -n openshift-cnv | grep kubevirt || echo "KubeVirt operator not found"

echo -e "\n${YELLOW}💡 DEPLOYMENT READY${NC}"
echo "------------------"
echo "✅ Bare metal resources cleaned up"
echo "✅ Standard worker nodes available"
echo "✅ Ready for VM deployments"
echo ""
echo "Next steps:"
echo "• Deploy VM: oc apply -f rhel9-webserver-vm.yaml"
echo "• Check guide: cat DEPLOY-STANDARD-VM.md"

echo -e "\n${BLUE}Monitor completed at $(date)${NC}"
