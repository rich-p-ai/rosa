#!/bin/bash

# ROSA Test Cluster for OpenShift Virtualization
# This script creates a minimal ROSA cluster optimized for testing OpenShift Virtualization
# Usage: ./create-test-cluster-for-virt.sh

set -e

# Configuration for minimal test cluster
TEST_CLUSTER_NAME="rosa-virt-test"
TEST_REGION="us-east-1"  # Better quota availability than us-east-2
TEST_VERSION="4.14"
TEST_MACHINE_TYPE="m5.xlarge"  # Minimum for virtualization
TEST_REPLICAS=3  # Minimal for HA
MIN_REPLICAS=3
MAX_REPLICAS=5

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
    log_info "Checking prerequisites for OpenShift Virtualization test cluster..."
    
    # Check authentication
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS CLI not authenticated. Run 'aws configure'"
        exit 1
    fi
    
    if ! rosa whoami >/dev/null 2>&1; then
        log_error "ROSA CLI not authenticated. Run 'rosa login'"
        exit 1
    fi
    
    # Check for existing clusters
    local existing_clusters=$(rosa list clusters --output json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "")
    
    if [[ -n "$existing_clusters" ]]; then
        log_warning "Existing ROSA clusters found:"
        echo "$existing_clusters" | sed 's/^/  /'
        echo ""
        read -p "Continue with creating a new test cluster? (yes/no): " continue_anyway
        if [[ "$continue_anyway" != "yes" ]]; then
            log_info "Operation cancelled."
            exit 0
        fi
    fi
}

# Check quotas specifically for minimal setup
check_minimal_quotas() {
    log_info "Checking quotas for minimal test cluster setup..."
    
    # Try a different region with potentially better quotas
    local current_region=$(aws configure get region)
    log_info "Current region: $current_region"
    log_info "Test cluster will be created in: $TEST_REGION"
    
    if [[ "$current_region" != "$TEST_REGION" ]]; then
        log_warning "Note: Test cluster will be created in $TEST_REGION (different from your default region)"
        log_info "This may help with quota limitations"
    fi
}

# Create minimal test cluster optimized for virtualization
create_test_cluster() {
    log_info "Creating minimal ROSA test cluster for OpenShift Virtualization..."
    echo ""
    echo "Cluster Configuration:"
    echo "  Name: $TEST_CLUSTER_NAME"
    echo "  Region: $TEST_REGION"
    echo "  Version: $TEST_VERSION"
    echo "  Machine Type: $TEST_MACHINE_TYPE (4 vCPUs, 16GB RAM)"
    echo "  Worker Nodes: $TEST_REPLICAS"
    echo "  Autoscaling: $MIN_REPLICAS - $MAX_REPLICAS nodes"
    echo ""
    
    log_warning "This will create AWS resources that incur costs!"
    log_info "Estimated cost: ~\$1.50-2.00/hour for the test cluster"
    echo ""
    
    read -p "Create the test cluster? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Cluster creation cancelled."
        return 0
    fi
    
    log_info "Starting cluster creation (this will take 30-45 minutes)..."
    
    # Create the cluster with optimized settings for virtualization
    if rosa create cluster \
        --cluster-name="$TEST_CLUSTER_NAME" \
        --region="$TEST_REGION" \
        --version="$TEST_VERSION" \
        --compute-machine-type="$TEST_MACHINE_TYPE" \
        --replicas="$TEST_REPLICAS" \
        --enable-autoscaling \
        --min-replicas="$MIN_REPLICAS" \
        --max-replicas="$MAX_REPLICAS" \
        --multi-az \
        --watch; then
        
        log_success "Test cluster '$TEST_CLUSTER_NAME' created successfully!"
        
        # Create admin user
        log_info "Creating cluster admin user..."
        if rosa create admin --cluster="$TEST_CLUSTER_NAME"; then
            log_success "Admin user created!"
        else
            log_warning "Failed to create admin user. You can create it later with: rosa create admin --cluster=$TEST_CLUSTER_NAME"
        fi
        
        # Save cluster info
        mkdir -p ../logs
        rosa describe cluster --cluster="$TEST_CLUSTER_NAME" > "../logs/${TEST_CLUSTER_NAME}-info.txt"
        
        log_success "Test cluster is ready!"
        
    else
        log_error "Cluster creation failed! Check the error messages above."
        log_info "Common issues:"
        log_info "1. Quota limitations - try requesting quota increase"
        log_info "2. Region availability - try a different region"
        log_info "3. Service limits - check AWS Service Quotas console"
        exit 1
    fi
}

