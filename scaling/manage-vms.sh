#!/bin/bash

# ROSA VM Management Interface
# Central command interface for managing VMs at scale (5 to 200+ VMs)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${CYAN}[ROSA-VM]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/Users/richardsawyers/work/rosa"

show_banner() {
    echo -e "${PURPLE}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║    🚀 ROSA VM Management Interface                           ║
    ║    Scaling from 5 Applications to 200+ Virtual Machines      ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

show_main_menu() {
    echo -e "${CYAN}🎯 Main Menu${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ${GREEN}📊 MONITORING & STATUS${NC}"
    echo "    1) Show VM Status Dashboard"
    echo "    2) Monitor Cluster Health"
    echo "    3) Check SSH Connectivity"
    echo "    4) View NLB Status"
    echo ""
    echo "  ${YELLOW}🛠️  VM DEPLOYMENT${NC}"
    echo "    5) Deploy Single VM"
    echo "    6) Deploy VM Cluster (Bulk)"
    echo "    7) Demo Scaling (Simulation)"
    echo ""
    echo "  ${BLUE}🌐 NETWORK & SCALING${NC}"
    echo "    8) Scale NLB Infrastructure"
    echo "    9) Generate DNS Configuration"
    echo "   10) Update External Access"
    echo ""
    echo "  ${PURPLE}📋 MANAGEMENT${NC}"
    echo "   11) Generate Deployment Report"
    echo "   12) Cleanup & Maintenance"
    echo "   13) Show Configuration"
    echo ""
    echo "   ${RED}q) Quit${NC}"
    echo ""
}

get_current_stats() {
    local total_vms=0
    local running_vms=0
    local nlb_count=0
    
    # Count VMs
    if oc whoami >/dev/null 2>&1; then
        total_vms=$(oc get namespaces -o name 2>/dev/null | grep -E "(frontend|backend|vm-|dev-|test-|staging-|angular|react|vue|nodejs|django)" | wc -l || echo "0")
        running_vms=$(oc get pods --all-namespaces -l app 2>/dev/null | grep -E "(frontend|backend|vm-)" | grep "Running" | wc -l || echo "0")
    fi
    
    # Count NLBs
    if aws sts get-caller-identity >/dev/null 2>&1; then
        nlb_count=$(aws elbv2 describe-load-balancers --region us-east-1 \
            --query "length(LoadBalancers[?contains(LoadBalancerName, 'rosa-ssh-nlb')])" \
            --output text 2>/dev/null || echo "0")
    fi
    
    echo "📊 Current Scale: $total_vms VMs | 🟢 $running_vms Running | 🌐 $nlb_count NLBs"
}

handle_vm_status() {
    log_header "VM Status Dashboard"
    echo ""
    
    if ! oc whoami >/dev/null 2>&1; then
        log_error "Not connected to OpenShift cluster"
        echo "Please run: oc login <cluster-url>"
        return
    fi
    
    $SCRIPT_DIR/monitor-vms.sh
}

handle_cluster_health() {
    log_header "Cluster Health Monitor"
    echo ""
    
    if ! oc whoami >/dev/null 2>&1; then
        log_error "Not connected to OpenShift cluster"
        return
    fi
    
    echo "Cluster Information:"
    oc cluster-info
    echo ""
    
    echo "Node Status:"
    oc get nodes
    echo ""
    
    echo "VM Namespaces:"
    oc get namespaces | grep -E "(frontend|backend|vm-|dev-|test-|staging-)" || echo "No VM namespaces found"
}

handle_ssh_test() {
    log_header "SSH Connectivity Test"
    echo ""
    
    $SCRIPT_DIR/monitor-vms.sh --ssh-test
}

handle_nlb_status() {
    log_header "Network Load Balancer Status"
    echo ""
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS CLI not configured"
        echo "Please run: aws configure"
        return
    fi
    
    $SCRIPT_DIR/scale-nlb.sh --action status
}

handle_single_vm() {
    log_header "Deploy Single VM"
    echo ""
    
    echo "VM Types available:"
    echo "  • frontend  - React/Vue/Angular with Nginx + Node.js"
    echo "  • backend   - Node.js Express API or Python Django"
    echo "  • fullstack - Combined frontend + backend"
    echo "  • minimal   - Basic development container"
    echo ""
    
    read -p "VM Name: " vm_name
    if [[ -z "$vm_name" ]]; then
        log_error "VM name is required"
        return
    fi
    
    read -p "VM Type [frontend]: " vm_type
    vm_type=${vm_type:-frontend}
    
    read -p "SSH Port (auto-assign if empty): " ssh_port
    
    echo ""
    log_info "Creating VM: $vm_name ($vm_type)"
    
    local cmd="$SCRIPT_DIR/create-vm.sh --name $vm_name --type $vm_type"
    if [[ -n "$ssh_port" ]]; then
        cmd="$cmd --port $ssh_port"
    fi
    
    if eval $cmd; then
        log_success "VM created successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Add '$vm_name/' to $BASE_DIR/apps/kustomization.yaml"
        echo "  2. Commit and push to trigger ArgoCD sync"
        echo "  3. Update NLB configuration for external access"
    else
        log_error "Failed to create VM"
    fi
}

handle_vm_cluster() {
    log_header "Deploy VM Cluster (Bulk)"
    echo ""
    
    read -p "Number of VMs to deploy: " vm_count
    if [[ ! "$vm_count" =~ ^[0-9]+$ ]] || [[ $vm_count -le 0 ]]; then
        log_error "Please enter a valid number"
        return
    fi
    
    read -p "VM name prefix [vm]: " vm_prefix
    vm_prefix=${vm_prefix:-vm}
    
    read -p "Domain name (optional): " domain_name
    
    echo ""
    log_warning "This will deploy $vm_count VMs with prefix '$vm_prefix'"
    
    if [[ $vm_count -gt 20 ]]; then
        log_warning "Large deployment detected. This may require multiple NLBs."
        local nlb_count=$(((vm_count + 50 + 5) / 50))  # +5 for existing apps
        log_warning "Estimated NLBs needed: $nlb_count (~\$$(($nlb_count * 22))/month)"
    fi
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        return
    fi
    
    local cmd="$SCRIPT_DIR/deploy-vm-cluster.sh --vms $vm_count --prefix $vm_prefix"
    if [[ -n "$domain_name" ]]; then
        cmd="$cmd --domain $domain_name"
    fi
    
    log_info "Executing: $cmd"
    eval $cmd
}

handle_demo_scaling() {
    log_header "Demo Scaling (Simulation)"
    echo ""
    
    $SCRIPT_DIR/demo-scaling.sh
}

handle_scale_nlb() {
    log_header "Scale NLB Infrastructure"
    echo ""
    
    echo "NLB Actions:"
    echo "  1) Create new NLBs"
    echo "  2) Show current status"
    echo "  3) Generate DNS configuration"
    echo "  4) Delete NLBs"
    echo ""
    
    read -p "Choose action (1-4): " nlb_action
    
    case $nlb_action in
        1)
            read -p "Number of NLBs to create: " nlb_count
            read -p "Domain name (optional): " domain_name
            
            local cmd="$SCRIPT_DIR/scale-nlb.sh --action create --nlb-count $nlb_count"
            if [[ -n "$domain_name" ]]; then
                cmd="$cmd --domain $domain_name"
            fi
            eval $cmd
            ;;
        2)
            $SCRIPT_DIR/scale-nlb.sh --action status
            ;;
        3)
            read -p "Domain name: " domain_name
            if [[ -n "$domain_name" ]]; then
                $SCRIPT_DIR/scale-nlb.sh --action dns --domain $domain_name
            else
                log_error "Domain name is required for DNS configuration"
            fi
            ;;
        4)
            log_warning "This will delete ALL NLBs with name pattern 'rosa-ssh-nlb'"
            read -p "Are you sure? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                $SCRIPT_DIR/scale-nlb.sh --action delete
            fi
            ;;
        *)
            log_error "Invalid choice"
            ;;
    esac
}

