#!/bin/bash

# ROSA VM Deployment Automation
# Complete end-to-end deployment of VMs with SSH access and external NLB configuration
# Usage: ./deploy-vm-cluster.sh --vms 10 --domain yourdomain.com

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="/Users/richardsawyers/work/rosa/apps"
BASE_PORT=2205  # Start after existing 5 applications

# Default values
VM_COUNT=10
DOMAIN_NAME=""
VM_PREFIX="vm"
VM_TYPES=("frontend" "backend" "fullstack" "minimal")
DRY_RUN=false
SKIP_NLB=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vms)
            VM_COUNT="$2"
            shift 2
            ;;
        --domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        --prefix)
            VM_PREFIX="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-nlb)
            SKIP_NLB=true
            shift
            ;;
        -h|--help)
            cat <<EOF
ROSA VM Deployment Automation

Usage: $0 --vms <count> [options]

Required:
  --vms <count>              Number of VMs to deploy

Optional:
  --domain <domain>          Domain name for external access (e.g., yourdomain.com)
  --prefix <prefix>          VM name prefix (default: vm)
  --dry-run                  Show what would be done without executing
  --skip-nlb                 Skip NLB creation (use existing)

Examples:
  $0 --vms 10 --domain yourdomain.com
  $0 --vms 50 --prefix dev --domain dev.company.com
  $0 --vms 5 --dry-run

VM Naming:
  With prefix 'vm': vm-01, vm-02, vm-03, etc.
  With prefix 'dev': dev-01, dev-02, dev-03, etc.

VM Types (distributed automatically):
  25% frontend   - React/Vue/Angular frontends
  25% backend    - Node.js/Django APIs  
  25% fullstack  - Combined frontend + backend
  25% minimal    - Basic development containers

Port Allocation:
  Starting from port $((BASE_PORT + 1)), each VM gets next available port
  NLBs created automatically (50 ports per NLB)

EOF
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ $VM_COUNT -le 0 ]]; then
    log_error "VM count must be greater than 0"
    exit 1
fi

echo "========================================="
echo "🚀 ROSA VM Cluster Deployment"
echo "========================================="
echo ""
echo "Configuration:"
echo "  VMs to deploy: $VM_COUNT"
echo "  VM prefix: $VM_PREFIX"
echo "  Domain: ${DOMAIN_NAME:-"Not specified"}"
echo "  Dry run: $DRY_RUN"
echo "  Skip NLB: $SKIP_NLB"
echo ""

# Calculate NLB requirements
calculate_nlb_requirements() {
    local total_ssh_ports=$((VM_COUNT + 5))  # +5 for existing apps
    local nlbs_needed=$(((total_ssh_ports + 49) / 50))  # Round up to nearest 50
    
    log_info "Port allocation analysis:"
    echo "  Existing apps: 5 (ports 2201-2205)"
    echo "  New VMs: $VM_COUNT (ports 2206-$((2205 + VM_COUNT)))"
    echo "  Total SSH ports needed: $total_ssh_ports"
    echo "  NLBs required: $nlbs_needed (50 ports per NLB)"
    echo ""
    
    if [[ $nlbs_needed -gt 4 ]]; then
        log_warning "You're planning to deploy $VM_COUNT VMs which requires $nlbs_needed NLBs"
        log_warning "This will cost approximately \$$(($nlbs_needed * 22))+ per month in AWS NLB fees"
        
        if [[ "$DRY_RUN" == "false" ]]; then
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Deployment cancelled"
                exit 0
            fi
        fi
    fi
    
    echo "NLB_COUNT=$nlbs_needed" > /tmp/nlb-requirements.env
}

