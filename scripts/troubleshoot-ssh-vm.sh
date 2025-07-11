#!/bin/bash

# SSH VM Troubleshooting Script for ROSA Cluster
# This script helps troubleshoot SSH connection issues to VMs through AWS Load Balancer
# Usage: ./troubleshoot-ssh-vm.sh [vm-name] [nodeport]

set -e

# Configuration
VM_NAME="${1:-test2}"
NODEPORT="${2:-30522}"
ELB_HOSTNAME="rosa-nodeport-ddaa814ca551b53e.elb.us-east-1.amazonaws.com"
SSH_USER="admin"

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

# Check SSH key setup
check_ssh_keys() {
    log_info "Checking SSH key configuration..."
    
    echo "Current SSH keys in ~/.ssh/:"
    ls -la ~/.ssh/id_* 2>/dev/null || echo "No SSH keys found in ~/.ssh/"
    
    echo ""
    echo "SSH keys being offered by ssh-agent:"
    ssh-add -l 2>/dev/null || echo "No keys in ssh-agent"
    
    echo ""
    if [ -f ~/.ssh/id_rsa.pub ]; then
        echo "Public key fingerprint (id_rsa):"
        ssh-keygen -lf ~/.ssh/id_rsa.pub
    fi
    
    if [ -f ~/.ssh/id_ed25519.pub ]; then
        echo "Public key fingerprint (id_ed25519):"
        ssh-keygen -lf ~/.ssh/id_ed25519.pub
    fi
}

# Check VM SSH key configuration in OpenShift
check_vm_ssh_config() {
    log_info "Checking VM SSH configuration in OpenShift cluster..."
    
    # Check if VM exists
    if oc get vm "$VM_NAME" -n default >/dev/null 2>&1; then
        log_success "VM '$VM_NAME' found"
        oc describe vm "$VM_NAME" -n default
    else
        log_error "VM '$VM_NAME' not found in default namespace"
        echo "Available VMs:"
        oc get vms --all-namespaces 2>/dev/null || echo "No VMs found or OpenShift not accessible"
    fi
    
    echo ""
    
    # Check SSH service and nodeport
    log_info "Checking SSH service configuration..."
    if oc get svc "${VM_NAME}-ssh" -n default >/dev/null 2>&1; then
        log_success "SSH service found"
        oc describe svc "${VM_NAME}-ssh" -n default
    else
        log_warning "SSH service '${VM_NAME}-ssh' not found"
        echo "Available services:"
        oc get svc -n default
    fi
}

# Test SSH connectivity with different keys
test_ssh_connectivity() {
    log_info "Testing SSH connectivity..."
    
    # Test basic connectivity
    echo "Testing port connectivity:"
    nc -zv "$ELB_HOSTNAME" "$NODEPORT" || echo "Port $NODEPORT is not reachable"
    
    echo ""
    
    # Test SSH with different key options
    log_info "Testing SSH with verbose output..."
    
    # Try with specific key if it exists
    if [ -f ~/.ssh/id_rsa ]; then
        echo "Attempting SSH with id_rsa key:"
        ssh -v -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
            -i ~/.ssh/id_rsa \
            "$SSH_USER@$ELB_HOSTNAME" -p "$NODEPORT" \
            "echo 'SSH connection successful'" 2>&1 | head -20
    fi
    
    echo ""
    
    if [ -f ~/.ssh/id_ed25519 ]; then
        echo "Attempting SSH with id_ed25519 key:"
        ssh -v -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
            -i ~/.ssh/id_ed25519 \
            "$SSH_USER@$ELB_HOSTNAME" -p "$NODEPORT" \
            "echo 'SSH connection successful'" 2>&1 | head -20
    fi
}

# Generate SSH key pair if needed
generate_ssh_key() {
    log_info "Generating new SSH key pair..."
    
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "rosa-vm-access"
        log_success "RSA key pair generated"
    else
        log_warning "RSA key already exists"
    fi
    
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "rosa-vm-access"
        log_success "Ed25519 key pair generated"
    else
        log_warning "Ed25519 key already exists"
    fi
    
    # Add keys to ssh-agent
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa 2>/dev/null || true
    ssh-add ~/.ssh/id_ed25519 2>/dev/null || true
}