handle_dns_config() {
    log_header "Generate DNS Configuration"
    echo ""
    
    read -p "Domain name: " domain_name
    if [[ -z "$domain_name" ]]; then
        log_error "Domain name is required"
        return
    fi
    
    $SCRIPT_DIR/scale-nlb.sh --action dns --domain $domain_name
}

handle_external_access() {
    log_header "Update External Access"
    echo ""
    
    log_info "Current external SSH access setup:"
    echo "  • Original 5 apps: ports 2201-2205"
    echo "  • Additional VMs: ports 2206+"
    echo "  • Access via AWS NLB with domain DNS"
    echo ""
    
    echo "Available actions:"
    echo "  1) Update existing NLB with new VMs"
    echo "  2) Test external SSH access"
    echo "  3) Show connection commands"
    echo ""
    
    read -p "Choose action (1-3): " access_action
    
    case $access_action in
        1)
            log_info "Updating NLB configuration..."
            $SCRIPT_DIR/scale-nlb.sh --action update
            ;;
        2)
            log_info "Testing external SSH access..."
            $BASE_DIR/test-ssh-access.sh
            ;;
        3)
            log_info "SSH connection commands:"
            echo ""
            echo "Original apps:"
            echo "  ssh developer@ssh.yourdomain.com:2201  # React Frontend"
            echo "  ssh developer@ssh.yourdomain.com:2202  # Vue Frontend"
            echo "  ssh developer@ssh.yourdomain.com:2203  # Angular Frontend"
            echo "  ssh developer@ssh.yourdomain.com:2204  # Node.js Backend"
            echo "  ssh developer@ssh.yourdomain.com:2205  # Django Backend"
            echo ""
            echo "Additional VMs (example):"
            echo "  ssh developer@ssh.yourdomain.com:2206  # First new VM"
            echo "  ssh developer@ssh.yourdomain.com:2207  # Second new VM"
            echo "  ..."
            ;;
        *)
            log_error "Invalid choice"
            ;;
    esac
}