# Install OpenShift Virtualization
install_openshift_virtualization() {
    local cluster_name=$1
    
    log_info "Installing OpenShift Virtualization on cluster '$cluster_name'..."
    
    # First, get the cluster login credentials
    log_info "Getting cluster login credentials..."
    rosa describe cluster --cluster="$cluster_name" | grep "Console URL" || true
    
    log_info "To install OpenShift Virtualization:"
    echo "1. Login to your cluster:"
    echo "   rosa describe cluster --cluster=$cluster_name"
    echo "   # Use the console URL and admin credentials"
    echo ""
    echo "2. Or use CLI login:"
    echo "   oc login --server=<api-url> --username=cluster-admin"
    echo ""
    echo "3. Install OpenShift Virtualization operator:"
    echo "   oc apply -f ../templates/openshift-virtualization.yaml"
    echo ""
    
    log_warning "OpenShift Virtualization requires:"
    log_warning "- Bare metal instances (not available in ROSA)"
    log_warning "- Or nested virtualization support"
    log_warning "- For testing, we'll use containers that simulate VMs"
}

# Create OpenShift Virtualization configuration
create_virt_templates() {
    log_info "Creating OpenShift Virtualization templates..."
    
    mkdir -p ../templates/virtualization
    
    # Create namespace for virtualization testing
    cat > ../templates/virtualization/virt-namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: virtualization-test
  labels:
    name: virtualization-test
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: virtualization-test
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
EOF

    # Create a Linux server simulation pod (since we can't use real VMs in ROSA)
    cat > ../templates/virtualization/linux-server-simulation.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: linux-server-sim
  namespace: virtualization-test
  labels:
    app: linux-server-sim
spec:
  replicas: 1
  selector:
    matchLabels:
      app: linux-server-sim
  template:
    metadata:
      labels:
        app: linux-server-sim
    spec:
      containers:
      - name: linux-server
        image: ubuntu:22.04
        command: ["/bin/bash"]
        args: ["-c", "apt-get update && apt-get install -y openssh-server net-tools iproute2 && service ssh start && tail -f /dev/null"]
        ports:
        - containerPort: 22
          name: ssh
        - containerPort: 80
          name: http
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        securityContext:
          privileged: true
---
apiVersion: v1
kind: Service
metadata:
  name: linux-server-sim-service
  namespace: virtualization-test
spec:
  selector:
    app: linux-server-sim
  ports:
  - name: ssh
    port: 22
    targetPort: 22
  - name: http
    port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: linux-server-sim-route
  namespace: virtualization-test
spec:
  to:
    kind: Service
    name: linux-server-sim-service
  port:
    targetPort: http
EOF

    # Network testing tools
    cat > ../templates/virtualization/network-testing-tools.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: network-testing-tools
  namespace: virtualization-test
  labels:
    app: network-testing-tools
spec:
  replicas: 1
  selector:
    matchLabels:
      app: network-testing-tools
  template:
    metadata:
      labels:
        app: network-testing-tools
    spec:
      containers:
      - name: network-tools
        image: nicolaka/netshoot
        command: ["sleep", "infinity"]
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
EOF

    log_success "OpenShift Virtualization templates created!"
    log_info "Templates created in: templates/virtualization/"
}

# Show next steps
show_next_steps() {
    local cluster_name=$1
    
    echo ""
    log_success "Test cluster setup complete!"
    echo ""
    log_info "Next steps for OpenShift Virtualization testing:"
    echo ""
    echo "1. 🔗 Connect to your cluster:"
    echo "   rosa describe cluster --cluster=$cluster_name"
    echo "   # Copy the Console URL and admin password"
    echo ""
    echo "2. 🖥️  Login via CLI:"
    echo "   oc login --server=<api-url> --username=cluster-admin"
    echo ""
    echo "3. 🚀 Deploy virtualization testing resources:"
    echo "   oc apply -f templates/virtualization/virt-namespace.yaml"
    echo "   oc apply -f templates/virtualization/linux-server-simulation.yaml"
    echo "   oc apply -f templates/virtualization/network-testing-tools.yaml"
    echo ""
    echo "4. 🔍 Test network connectivity:"
    echo "   oc get pods -n virtualization-test"
    echo "   oc exec -it deployment/network-testing-tools -n virtualization-test -- ping linux-server-sim-service"
    echo ""
    echo "5. 🌐 Access the simulated Linux server:"
    echo "   oc get route -n virtualization-test"
    echo ""
    echo "6. 📊 Monitor cluster:"
    echo "   ./scripts/cluster-status.sh $cluster_name"
    echo ""
    log_warning "Remember to delete the cluster when done testing:"
    log_warning "./scripts/delete-rosa-cluster.sh $cluster_name"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "========================================="
    echo "🧪 ROSA Test Cluster for OpenShift Virtualization"
    echo "========================================="
    echo ""
    
    check_prerequisites
    check_minimal_quotas
    create_virt_templates
    
    echo ""
    read -p "Proceed with creating the test cluster? (yes/no): " final_confirm
    
    if [[ "$final_confirm" == "yes" ]]; then
        create_test_cluster
        show_next_steps "$TEST_CLUSTER_NAME"
    else
        log_info "Test cluster creation cancelled."
        log_info "Templates have been created in templates/virtualization/ for future use."
    fi
}

main "$@"
