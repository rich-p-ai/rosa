#!/bin/bash

# Simple VM status checker to help debug looping issues
# This script only checks status without making any changes

set -e

NAMESPACE="webserver"
VM_NAME="rhel9-webserver-bare-metal"
NODE_SELECTOR="node.kubernetes.io/instance-type=m5.metal"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Check CLI
if command -v oc &> /dev/null; then
    CLI="oc"
elif command -v kubectl &> /dev/null; then
    CLI="kubectl"
else
    echo "Error: Neither 'oc' nor 'kubectl' found"
    exit 1
fi

log "VM Status Checker - READ ONLY MODE"
echo "=================================="

# Check bare metal nodes
echo ""
echo "🖥️  BARE METAL NODES:"
echo "-------------------"
READY_NODES=$($CLI get nodes -l "$NODE_SELECTOR" --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
TOTAL_NODES=$($CLI get nodes -l "$NODE_SELECTOR" --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$TOTAL_NODES" -eq 0 ]; then
    echo -e "${RED}❌ No bare metal nodes found with selector: $NODE_SELECTOR${NC}"
else
    echo -e "${GREEN}✅ Found $TOTAL_NODES bare metal node(s), $READY_NODES ready${NC}"
    $CLI get nodes -l "$NODE_SELECTOR" -o wide
fi

# Check namespace
echo ""
echo "📁 NAMESPACE:"
echo "------------"
if $CLI get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${GREEN}✅ Namespace '$NAMESPACE' exists${NC}"
else
    echo -e "${RED}❌ Namespace '$NAMESPACE' does not exist${NC}"
fi

# Check VM
echo ""
echo "🖥️  VIRTUAL MACHINE:"
echo "------------------"
if $CLI get vm "$VM_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${GREEN}✅ VM '$VM_NAME' exists${NC}"
    
    # Get VM details
    VM_RUNNING=$($CLI get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.running}' 2>/dev/null || echo "unknown")
    VM_READY=$($CLI get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.ready}' 2>/dev/null || echo "unknown")
    
    echo "   Running: $VM_RUNNING"
    echo "   Ready: $VM_READY"
    
    # Check VMI if exists
    if $CLI get vmi "$VM_NAME" -n "$NAMESPACE" &>/dev/null; then
        VMI_PHASE=$($CLI get vmi "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
        VMI_NODE=$($CLI get vmi "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.nodeName}' 2>/dev/null || echo "unknown")
        echo "   VMI Phase: $VMI_PHASE"
        echo "   Running on Node: $VMI_NODE"
        
        # Check if running on bare metal
        if [ "$VMI_NODE" != "unknown" ]; then
            NODE_TYPE=$($CLI get node "$VMI_NODE" -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}' 2>/dev/null || echo "unknown")
            if [ "$NODE_TYPE" = "m5.metal" ]; then
                echo -e "   ${GREEN}✅ Running on bare metal node${NC}"
            else
                echo -e "   ${YELLOW}⚠️  Not running on bare metal (node type: $NODE_TYPE)${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  No VMI found (VM may be stopped)${NC}"
    fi
    
    echo ""
    echo "VM Details:"
    $CLI get vm "$VM_NAME" -n "$NAMESPACE"
    
else
    echo -e "${RED}❌ VM '$VM_NAME' does not exist${NC}"
fi

# Check DataVolume
echo ""
echo "💾 DATA VOLUMES:"
echo "---------------"
if $CLI get dv -n "$NAMESPACE" &>/dev/null; then
    $CLI get dv -n "$NAMESPACE"
else
    echo "No DataVolumes found"
fi

# Check PVCs
echo ""
echo "💿 PERSISTENT VOLUME CLAIMS:"
echo "---------------------------"
if $CLI get pvc -n "$NAMESPACE" &>/dev/null; then
    $CLI get pvc -n "$NAMESPACE"
else
    echo "No PVCs found"
fi

# Check Services
echo ""
echo "🌐 SERVICES:"
echo "-----------"
if $CLI get svc -n "$NAMESPACE" &>/dev/null; then
    $CLI get svc -n "$NAMESPACE"
else
    echo "No services found"
fi

# Check Recent Events
echo ""
echo "📋 RECENT EVENTS:"
echo "----------------"
$CLI get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10

# Summary
echo ""
echo "🎯 SUMMARY:"
echo "----------"
if [ "$READY_NODES" -gt 0 ]; then
    echo -e "${GREEN}✅ Bare metal nodes available${NC}"
else
    echo -e "${RED}❌ No ready bare metal nodes${NC}"
fi

if $CLI get vm "$VM_NAME" -n "$NAMESPACE" &>/dev/null; then
    VM_RUNNING=$($CLI get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.running}' 2>/dev/null || echo "false")
    if [ "$VM_RUNNING" = "true" ]; then
        echo -e "${GREEN}✅ VM is configured to run${NC}"
    else
        echo -e "${YELLOW}⚠️  VM is stopped${NC}"
    fi
else
    echo -e "${RED}❌ VM does not exist${NC}"
fi

echo ""
log "Status check complete"