# Create VM with proper SSH configuration
create_vm_with_ssh() {
    log_info "Creating VM manifest with SSH access..."
    
    # Get public key
    if [ -f ~/.ssh/id_rsa.pub ]; then
        SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)
    elif [ -f ~/.ssh/id_ed25519.pub ]; then
        SSH_PUBLIC_KEY=$(cat ~/.ssh/id_ed25519.pub)
    else
        log_error "No SSH public key found. Run with --generate-key option first."
        return 1
    fi
    
    cat > "/tmp/${VM_NAME}-with-ssh.yaml" << EOF
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: $VM_NAME
  namespace: default
spec:
  running: true
  template:
    metadata:
      labels:
        kubevirt.io/vm: $VM_NAME
    spec:
      domain:
        cpu:
          cores: 2
        memory:
          guest: 4Gi
        devices:
          disks:
          - name: containerdisk
            disk:
              bus: virtio
          - name: cloudinitdisk
            disk:
              bus: virtio
          interfaces:
          - name: default
            masquerade: {}
        resources:
          requests:
            memory: 4Gi
      networks:
      - name: default
        pod: {}
      volumes:
      - name: containerdisk
        containerDisk:
          image: quay.io/containerdisks/ubuntu:20.04
      - name: cloudinitdisk
        cloudInitNoCloud:
          userData: |
            #cloud-config
            hostname: $VM_NAME
            users:
            - name: admin
              sudo: ALL=(ALL) NOPASSWD:ALL
              ssh_authorized_keys:
              - $SSH_PUBLIC_KEY
            - name: root
              ssh_authorized_keys:
              - $SSH_PUBLIC_KEY
            packages:
            - openssh-server
            - net-tools
            - curl
            - wget
            - vim
            runcmd:
            - systemctl enable ssh
            - systemctl start ssh
            - ufw allow ssh
---
apiVersion: v1
kind: Service
metadata:
  name: ${VM_NAME}-ssh
  namespace: default
spec:
  type: NodePort
  ports:
  - port: 22
    targetPort: 22
    nodePort: $NODEPORT
    protocol: TCP
    name: ssh
  selector:
    kubevirt.io/vm: $VM_NAME
EOF
    
    log_success "VM manifest created at /tmp/${VM_NAME}-with-ssh.yaml"
    echo "Apply with: oc apply -f /tmp/${VM_NAME}-with-ssh.yaml"
}

# Show connection instructions
show_connection_info() {
    log_info "SSH Connection Information:"
    echo ""
    echo "Connection Details:"
    echo "  Hostname: $ELB_HOSTNAME"
    echo "  Port: $NODEPORT"
    echo "  User: $SSH_USER"
    echo "  VM: $VM_NAME"
    echo ""
    echo "Connection Commands:"
    echo "  ssh $SSH_USER@$ELB_HOSTNAME -p $NODEPORT"
    echo "  ssh -i ~/.ssh/id_rsa $SSH_USER@$ELB_HOSTNAME -p $NODEPORT"
    echo "  ssh -i ~/.ssh/id_ed25519 $SSH_USER@$ELB_HOSTNAME -p $NODEPORT"
    echo ""
    echo "Debug Connection:"
    echo "  ssh -vvv $SSH_USER@$ELB_HOSTNAME -p $NODEPORT"
    echo ""
}

# Main troubleshooting function
main() {
    echo ""
    echo "========================================="
    echo "ROSA VM SSH Troubleshooting"
    echo "VM: $VM_NAME | Port: $NODEPORT"
    echo "========================================="
    echo ""
    
    case "${3:-check}" in
        "check")
            check_ssh_keys
            echo ""
            check_vm_ssh_config
            echo ""
            show_connection_info
            ;;
        "test")
            test_ssh_connectivity
            ;;
        "generate-key")
            generate_ssh_key
            ;;
        "create-vm")
            create_vm_with_ssh
            ;;
        "full")
            check_ssh_keys
            echo ""
            check_vm_ssh_config
            echo ""
            test_ssh_connectivity
            echo ""
            show_connection_info
            ;;
        *)
            echo "Usage: $0 [vm-name] [nodeport] [action]"
            echo ""
            echo "Actions:"
            echo "  check      - Check SSH keys and VM configuration (default)"
            echo "  test       - Test SSH connectivity"
            echo "  generate-key - Generate new SSH key pair"
            echo "  create-vm  - Create VM manifest with SSH access"
            echo "  full       - Run all checks"
            echo ""
            exit 1
            ;;
    esac
}

main "$@"
