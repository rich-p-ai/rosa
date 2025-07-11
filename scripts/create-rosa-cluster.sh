#!/bin/bash

# ROSA Cluster Creation Script
# This script creates a new ROSA cluster with customizable options
# Usage: ./create-rosa-cluster.sh [cluster-name]

set -e

# Configuration
DEFAULT_CLUSTER_NAME="my-rosa-cluster"
DEFAULT_REGION="us-east-1"
DEFAULT_VERSION="4.14"
DEFAULT_MACHINE_TYPE="m5.xlarge"
DEFAULT_REPLICAS=3

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

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    if ! command -v rosa >/dev/null 2>&1; then
        missing_tools+=("rosa")
    fi
    
    if ! command -v aws >/dev/null 2>&1; then
        missing_tools+=("aws")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Run './setup-rosa-environment.sh' first"
        exit 1
    fi
    
    # Check AWS authentication
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS CLI not authenticated. Run 'aws configure'"
        exit 1
    fi
    
    # Check ROSA authentication
    if ! rosa whoami >/dev/null 2>&1; then
        log_error "ROSA CLI not authenticated. Run 'rosa login'"
        exit 1
    fi
}

# Show available options
show_options() {
    echo ""
    log_info "Available OpenShift versions:"
    rosa list versions
    
    echo ""
    log_info "Available machine types:"
    echo "  m5.large: 2 vCPUs, 8GB RAM"
    echo "  m5.xlarge: 4 vCPUs, 16GB RAM (recommended)"
    echo "  m5.2xlarge: 8 vCPUs, 32GB RAM"
    echo "  m5.4xlarge: 16 vCPUs, 64GB RAM"
    echo "  c5.large: 2 vCPUs, 4GB RAM"
    echo "  c5.xlarge: 4 vCPUs, 8GB RAM"
    echo "  r5.large: 2 vCPUs, 16GB RAM"
    echo "  r5.xlarge: 4 vCPUs, 32GB RAM"
    
    echo ""
    log_info "Available regions:"
    rosa list regions
}

# Verify AWS account and quotas
verify_aws_account() {
    log_info "Verifying AWS account and service quotas..."
    
    # Check account ID
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    log_info "AWS Account ID: $account_id"
    
    # Check if ROSA service is enabled
    if ! rosa verify quota >/dev/null 2>&1; then
        log_warning "ROSA quota verification failed. Check your AWS service quotas."
        log_info "Visit: https://console.aws.amazon.com/servicequotas/"
    else
        log_success "AWS quotas verified for ROSA"
    fi
}

# Create ROSA cluster
create_cluster() {
    local cluster_name=${1:-$DEFAULT_CLUSTER_NAME}
    local region=${2:-$DEFAULT_REGION}
    local version=${3:-$DEFAULT_VERSION}
    local machine_type=${4:-$DEFAULT_MACHINE_TYPE}
    local replicas=${5:-$DEFAULT_REPLICAS}
    
    log_info "Creating ROSA cluster with the following configuration:"
    echo "  Name: $cluster_name"
    echo "  Region: $region"
    echo "  Version: $version"
    echo "  Machine Type: $machine_type"
    echo "  Worker Replicas: $replicas"
    
    echo ""
    read -p "Do you want to proceed? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Cluster creation cancelled."
        return 0
    fi
    
    log_info "Starting cluster creation (this may take 30-45 minutes)..."
    
    # Create the cluster
    rosa create cluster \
        --cluster-name="$cluster_name" \
        --region="$region" \
        --version="$version" \
        --compute-machine-type="$machine_type" \
        --replicas="$replicas" \
        --watch \
        --enable-autoscaling \
        --min-replicas="$replicas" \
        --max-replicas=$((replicas * 2))
    
    if [[ $? -eq 0 ]]; then
        log_success "Cluster '$cluster_name' created successfully!"
        
        # Create admin user
        log_info "Creating cluster admin user..."
        rosa create admin --cluster="$cluster_name"
        
        # Save cluster info
        mkdir -p ../logs
        rosa describe cluster --cluster="$cluster_name" > "../logs/${cluster_name}-info.txt"
        
        log_info "Cluster information saved to logs/${cluster_name}-info.txt"
        log_success "Setup complete! Use 'oc login' with the provided credentials."
    else
        log_error "Cluster creation failed!"
        exit 1
    fi
}

# Interactive mode
interactive_mode() {
    echo ""
    echo "========================================="
    echo "ROSA Cluster Creation (Interactive Mode)"
    echo "========================================="
    
    show_options
    
    echo ""
    read -p "Enter cluster name (default: $DEFAULT_CLUSTER_NAME): " cluster_name
    cluster_name=${cluster_name:-$DEFAULT_CLUSTER_NAME}
    
    read -p "Enter region (default: $DEFAULT_REGION): " region
    region=${region:-$DEFAULT_REGION}
    
    read -p "Enter OpenShift version (default: $DEFAULT_VERSION): " version
    version=${version:-$DEFAULT_VERSION}
    
    read -p "Enter machine type (default: $DEFAULT_MACHINE_TYPE): " machine_type
    machine_type=${machine_type:-$DEFAULT_MACHINE_TYPE}
    
    read -p "Enter number of worker nodes (default: $DEFAULT_REPLICAS): " replicas
    replicas=${replicas:-$DEFAULT_REPLICAS}
    
    create_cluster "$cluster_name" "$region" "$version" "$machine_type" "$replicas"
}

# Main execution
main() {
    check_prerequisites
    verify_aws_account
    
    if [[ $# -eq 0 ]]; then
        interactive_mode
    else
        case $1 in
            --help|-h)
                echo "Usage: $0 [cluster-name] [region] [version] [machine-type] [replicas]"
                echo "  cluster-name  - Name of the cluster (default: $DEFAULT_CLUSTER_NAME)"
                echo "  region        - AWS region (default: $DEFAULT_REGION)"
                echo "  version       - OpenShift version (default: $DEFAULT_VERSION)"
                echo "  machine-type  - EC2 instance type (default: $DEFAULT_MACHINE_TYPE)"
                echo "  replicas      - Number of worker nodes (default: $DEFAULT_REPLICAS)"
                echo ""
                echo "Run without arguments for interactive mode"
                exit 0
                ;;
            *)
                create_cluster "$@"
                ;;
        esac
    fi
}

main "$@"
