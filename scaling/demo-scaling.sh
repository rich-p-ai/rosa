#!/bin/bash

# Quick Demo: Deploy 10 VMs with External SSH Access
# This demonstrates the scaling system from 5 apps to 15 total VMs

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

echo "========================================="
echo "🚀 ROSA Scaling Demo: 5 Apps → 15 VMs"
echo "========================================="
echo ""

# Step 1: Show current state
log_info "Current State Assessment:"
echo "  ✅ Existing Apps: 5 (react, vue, angular, nodejs, django)"
echo "  ✅ SSH Ports Used: 2201-2205"
echo "  ✅ Current NLB: 1 (rosa-ssh-nlb)"
echo ""

# Step 2: Demo VM creation
log_info "Demo: Creating 10 additional VMs..."
echo ""

VMs=(
    "dev-frontend-01:frontend"
    "dev-backend-01:backend" 
    "test-app-01:fullstack"
    "staging-web-01:frontend"
    "api-service-01:backend"
    "demo-app-01:fullstack"
    "dev-minimal-01:minimal"
    "test-backend-01:backend"
    "staging-api-01:backend"
    "demo-frontend-01:frontend"
)

for i in "${!VMs[@]}"; do
    IFS=':' read -r vm_name vm_type <<< "${VMs[$i]}"
    port=$((2206 + i))
    
    echo "[$((i+1))/10] Creating VM: $vm_name"
    echo "    Type: $vm_type"
    echo "    SSH Port: $port"
    echo "    SSH Command: ssh developer@ssh.yourdomain.com:$port"
    echo "    Password: ${vm_name^}Dev@2024"
    echo ""
done

log_success "Demo VMs configured! (This was a simulation)"
echo ""

# Step 3: NLB scaling requirements
log_info "NLB Scaling Analysis:"
echo "  Current: 5 apps + 10 new VMs = 15 total SSH endpoints"
echo "  Ports needed: 2201-2215 (15 ports)"
echo "  NLBs required: 1 (under 50 port limit)"
echo "  Monthly cost: ~$22.50 (1 NLB)"
echo ""

# Step 4: Scaling to 200 VMs projection
log_info "Scaling to 200 VMs projection:"
echo "  Total SSH endpoints: 200"
echo "  Port range: 2201-2400"
echo "  NLBs required: 4 (50 ports each)"
echo "  Monthly cost: ~$90 (4 NLBs)"
echo ""
echo "  NLB Distribution:"
echo "    NLB-1: ssh.domain.com:2201-2250   (50 VMs)"
echo "    NLB-2: ssh2.domain.com:2201-2250  (50 VMs)"
echo "    NLB-3: ssh3.domain.com:2201-2250  (50 VMs)"
echo "    NLB-4: ssh4.domain.com:2201-2250  (50 VMs)"
echo ""

# Step 5: Real deployment commands
log_info "To actually deploy VMs, use these commands:"
echo ""
echo "# Deploy 10 VMs:"
echo "  ./scaling/deploy-vm-cluster.sh --vms 10 --domain yourdomain.com"
echo ""
echo "# Deploy 50 VMs with custom prefix:"
echo "  ./scaling/deploy-vm-cluster.sh --vms 50 --prefix prod --domain yourdomain.com"
echo ""
echo "# Create single VM manually:"
echo "  ./scaling/create-vm.sh --name my-app --type frontend --port 2206"
echo ""
echo "# Scale NLB infrastructure:"
echo "  ./scaling/scale-nlb.sh --action create --nlb-count 4 --domain yourdomain.com"
echo ""

# Step 6: Integration with existing workflow
log_info "Integration with your existing GitOps workflow:"
echo "  1. Generated VMs follow the same Red Hat UBI9 pattern as your 5 apps"
echo "  2. SSH access uses identical sidecar container approach"
echo "  3. ArgoCD sync waves ensure proper deployment order"
echo "  4. External access scales seamlessly with AWS NLB"
echo ""

log_success "Demo completed! Your scaling architecture is ready."
echo ""
echo "Next steps to deploy real VMs:"
echo "  1. Run: ./scaling/deploy-vm-cluster.sh --vms 10 --dry-run"
echo "  2. Review the output and configurations"  
echo "  3. Run without --dry-run to deploy"
echo "  4. Update your DNS with the generated CNAME records"
