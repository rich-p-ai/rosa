#!/bin/bash

# GitOps Web Applications Deployment Script
# Deploys 5 different web applications using GitOps methodology

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

# Check if we're connected to the cluster
check_cluster_connection() {
    log_info "Checking cluster connection..."
    if ! oc whoami &>/dev/null; then
        log_error "Not connected to OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    
    local current_user=$(oc whoami)
    local current_server=$(oc whoami --show-server)
    log_success "Connected as: $current_user"
    log_info "Server: $current_server"
}

# Deploy individual application
deploy_app() {
    local app_name=$1
    local app_path="apps/$app_name"
    
    log_info "Deploying $app_name..."
    
    if [ ! -d "$app_path" ]; then
        log_error "Application directory $app_path not found"
        return 1
    fi
    
    # Apply the application manifests
    oc apply -k "$app_path"
    
    log_success "$app_name deployed successfully"
}

# Wait for application to be ready
wait_for_app() {
    local app_name=$1
    local namespace=$2
    
    log_info "Waiting for $app_name to be ready..."
    
    # Wait for deployment to be ready
    if oc get deployment "$app_name" -n "$namespace" &>/dev/null; then
        oc rollout status deployment/"$app_name" -n "$namespace" --timeout=300s
        log_success "$app_name is ready"
    else
        log_warning "No deployment found for $app_name in namespace $namespace"
    fi
}

# Show application URLs
show_application_urls() {
    log_info "Application URLs:"
    echo ""
    
    local apps=("react-frontend" "vue-frontend" "angular-frontend" "nodejs-backend" "django-backend")
    local hosts=("react.apps.p-ai.net" "vue.apps.p-ai.net" "angular.apps.p-ai.net" "nodejs.apps.p-ai.net" "django.apps.p-ai.net")
    
    for i in "${!apps[@]}"; do
        local app="${apps[$i]}"
        local host="${hosts[$i]}"
        echo -e "  🌐 ${app}: ${GREEN}https://${host}${NC}"
    done
    
    echo ""
}

# Deploy all applications
deploy_all_apps() {
    log_info "Starting deployment of all web applications..."
    echo ""
    
    # Backend applications first (lower sync wave)
    log_info "Deploying backend applications..."
    deploy_app "nodejs-backend"
    deploy_app "django-backend"
    
    echo ""
    
    # Frontend applications
    log_info "Deploying frontend applications..."
    deploy_app "react-frontend"
    deploy_app "vue-frontend"
    deploy_app "angular-frontend"
    
    echo ""
    log_success "All applications deployed!"
    echo ""
    log_info "🔧 Testing SSH access to applications..."
    if [ -f "./test-ssh-access.sh" ]; then
        ./test-ssh-access.sh check
    else
        log_warning "SSH test script not found. Run manually: ./test-ssh-access.sh"
    fi
}

# Wait for all applications
wait_for_all_apps() {
    log_info "Waiting for all applications to be ready..."
    echo ""
    
    wait_for_app "nodejs-backend" "nodejs-backend"
    wait_for_app "django-backend" "django-backend"
    wait_for_app "react-frontend" "react-frontend"
    wait_for_app "vue-frontend" "vue-frontend"
    wait_for_app "angular-frontend" "angular-frontend"
    
    echo ""
    log_success "All applications are ready!"
}

# Show status of all applications
show_status() {
    log_info "Application Status:"
    echo ""
    
    local namespaces=("react-frontend" "vue-frontend" "angular-frontend" "nodejs-backend" "django-backend")
    
    for ns in "${namespaces[@]}"; do
        echo -e "${BLUE}=== $ns ===${NC}"
        if oc get namespace "$ns" &>/dev/null; then
            oc get pods,svc,routes -n "$ns" 2>/dev/null || echo "No resources found"
        else
            echo "Namespace not found"
        fi
        echo ""
    done
}

# Clean up applications
cleanup_apps() {
    log_warning "Cleaning up all web applications..."
    
    local namespaces=("react-frontend" "vue-frontend" "angular-frontend" "nodejs-backend" "django-backend")
    
    for ns in "${namespaces[@]}"; do
        if oc get namespace "$ns" &>/dev/null; then
            log_info "Deleting namespace: $ns"
            oc delete namespace "$ns" --wait=false
        fi
    done
    
    log_success "Cleanup initiated"
}

# Show help
show_help() {
    echo "GitOps Web Applications Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy         Deploy all web applications"
    echo "  status         Show status of all applications"
    echo "  urls           Show application URLs"
    echo "  wait           Wait for all applications to be ready"
    echo "  cleanup        Delete all applications"
    echo "  help           Show this help message"
    echo ""
    echo "Applications:"
    echo "  - React Frontend (react.apps.p-ai.net) - Red Hat UBI9/NGINX + Node.js"
    echo "  - Vue.js Frontend (vue.apps.p-ai.net) - Red Hat UBI9/NGINX + Node.js"
    echo "  - Angular Frontend (angular.apps.p-ai.net) - Red Hat UBI9/NGINX + Node.js"
    echo "  - Node.js Backend (nodejs.apps.p-ai.net) - Red Hat UBI9/Node.js 18"
    echo "  - Django Backend (django.apps.p-ai.net) - Red Hat UBI9/Python 3.11"
    echo ""
    echo "Examples:"
    echo "  $0 deploy      # Deploy all applications"
    echo "  $0 status      # Check deployment status"
    echo "  $0 urls        # Show application URLs"
}

# Main script logic
main() {
    case "${1:-deploy}" in
        deploy)
            check_cluster_connection
            deploy_all_apps
            echo ""
            show_application_urls
            log_info "Run '$0 wait' to wait for applications to be ready"
            log_info "Run '$0 status' to check deployment status"
            ;;
        wait)
            check_cluster_connection
            wait_for_all_apps
            show_application_urls
            ;;
        status)
            check_cluster_connection
            show_status
            ;;
        urls)
            show_application_urls
            ;;
        cleanup)
            check_cluster_connection
            cleanup_apps
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
