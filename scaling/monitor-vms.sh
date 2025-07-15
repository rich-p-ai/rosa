#!/bin/bash

# VM Status Monitor for ROSA Scaling Environment
# Monitors all VMs, SSH access, and NLB health across the scaled deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${CYAN}[MONITOR]${NC} $1"; }

# Configuration
AWS_REGION="us-east-1"
NLB_BASE_NAME="rosa-ssh-nlb"
APPS_DIR="/Users/richardsawyers/work/rosa/apps"

echo "========================================="
echo "📊 ROSA VM Status Monitor"
echo "========================================="
echo "Timestamp: $(date)"
echo ""

# Check OpenShift connection
check_cluster_connection() {
    log_header "Cluster Connection Status"
    
    if oc whoami >/dev/null 2>&1; then
        local cluster_info=$(oc cluster-info | head -1)
        local user=$(oc whoami)
        log_success "Connected to cluster as: $user"
        echo "  $cluster_info"
    else
        log_error "Not connected to OpenShift cluster"
        echo "  Run: oc login <cluster-url>"
        return 1
    fi
    echo ""
}

# Scan for all VM deployments
scan_vm_deployments() {
    log_header "VM Deployment Discovery"
    
    # Find all application directories
    local app_dirs=($(find $APPS_DIR -mindepth 1 -maxdepth 1 -type d -not -name ".*" | sort))
    
    echo "Found ${#app_dirs[@]} application directories:"
    
    for app_dir in "${app_dirs[@]}"; do
        local app_name=$(basename "$app_dir")
        local has_ssh=false
        local vm_type="unknown"
        local ssh_port="unknown"
        
        # Check for SSH components
        if [[ -f "$app_dir/ssh-deployment.yaml" ]]; then
            has_ssh=true
        fi
        
        # Extract VM type from kustomization labels
        if [[ -f "$app_dir/kustomization.yaml" ]]; then
            vm_type=$(grep "vm-type:" "$app_dir/kustomization.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "legacy")
            ssh_port=$(grep "ssh-port:" "$app_dir/kustomization.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "unknown")
        fi
        
        # Status indicator
        local ssh_status="❌"
        if [[ "$has_ssh" == "true" ]]; then
            ssh_status="✅"
        fi
        
        printf "  %-20s | %-10s | %-8s | %s\n" "$app_name" "$vm_type" "$ssh_port" "$ssh_status"
    done
    echo ""
}

# Check VM pod status in cluster
check_vm_pod_status() {
    log_header "VM Pod Status"
    
    local total_vms=0
    local running_vms=0
    local failed_vms=0
    
    # Get all namespaces that look like VMs
    local namespaces=($(oc get namespaces -o name | grep -E "(frontend|backend|vm-|dev-|test-|staging-|angular|react|vue|nodejs|django)" | cut -d'/' -f2))
    
    printf "%-20s | %-15s | %-10s | %-10s | %s\n" "NAMESPACE" "MAIN POD" "SSH POD" "SSH PORT" "STATUS"
    echo "-------------------|----------------|-----------|-----------|--------"
    
    for ns in "${namespaces[@]}"; do
        total_vms=$((total_vms + 1))
        
        # Check main application pod
        local main_pod_status=$(oc get pods -n "$ns" -l "app=$ns" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
        
        # Check SSH pod
        local ssh_pod_status=$(oc get pods -n "$ns" -l "app=${ns}-ssh" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
        
        # Get SSH port from service
        local ssh_port=$(oc get service -n "$ns" "${ns}-ssh-service" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
        
        # Status indicators
        local main_indicator="❌"
        local ssh_indicator="❌"
        local overall_status="FAILED"
        
        if [[ "$main_pod_status" == "Running" ]]; then
            main_indicator="✅"
        fi
        
        if [[ "$ssh_pod_status" == "Running" ]]; then
            ssh_indicator="✅"
            if [[ "$main_pod_status" == "Running" ]]; then
                overall_status="HEALTHY"
                running_vms=$((running_vms + 1))
            fi
        fi
        
        if [[ "$overall_status" == "FAILED" ]]; then
            failed_vms=$((failed_vms + 1))
        fi
        
        printf "%-20s | %-15s | %-10s | %-10s | %s\n" "$ns" "$main_indicator $main_pod_status" "$ssh_indicator $ssh_pod_status" "$ssh_port" "$overall_status"
    done
    
    echo ""
    log_info "Summary: $running_vms running, $failed_vms failed, $total_vms total VMs"
    echo ""
}

# Check NLB status
check_nlb_status() {
    log_header "Network Load Balancer Status"
    
    # Check AWS CLI connection
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_warning "AWS CLI not configured. Skipping NLB status check."
        return
    fi
    
    # Get all NLBs with our naming pattern
    local nlb_arns=($(aws elbv2 describe-load-balancers --region $AWS_REGION \
        --query "LoadBalancers[?contains(LoadBalancerName, '$NLB_BASE_NAME')].LoadBalancerArn" \
        --output text 2>/dev/null || echo ""))
    
    if [[ ${#nlb_arns[@]} -eq 0 ]]; then
        log_warning "No NLBs found with pattern: $NLB_BASE_NAME"
        return
    fi
    
    printf "%-20s | %-50s | %-10s | %s\n" "NLB NAME" "DNS NAME" "STATE" "LISTENERS"
    echo "-------------------|--------------------------------------------------|-----------|----------"
    
    for nlb_arn in "${nlb_arns[@]}"; do
        # Get NLB details
        local nlb_info=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
            --load-balancer-arns "$nlb_arn" \
            --query 'LoadBalancers[0].[LoadBalancerName,DNSName,State.Code]' \
            --output text 2>/dev/null)
        
        local nlb_name=$(echo "$nlb_info" | cut -f1)
        local nlb_dns=$(echo "$nlb_info" | cut -f2)
        local nlb_state=$(echo "$nlb_info" | cut -f3)
        
        # Count listeners
        local listener_count=$(aws elbv2 describe-listeners --region $AWS_REGION \
            --load-balancer-arn "$nlb_arn" \
            --query 'length(Listeners)' --output text 2>/dev/null || echo "0")
        
        # State indicator
        local state_indicator="❌"
        if [[ "$nlb_state" == "active" ]]; then
            state_indicator="✅"
        fi
        
        printf "%-20s | %-50s | %-10s | %s\n" "$nlb_name" "$nlb_dns" "$state_indicator $nlb_state" "$listener_count ports"
    done
    echo ""
}

# Test SSH connectivity
test_ssh_connectivity() {
    log_header "SSH Connectivity Test (Sample)"
    
    # Test a few random SSH endpoints
    local namespaces=($(oc get namespaces -o name | grep -E "(frontend|backend|vm-)" | cut -d'/' -f2 | head -3))
    
    for ns in "${namespaces[@]}"; do
        local ssh_port=$(oc get service -n "$ns" "${ns}-ssh-service" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
        
        if [[ -n "$ssh_port" ]]; then
            log_info "Testing SSH connectivity for $ns:$ssh_port..."
            
            # Get worker node IP for testing
            local worker_ip=$(oc get nodes -l node-role.kubernetes.io/worker \
                -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
            
            if [[ -n "$worker_ip" ]]; then
                # Test port connectivity (timeout after 3 seconds)
                if timeout 3 bash -c "</dev/tcp/$worker_ip/$ssh_port" 2>/dev/null; then
                    log_success "  ✅ SSH port $ssh_port is accepting connections"
                else
                    log_warning "  ❌ SSH port $ssh_port is not accessible"
                fi
            fi
        fi
    done
    echo ""
}

# Generate scaling recommendations
generate_scaling_recommendations() {
    log_header "Scaling Recommendations"
    
    # Count total VMs
    local total_namespaces=$(oc get namespaces -o name | grep -E "(frontend|backend|vm-|dev-|test-|staging-)" | wc -l)
    local current_ports=$((2200 + total_namespaces))
    
    echo "Current Scale:"
    echo "  Total VMs: $total_namespaces"
    echo "  Port range: 2201-$current_ports"
    echo "  NLBs in use: $(((total_namespaces + 49) / 50))"
    echo ""
    
    # Scaling recommendations
    echo "Scaling Recommendations:"
    
    if [[ $total_namespaces -lt 20 ]]; then
        echo "  📈 Current scale: Small (< 20 VMs)"
        echo "  💡 Recommendation: Can grow to 50 VMs on current NLB"
        echo "  💰 Cost: Minimal (~$25/month for 1 NLB)"
    elif [[ $total_namespaces -lt 50 ]]; then
        echo "  📈 Current scale: Medium (20-50 VMs)"
        echo "  💡 Recommendation: Consider 2nd NLB for redundancy"
        echo "  💰 Cost: Low (~$50/month for 2 NLBs)"
    elif [[ $total_namespaces -lt 100 ]]; then
        echo "  📈 Current scale: Large (50-100 VMs)"
        echo "  💡 Recommendation: Deploy regional NLB clusters"
        echo "  💰 Cost: Moderate (~$90/month for 4 NLBs)"
    else
        echo "  📈 Current scale: Enterprise (100+ VMs)"
        echo "  💡 Recommendation: Consider load balancer alternatives"
        echo "  💰 Cost: High (>$90/month)"
    fi
    echo ""
}

# Resource utilization summary
check_resource_utilization() {
    log_header "Resource Utilization"
    
    # Get cluster resource usage
    local total_cpu=$(oc describe nodes | grep -A 5 "Allocated resources" | grep "cpu" | awk '{sum += $2} END {print sum}' || echo "0")
    local total_memory=$(oc describe nodes | grep -A 5 "Allocated resources" | grep "memory" | awk '{sum += $2} END {print sum}' || echo "0")
    
    echo "Cluster Resources:"
    echo "  CPU allocated: ${total_cpu:-"Unknown"}"
    echo "  Memory allocated: ${total_memory:-"Unknown"}"
    echo ""
    
    # VM resource summary
    local vm_count=$(oc get pods --all-namespaces -l app | grep -E "(frontend|backend|vm-)" | wc -l || echo "0")
    echo "VM Workload Summary:"
    echo "  Active VM pods: $vm_count"
    echo "  Estimated CPU usage: $((vm_count * 200))m (200m per VM)"
    echo "  Estimated Memory usage: $((vm_count * 512))Mi (512Mi per VM)"
    echo ""
}

# Generate status report
generate_status_report() {
    local report_file="/tmp/rosa-vm-status-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" <<EOF
# ROSA VM Status Report

**Generated:** $(date)
**Cluster:** $(oc cluster-info | head -1 | awk '{print $6}')
**User:** $(oc whoami)

## Summary

$(oc get namespaces -o name | grep -E "(frontend|backend|vm-)" | wc -l) total VMs deployed across the cluster.

## VM Status Details

\`\`\`
$(check_vm_pod_status 2>/dev/null | tail -n +4)
\`\`\`

## Network Load Balancer Status

\`\`\`
$(check_nlb_status 2>/dev/null | tail -n +4)
\`\`\`

## Quick Commands

\`\`\`bash
# Check all VM pods
oc get pods --all-namespaces -l app | grep -E "(frontend|backend|vm-)"

# List SSH services
oc get services --all-namespaces | grep ssh-service

# Monitor NLB status
./scaling/scale-nlb.sh --action status

# Deploy new VMs
./scaling/deploy-vm-cluster.sh --vms 10 --dry-run
\`\`\`

## Next Steps

1. Review any failed VMs and restart if needed
2. Monitor NLB listener configuration
3. Test SSH connectivity to new VMs
4. Consider scaling if approaching port limits
EOF
    
    log_success "Status report saved to: $report_file"
    echo "  View with: cat $report_file"
}

# Main execution
main() {
    # Run all checks
    check_cluster_connection || exit 1
    scan_vm_deployments
    check_vm_pod_status
    check_nlb_status
    test_ssh_connectivity
    generate_scaling_recommendations
    check_resource_utilization
    
    # Generate report
    generate_status_report
    
    log_success "VM status monitoring completed!"
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        cat <<EOF
ROSA VM Status Monitor

Usage: $0 [options]

Options:
  --help, -h         Show this help message
  --report-only      Generate status report only
  --ssh-test         Run SSH connectivity tests only
  --nlb-only         Check NLB status only

Examples:
  $0                 # Run full status check
  $0 --ssh-test      # Test SSH connectivity only
  $0 --nlb-only      # Check NLB status only

EOF
        exit 0
        ;;
    --report-only)
        generate_status_report
        ;;
    --ssh-test)
        test_ssh_connectivity
        ;;
    --nlb-only)
        check_nlb_status
        ;;
    *)
        main
        ;;
esac
