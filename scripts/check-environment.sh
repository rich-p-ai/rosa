#!/bin/bash

# ROSA Environment Check Script
# This script checks the status of your ROSA environment and authentication
# Usage: ./check-environment.sh

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

check_tool() {
    local tool=$1
    local description=$2
    
    if command -v "$tool" >/dev/null 2>&1; then
        local version=$(eval "$tool --version 2>/dev/null | head -1" 2>/dev/null || echo "Unknown")
        log_success "$description: ✅ Installed ($version)"
        return 0
    else
        log_error "$description: ❌ Not installed"
        return 1
    fi
}

check_aws_authentication() {
    log_info "Checking AWS authentication..."
    
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        local user_arn=$(aws sts get-caller-identity --query Arn --output text)
        log_success "AWS CLI: ✅ Authenticated"
        echo "  Account ID: $account_id"
        echo "  User/Role: $user_arn"
        
        # Check default region
        local region=$(aws configure get region)
        if [[ -n "$region" ]]; then
            echo "  Default Region: $region"
        else
            log_warning "  No default region configured"
        fi
        
        return 0
    else
        log_error "AWS CLI: ❌ Not authenticated"
        log_info "Run 'aws configure' to set up your credentials"
        return 1
    fi
}

check_rosa_authentication() {
    log_info "Checking ROSA authentication..."
    
    if rosa whoami >/dev/null 2>&1; then
        local whoami_output=$(rosa whoami)
        log_success "ROSA CLI: ✅ Authenticated"
        echo "$whoami_output" | sed 's/^/  /'
        return 0
    else
        log_error "ROSA CLI: ❌ Not authenticated"
        log_info "Run 'rosa login' to authenticate with Red Hat"
        return 1
    fi
}

check_rosa_quotas() {
    log_info "Checking ROSA service quotas..."
    
    if rosa verify quota >/dev/null 2>&1; then
        log_success "ROSA Quotas: ✅ Verified"
    else
        log_warning "ROSA Quotas: ⚠️  Verification failed"
        log_info "Check your AWS service quotas at: https://console.aws.amazon.com/servicequotas/"
    fi
}

list_rosa_clusters() {
    log_info "Listing existing ROSA clusters..."
    
    if rosa list clusters >/dev/null 2>&1; then
        local clusters=$(rosa list clusters --output json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "")
        
        if [[ -n "$clusters" ]]; then
            log_success "Found ROSA clusters:"
            echo "$clusters" | sed 's/^/  /'
        else
            log_info "No ROSA clusters found"
        fi
    else
        log_warning "Could not list ROSA clusters"
    fi
}

check_openshift_connection() {
    log_info "Checking OpenShift connection..."
    
    if oc whoami >/dev/null 2>&1; then
        local current_user=$(oc whoami)
        local current_server=$(oc whoami --show-server)
        log_success "OpenShift CLI: ✅ Connected"
        echo "  User: $current_user"
        echo "  Server: $current_server"
        
        # Show current project
        local current_project=$(oc project -q 2>/dev/null || echo "Unknown")
        echo "  Current Project: $current_project"
        
        return 0
    else
        log_warning "OpenShift CLI: ⚠️  Not connected to any cluster"
        log_info "Use 'oc login' to connect to a cluster"
        return 1
    fi
}

show_environment_summary() {
    echo ""
    echo "========================================="
    echo "Environment Summary"
    echo "========================================="
    
    local tools_ok=0
    local auth_ok=0
    
    # Check tools
    echo ""
    log_info "Required Tools:"
    check_tool "aws" "AWS CLI" && ((tools_ok++))
    check_tool "rosa" "ROSA CLI" && ((tools_ok++))
    check_tool "oc" "OpenShift CLI" && ((tools_ok++))
    check_tool "kubectl" "Kubernetes CLI" && ((tools_ok++))
    check_tool "jq" "JSON Processor" && ((tools_ok++))
    
    # Check authentication
    echo ""
    log_info "Authentication Status:"
    check_aws_authentication && ((auth_ok++))
    check_rosa_authentication && ((auth_ok++))
    
    echo ""
    check_rosa_quotas
    
    echo ""
    list_rosa_clusters
    
    echo ""
    check_openshift_connection
    
    echo ""
    echo "========================================="
    if [[ $tools_ok -eq 5 && $auth_ok -eq 2 ]]; then
        log_success "Environment Status: ✅ Ready for ROSA operations"
    elif [[ $tools_ok -eq 5 ]]; then
        log_warning "Environment Status: ⚠️  Tools installed but authentication needed"
    else
        log_error "Environment Status: ❌ Setup incomplete"
        log_info "Run './setup-rosa-environment.sh' to complete setup"
    fi
    echo "========================================="
}

# Main execution
main() {
    case ${1:-summary} in
        tools)
            echo "Checking required tools..."
            check_tool "aws" "AWS CLI"
            check_tool "rosa" "ROSA CLI"
            check_tool "oc" "OpenShift CLI"
            check_tool "kubectl" "Kubernetes CLI"
            check_tool "jq" "JSON Processor"
            ;;
        auth)
            echo "Checking authentication..."
            check_aws_authentication
            check_rosa_authentication
            ;;
        clusters)
            list_rosa_clusters
            ;;
        connection)
            check_openshift_connection
            ;;
        quotas)
            check_rosa_quotas
            ;;
        summary|*)
            show_environment_summary
            ;;
    esac
}

main "$@"