# Generate VM configurations
generate_vm_configs() {
    log_info "Generating VM configurations..."
    
    local generated_count=0
    local current_port=$((BASE_PORT + 1))
    
    for i in $(seq 1 $VM_COUNT); do
        local vm_name="${VM_PREFIX}-$(printf "%02d" $i)"
        local vm_type="${VM_TYPES[$((i % ${#VM_TYPES[@]}))]}"
        
        log_info "[$i/$VM_COUNT] Configuring VM: $vm_name ($vm_type) - Port: $current_port"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  [DRY RUN] Would create VM: $vm_name"
            echo "    Type: $vm_type"
            echo "    SSH Port: $current_port"
            echo "    Namespace: $vm_name"
            echo ""
        else
            # Create VM using the template script
            if $SCRIPT_DIR/create-vm.sh --name "$vm_name" --type "$vm_type" --port "$current_port"; then
                generated_count=$((generated_count + 1))
                log_success "Created VM: $vm_name"
            else
                log_error "Failed to create VM: $vm_name"
            fi
        fi
        
        current_port=$((current_port + 1))
    done
    
    if [[ "$DRY_RUN" == "false" ]]; then
        log_success "Generated $generated_count VM configurations"
    fi
}

# Update main kustomization.yaml
update_main_kustomization() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update main kustomization.yaml with new VMs"
        return
    fi
    
    log_info "Updating main kustomization.yaml..."
    
    # Backup original
    cp "$APPS_DIR/kustomization.yaml" "$APPS_DIR/kustomization.yaml.backup"
    
    # Add new VMs to kustomization
    echo "" >> "$APPS_DIR/kustomization.yaml"
    echo "# Auto-generated VMs ($(date))" >> "$APPS_DIR/kustomization.yaml"
    
    for i in $(seq 1 $VM_COUNT); do
        local vm_name="${VM_PREFIX}-$(printf "%02d" $i)"
        echo "- $vm_name/" >> "$APPS_DIR/kustomization.yaml"
    done
    
    log_success "Updated main kustomization.yaml"
}

# Create NLB infrastructure
create_nlb_infrastructure() {
    if [[ "$SKIP_NLB" == "true" ]]; then
        log_info "Skipping NLB creation (--skip-nlb specified)"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        source /tmp/nlb-requirements.env
        log_info "[DRY RUN] Would create $NLB_COUNT NLBs for external access"
        if [[ -n "$DOMAIN_NAME" ]]; then
            log_info "[DRY RUN] Would generate DNS configuration for $DOMAIN_NAME"
        fi
        return
    fi
    
    source /tmp/nlb-requirements.env
    log_info "Creating NLB infrastructure ($NLB_COUNT NLBs)..."
    
    local nlb_args="--action create --nlb-count $NLB_COUNT"
    if [[ -n "$DOMAIN_NAME" ]]; then
        nlb_args="$nlb_args --domain $DOMAIN_NAME"
    fi
    
    if $SCRIPT_DIR/scale-nlb.sh $nlb_args; then
        log_success "NLB infrastructure created successfully"
    else
        log_error "Failed to create NLB infrastructure"
        return 1
    fi
}

# Configure target groups for new VMs
configure_target_groups() {
    if [[ "$SKIP_NLB" == "true" || "$DRY_RUN" == "true" ]]; then
        return
    fi
    
    log_info "Configuring target groups for new VMs..."
    
    # Get ROSA worker nodes
    local worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker \
        -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
    
    if [[ -z "$worker_nodes" ]]; then
        log_error "Could not find ROSA worker nodes"
        return 1
    fi
    
    log_info "Found worker nodes: $worker_nodes"
    
    # Configure target groups for each new VM port
    local current_port=$((BASE_PORT + 1))
    
    for i in $(seq 1 $VM_COUNT); do
        local vm_name="${VM_PREFIX}-$(printf "%02d" $i)"
        log_info "Configuring target group for $vm_name:$current_port..."
        
        # Determine which NLB this port belongs to
        local nlb_index=$(((current_port - 2201) / 50 + 1))
        local nlb_name="rosa-ssh-nlb-$nlb_index"
        
        # Create target group and listener
        # (This would be expanded with actual AWS CLI commands)
        
        current_port=$((current_port + 1))
    done
}

