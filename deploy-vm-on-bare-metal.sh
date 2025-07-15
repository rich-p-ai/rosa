#!/bin/bash

# DEPRECATED: Bare metal machine pool has been removed due to quota constraints
# This script is kept for reference but will not function without bare metal nodes
# Use rhel9-webserver-vm.yaml for standard VM deployments instead
#
# Script to deploy RHEL9 webserver VM when bare metal node becomes available
# This script monitors for available bare metal nodes and deploys the VM automatically

echo "⚠️  WARNING: Bare metal machine pool has been removed from the cluster"
echo "   Use standard VM deployment instead: oc apply -f rhel9-webserver-vm.yaml"
echo "   This script is preserved for reference only"
echo ""

set -e

NAMESPACE="webserver"
VM_NAME="rhel9-webserver-bare-metal"
NODE_SELECTOR="node.kubernetes.io/instance-type=m5.metal"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if kubectl/oc is available
check_cli() {
    if command -v oc &> /dev/null; then
        CLI="oc"
        log "Using OpenShift CLI (oc)"
    elif command -v kubectl &> /dev/null; then
        CLI="kubectl"
        log "Using Kubernetes CLI (kubectl)"
    else
        error "Neither 'oc' nor 'kubectl' command found. Please install one of them."
        exit 1
    fi
}

# Check if bare metal nodes are available
check_bare_metal_nodes() {
    log "Checking for available bare metal nodes..."
    
    # Get nodes with the bare metal instance type
    AVAILABLE_NODES=$($CLI get nodes -l "$NODE_SELECTOR" --no-headers 2>/dev/null | wc -l)
    READY_NODES=$($CLI get nodes -l "$NODE_SELECTOR" --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
    
    if [ "$AVAILABLE_NODES" -eq 0 ]; then
        warning "No bare metal nodes found with selector: $NODE_SELECTOR"
        return 1
    fi
    
    if [ "$READY_NODES" -eq 0 ]; then
        warning "Found $AVAILABLE_NODES bare metal node(s), but none are in Ready state"
        return 1
    fi
    
    success "Found $READY_NODES ready bare metal node(s)"
    return 0
}

# Check if VM already exists
check_vm_exists() {
    if $CLI get vm "$VM_NAME" -n "$NAMESPACE" &>/dev/null; then
        warning "VM '$VM_NAME' already exists in namespace '$NAMESPACE'"
        return 0
    fi
    return 1
}

# Deploy namespace
deploy_namespace() {
    log "Deploying namespace..."
    if $CLI get namespace "$NAMESPACE" &>/dev/null; then
        log "Namespace '$NAMESPACE' already exists"
    else
        $CLI apply -f "$SCRIPT_DIR/rhel9-webserver-namespace.yaml"
        success "Namespace '$NAMESPACE' created"
    fi
}

# Deploy the VM
deploy_vm() {
    log "Deploying RHEL9 webserver VM on bare metal..."
    
    # Check one more time if VM was created by another process
    if $CLI get vm "$VM_NAME" -n "$NAMESPACE" &>/dev/null; then
        warning "VM was just created by another process. Skipping deployment."
        return 0
    fi
    
    # Apply the VM configuration
    $CLI apply -f "$SCRIPT_DIR/rhel9-webserver-vm-bare-metal.yaml"
    success "VM '$VM_NAME' deployment initiated"
    
    # Wait for VM to be created and ready
    log "Waiting for VM to be created..."
    timeout 60 bash -c "
        while ! $CLI get vm \"$VM_NAME\" -n \"$NAMESPACE\" &>/dev/null; do
            sleep 2
        done
    " || {
        error "Timeout waiting for VM to be created"
        return 1
    }
    
    log "VM created. Waiting for VM to be ready..."
    timeout 600 $CLI wait --for=condition=Ready vm/"$VM_NAME" -n "$NAMESPACE" || {
        error "Timeout waiting for VM to be ready"
        # Show VM status for debugging
        log "VM Status:"
        $CLI get vm "$VM_NAME" -n "$NAMESPACE" -o yaml
        return 1
    }
    
    success "VM '$VM_NAME' is ready"
}

