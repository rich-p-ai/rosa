#!/bin/bash

# ROSA Cluster Scaling Script
# This script helps scale ROSA cluster resources
# Usage: ./scale-cluster.sh [cluster-name]

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

# Select cluster
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
    read -p "Select cluster number (1-${#clusters[@]}): " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#clusters[@]}" ]]; then
        echo "${clusters[$((selection-1))]}"
        return 0
    else
        log_error "Invalid selection"
        return 1
    fi
}

# Show current cluster scaling configuration
show_current_scaling() {
    local cluster_name=$1
    
    log_info "Current scaling configuration for '$cluster_name':"
    echo ""
    
    rosa list machinepools --cluster="$cluster_name" 2>/dev/null || {
        log_error "Could not retrieve machine pools for cluster '$cluster_name'"
        return 1
    }
}

# Scale worker nodes
scale_workers() {
    local cluster_name=$1
    local machinepool_name=${2:-"worker"}
    
    show_current_scaling "$cluster_name"
    
    echo ""
    log_info "Scaling options for machine pool '$machinepool_name':"
    echo "1. Set exact replica count"
    echo "2. Enable/configure autoscaling"
    echo "3. Change machine type"
    echo "4. Back to main menu"
    
    echo ""
    read -p "Select scaling option (1-4): " scaling_option
    
    case $scaling_option in
        1)
            scale_exact_replicas "$cluster_name" "$machinepool_name"
            ;;
        2)
            configure_autoscaling "$cluster_name" "$machinepool_name"
            ;;
        3)
            change_machine_type "$cluster_name" "$machinepool_name"
            ;;
        4)
            return 0
            ;;
        *)
            log_error "Invalid option"
            return 1
            ;;
    esac
}

# Set exact replica count
scale_exact_replicas() {
    local cluster_name=$1
    local machinepool_name=$2
    
    echo ""
    read -p "Enter number of worker nodes: " replica_count
    
    if ! [[ "$replica_count" =~ ^[0-9]+$ ]] || [[ "$replica_count" -lt 1 ]]; then
        log_error "Invalid replica count. Must be a positive integer."
        return 1
    fi
    
    log_info "Scaling machine pool '$machinepool_name' to $replica_count replicas..."
    
    if rosa edit machinepool --cluster="$cluster_name" --machinepool="$machinepool_name" --replicas="$replica_count"; then
        log_success "Successfully scaled to $replica_count replicas"
        
        log_info "Waiting for nodes to be ready..."
        sleep 10
        show_current_scaling "$cluster_name"
    else
        log_error "Failed to scale machine pool"
        return 1
    fi
}

# Configure autoscaling
configure_autoscaling() {
    local cluster_name=$1
    local machinepool_name=$2
    
    echo ""
    log_info "Autoscaling configuration:"
    read -p "Enter minimum replicas: " min_replicas
    read -p "Enter maximum replicas: " max_replicas
    
    if ! [[ "$min_replicas" =~ ^[0-9]+$ ]] || [[ "$min_replicas" -lt 1 ]]; then
        log_error "Invalid minimum replicas. Must be a positive integer."
        return 1
    fi
    
    if ! [[ "$max_replicas" =~ ^[0-9]+$ ]] || [[ "$max_replicas" -lt "$min_replicas" ]]; then
        log_error "Invalid maximum replicas. Must be greater than or equal to minimum."
        return 1
    fi
    
    log_info "Enabling autoscaling ($min_replicas-$max_replicas replicas)..."
    
    if rosa edit machinepool --cluster="$cluster_name" --machinepool="$machinepool_name" \
        --enable-autoscaling --min-replicas="$min_replicas" --max-replicas="$max_replicas"; then
        log_success "Autoscaling configured successfully"
        show_current_scaling "$cluster_name"
    else
        log_error "Failed to configure autoscaling"
        return 1
    fi
}

# Change machine type (requires new machine pool)
change_machine_type() {
    local cluster_name=$1
    local current_pool=$2
    
    echo ""
    log_info "Available machine types:"
    echo "  m5.large: 2 vCPUs, 8GB RAM"
    echo "  m5.xlarge: 4 vCPUs, 16GB RAM"
    echo "  m5.2xlarge: 8 vCPUs, 32GB RAM"
    echo "  m5.4xlarge: 16 vCPUs, 64GB RAM"
    echo "  c5.large: 2 vCPUs, 4GB RAM"
    echo "  c5.xlarge: 4 vCPUs, 8GB RAM"
    echo "  c5.2xlarge: 8 vCPUs, 16GB RAM"
    echo "  r5.large: 2 vCPUs, 16GB RAM"
    echo "  r5.xlarge: 4 vCPUs, 32GB RAM"
    
    echo ""
    read -p "Enter new machine type: " machine_type
    read -p "Enter name for new machine pool: " new_pool_name
    read -p "Enter number of replicas for new pool: " replicas
    
    log_warning "This will create a new machine pool. You'll need to manually migrate workloads and delete the old pool."
    echo ""
    read -p "Continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Operation cancelled."
        return 0
    fi
    
    log_info "Creating new machine pool '$new_pool_name' with machine type '$machine_type'..."
    
    if rosa create machinepool --cluster="$cluster_name" --name="$new_pool_name" \
        --instance-type="$machine_type" --replicas="$replicas"; then
        log_success "New machine pool created successfully"
        
        echo ""
        log_warning "Next steps:"
        echo "1. Wait for new nodes to be ready"
        echo "2. Migrate workloads to new nodes"
        echo "3. Delete old machine pool: rosa delete machinepool --cluster=$cluster_name --machinepool=$current_pool"
        
        show_current_scaling "$cluster_name"
    else
        log_error "Failed to create new machine pool"
        return 1
    fi
}

