#!/bin/bash

# ROSA Cluster Status Script
# This script shows detailed status of ROSA clusters
# Usage: ./cluster-status.sh [cluster-name]

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

# List all clusters
list_all_clusters() {
    log_info "All ROSA clusters:"
    echo ""
    
    if rosa list clusters --output table 2>/dev/null; then
        echo ""
    else
        log_warning "No clusters found or unable to list clusters"
    fi
}

# Show detailed cluster information
show_cluster_details() {
    local cluster_name=$1
    
    if [[ -z "$cluster_name" ]]; then
        log_error "Cluster name is required"
        return 1
    fi
    
    log_info "Detailed information for cluster: $cluster_name"
    echo ""
    
    # Basic cluster info
    if rosa describe cluster --cluster="$cluster_name" 2>/dev/null; then
        echo ""
    else
        log_error "Cluster '$cluster_name' not found"
        return 1
    fi
    
    # Cluster nodes
    log_info "Cluster nodes:"
    rosa list machinepools --cluster="$cluster_name" 2>/dev/null || log_warning "Could not retrieve machine pools"
    
    echo ""
    
    # Cluster add-ons
    log_info "Installed add-ons:"
    rosa list addons --cluster="$cluster_name" 2>/dev/null || log_warning "Could not retrieve add-ons"
    
    echo ""
    
    # Check if cluster is accessible via oc
    log_info "OpenShift connection test:"
    if oc whoami >/dev/null 2>&1; then
        local current_server=$(oc whoami --show-server 2>/dev/null || echo "Unknown")
        if [[ "$current_server" == *"$cluster_name"* ]]; then
            log_success "Currently connected to this cluster"
            echo "  Server: $current_server"
            echo "  User: $(oc whoami 2>/dev/null || echo "Unknown")"
            
            echo ""
            log_info "Cluster nodes (via oc):"
            oc get nodes 2>/dev/null || log_warning "Could not retrieve nodes via oc"
            
            echo ""
            log_info "Running pods summary:"
            oc get pods --all-namespaces --field-selector=status.phase=Running 2>/dev/null | wc -l | xargs echo "Running pods:" || true
            
        else
            log_warning "Connected to a different cluster or not connected"
        fi
    else
        log_warning "Not connected to any OpenShift cluster"
        log_info "To connect: rosa logs install --cluster=$cluster_name"
    fi
}

# Show cluster logs
show_cluster_logs() {
    local cluster_name=$1
    
    if [[ -z "$cluster_name" ]]; then
        log_error "Cluster name is required"
        return 1
    fi
    
    log_info "Recent installation/operation logs for: $cluster_name"
    echo ""
    
    rosa logs install --cluster="$cluster_name" 2>/dev/null || log_warning "Could not retrieve installation logs"
}

# Show cluster costs
show_cluster_costs() {
    local cluster_name=$1
    
    log_info "Cluster cost information:"
    echo ""
    
    if [[ -n "$cluster_name" ]]; then
        # Show specific cluster details that might help estimate costs
        rosa describe cluster --cluster="$cluster_name" | grep -E "(Machine Type|Replicas|Multi-AZ)" || true
    fi
    
    echo ""
    log_info "For detailed billing information, check AWS Cost Explorer:"
    echo "https://console.aws.amazon.com/cost/home"
}

# Interactive cluster selection
select_cluster_interactive() {
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

# Main menu
show_menu() {
    echo ""
    echo "========================================="
    echo "ROSA Cluster Status Options"
    echo "========================================="
    echo "1. List all clusters"
    echo "2. Show cluster details"
    echo "3. Show cluster logs"
    echo "4. Show cluster costs"
    echo "5. Test cluster connectivity"
    echo "6. Exit"
    echo ""
}

# Test cluster connectivity
test_connectivity() {
    local cluster_name=$1
    
    if [[ -z "$cluster_name" ]]; then
        log_error "Cluster name is required"
        return 1
    fi
    
    log_info "Testing connectivity to cluster: $cluster_name"
    
    # Get cluster API URL
    local api_url=$(rosa describe cluster --cluster="$cluster_name" --output json 2>/dev/null | jq -r '.api.url' 2>/dev/null || echo "")
    
    if [[ -n "$api_url" && "$api_url" != "null" ]]; then
        echo "  API URL: $api_url"
        
        # Test API connectivity
        if curl -s --max-time 10 -k "$api_url/healthz" >/dev/null 2>&1; then
            log_success "API endpoint is reachable"
        else
            log_warning "API endpoint is not reachable or requires authentication"
        fi
    else
        log_warning "Could not retrieve API URL"
    fi
    
    # Check if we can authenticate via oc
    log_info "To test full connectivity, use: oc login --server=$api_url"
}

# Main execution
main() {
    check_prerequisites
    
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select an option (1-6): " choice
            
            case $choice in
                1)
                    list_all_clusters
                    ;;
                2)
                    if cluster_name=$(select_cluster_interactive); then
                        show_cluster_details "$cluster_name"
                    fi
                    ;;
                3)
                    if cluster_name=$(select_cluster_interactive); then
                        show_cluster_logs "$cluster_name"
                    fi
                    ;;
                4)
                    if cluster_name=$(select_cluster_interactive); then
                        show_cluster_costs "$cluster_name"
                    fi
                    ;;
                5)
                    if cluster_name=$(select_cluster_interactive); then
                        test_connectivity "$cluster_name"
                    fi
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
    else
        # Command line mode
        case $1 in
            list)
                list_all_clusters
                ;;
            details)
                show_cluster_details "$2"
                ;;
            logs)
                show_cluster_logs "$2"
                ;;
            costs)
                show_cluster_costs "$2"
                ;;
            test)
                test_connectivity "$2"
                ;;
            *)
                echo "Usage: $0 [list|details|logs|costs|test] [cluster-name]"
                echo "  list                    - List all clusters"
                echo "  details <cluster-name>  - Show detailed cluster information"
                echo "  logs <cluster-name>     - Show cluster installation logs"
                echo "  costs <cluster-name>    - Show cluster cost information"
                echo "  test <cluster-name>     - Test cluster connectivity"
                echo ""
                echo "Run without arguments for interactive mode"
                exit 1
                ;;
        esac
    fi
}

main "$@"
