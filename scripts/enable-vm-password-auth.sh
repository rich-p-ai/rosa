#!/bin/bash

# Script to Enable Password Authentication for ROSA VM SSH Access
# This script provides instructions for customers to enable password-based SSH
# instead of key-based authentication for their VMs

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

VM_NAME=${1:-"test2"}

echo "========================================="
echo "Enable Password Authentication for VM"
echo "VM Name: $VM_NAME"
echo "========================================="
echo ""

# Check if oc is available
if ! command -v oc >/dev/null 2>&1; then
    log_error "OpenShift CLI (oc) is not installed or not in PATH"
    exit 1
fi

# Check if logged in to OpenShift
if ! oc whoami >/dev/null 2>&1; then
    log_error "Not logged in to OpenShift. Run 'oc login' first."
    exit 1
fi

log_info "Checking VM status..."

# Check if VM exists
if ! oc get vm "$VM_NAME" >/dev/null 2>&1; then
    log_error "VM '$VM_NAME' not found. Available VMs:"
    oc get vm -A
    exit 1
fi

log_success "VM '$VM_NAME' found"

echo ""
log_info "To enable password authentication, follow these steps:"
echo ""

echo "1. Access VM Console:"
echo "   - Go to OpenShift Web Console"
echo "   - Navigate: Virtualization → Virtual Machines"
echo "   - Find VM '$VM_NAME' and click on it"
echo "   - Go to 'Console' tab"
echo "   - Login with existing credentials"
echo ""

echo "2. Configure SSH for Password Authentication:"
echo "   Run these commands in the VM console:"
echo ""
echo "   sudo nano /etc/ssh/sshd_config"
echo ""
echo "   Make these changes:"
echo "   PasswordAuthentication yes"
echo "   PubkeyAuthentication no"
echo "   ChallengeResponseAuthentication yes"
echo "   UsePAM yes"
echo ""
echo "   Save and restart SSH:"
echo "   sudo systemctl restart sshd"
echo ""

echo "3. Set User Password:"
echo "   sudo passwd admin"
echo "   # Enter new password when prompted"
echo ""

echo "4. Test SSH Connection:"
echo "   ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no admin@rosa-nodeport-ddaa814ca551b53e.elb.us-east-1.amazonaws.com -p 30522"
echo ""

log_warning "SECURITY NOTE: Password authentication is less secure than SSH keys"
log_info "Consider using strong passwords and monitoring access"

echo ""
log_info "Alternative: Update VM Configuration for Persistent Changes"
echo ""

# Generate cloud-init template
cat > "/tmp/vm-password-auth-cloudinit.yaml" << 'EOF'
# Add this to your VM's cloud-init configuration
# oc edit vm test2

spec:
  template:
    spec:
      volumes:
      - cloudInitNoCloud:
          userData: |
            #cloud-config
            users:
              - name: admin
                sudo: ALL=(ALL) NOPASSWD:ALL
                lock_passwd: false
                plain_text_passwd: your_password_here
            ssh_pwauth: true
            package_update: true
            runcmd:
              - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
              - sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
              - sed -i 's/PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config
              - systemctl restart sshd
        name: cloudinitdisk
EOF

log_success "Cloud-init template saved to: /tmp/vm-password-auth-cloudinit.yaml"

echo ""
log_info "Useful debugging commands:"
echo ""
echo "# Check VM status"
echo "oc get vm $VM_NAME -o wide"
echo ""
echo "# Check VM instance"
echo "oc get vmi $VM_NAME -o wide"
echo ""
echo "# Get VM console URL"
echo "oc get vm $VM_NAME -o jsonpath='{.status.printableStatus}'"
echo ""
echo "# Check NodePort service"
echo "oc get svc -A | grep nodeport"
echo ""
echo "# Test network connectivity"
echo "telnet rosa-nodeport-ddaa814ca551b53e.elb.us-east-1.amazonaws.com 30522"
echo ""

log_success "Instructions provided. Customer should follow steps 1-4 above."