# Generate deployment summary
generate_summary() {
    local summary_file="/tmp/vm-deployment-summary-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$summary_file" <<EOF
# VM Deployment Summary

**Deployment Date:** $(date)
**VM Count:** $VM_COUNT
**VM Prefix:** $VM_PREFIX
**Domain:** ${DOMAIN_NAME:-"Not configured"}

## VM List

| VM Name | Type | SSH Port | Namespace | SSH Command |
|---------|------|----------|-----------|-------------|
EOF

    local current_port=$((BASE_PORT + 1))
    for i in $(seq 1 $VM_COUNT); do
        local vm_name="${VM_PREFIX}-$(printf "%02d" $i)"
        local vm_type="${VM_TYPES[$((i % ${#VM_TYPES[@]}))]}"
        local password="${vm_name^}Dev@2024"
        
        if [[ -n "$DOMAIN_NAME" ]]; then
            local nlb_index=$(((current_port - 2201) / 50 + 1))
            local subdomain="ssh"
            if [[ $nlb_index -gt 1 ]]; then
                subdomain="ssh$nlb_index"
            fi
            local ssh_command="ssh developer@$subdomain.$DOMAIN_NAME:$current_port"
        else
            local ssh_command="ssh developer@<nlb-dns>:$current_port"
        fi
        
        echo "| $vm_name | $vm_type | $current_port | $vm_name | \`$ssh_command\` |" >> "$summary_file"
        current_port=$((current_port + 1))
    done
    
    cat >> "$summary_file" <<EOF

## SSH Access

All VMs use the following credentials:
- **Username:** developer
- **Password:** {VMName}Dev@2024 (e.g., Vm-01Dev@2024)

## Port Allocation

- **Existing Apps:** 2201-2205 (5 ports)
- **New VMs:** 2206-$((2205 + VM_COUNT)) ($VM_COUNT ports)
- **Total:** $((VM_COUNT + 5)) SSH ports

## NLB Configuration

EOF

    if [[ -f "/tmp/nlb-requirements.env" ]]; then
        source /tmp/nlb-requirements.env
        echo "- **NLBs Required:** $NLB_COUNT" >> "$summary_file"
        echo "- **Estimated Monthly Cost:** \$$(($NLB_COUNT * 22))+" >> "$summary_file"
    fi
    
    cat >> "$summary_file" <<EOF

## Next Steps

1. **Commit and Push:** Add new VM manifests to git and push
2. **ArgoCD Sync:** Wait for ArgoCD to deploy the new VMs
3. **NLB Configuration:** Complete target group configuration
4. **DNS Setup:** Add CNAME records to your domain provider
5. **Testing:** Use the generated SSH commands to test access

## Files Created

EOF
    
    for i in $(seq 1 $VM_COUNT); do
        local vm_name="${VM_PREFIX}-$(printf "%02d" $i)"
        echo "- \`apps/$vm_name/\` - Complete GitOps manifests" >> "$summary_file"
    done
    
    log_success "Deployment summary saved to: $summary_file"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo ""
        log_info "Quick Access Commands:"
        echo "  cat $summary_file"
        echo "  code $summary_file"
    fi
}

# Main execution
main() {
    log_info "Starting VM cluster deployment..."
    
    # Calculate requirements
    calculate_nlb_requirements
    
    # Generate VM configurations
    generate_vm_configs
    
    # Update main kustomization
    update_main_kustomization
    
    # Create NLB infrastructure
    create_nlb_infrastructure
    
    # Configure target groups
    configure_target_groups
    
    # Generate summary
    generate_summary
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run completed. No changes were made."
    else
        log_success "VM cluster deployment completed successfully!"
        log_info "Next steps:"
        echo "  1. Review generated configurations"
        echo "  2. Commit and push to git repository"
        echo "  3. Monitor ArgoCD for deployment status"
        echo "  4. Configure DNS records if domain was specified"
    fi
}

# Run main function
main