# Deploy service
deploy_service() {
    log "Deploying service..."
    $CLI apply -f "$SCRIPT_DIR/rhel9-webserver-service.yaml"
    success "Service deployed"
}

# Monitor VM status
monitor_vm() {
    log "Monitoring VM status..."
    $CLI get vm "$VM_NAME" -n "$NAMESPACE" -w
}

# Main deployment function
deploy() {
    log "Starting deployment process..."
    
    deploy_namespace
    
    if check_vm_exists; then
        # Get VM status
        VM_RUNNING=$($CLI get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.running}' 2>/dev/null || echo "false")
        VM_PHASE=$($CLI get vmi "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        
        log "VM already exists. Status: running=$VM_RUNNING, phase=$VM_PHASE"
        
        if [ "$VM_RUNNING" = "true" ] && [ "$VM_PHASE" = "Running" ]; then
            success "VM is already running successfully. No action needed."
            log "VM Information:"
            $CLI get vm "$VM_NAME" -n "$NAMESPACE"
            $CLI get vmi "$VM_NAME" -n "$NAMESPACE" 2>/dev/null || true
            return 0
        elif [ "$VM_RUNNING" = "true" ] && [ "$VM_PHASE" != "Running" ]; then
            warning "VM is set to run but not in Running phase. Waiting for it to start..."
            log "Waiting for VM to reach Running state..."
            timeout 300 bash -c "
                while true; do
                    PHASE=\$($CLI get vmi \"$VM_NAME\" -n \"$NAMESPACE\" -o jsonpath='{.status.phase}' 2>/dev/null || echo \"Unknown\")
                    if [ \"\$PHASE\" = \"Running\" ]; then
                        break
                    fi
                    sleep 5
                done
            " && success "VM is now running" || warning "Timeout waiting for VM to start"
            return 0
        else
            read -p "VM exists but is not running. Do you want to start it? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                log "Starting existing VM..."
                $CLI patch vm "$VM_NAME" -n "$NAMESPACE" --type='merge' -p='{"spec":{"running":true}}'
                success "VM start initiated"
                return 0
            else
                read -p "Do you want to delete and recreate the VM? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log "Deployment cancelled"
                    return 0
                fi
                log "Deleting existing VM..."
                $CLI delete vm "$VM_NAME" -n "$NAMESPACE" --wait=true
                log "Existing VM deleted"
            fi
        fi
    fi
    
    deploy_vm
    deploy_service
    
    success "Deployment completed successfully!"
    
    # Show VM information
    log "VM Information:"
    $CLI get vm "$VM_NAME" -n "$NAMESPACE"
    $CLI get vmi "$VM_NAME" -n "$NAMESPACE" 2>/dev/null || true
}

# Wait for bare metal node function
wait_for_bare_metal() {
    log "Waiting for bare metal node to become available..."
    
    while true; do
        # First check if VM already exists and is running
        if check_vm_exists; then
            VM_RUNNING=$($CLI get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.running}' 2>/dev/null || echo "false")
            if [ "$VM_RUNNING" = "true" ]; then
                success "VM '$VM_NAME' already exists and is running. Monitoring mode..."
                monitor_vm
                break
            else
                log "VM exists but is not running. Checking if we should start it..."
                read -p "VM exists but is stopped. Do you want to start it? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    $CLI patch vm "$VM_NAME" -n "$NAMESPACE" --type='merge' -p='{"spec":{"running":true}}'
                    success "VM started"
                fi
                break
            fi
        fi
        
        if check_bare_metal_nodes; then
            success "Bare metal node is available! Starting deployment..."
            deploy
            success "Deployment completed. Exiting wait loop."
            break
        else
            log "No ready bare metal nodes found. Checking again in 60 seconds..."
            sleep 60
        fi
    done
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy RHEL9 webserver VM on bare metal nodes"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -w, --wait        Wait for bare metal node to become available and deploy"
    echo "  -d, --deploy      Deploy immediately if bare metal node is available"
    echo "  -s, --status      Show current status of nodes, namespace, VM, and services"
    echo "  -m, --monitor     Monitor VM status (continuous)"
    echo "  -c, --check       Check bare metal nodes only (no deployment)"
    echo "  --start           Start an existing stopped VM"
    echo "  --stop            Stop a running VM"
    echo ""
    echo "Examples:"
    echo "  $0 --wait         # Wait for bare metal node and deploy automatically"
    echo "  $0 --deploy       # Deploy immediately if bare metal node is ready"
    echo "  $0 --status       # Check current status"
    echo "  $0 --check        # Just check for bare metal nodes"
    echo "  $0 --start        # Start existing VM"
    echo "  $0 --stop         # Stop running VM"
}

# Show current status
show_status() {
    log "Current status:"
    
    echo ""
    echo "=== Bare Metal Nodes ==="
    if $CLI get nodes -l "$NODE_SELECTOR" &>/dev/null; then
        $CLI get nodes -l "$NODE_SELECTOR"
    else
        echo "No bare metal nodes found"
    fi
    
    echo ""
    echo "=== Namespace ==="
    if $CLI get namespace "$NAMESPACE" &>/dev/null; then
        echo "Namespace '$NAMESPACE' exists"
    else
        echo "Namespace '$NAMESPACE' does not exist"
    fi
    
    echo ""
    echo "=== VM Status ==="
    if $CLI get vm "$VM_NAME" -n "$NAMESPACE" &>/dev/null; then
        $CLI get vm "$VM_NAME" -n "$NAMESPACE"
        echo ""
        $CLI get vmi "$VM_NAME" -n "$NAMESPACE" 2>/dev/null || echo "VMI not found"
    else
        echo "VM '$VM_NAME' does not exist"
    fi
    
    echo ""
    echo "=== Service Status ==="
    $CLI get svc -n "$NAMESPACE" 2>/dev/null || echo "No services found in namespace '$NAMESPACE'"
}

# Start VM
start_vm() {
    if ! check_vm_exists; then
        error "VM '$VM_NAME' does not exist"
        return 1
    fi
    
    VM_RUNNING=$($CLI get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.running}' 2>/dev/null || echo "false")
    if [ "$VM_RUNNING" = "true" ]; then
        warning "VM '$VM_NAME' is already set to running"
        return 0
    fi
    
    log "Starting VM '$VM_NAME'..."
    $CLI patch vm "$VM_NAME" -n "$NAMESPACE" --type='merge' -p='{"spec":{"running":true}}'
    success "VM start initiated"
}

# Stop VM
stop_vm() {
    if ! check_vm_exists; then
        error "VM '$VM_NAME' does not exist"
        return 1
    fi
    
    VM_RUNNING=$($CLI get vm "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.running}' 2>/dev/null || echo "false")
    if [ "$VM_RUNNING" = "false" ]; then
        warning "VM '$VM_NAME' is already stopped"
        return 0
    fi
    
    log "Stopping VM '$VM_NAME'..."
    $CLI patch vm "$VM_NAME" -n "$NAMESPACE" --type='merge' -p='{"spec":{"running":false}}'
    success "VM stop initiated"
}

# Just check nodes without any deployment action
check_nodes_only() {
    log "Checking bare metal node availability..."
    
    echo ""
    echo "=== Bare Metal Nodes Check ==="
    if check_bare_metal_nodes; then
        echo ""
        $CLI get nodes -l "$NODE_SELECTOR" -o wide
        echo ""
        success "Bare metal nodes are available and ready"
    else
        echo ""
        echo "Searching for any nodes with the selector..."
        $CLI get nodes -l "$NODE_SELECTOR" 2>/dev/null || echo "No nodes found with selector: $NODE_SELECTOR"
        echo ""
        warning "No ready bare metal nodes available"
    fi
}

# Main script logic
main() {
    check_cli
    
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -w|--wait)
            wait_for_bare_metal
            ;;
        -d|--deploy)
            if check_bare_metal_nodes; then
                deploy
            else
                error "No ready bare metal nodes available. Use --wait to wait for nodes."
                exit 1
            fi
            ;;
        -s|--status)
            show_status
            ;;
        -m|--monitor)
            if check_vm_exists; then
                monitor_vm
            else
                error "VM '$VM_NAME' does not exist"
                exit 1
            fi
            ;;
        -c|--check)
            check_nodes_only
            ;;
        --start)
            start_vm
            ;;
        --stop)
            stop_vm
            ;;
        "")
            show_help
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
