#!/bin/bash

# External SSH Access Setup for ROSA Web Applications
# Creates AWS NLB with dedicated ports for each SSH service
# Usage: ./setup-external-ssh-access.sh

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

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="rosa-dev-cluster"
NLB_NAME="rosa-ssh-nlb"

# SSH Port mappings for external access
declare -A SSH_PORTS=(
    ["react-frontend"]=2201
    ["vue-frontend"]=2202
    ["angular-frontend"]=2203
    ["nodejs-backend"]=2204
    ["django-backend"]=2205
)

# SSH Connection Details (same as before)
declare -A SSH_PASSWORDS=(
    ["react-frontend"]="ReactDev@2024"
    ["vue-frontend"]="VueDev@2024"
    ["angular-frontend"]="AngularDev@2024"
    ["nodejs-backend"]="NodeDev@2024"
    ["django-backend"]="DjangoDev@2024"
)

SSH_USER="developer"

echo "========================================="
echo "🌐 External SSH Access Setup for ROSA"
echo "========================================="
echo ""

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v oc >/dev/null 2>&1; then
        log_error "OpenShift CLI (oc) is not installed"
        exit 1
    fi
    
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! oc whoami >/dev/null 2>&1; then
        log_error "Not logged in to OpenShift. Run 'oc login' first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "Not authenticated with AWS. Run 'aws configure' first."
        exit 1
    fi
    
    log_success "Prerequisites satisfied"
}

# Create NodePort services for external access
create_nodeport_services() {
    log_info "Creating NodePort services for external SSH access..."
    echo ""
    
    for app in "${!SSH_PORTS[@]}"; do
        local namespace="${app}"
        local external_port="${SSH_PORTS[$app]}"
        
        log_info "Creating NodePort service for ${app} on port ${external_port}..."
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ${app}-ssh-external
  namespace: ${namespace}
  labels:
    app: ${app}-ssh
    app.kubernetes.io/name: ${app}-ssh
    app.kubernetes.io/part-of: web-applications
    external-access: "true"
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  type: NodePort
  ports:
  - name: ssh
    port: 22
    targetPort: 22
    nodePort: ${external_port}
    protocol: TCP
  selector:
    app: ${app}-ssh
EOF
        
        if [ $? -eq 0 ]; then
            log_success "${app} NodePort service created on port ${external_port}"
        else
            log_error "Failed to create NodePort service for ${app}"
        fi
    done
    
    echo ""
    log_success "All NodePort services created"
}