# Add new machine pool
add_machine_pool() {
    local cluster_name=$1
    
    echo ""
    log_info "Adding new machine pool to '$cluster_name'"
    
    read -p "Enter machine pool name: " pool_name
    read -p "Enter machine type (default: m5.xlarge): " machine_type
    machine_type=${machine_type:-"m5.xlarge"}
    read -p "Enter number of replicas: " replicas
    
    echo ""
    read -p "Enable autoscaling? (yes/no): " enable_autoscaling
    
    local create_cmd="rosa create machinepool --cluster=$cluster_name --name=$pool_name --instance-type=$machine_type"
    
    if [[ "$enable_autoscaling" == "yes" ]]; then
        read -p "Enter minimum replicas: " min_replicas
        read -p "Enter maximum replicas: " max_replicas
        create_cmd="$create_cmd --enable-autoscaling --min-replicas=$min_replicas --max-replicas=$max_replicas"
    else
        create_cmd="$create_cmd --replicas=$replicas"
    fi
    
    log_info "Creating machine pool..."
    
    if eval "$create_cmd"; then
        log_success "Machine pool '$pool_name' created successfully"
        show_current_scaling "$cluster_name"
    else
        log_error "Failed to create machine pool"
        return 1
    fi
}

# Delete machine pool
delete_machine_pool() {
    local cluster_name=$1
    
    show_current_scaling "$cluster_name"
    
    echo ""
    read -p "Enter machine pool name to delete: " pool_name
    
    if [[ "$pool_name" == "worker" ]]; then
        log_error "Cannot delete the default 'worker' machine pool"
        return 1
    fi
    
    log_warning "This will delete machine pool '$pool_name' and all its nodes"
    echo ""
    read -p "Are you sure? Type 'DELETE' to confirm: " confirm
    
    if [[ "$confirm" != "DELETE" ]]; then
        log_info "Operation cancelled."
        return 0
    fi
    
    log_info "Deleting machine pool '$pool_name'..."
    
    if rosa delete machinepool --cluster="$cluster_name" --machinepool="$pool_name" --yes; then
        log_success "Machine pool '$pool_name' deleted successfully"
        show_current_scaling "$cluster_name"
    else
        log_error "Failed to delete machine pool"
        return 1
    fi
}

# Show scaling costs
show_scaling_costs() {
    local cluster_name=$1
    
    show_current_scaling "$cluster_name"
    
    echo ""
    log_info "Estimated hourly costs (US East 1):"
    echo "  m5.large:    ~\$0.096/hour per node"
    echo "  m5.xlarge:   ~\$0.192/hour per node"
    echo "  m5.2xlarge:  ~\$0.384/hour per node"
    echo "  m5.4xlarge:  ~\$0.768/hour per node"
    echo "  c5.large:    ~\$0.085/hour per node"
    echo "  c5.xlarge:   ~\$0.170/hour per node"
    echo "  r5.large:    ~\$0.126/hour per node"
    echo "  r5.xlarge:   ~\$0.252/hour per node"
    
    echo ""
    log_warning "Costs vary by region and are subject to change"
    log_info "Use AWS Cost Explorer for accurate billing information"
}

# Main menu
show_menu() {
    echo ""
    echo "========================================="
    echo "ROSA Cluster Scaling Options"
    echo "========================================="
    echo "1. Show current scaling configuration"
    echo "2. Scale worker nodes"
    echo "3. Add new machine pool"
    echo "4. Delete machine pool"
    echo "5. Show scaling costs"
    echo "6. Exit"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    
    local cluster_name
    
    if [[ -n "$1" ]]; then
        cluster_name="$1"
    else
        if ! cluster_name=$(select_cluster); then
            exit 1
        fi
    fi
    
    while true; do
        show_menu
        read -p "Select an option (1-6): " choice
        
        case $choice in
            1)
                show_current_scaling "$cluster_name"
                ;;
            2)
                scale_workers "$cluster_name"
                ;;
            3)
                add_machine_pool "$cluster_name"
                ;;
            4)
                delete_machine_pool "$cluster_name"
                ;;
            5)
                show_scaling_costs "$cluster_name"
                ;;
            6)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

main "$@"