handle_deployment_report() {
    log_header "Generate Deployment Report"
    echo ""
    
    local report_file="/tmp/rosa-deployment-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" <<EOF
# ROSA VM Deployment Report

**Generated:** $(date)
**Cluster:** $(oc cluster-info 2>/dev/null | head -1 | awk '{print $6}' || echo "Not connected")
**User:** $(oc whoami 2>/dev/null || echo "Not logged in")

## Deployment Overview

$(get_current_stats)

## VM Inventory

\`\`\`
$(oc get namespaces 2>/dev/null | grep -E "(frontend|backend|vm-|dev-|test-|staging-)" | nl || echo "No VMs found")
\`\`\`

## SSH Port Allocation

| Port Range | Usage | NLB |
|------------|-------|-----|
| 2201-2205 | Original 5 apps | NLB-1 |
| 2206-2250 | Additional VMs | NLB-1 |
| 2251-2300 | Scaling VMs | NLB-2 |
| 2301-2350 | Extended VMs | NLB-3 |

## Quick Commands

\`\`\`bash
# Monitor VMs
./scaling/monitor-vms.sh

# Deploy new VMs
./scaling/deploy-vm-cluster.sh --vms 10 --domain yourdomain.com

# Scale NLB
./scaling/scale-nlb.sh --action create --nlb-count 2

# Management interface
./scaling/manage-vms.sh
\`\`\`

## Architecture Status

- ✅ GitOps deployment with ArgoCD
- ✅ Red Hat UBI9 base images
- ✅ SSH access via sidecar containers
- ✅ External access via AWS NLB
- ✅ Scalable port allocation
- ✅ Domain-based DNS routing

## Scaling Capacity

Current architecture supports:
- **Phase 1:** 5-50 VMs (1 NLB)
- **Phase 2:** 51-100 VMs (2 NLBs)
- **Phase 3:** 101-200 VMs (4 NLBs)
- **Phase 4:** 200+ VMs (Regional scaling)

## Cost Analysis

| Scale | VMs | NLBs | Monthly Cost |
|-------|-----|------|--------------|
| Small | 5-50 | 1 | ~\$25 |
| Medium | 51-100 | 2 | ~\$50 |
| Large | 101-200 | 4 | ~\$90 |
| Enterprise | 200+ | 6+ | \$130+ |

EOF
    
    log_success "Deployment report saved to: $report_file"
    echo "  View with: cat $report_file"
    echo "  Edit with: code $report_file"
}

handle_cleanup() {
    log_header "Cleanup & Maintenance"
    echo ""
    
    echo "Cleanup options:"
    echo "  1) Remove failed VM pods"
    echo "  2) Clean up unused secrets"
    echo "  3) Remove orphaned services"
    echo "  4) Delete test VMs"
    echo "  5) Full cleanup (DANGEROUS)"
    echo ""
    
    read -p "Choose cleanup action (1-5): " cleanup_action
    
    case $cleanup_action in
        1)
            log_info "Removing failed VM pods..."
            oc get pods --all-namespaces | grep -E "(Error|Failed|CrashLoopBackOff)" | awk '{print $1, $2}' | while read ns pod; do
                log_info "Deleting failed pod: $pod in namespace $ns"
                oc delete pod $pod -n $ns 2>/dev/null || true
            done
            ;;
        2)
            log_info "Cleaning up unused secrets..."
            # Add secret cleanup logic
            log_warning "Secret cleanup not implemented yet"
            ;;
        3)
            log_info "Removing orphaned services..."
            # Add service cleanup logic
            log_warning "Service cleanup not implemented yet"
            ;;
        4)
            log_warning "This will delete all VMs with 'test-' prefix"
            read -p "Are you sure? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                oc get namespaces | grep "test-" | awk '{print $1}' | while read ns; do
                    log_info "Deleting test namespace: $ns"
                    oc delete namespace $ns
                done
            fi
            ;;
        5)
            log_error "Full cleanup is not implemented for safety reasons"
            log_info "Please use individual cleanup options or manual deletion"
            ;;
        *)
            log_error "Invalid choice"
            ;;
    esac
}

handle_show_config() {
    log_header "Current Configuration"
    echo ""
    
    echo "📁 Directory Structure:"
    echo "  Base: $BASE_DIR"
    echo "  Apps: $BASE_DIR/apps"
    echo "  Scaling: $SCRIPT_DIR"
    echo ""
    
    echo "🔧 Available Scripts:"
    echo "  • create-vm.sh        - Create single VM"
    echo "  • deploy-vm-cluster.sh - Deploy multiple VMs"
    echo "  • scale-nlb.sh        - Manage NLB infrastructure"
    echo "  • monitor-vms.sh      - Monitor VM status"
    echo "  • demo-scaling.sh     - Scaling demonstration"
    echo "  • manage-vms.sh       - This management interface"
    echo ""
    
    echo "🌐 Network Configuration:"
    echo "  AWS Region: us-east-1"
    echo "  NLB Pattern: rosa-ssh-nlb-*"
    echo "  Port Range: 2201-2400 (200 VMs max per region)"
    echo "  DNS Pattern: ssh.domain.com, ssh2.domain.com, etc."
    echo ""
    
    echo "🔐 SSH Configuration:"
    echo "  User: developer"
    echo "  Auth: Password-based"
    echo "  Password Pattern: {VMName}Dev@2024"
    echo ""
    
    echo "📊 Current Status:"
    get_current_stats
}

# Main program loop
main() {
    show_banner
    
    while true; do
        echo ""
        get_current_stats
        echo ""
        show_main_menu
        
        read -p "Choose an option: " choice
        
        case $choice in
            1) handle_vm_status ;;
            2) handle_cluster_health ;;
            3) handle_ssh_test ;;
            4) handle_nlb_status ;;
            5) handle_single_vm ;;
            6) handle_vm_cluster ;;
            7) handle_demo_scaling ;;
            8) handle_scale_nlb ;;
            9) handle_dns_config ;;
            10) handle_external_access ;;
            11) handle_deployment_report ;;
            12) handle_cleanup ;;
            13) handle_show_config ;;
            q|Q) 
                log_success "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please try again."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
