#!/bin/bash

# SSH Access Testing Script for ROSA Web Applications
# This script tests SSH connectivity to all web application SSH services
# Usage: ./test-ssh-access.sh

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

# SSH Connection Details
declare -A SSH_SERVICES=(
    ["react-frontend"]="react-frontend-ssh-service.react-frontend.svc.cluster.local"
    ["vue-frontend"]="vue-frontend-ssh-service.vue-frontend.svc.cluster.local"
    ["angular-frontend"]="angular-frontend-ssh-service.angular-frontend.svc.cluster.local"
    ["nodejs-backend"]="nodejs-backend-ssh-service.nodejs-backend.svc.cluster.local"
    ["django-backend"]="django-backend-ssh-service.django-backend.svc.cluster.local"
)

declare -A SSH_PASSWORDS=(
    ["react-frontend"]="ReactDev@2024"
    ["vue-frontend"]="VueDev@2024"
    ["angular-frontend"]="AngularDev@2024"
    ["nodejs-backend"]="NodeDev@2024"
    ["django-backend"]="DjangoDev@2024"
)

SSH_USER="developer"
SSH_PORT="22"

echo "========================================="
echo "SSH Access Testing for ROSA Web Applications"
echo "========================================="
echo ""

# Check if oc is available and user is logged in
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v oc >/dev/null 2>&1; then
        log_error "OpenShift CLI (oc) is not installed or not in PATH"
        exit 1
    fi
    
    if ! oc whoami >/dev/null 2>&1; then
        log_error "Not logged in to OpenShift. Run 'oc login' first."
        exit 1
    fi
    
    log_success "Prerequisites satisfied"
}

