#!/bin/bash

# Comprehensive ROSA Web Applications Verification Script
# Tests web applications, SSH access, and GitOps deployment health
# Usage: ./verify-complete-deployment.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1"
}

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

# Application definitions
declare -A APPLICATIONS=(
    ["react-frontend"]="React Frontend"
    ["vue-frontend"]="Vue.js Frontend" 
    ["angular-frontend"]="Angular Frontend"
    ["nodejs-backend"]="Node.js Backend"
    ["django-backend"]="Django Backend"
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
echo "🚀 ROSA Web Applications Verification"
echo "========================================="
echo ""

# Check prerequisites
check_prerequisites() {
    log_section "🔍 Checking Prerequisites"
    
    local missing_tools=()
    
    # Check required tools
    if ! command -v oc >/dev/null 2>&1; then
        missing_tools+=("oc (OpenShift CLI)")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_tools+=("curl")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check OpenShift connection
    if ! oc whoami >/dev/null 2>&1; then
        log_error "Not logged in to OpenShift. Run 'oc login' first."
        exit 1
    fi
    
    local current_user=$(oc whoami)
    local current_server=$(oc whoami --show-server)
    log_success "Connected as: $current_user"
    log_info "Server: $current_server"
    echo ""
}

# Check namespace status
check_namespaces() {
    log_section "🏠 Checking Namespaces"
    
    local all_good=true
    
    for app in "${!APPLICATIONS[@]}"; do
        if oc get namespace "$app" >/dev/null 2>&1; then
            log_success "✅ Namespace: $app"
        else
            log_error "❌ Namespace: $app (not found)"
            all_good=false
        fi
    done
    
    if $all_good; then
        log_success "All namespaces are present"
    else
        log_warning "Some namespaces are missing"
    fi
    echo ""
}

# Check deployments and pods
check_deployments() {
    log_section "🚢 Checking Deployments and Pods"
    
    for app in "${!APPLICATIONS[@]}"; do
        local app_name="${APPLICATIONS[$app]}"
        log_test "Testing $app_name..."
        
        # Check main application deployment
        if oc get deployment "$app" -n "$app" >/dev/null 2>&1; then
            local replicas=$(oc get deployment "$app" -n "$app" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local desired=$(oc get deployment "$app" -n "$app" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
            
            if [[ "$replicas" == "$desired" ]] && [[ "$replicas" != "0" ]]; then
                log_success "  ✅ Main deployment: $replicas/$desired ready"
            else
                log_warning "  ⚠️  Main deployment: $replicas/$desired ready"
            fi
        else
            log_error "  ❌ Main deployment not found"
        fi
        
        # Check SSH deployment
        local ssh_deployment="${app}-ssh"
        if oc get deployment "$ssh_deployment" -n "$app" >/dev/null 2>&1; then
            local ssh_replicas=$(oc get deployment "$ssh_deployment" -n "$app" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local ssh_desired=$(oc get deployment "$ssh_deployment" -n "$app" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
            
            if [[ "$ssh_replicas" == "$ssh_desired" ]] && [[ "$ssh_replicas" != "0" ]]; then
                log_success "  ✅ SSH deployment: $ssh_replicas/$ssh_desired ready"
            else
                log_warning "  ⚠️  SSH deployment: $ssh_replicas/$ssh_desired ready"
            fi
        else
            log_error "  ❌ SSH deployment not found"
        fi
        
        echo ""
    done
}

# Check services
check_services() {
    log_section "🌐 Checking Services"
    
    for app in "${!APPLICATIONS[@]}"; do
        local app_name="${APPLICATIONS[$app]}"
        log_test "Testing services for $app_name..."
        
        # Check main service
        if oc get service "$app-service" -n "$app" >/dev/null 2>&1; then
            log_success "  ✅ Main service: $app-service"
        else
            log_error "  ❌ Main service not found"
        fi
        
        # Check SSH service
        local ssh_service="${app}-ssh-service"
        if oc get service "$ssh_service" -n "$app" >/dev/null 2>&1; then
            log_success "  ✅ SSH service: $ssh_service"
        else
            log_error "  ❌ SSH service not found"
        fi
        
        echo ""
    done
}

# Check routes and connectivity
check_routes() {
    log_section "🛤️  Checking Routes and Connectivity"
    
    for app in "${!APPLICATIONS[@]}"; do
        local app_name="${APPLICATIONS[$app]}"
        log_test "Testing routes for $app_name..."
        
        # Check main route
        local main_route="${app}-route"
        if oc get route "$main_route" -n "$app" >/dev/null 2>&1; then
            local route_host=$(oc get route "$main_route" -n "$app" -o jsonpath='{.spec.host}' 2>/dev/null)
            log_success "  ✅ Main route: https://$route_host"
            
            # Test HTTP connectivity
            local http_status=$(curl -s -o /dev/null -w "%{http_code}" "https://$route_host" --connect-timeout 10 || echo "000")
            if [[ "$http_status" =~ ^[23] ]]; then
                log_success "  ✅ HTTP connectivity: $http_status"
            else
                log_warning "  ⚠️  HTTP connectivity: $http_status"
            fi
        else
            log_error "  ❌ Main route not found"
        fi
        
        # Check SSH route
        local ssh_route="${app}-ssh-route"
        if oc get route "$ssh_route" -n "$app" >/dev/null 2>&1; then
            local ssh_route_host=$(oc get route "$ssh_route" -n "$app" -o jsonpath='{.spec.host}' 2>/dev/null)
            log_success "  ✅ SSH route: $ssh_route_host:$SSH_PORT"
            
            # Test SSH port connectivity
            if timeout 5 bash -c "</dev/tcp/$ssh_route_host/$SSH_PORT" >/dev/null 2>&1; then
                log_success "  ✅ SSH port connectivity"
            else
                log_warning "  ⚠️  SSH port not reachable"
            fi
        else
            log_error "  ❌ SSH route not found"
        fi
        
        echo ""
    done
}

# Test SSH authentication
test_ssh_authentication() {
    log_section "🔐 Testing SSH Authentication"
    
    for app in "${!APPLICATIONS[@]}"; do
        local app_name="${APPLICATIONS[$app]}"
        local password="${SSH_PASSWORDS[$app]}"
        log_test "Testing SSH auth for $app_name..."
        
        local ssh_route="${app}-ssh-route"
        if oc get route "$ssh_route" -n "$app" >/dev/null 2>&1; then
            local ssh_host=$(oc get route "$ssh_route" -n "$app" -o jsonpath='{.spec.host}' 2>/dev/null)
            
            # Test SSH banner (non-interactive)
            local ssh_test=$(timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "$SSH_USER@$ssh_host" -p "$SSH_PORT" "echo 'SSH test successful'" 2>&1 || echo "Connection failed")
            
            if [[ "$ssh_test" == *"SSH test successful"* ]]; then
                log_success "  ✅ SSH authentication working"
            elif [[ "$ssh_test" == *"Permission denied"* ]]; then
                log_warning "  ⚠️  SSH server running, auth configured (password: $password)"
            else
                log_warning "  ⚠️  SSH connection issue: ${ssh_test:0:50}..."
            fi
        else
            log_error "  ❌ SSH route not available"
        fi
        
        echo ""
    done
}

# Check secrets and configurations
check_secrets() {
    log_section "🔑 Checking Secrets and Configurations"
    
    for app in "${!APPLICATIONS[@]}"; do
        local app_name="${APPLICATIONS[$app]}"
        log_test "Testing secrets for $app_name..."
        
        # Check SSH secret
        local ssh_secret="${app}-ssh-secret"
        if oc get secret "$ssh_secret" -n "$app" >/dev/null 2>&1; then
            log_success "  ✅ SSH secret: $ssh_secret"
        else
            log_error "  ❌ SSH secret not found"
        fi
        
        # Check ConfigMap
        local configmap="${app}-config"
        if oc get configmap "$configmap" -n "$app" >/dev/null 2>&1; then
            log_success "  ✅ ConfigMap: $configmap"
        else
            log_warning "  ⚠️  ConfigMap not found (may be optional)"
        fi
        
        echo ""
    done
}

# Check resource usage
check_resource_usage() {
    log_section "📊 Checking Resource Usage"
    
    for app in "${!APPLICATIONS[@]}"; do
        local app_name="${APPLICATIONS[$app]}"
        log_test "Resource usage for $app_name..."
        
        # Get pod resource usage
        local pods=$(oc get pods -n "$app" -o name 2>/dev/null | wc -l)
        log_info "  📦 Pods running: $pods"
        
        # Check PVC if exists (mainly for Django)
        if oc get pvc -n "$app" >/dev/null 2>&1; then
            local pvc_count=$(oc get pvc -n "$app" --no-headers 2>/dev/null | wc -l)
            log_info "  💾 PVCs: $pvc_count"
        fi
        
        echo ""
    done
}

# Generate connectivity summary
generate_connectivity_summary() {
    log_section "📋 Connectivity Summary"
    
    echo "🌐 Web Application URLs:"
    for app in "${!APPLICATIONS[@]}"; do
        local app_name="${APPLICATIONS[$app]}"
        local main_route="${app}-route"
        
        if oc get route "$main_route" -n "$app" >/dev/null 2>&1; then
            local route_host=$(oc get route "$main_route" -n "$app" -o jsonpath='{.spec.host}' 2>/dev/null)
            echo -e "  ${GREEN}$app_name${NC}: https://$route_host"
        fi
    done
    
    echo ""
    echo "🔐 SSH Access Commands:"
    for app in "${!APPLICATIONS[@]}"; do
        local app_name="${APPLICATIONS[$app]}"
        local ssh_route="${app}-ssh-route"
        local password="${SSH_PASSWORDS[$app]}"
        
        if oc get route "$ssh_route" -n "$app" >/dev/null 2>&1; then
            local ssh_host=$(oc get route "$ssh_route" -n "$app" -o jsonpath='{.spec.host}' 2>/dev/null)
            echo -e "  ${GREEN}$app_name${NC}:"
            echo "    ssh $SSH_USER@$ssh_host -p $SSH_PORT"
            echo "    Password: $password"
            echo ""
        fi
    done
}

# Generate troubleshooting guide
generate_troubleshooting() {
    log_section "🔧 Troubleshooting Guide"
    
    cat << 'EOF'
If you encounter issues:

1. 🔍 Check Pod Status:
   oc get pods -A | grep -E "(react|vue|angular|nodejs|django)"

2. 📋 View Pod Logs:
   oc logs -n <namespace> deployment/<app-name>
   oc logs -n <namespace> deployment/<app-name>-ssh

3. 🌐 Test Routes:
   oc get routes -A | grep -E "(react|vue|angular|nodejs|django)"

4. 🔐 Test SSH Manually:
   oc port-forward -n <namespace> svc/<app>-ssh-service 2222:22
   ssh developer@localhost -p 2222

5. 📊 Check Resource Usage:
   oc describe pod -n <namespace> -l app=<app-name>

6. 🔄 Restart Applications:
   oc rollout restart deployment/<app-name> -n <namespace>
   oc rollout restart deployment/<app-name>-ssh -n <namespace>

For detailed SSH access guide, see: SSH-ACCESS-GUIDE.md
EOF
}

# Main execution
main() {
    case "${1:-all}" in
        "prereq")
            check_prerequisites
            ;;
        "namespaces")
            check_prerequisites
            check_namespaces
            ;;
        "deployments")
            check_prerequisites
            check_deployments
            ;;
        "services")
            check_prerequisites
            check_services
            ;;
        "routes")
            check_prerequisites
            check_routes
            ;;
        "ssh")
            check_prerequisites
            test_ssh_authentication
            ;;
        "secrets")
            check_prerequisites
            check_secrets
            ;;
        "resources")
            check_prerequisites
            check_resource_usage
            ;;
        "summary")
            check_prerequisites
            generate_connectivity_summary
            ;;
        "troubleshoot")
            generate_troubleshooting
            ;;
        "all"|*)
            check_prerequisites
            check_namespaces
            check_deployments
            check_services
            check_routes
            test_ssh_authentication
            check_secrets
            check_resource_usage
            echo ""
            generate_connectivity_summary
            echo ""
            generate_troubleshooting
            echo ""
            log_success "🎉 Verification complete! All systems checked."
            ;;
    esac
}

main "$@"
