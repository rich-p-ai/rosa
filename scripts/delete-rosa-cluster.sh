#!/bin/bash

# ROSA Cluster Deletion Script
# This script safely deletes a ROSA cluster
# Usage: ./delete-rosa-cluster.sh [cluster-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v rosa >/dev/null 2>&1; then
        log_error "ROSA CLI not found. Run './setup-rosa-environment.sh' first"
        exit 1
    fi
    
    if ! rosa whoami >/dev/null 2>&1; then
        log_error "ROSA CLI not authenticated. Run 'rosa login'"
        exit 1
    fi
}

# List clusters for selection
select_cluster() {
    local clusters=($(rosa list clusters --output json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo ""))
    
    if [[ ${#clusters[@]} -eq 0 ]]; then
        log_warning "No ROSA clusters found"
        return 1
    fi
    
    echo ""
    log_info "Available clusters:"
    for i in "${!clusters[@]}"; do
        echo "  $((i+1)). ${clusters[i]}"
    done
    
    echo ""
    read -p "Select cluster number to delete (1-${#clusters[@]}): " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#clusters[@]}" ]]; then
        echo "${clusters[$((selection-1))]}"
        return 0
    else
        log_error "Invalid selection"
        return 1
    fi
}

# Show cluster information before deletion
show_cluster_info() {
    local cluster_name=$1
    
    log_info "Cluster information for '$cluster_name':"
    echo ""
    
    rosa describe cluster --cluster="$cluster_name" 2>/dev/null || {
        log_error "Cluster '$cluster_name' not found"
        return 1
    }
    
    echo ""
    log_info "Machine pools:"
    rosa list machinepools --cluster="$cluster_name" 2>/dev/null || log_warning "Could not retrieve machine pools"
    
    echo ""
    log_info "Add-ons:"
    rosa list addons --cluster="$cluster_name" 2>/dev/null || log_warning "Could not retrieve add-ons"
}

# Delete cluster with confirmation
delete_cluster() {
    local cluster_name=$1
    
    if [[ -z "$cluster_name" ]]; then
        log_error "Cluster name is required"
        return 1
    fi
    
    # Show cluster information
    if ! show_cluster_info "$cluster_name"; then
        return 1
    fi
    
    echo ""
    log_warning "⚠️  DANGER: This will permanently delete the cluster '$cluster_name'"
    log_warning "⚠️  All data, applications, and configurations will be lost!"
    log_warning "⚠️  This action cannot be undone!"
    
    echo ""
    echo "Type the cluster name to confirm deletion:"
    read -p "Cluster name: " confirmation
    
    if [[ "$confirmation" != "$cluster_name" ]]; then
        log_info "Cluster name does not match. Deletion cancelled."
        return 0
    fi
    
    echo ""
    read -p "Are you absolutely sure? Type 'DELETE' to proceed: " final_confirmation
    
    if [[ "$final_confirmation" != "DELETE" ]]; then
        log_info "Final confirmation failed. Deletion cancelled."
        return 0
    fi
    
    log_info "Starting cluster deletion (this may take 10-15 minutes)..."
    
    # Delete the cluster
    if rosa delete cluster --cluster="$cluster_name" --watch; then
        log_success "Cluster '$cluster_name' deleted successfully!"
        
        # Clean up local files
        if [[ -f "../logs/${cluster_name}-info.txt" ]]; then
            mv "../logs/${cluster_name}-info.txt" "../logs/${cluster_name}-info-deleted-$(date +%Y%m%d-%H%M%S).txt"
            log_info "Moved cluster info file to archived name"
        fi
        
        # Disconnect from cluster if currently connected
        if oc whoami >/dev/null 2>&1; then
            local current_server=$(oc whoami --show-server 2>/dev/null || echo "")
            if [[ "$current_server" == *"$cluster_name"* ]]; then
                log_info "Logging out from deleted cluster..."
                oc logout 2>/dev/null || true
            fi
        fi
        
    else
        log_error "Cluster deletion failed!"
        return 1
    fi
}

# Force delete (for stuck clusters)
force_delete_cluster() {
    local cluster_name=$1
    
    log_warning "Force deletion will attempt to delete the cluster even if it's in an error state"
    log_warning "This should only be used if normal deletion fails"
    
    echo ""
    read -p "Are you sure you want to force delete '$cluster_name'? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Force deletion cancelled."
        return 0
    fi
    
    log_info "Attempting force deletion..."
    rosa delete cluster --cluster="$cluster_name" --yes || {
        log_error "Force deletion failed. You may need to contact Red Hat support."
        return 1
    }
}

# Show deletion cost implications
show_cost_implications() {
    local cluster_name=$1
    
    log_info "Cost implications of deleting '$cluster_name':"
    echo ""
    echo "✅ Compute costs will stop immediately"
    echo "✅ Load balancer costs will stop immediately"
    echo "✅ EBS volume costs will stop immediately"
    echo ""
    echo "⚠️  Check for any persistent volumes that might remain"
    echo "⚠️  Verify no Load Balancers are left behind"
    echo "⚠️  Check AWS Route53 for any DNS records"
    echo ""
    log_info "Monitor AWS billing for 24-48 hours to ensure all resources are removed"
}

# List resources that might remain
check_remaining_resources() {
    log_info "After cluster deletion, check these AWS resources manually:"
    echo ""
    echo "1. EC2 Instances (should be terminated)"
    echo "2. Load Balancers (should be deleted)"
    echo "3. EBS Volumes (should be deleted)"
    echo "4. VPC and networking components"
    echo "5. Route53 DNS records"
    echo "6. CloudFormation stacks"
    echo ""
    log_info "Use AWS CLI or Console to verify cleanup:"
    echo "  aws ec2 describe-instances --filters 'Name=tag:kubernetes.io/cluster/*,Values=owned'"
    echo "  aws elb describe-load-balancers"
    echo "  aws elbv2 describe-load-balancers"
}

# Main execution
main() {
    check_prerequisites
    
    case ${1:-interactive} in
        interactive)
            if cluster_name=$(select_cluster); then
                delete_cluster "$cluster_name"
            fi
            ;;
        force)
            if [[ -z "$2" ]]; then
                if cluster_name=$(select_cluster); then
                    force_delete_cluster "$cluster_name"
                fi
            else
                force_delete_cluster "$2"
            fi
            ;;
        cost)
            if [[ -z "$2" ]]; then
                if cluster_name=$(select_cluster); then
                    show_cost_implications "$cluster_name"
                fi
            else
                show_cost_implications "$2"
            fi
            ;;
        check)
            check_remaining_resources
            ;;
        --help|-h)
            echo "Usage: $0 [interactive|force|cost|check] [cluster-name]"
            echo "  interactive           - Interactive cluster selection and deletion"
            echo "  force <cluster-name>  - Force delete a stuck cluster"
            echo "  cost <cluster-name>   - Show cost implications"
            echo "  check                 - List resources to check after deletion"
            echo ""
            echo "Run without arguments for interactive mode"
            exit 0
            ;;
        *)
            if [[ -n "$1" ]]; then
                delete_cluster "$1"
            else
                if cluster_name=$(select_cluster); then
                    delete_cluster "$cluster_name"
                fi
            fi
            ;;
    esac
}

main "$@"
