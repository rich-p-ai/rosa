#!/bin/bash

# Web Applications Testing Script
# Comprehensive testing suite for all deployed applications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Increment test counter
test_start() {
    ((TOTAL_TESTS++))
}

# Test cluster connectivity
test_cluster_connection() {
    test_start
    log_info "Testing cluster connection..."
    
    if oc whoami &>/dev/null; then
        local user=$(oc whoami)
        local server=$(oc whoami --show-server)
        log_success "Connected to cluster as: $user ($server)"
    else
        log_error "Not connected to cluster. Please run 'oc login' first."
        return 1
    fi
}

# Test namespace existence
test_namespaces() {
    local namespaces=("react-frontend" "vue-frontend" "angular-frontend" "nodejs-backend" "django-backend")
    
    for ns in "${namespaces[@]}"; do
        test_start
        log_info "Testing namespace: $ns"
        
        if oc get namespace "$ns" &>/dev/null; then
            log_success "Namespace $ns exists"
        else
            log_error "Namespace $ns not found"
        fi
    done
}

# Test pod status
test_pod_status() {
    local deployments=(
        "react-frontend:react-frontend"
        "vue-frontend:vue-frontend" 
        "angular-frontend:angular-frontend"
        "nodejs-backend:nodejs-backend"
        "django-backend:django-backend"
    )
    
    for deployment in "${deployments[@]}"; do
        IFS=':' read -r namespace app <<< "$deployment"
        test_start
        log_info "Testing pods in $namespace..."
        
        if oc get deployment "$app" -n "$namespace" &>/dev/null; then
            local ready_replicas=$(oc get deployment "$app" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local desired_replicas=$(oc get deployment "$app" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            
            if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
                log_success "$app: $ready_replicas/$desired_replicas pods ready"
            else
                log_error "$app: $ready_replicas/$desired_replicas pods ready"
            fi
        else
            log_error "Deployment $app not found in namespace $namespace"
        fi
    done
}

# Test service endpoints
test_services() {
    local services=(
        "react-frontend:react-frontend-service:80"
        "vue-frontend:vue-frontend-service:80"
        "angular-frontend:angular-frontend-service:80"
        "nodejs-backend:nodejs-backend-service:3000"
        "django-backend:django-backend-service:8000"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r namespace svc_name port <<< "$service"
        test_start
        log_info "Testing service: $svc_name in $namespace"
        
        if oc get service "$svc_name" -n "$namespace" &>/dev/null; then
            local cluster_ip=$(oc get service "$svc_name" -n "$namespace" -o jsonpath='{.spec.clusterIP}')
            log_success "Service $svc_name available at $cluster_ip:$port"
        else
            log_error "Service $svc_name not found in namespace $namespace"
        fi
    done
}

# Test routes
test_routes() {
    local routes=(
        "react-frontend:react-frontend-route:react.apps.p-ai.net"
        "vue-frontend:vue-frontend-route:vue.apps.p-ai.net"
        "angular-frontend:angular-frontend-route:angular.apps.p-ai.net"
        "nodejs-backend:nodejs-backend-route:nodejs.apps.p-ai.net"
        "django-backend:django-backend-route:django.apps.p-ai.net"
    )
    
    for route in "${routes[@]}"; do
        IFS=':' read -r namespace route_name expected_host <<< "$route"
        test_start
        log_info "Testing route: $route_name in $namespace"
        
        if oc get route "$route_name" -n "$namespace" &>/dev/null; then
            local host=$(oc get route "$route_name" -n "$namespace" -o jsonpath='{.spec.host}')
            if [ "$host" = "$expected_host" ]; then
                log_success "Route $route_name configured correctly: $host"
            else
                log_error "Route $route_name host mismatch. Expected: $expected_host, Got: $host"
            fi
        else
            log_error "Route $route_name not found in namespace $namespace"
        fi
    done
}

# Test HTTP endpoints
test_http_endpoints() {
    local endpoints=(
        "https://react.apps.p-ai.net:React Frontend"
        "https://vue.apps.p-ai.net:Vue Frontend"
        "https://angular.apps.p-ai.net:Angular Frontend"
        "https://nodejs.apps.p-ai.net/health:Node.js Backend Health"
        "https://django.apps.p-ai.net/health/:Django Backend Health"
    )
    
    for endpoint in "${endpoints[@]}"; do
        IFS=':' read -r url description <<< "$endpoint"
        test_start
        log_info "Testing HTTP endpoint: $description"
        
        local response_code=$(curl -k -s -o /dev/null -w "%{http_code}" "$url" --connect-timeout 10 || echo "000")
        
        if [ "$response_code" = "200" ]; then
            log_success "$description responded with HTTP $response_code"
        elif [ "$response_code" = "000" ]; then
            log_error "$description - Connection failed"
        else
            log_error "$description responded with HTTP $response_code"
        fi
    done
}

# Test API functionality
test_api_functionality() {
    log_info "Testing API functionality..."
    
    # Test Node.js API endpoints
    test_start
    log_info "Testing Node.js API endpoints"
    
    local nodejs_status=$(curl -k -s "https://nodejs.apps.p-ai.net/api/status" --connect-timeout 10 | grep -o "Node.js API is running" || echo "")
    if [ -n "$nodejs_status" ]; then
        log_success "Node.js API status endpoint working"
    else
        log_error "Node.js API status endpoint failed"
    fi
    
    test_start
    local nodejs_users=$(curl -k -s "https://nodejs.apps.p-ai.net/api/users" --connect-timeout 10 | grep -o "users" || echo "")
    if [ -n "$nodejs_users" ]; then
        log_success "Node.js API users endpoint working"
    else
        log_error "Node.js API users endpoint failed"
    fi
    
    # Test Django admin (if accessible)
    test_start
    log_info "Testing Django admin interface"
    
    local django_admin=$(curl -k -s -o /dev/null -w "%{http_code}" "https://django.apps.p-ai.net/admin/" --connect-timeout 10 || echo "000")
    if [ "$django_admin" = "200" ] || [ "$django_admin" = "302" ]; then
        log_success "Django admin interface accessible"
    else
        log_error "Django admin interface not accessible (HTTP $django_admin)"
    fi
}

# Test resource usage
test_resource_usage() {
    log_info "Testing resource usage..."
    
    local namespaces=("react-frontend" "vue-frontend" "angular-frontend" "nodejs-backend" "django-backend")
    
    for ns in "${namespaces[@]}"; do
        test_start
        log_info "Checking resource usage in $ns"
        
        local cpu_usage=$(oc adm top pods -n "$ns" --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum}' || echo "0")
        local memory_usage=$(oc adm top pods -n "$ns" --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum}' || echo "0")
        
        if [ "$cpu_usage" != "0" ] || [ "$memory_usage" != "0" ]; then
            log_success "$ns resource usage: CPU=${cpu_usage}m, Memory=${memory_usage}Mi"
        else
            log_warning "$ns resource metrics not available (metrics server may not be installed)"
        fi
    done
}

# Test persistent volumes (for Django)
test_persistent_volumes() {
    test_start
    log_info "Testing persistent volumes..."
    
    if oc get pvc django-media-pvc -n django-backend &>/dev/null; then
        local pvc_status=$(oc get pvc django-media-pvc -n django-backend -o jsonpath='{.status.phase}')
        if [ "$pvc_status" = "Bound" ]; then
            log_success "Django PVC is bound and ready"
        else
            log_error "Django PVC status: $pvc_status"
        fi
    else
        log_error "Django PVC not found"
    fi
}

# Test secrets
test_secrets() {
    log_info "Testing secrets configuration..."
    
    # Test Node.js secrets
    test_start
    if oc get secret nodejs-secrets -n nodejs-backend &>/dev/null; then
        local secret_keys=$(oc get secret nodejs-secrets -n nodejs-backend -o jsonpath='{.data}' | grep -o '"[^"]*"' | wc -l)
        if [ "$secret_keys" -gt 0 ]; then
            log_success "Node.js secrets configured ($secret_keys keys)"
        else
            log_error "Node.js secrets empty"
        fi
    else
        log_error "Node.js secrets not found"
    fi
    
    # Test Django secrets
    test_start
    if oc get secret django-secrets -n django-backend &>/dev/null; then
        local secret_keys=$(oc get secret django-secrets -n django-backend -o jsonpath='{.data}' | grep -o '"[^"]*"' | wc -l)
        if [ "$secret_keys" -gt 0 ]; then
            log_success "Django secrets configured ($secret_keys keys)"
        else
            log_error "Django secrets empty"
        fi
    else
        log_error "Django secrets not found"
    fi
}

# Test configuration maps
test_configmaps() {
    log_info "Testing configuration maps..."
    
    local configs=(
        "react-frontend:react-config"
        "vue-frontend:vue-config"
        "angular-frontend:angular-config"
        "nodejs-backend:nodejs-config"
        "django-backend:django-config"
    )
    
    for config in "${configs[@]}"; do
        IFS=':' read -r namespace cm_name <<< "$config"
        test_start
        
        if oc get configmap "$cm_name" -n "$namespace" &>/dev/null; then
            local data_keys=$(oc get configmap "$cm_name" -n "$namespace" -o jsonpath='{.data}' | grep -o '"[^"]*"' | wc -l)
            log_success "$cm_name has $data_keys configuration keys"
        else
            log_error "ConfigMap $cm_name not found in $namespace"
        fi
    done
}

# Test Red Hat image usage
test_redhat_images() {
    log_info "Testing Red Hat image usage..."
    
    local namespaces=("react-frontend" "vue-frontend" "angular-frontend" "nodejs-backend" "django-backend")
    local redhat_images_found=0
    
    for ns in "${namespaces[@]}"; do
        test_start
        if oc get namespace "$ns" &>/dev/null; then
            local images=$(oc get pods -n "$ns" -o jsonpath='{.items[*].spec.containers[*].image}' 2>/dev/null)
            if echo "$images" | grep -q "registry.redhat.io"; then
                log_success "$ns: Using Red Hat images"
                ((redhat_images_found++))
            else
                log_error "$ns: Not using Red Hat images"
            fi
        else
            log_error "Namespace $ns not found"
        fi
    done
    
    echo ""
    log_info "Red Hat Images Summary: $redhat_images_found/${#namespaces[@]} applications using Red Hat images"
}

# Generate test report
generate_report() {
    echo ""
    echo "========================================"
    echo "           TEST REPORT SUMMARY"
    echo "========================================"
    echo ""
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed:      ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:      ${RED}$FAILED_TESTS${NC}"
    echo ""
    
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "Success Rate: ${BLUE}$success_rate%${NC}"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! Applications are healthy.${NC}"
    elif [ $success_rate -ge 80 ]; then
        echo -e "${YELLOW}⚠️  Most tests passed. Review failed tests above.${NC}"
    else
        echo -e "${RED}❌ Multiple test failures detected. Applications may have issues.${NC}"
    fi
    
    echo ""
    echo "Application URLs:"
    echo "  🌐 React:   https://react.apps.p-ai.net"
    echo "  🌐 Vue:     https://vue.apps.p-ai.net"
    echo "  🌐 Angular: https://angular.apps.p-ai.net"
    echo "  🌐 Node.js: https://nodejs.apps.p-ai.net"
    echo "  🌐 Django:  https://django.apps.p-ai.net"
    echo ""
}

# Quick test (basic functionality)
quick_test() {
    log_info "Running quick test suite..."
    echo ""
    
    test_cluster_connection
    test_namespaces
    test_pod_status
    test_routes
    
    generate_report
}

# Full test suite
full_test() {
    log_info "Running full test suite..."
    echo ""
    
    test_cluster_connection
    test_namespaces
    test_pod_status
    test_services
    test_routes
    test_http_endpoints
    test_api_functionality
    test_resource_usage
    test_persistent_volumes
    test_secrets
    test_configmaps
    test_redhat_images
    
    generate_report
}

# Smoke test (minimal checks)
smoke_test() {
    log_info "Running smoke test..."
    echo ""
    
    test_cluster_connection
    test_pod_status
    test_http_endpoints
    
    generate_report
}

# Show help
show_help() {
    echo "Web Applications Testing Script"
    echo ""
    echo "Usage: $0 [TEST_TYPE]"
    echo ""
    echo "Test Types:"
    echo "  quick      Quick test (basic functionality)"
    echo "  full       Full test suite (comprehensive)"
    echo "  smoke      Smoke test (minimal checks)"
    echo "  endpoints  Test HTTP endpoints only"
    echo "  resources  Test resource usage only"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 quick      # Run quick tests"
    echo "  $0 full       # Run all tests"
    echo "  $0 smoke      # Run smoke tests"
}

# Main script logic
main() {
    case "${1:-quick}" in
        quick)
            quick_test
            ;;
        full)
            full_test
            ;;
        smoke)
            smoke_test
            ;;
        endpoints)
            test_cluster_connection
            test_http_endpoints
            test_api_functionality
            generate_report
            ;;
        resources)
            test_cluster_connection
            test_resource_usage
            generate_report
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown test type: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
