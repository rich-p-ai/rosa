#!/bin/bash

# ROSA Environment Setup Script
# This script sets up the complete environment for managing Red Hat OpenShift Service on AWS
# Usage: ./setup-rosa-environment.sh

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

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script is designed for macOS"
    exit 1
fi

# Install prerequisites
install_prerequisites() {
    log_info "Installing prerequisites..."
    
    # Check if Homebrew is installed
    if ! command -v brew >/dev/null 2>&1; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install AWS CLI
    if ! command -v aws >/dev/null 2>&1; then
        log_info "Installing AWS CLI..."
        brew install awscli
    fi
    
    # Install ROSA CLI
    if ! command -v rosa >/dev/null 2>&1; then
        log_info "Installing ROSA CLI..."
        brew install rosa-cli
    fi
    
    # Install OpenShift CLI
    if ! command -v oc >/dev/null 2>&1; then
        log_info "Installing OpenShift CLI..."
        brew install openshift-cli
    fi
    
    # Install kubectl (if not already installed)
    if ! command -v kubectl >/dev/null 2>&1; then
        log_info "Installing kubectl..."
        brew install kubectl
    fi
    
    # Install jq for JSON processing
    if ! command -v jq >/dev/null 2>&1; then
        log_info "Installing jq..."
        brew install jq
    fi
    
    log_success "Prerequisites installed!"
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    mkdir -p scripts
    mkdir -p configs
    mkdir -p templates
    mkdir -p logs
    mkdir -p docs
    
    log_success "Directory structure created!"
}

# Create configuration files
create_configs() {
    log_info "Creating configuration templates..."
    
    # Create AWS config template
    cat > configs/aws-config-template.txt << 'EOF'
# AWS Configuration for ROSA
# Copy this to ~/.aws/config and update with your values

[default]
region = us-east-1
output = json

[profile rosa-admin]
region = us-east-1
output = json
EOF

    # Create ROSA cluster config template
    cat > configs/rosa-cluster-config.yaml << 'EOF'
# ROSA Cluster Configuration Template
cluster:
  name: "my-rosa-cluster"
  region: "us-east-1"
  version: "4.14"
  compute:
    machine_type: "m5.xlarge"
    replicas: 3
    min_replicas: 3
    max_replicas: 6
  networking:
    machine_cidr: "10.0.0.0/16"
    service_cidr: "172.30.0.0/16"
    pod_cidr: "10.128.0.0/14"
  availability_zones:
    - "us-east-1a"
    - "us-east-1b"
    - "us-east-1c"
EOF

    log_success "Configuration templates created!"
}

# Check AWS authentication
check_aws_auth() {
    log_info "Checking AWS authentication..."
    
    if aws sts get-caller-identity >/dev/null 2>&1; then
        log_success "AWS CLI is authenticated"
        aws sts get-caller-identity
    else
        log_warning "AWS CLI is not authenticated"
        log_info "Run 'aws configure' to set up your credentials"
    fi
}

# Check ROSA authentication
check_rosa_auth() {
    log_info "Checking ROSA authentication..."
    
    if rosa whoami >/dev/null 2>&1; then
        log_success "ROSA CLI is authenticated"
        rosa whoami
    else
        log_warning "ROSA CLI is not authenticated"
        log_info "Run 'rosa login' to authenticate with Red Hat"
    fi
}

# Create README
create_readme() {
    cat > README.md << 'EOF'
# ROSA (Red Hat OpenShift Service on AWS) Management Environment

This environment provides tools and scripts for managing Red Hat OpenShift Service on AWS clusters.

## Prerequisites

- macOS
- Homebrew
- AWS CLI
- ROSA CLI
- OpenShift CLI (oc)
- kubectl

## Getting Started

1. Run the setup script: `./setup-rosa-environment.sh`
2. Configure AWS credentials: `aws configure`
3. Login to ROSA: `rosa login`
4. Create your first cluster: `./scripts/create-rosa-cluster.sh`

## Directory Structure

```
rosa/
├── scripts/           # Management scripts
├── configs/          # Configuration templates
├── templates/        # Kubernetes/OpenShift templates
├── logs/            # Operation logs
├── docs/            # Documentation
└── README.md        # This file
```

## Quick Commands

- Check environment: `./scripts/check-environment.sh`
- Create cluster: `./scripts/create-rosa-cluster.sh`
- Delete cluster: `./scripts/delete-rosa-cluster.sh`
- Get cluster status: `./scripts/cluster-status.sh`
- Scale cluster: `./scripts/scale-cluster.sh`

## Documentation

See the `docs/` directory for detailed guides and best practices.
EOF

    log_success "README.md created!"
}

# Main execution
main() {
    echo ""
    echo "========================================="
    echo "ROSA Environment Setup"
    echo "========================================="
    echo ""
    
    install_prerequisites
    create_directories
    create_configs
    create_readme
    
    echo ""
    log_info "Checking authentication status..."
    check_aws_auth
    echo ""
    check_rosa_auth
    
    echo ""
    log_success "ROSA environment setup complete!"
    echo ""
    log_info "Next steps:"
    echo "1. Configure AWS: aws configure"
    echo "2. Login to ROSA: rosa login"
    echo "3. Create your first cluster: ./scripts/create-rosa-cluster.sh"
    echo ""
}

main "$@"