# Create AWS Network Load Balancer
create_aws_nlb() {
    log_info "Creating AWS Network Load Balancer..."
    
    # Get cluster VPC and subnets
    local cluster_vpc=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.aws.region}' 2>/dev/null || echo "$AWS_REGION")
    
    # Get ROSA cluster infrastructure details
    log_info "Getting ROSA cluster infrastructure details..."
    
    # Get worker node IPs for NLB targets
    local node_ips=($(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}'))
    
    if [ ${#node_ips[@]} -eq 0 ]; then
        log_warning "No external IPs found for worker nodes. Getting internal IPs..."
        node_ips=($(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'))
    fi
    
    if [ ${#node_ips[@]} -eq 0 ]; then
        log_error "Cannot find worker node IPs"
        return 1
    fi
    
    log_info "Found ${#node_ips[@]} worker nodes: ${node_ips[*]}"
    
    # Get VPC ID from cluster
    local vpc_id=$(aws ec2 describe-instances \
        --filters "Name=private-ip-address,Values=${node_ips[0]}" \
        --query 'Reservations[0].Instances[0].VpcId' \
        --output text --region "$AWS_REGION" 2>/dev/null)
    
    if [ "$vpc_id" == "None" ] || [ -z "$vpc_id" ]; then
        log_error "Cannot determine VPC ID for cluster"
        return 1
    fi
    
    log_info "Using VPC: $vpc_id"
    
    # Get subnets in VPC
    local subnet_ids=($(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=state,Values=available" \
        --query 'Subnets[*].SubnetId' \
        --output text --region "$AWS_REGION"))
    
    if [ ${#subnet_ids[@]} -eq 0 ]; then
        log_error "No subnets found in VPC $vpc_id"
        return 1
    fi
    
    log_info "Using subnets: ${subnet_ids[*]}"
    
    # Create NLB
    log_info "Creating Network Load Balancer: $NLB_NAME..."
    
    local nlb_arn=$(aws elbv2 create-load-balancer \
        --name "$NLB_NAME" \
        --scheme internet-facing \
        --type network \
        --ip-address-type ipv4 \
        --subnets ${subnet_ids[*]} \
        --tags "Key=Name,Value=$NLB_NAME" "Key=Purpose,Value=ROSA-SSH-Access" \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text --region "$AWS_REGION")
    
    if [ $? -ne 0 ] || [ "$nlb_arn" == "None" ]; then
        log_error "Failed to create Network Load Balancer"
        return 1
    fi
    
    log_success "Network Load Balancer created: $nlb_arn"
    
    # Wait for NLB to be active
    log_info "Waiting for NLB to become active..."
    aws elbv2 wait load-balancer-available --load-balancer-arns "$nlb_arn" --region "$AWS_REGION"
    
    # Get NLB DNS name
    local nlb_dns=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$nlb_arn" \
        --query 'LoadBalancers[0].DNSName' \
        --output text --region "$AWS_REGION")
    
    log_success "NLB DNS Name: $nlb_dns"
    
    # Create target groups and listeners for each application
    for app in "${!SSH_PORTS[@]}"; do
        local external_port="${SSH_PORTS[$app]}"
        
        log_info "Creating target group for ${app} on port ${external_port}..."
        
        # Create target group
        local tg_arn=$(aws elbv2 create-target-group \
            --name "${NLB_NAME}-${app}-${external_port}" \
            --protocol TCP \
            --port "$external_port" \
            --vpc-id "$vpc_id" \
            --target-type ip \
            --health-check-protocol TCP \
            --health-check-port "$external_port" \
            --health-check-interval-seconds 30 \
            --healthy-threshold-count 2 \
            --unhealthy-threshold-count 2 \
            --tags "Key=Application,Value=${app}" "Key=Port,Value=${external_port}" \
            --query 'TargetGroups[0].TargetGroupArn' \
            --output text --region "$AWS_REGION")
        
        if [ $? -ne 0 ] || [ "$tg_arn" == "None" ]; then
            log_error "Failed to create target group for $app"
            continue
        fi
        
        # Register worker nodes as targets
        for node_ip in "${node_ips[@]}"; do
            aws elbv2 register-targets \
                --target-group-arn "$tg_arn" \
                --targets "Id=$node_ip,Port=$external_port" \
                --region "$AWS_REGION" >/dev/null 2>&1
        done
        
        # Create listener
        aws elbv2 create-listener \
            --load-balancer-arn "$nlb_arn" \
            --protocol TCP \
            --port "$external_port" \
            --default-actions "Type=forward,TargetGroupArn=$tg_arn" \
            --region "$AWS_REGION" >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            log_success "${app}: Target group and listener created for port ${external_port}"
        else
            log_error "Failed to create listener for $app"
        fi
    done
    
    echo ""
    log_success "🎉 AWS Network Load Balancer setup complete!"
    echo ""
    echo "📋 NLB Details:"
    echo "  Name: $NLB_NAME"
    echo "  DNS: $nlb_dns"
    echo "  ARN: $nlb_arn"
    echo ""
    
    # Save NLB info for later use
    cat > nlb-info.txt << EOF
NLB_NAME=$NLB_NAME
NLB_DNS=$nlb_dns
NLB_ARN=$nlb_arn
VPC_ID=$vpc_id
AWS_REGION=$AWS_REGION
EOF
    
    log_success "NLB information saved to nlb-info.txt"
}

# Display connection information
show_connection_info() {
    log_info "📋 External SSH Access Information"
    echo ""
    
    # Get NLB DNS from AWS or file
    local nlb_dns=""
    if [ -f "nlb-info.txt" ]; then
        source nlb-info.txt
        nlb_dns="$NLB_DNS"
    fi
    
    if [ -z "$nlb_dns" ]; then
        nlb_dns=$(aws elbv2 describe-load-balancers \
            --names "$NLB_NAME" \
            --query 'LoadBalancers[0].DNSName' \
            --output text --region "$AWS_REGION" 2>/dev/null || echo "check-nlb-manually")
    fi
    
    echo "🌐 DNS Name: $nlb_dns"
    echo ""
    echo "🔑 SSH Connection Commands (for developers):"
    echo ""
    
    for app in "${!SSH_PORTS[@]}"; do
        local external_port="${SSH_PORTS[$app]}"
        echo "${app^} Frontend/Backend:"
        echo "  ssh $SSH_USER@$nlb_dns -p $external_port"
        echo "  Password: ${SSH_PASSWORDS[$app]}"
        echo ""
    done
    
    echo "📝 PuTTY Configuration:"
    echo "  Host Name: $nlb_dns"
    echo "  Port: <see above for each application>"
    echo "  Connection Type: SSH"
    echo "  Username: $SSH_USER"
    echo "  Authentication: Password"
    echo ""
}

# Create DNS records (Squarespace instructions)
show_dns_instructions() {
    log_info "📝 DNS Setup Instructions for Squarespace"
    echo ""
    
    # Get NLB DNS
    local nlb_dns=""
    if [ -f "nlb-info.txt" ]; then
        source nlb-info.txt
        nlb_dns="$NLB_DNS"
    fi
    
    if [ -z "$nlb_dns" ]; then
        nlb_dns=$(aws elbv2 describe-load-balancers \
            --names "$NLB_NAME" \
            --query 'LoadBalancers[0].DNSName' \
            --output text --region "$AWS_REGION" 2>/dev/null || echo "your-nlb-dns-name")
    fi
    
    cat << EOF
🌐 Squarespace DNS Configuration:

1. Log in to your Squarespace account
2. Go to Settings > Domains > DNS Settings
3. Add these CNAME records:

Application SSH Access:
- Host: ssh-react      Record Type: CNAME    Data: $nlb_dns
- Host: ssh-vue        Record Type: CNAME    Data: $nlb_dns  
- Host: ssh-angular    Record Type: CNAME    Data: $nlb_dns
- Host: ssh-nodejs     Record Type: CNAME    Data: $nlb_dns
- Host: ssh-django     Record Type: CNAME    Data: $nlb_dns

Generic SSH Access:
- Host: ssh            Record Type: CNAME    Data: $nlb_dns

4. Save and wait for DNS propagation (5-30 minutes)

📱 Developer Instructions (after DNS setup):
React Frontend:    ssh $SSH_USER@ssh-react.yourdomain.com -p 2201
Vue Frontend:      ssh $SSH_USER@ssh-vue.yourdomain.com -p 2202  
Angular Frontend:  ssh $SSH_USER@ssh-angular.yourdomain.com -p 2203
Node.js Backend:   ssh $SSH_USER@ssh-nodejs.yourdomain.com -p 2204
Django Backend:    ssh $SSH_USER@ssh-django.yourdomain.com -p 2205

Or use single DNS with different ports:
ssh $SSH_USER@ssh.yourdomain.com -p 2201  # React
ssh $SSH_USER@ssh.yourdomain.com -p 2202  # Vue
ssh $SSH_USER@ssh.yourdomain.com -p 2203  # Angular
ssh $SSH_USER@ssh.yourdomain.com -p 2204  # Node.js
ssh $SSH_USER@ssh.yourdomain.com -p 2205  # Django

🔐 Passwords are shown in the connection info above.
EOF
}

# Test external connectivity
test_external_connectivity() {
    log_info "🧪 Testing external SSH connectivity..."
    echo ""
    
    # Get NLB DNS
    local nlb_dns=""
    if [ -f "nlb-info.txt" ]; then
        source nlb-info.txt
        nlb_dns="$NLB_DNS"
    fi
    
    if [ -z "$nlb_dns" ]; then
        log_error "NLB DNS not found. Run setup first."
        return 1
    fi
    
    for app in "${!SSH_PORTS[@]}"; do
        local external_port="${SSH_PORTS[$app]}"
        
        echo "Testing ${app} on port ${external_port}:"
        
        # Test port connectivity
        if timeout 10 bash -c "</dev/tcp/$nlb_dns/$external_port" >/dev/null 2>&1; then
            echo "  ✅ Port $external_port is reachable"
        else
            echo "  ❌ Port $external_port is not reachable"
        fi
        
        # Test SSH banner
        local ssh_banner=$(timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SSH_USER@$nlb_dns" -p "$external_port" 2>&1 | head -1 || echo "Connection failed")
        echo "  📡 SSH Response: $ssh_banner"
        
        echo ""
    done
}

# Cleanup external access
cleanup_external_access() {
    log_warning "🧹 Cleaning up external SSH access..."
    
    # Delete NodePort services
    for app in "${!SSH_PORTS[@]}"; do
        local namespace="${app}"
        oc delete svc "${app}-ssh-external" -n "$namespace" 2>/dev/null || true
    done
    
    # Delete AWS NLB
    if [ -f "nlb-info.txt" ]; then
        source nlb-info.txt
        
        log_info "Deleting Network Load Balancer: $NLB_NAME"
        aws elbv2 delete-load-balancer --load-balancer-arn "$NLB_ARN" --region "$AWS_REGION" 2>/dev/null || true
        
        # Wait a bit for deletion
        sleep 10
        
        # Delete target groups
        aws elbv2 describe-target-groups --names "${NLB_NAME}-*" --region "$AWS_REGION" --query 'TargetGroups[*].TargetGroupArn' --output text 2>/dev/null | \
        xargs -I {} aws elbv2 delete-target-group --target-group-arn {} --region "$AWS_REGION" 2>/dev/null || true
        
        rm -f nlb-info.txt
    fi
    
    log_success "Cleanup completed"
}

# Status check
check_status() {
    log_info "📊 External SSH Access Status"
    echo ""
    
    # Check NodePort services
    echo "NodePort Services:"
    for app in "${!SSH_PORTS[@]}"; do
        local namespace="${app}"
        local external_port="${SSH_PORTS[$app]}"
        
        if oc get svc "${app}-ssh-external" -n "$namespace" >/dev/null 2>&1; then
            echo "  ✅ ${app}: Port ${external_port}"
        else
            echo "  ❌ ${app}: Not found"
        fi
    done
    
    echo ""
    
    # Check AWS NLB
    echo "AWS Network Load Balancer:"
    if aws elbv2 describe-load-balancers --names "$NLB_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        local nlb_state=$(aws elbv2 describe-load-balancers --names "$NLB_NAME" --region "$AWS_REGION" --query 'LoadBalancers[0].State.Code' --output text)
        local nlb_dns=$(aws elbv2 describe-load-balancers --names "$NLB_NAME" --region "$AWS_REGION" --query 'LoadBalancers[0].DNSName' --output text)
        echo "  ✅ $NLB_NAME: $nlb_state"
        echo "  🌐 DNS: $nlb_dns"
    else
        echo "  ❌ $NLB_NAME: Not found"
    fi
}

# Main execution
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            echo ""
            create_nodeport_services
            echo ""
            create_aws_nlb
            echo ""
            show_connection_info
            echo ""
            show_dns_instructions
            ;;
        "status")
            check_status
            ;;
        "test")
            test_external_connectivity
            ;;
        "info")
            show_connection_info
            echo ""
            show_dns_instructions
            ;;
        "cleanup")
            cleanup_external_access
            ;;
        "help"|"--help"|"-h")
            echo "External SSH Access Setup for ROSA Web Applications"
            echo ""
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  setup      Create external SSH access (default)"
            echo "  status     Check status of external access"
            echo "  test       Test external connectivity"
            echo "  info       Show connection and DNS information"
            echo "  cleanup    Remove external SSH access"
            echo "  help       Show this help"
            echo ""
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