# Check SSH service status
check_ssh_services() {
    log_info "Checking SSH service status..."
    echo ""
    
    for app in "${!SSH_SERVICES[@]}"; do
        local service_name="${app}-ssh-service"
        local namespace="${app}"
        
        echo "Checking ${app}:"
        
        # Check if namespace exists
        if oc get namespace "$namespace" >/dev/null 2>&1; then
            echo "  ✅ Namespace: $namespace"
        else
            echo "  ❌ Namespace: $namespace (not found)"
            continue
        fi
        
        # Check if service exists
        if oc get service "$service_name" -n "$namespace" >/dev/null 2>&1; then
            echo "  ✅ Service: $service_name"
        else
            echo "  ❌ Service: $service_name (not found)"
            continue
        fi
        
        # Check if SSH deployment exists
        local ssh_deployment="${app}-ssh"
        if oc get deployment "$ssh_deployment" -n "$namespace" >/dev/null 2>&1; then
            echo "  ✅ SSH Deployment: $ssh_deployment"
            
            # Check pod status
            local pod_status=$(oc get pods -n "$namespace" -l "app=$ssh_deployment" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
            echo "  📊 Pod Status: $pod_status"
        else
            echo "  ❌ SSH Deployment: $ssh_deployment (not found)"
        fi
        
        echo ""
    done
}

# Get SSH route information
get_ssh_routes() {
    log_info "Getting SSH route information..."
    echo ""
    
    for app in "${!SSH_SERVICES[@]}"; do
        local route_name="${app}-ssh-route"
        local namespace="${app}"
        
        echo "SSH Route for ${app}:"
        
        if oc get route "$route_name" -n "$namespace" >/dev/null 2>&1; then
            local route_host=$(oc get route "$route_name" -n "$namespace" -o jsonpath='{.spec.host}' 2>/dev/null)
            echo "  🌐 Route Host: $route_host"
            echo "  🔑 SSH Command: ssh $SSH_USER@$route_host -p $SSH_PORT"
            echo "  🔐 Password: ${SSH_PASSWORDS[$app]}"
        else
            echo "  ❌ Route not found: $route_name"
        fi
        
        echo ""
    done
}

# Test SSH connectivity
test_ssh_connectivity() {
    log_info "Testing SSH connectivity..."
    echo ""
    
    for app in "${!SSH_SERVICES[@]}"; do
        local route_name="${app}-ssh-route"
        local namespace="${app}"
        
        echo "Testing SSH for ${app}:"
        
        if oc get route "$route_name" -n "$namespace" >/dev/null 2>&1; then
            local route_host=$(oc get route "$route_name" -n "$namespace" -o jsonpath='{.spec.host}' 2>/dev/null)
            
            # Test port connectivity
            if timeout 5 bash -c "</dev/tcp/$route_host/$SSH_PORT" >/dev/null 2>&1; then
                echo "  ✅ Port $SSH_PORT is reachable on $route_host"
            else
                echo "  ❌ Port $SSH_PORT is not reachable on $route_host"
            fi
            
            # Test SSH banner (non-interactive)
            local ssh_banner=$(timeout 5 ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$SSH_USER@$route_host" -p "$SSH_PORT" 2>&1 | head -1 || echo "Connection failed")
            echo "  📡 SSH Response: $ssh_banner"
        else
            echo "  ❌ Route not available"
        fi
        
        echo ""
    done
}

# Display SSH access instructions
display_ssh_instructions() {
    log_info "SSH Access Instructions"
    echo ""
    
    cat << 'EOF'
📋 SSH Access Guide:

1. 🔐 SSH Authentication:
   - All SSH services use password authentication
   - Username: developer
   - Passwords are listed below for each service

2. 📁 Workspace Location:
   - All editable files are in: /home/developer/workspace/src
   - Use vim, nano, or other editors to modify files

3. 🛠️ Available Tools:
   - Text editors: vim, nano
   - Development tools: git, curl, wget
   - Package managers: dnf (RHEL), pip (Python), npm (Node.js)

4. 🔄 Making Changes:
   - Edit files directly in the workspace
   - Changes are persistent within the container
   - Restart the main application if needed

EOF

    echo "🔑 SSH Connection Commands:"
    echo ""
    
    for app in "${!SSH_SERVICES[@]}"; do
        local route_name="${app}-ssh-route"
        local namespace="${app}"
        
        if oc get route "$route_name" -n "$namespace" >/dev/null 2>&1; then
            local route_host=$(oc get route "$route_name" -n "$namespace" -o jsonpath='{.spec.host}' 2>/dev/null)
            echo "${app}:"
            echo "  ssh $SSH_USER@$route_host -p $SSH_PORT"
            echo "  Password: ${SSH_PASSWORDS[$app]}"
            echo ""
        fi
    done
}

# Port forwarding alternative
setup_port_forwarding() {
    log_info "Setting up port forwarding as an alternative..."
    echo ""
    
    echo "If routes are not accessible, you can use port forwarding:"
    echo ""
    
    for app in "${!SSH_SERVICES[@]}"; do
        local service_name="${app}-ssh-service"
        local namespace="${app}"
        local local_port=$((2200 + $(echo "$app" | wc -c)))
        
        echo "${app}:"
        echo "  oc port-forward -n $namespace svc/$service_name $local_port:22"
        echo "  ssh $SSH_USER@localhost -p $local_port"
        echo "  Password: ${SSH_PASSWORDS[$app]}"
        echo ""
    done
}

# Main execution
main() {
    case "${1:-all}" in
        "check")
            check_prerequisites
            check_ssh_services
            ;;
        "routes")
            check_prerequisites
            get_ssh_routes
            ;;
        "test")
            check_prerequisites
            test_ssh_connectivity
            ;;
        "instructions")
            display_ssh_instructions
            ;;
        "port-forward")
            setup_port_forwarding
            ;;
        "all"|*)
            check_prerequisites
            echo ""
            check_ssh_services
            echo ""
            get_ssh_routes
            echo ""
            test_ssh_connectivity
            echo ""
            display_ssh_instructions
            echo ""
            setup_port_forwarding
            ;;
    esac
}

main "$@"
