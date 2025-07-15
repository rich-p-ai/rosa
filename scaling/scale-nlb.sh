#!/bin/bash

# NLB Scaling Manager for ROSA SSH Access
# Manages multiple Network Load Balancers for scaling to 200+ VMs
# Usage: ./scale-nlb.sh --action create --nlb-count 4 --start-port 2201

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="rosa-dev-cluster"
NLB_BASE_NAME="rosa-ssh-nlb"
PORTS_PER_NLB=50
DOMAIN_BASE="ssh"  # Will create ssh.yourdomain.com, ssh2.yourdomain.com, etc.

# Default values
ACTION=""
NLB_COUNT=1
START_PORT=2201
DOMAIN_NAME=""
VPC_ID=""
SUBNET_IDS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --action)
            ACTION="$2"
            shift 2
            ;;
        --nlb-count)
            NLB_COUNT="$2"
            shift 2
            ;;
        --start-port)
            START_PORT="$2"
            shift 2
            ;;
        --domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        --vpc-id)
            VPC_ID="$2"
            shift 2
            ;;
        --subnet-ids)
            SUBNET_IDS="$2"
            shift 2
            ;;
        -h|--help)
            cat <<EOF
NLB Scaling Manager for ROSA SSH Access

Usage: $0 --action <action> [options]

Actions:
  create     Create new NLBs for scaling
  update     Update existing NLBs with new VMs
  delete     Delete specified NLBs
  status     Show status of all NLBs
  dns        Generate DNS configuration

Options:
  --nlb-count <count>        Number of NLBs to create (default: 1)
  --start-port <port>        Starting port number (default: 2201)
  --domain <domain>          Base domain name (e.g., yourdomain.com)
  --vpc-id <vpc-id>          VPC ID (auto-detected if not specified)
  --subnet-ids <subnet-ids>  Comma-separated subnet IDs (auto-detected if not specified)

Examples:
  $0 --action create --nlb-count 4 --domain yourdomain.com
  $0 --action update --nlb-count 2
  $0 --action status
  $0 --action dns --domain yourdomain.com

Port Ranges (50 ports per NLB):
  NLB-1: 2201-2250
  NLB-2: 2251-2300
  NLB-3: 2301-2350
  NLB-4: 2351-2400

EOF
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$ACTION" ]]; then
    log_error "Action is required. Use --action <create|update|delete|status|dns>"
    exit 1
fi

echo "========================================="
echo "🌐 NLB Scaling Manager for ROSA"
echo "========================================="
echo ""

# Auto-detect VPC and Subnets if not provided
auto_detect_network() {
    if [[ -z "$VPC_ID" ]]; then
        log_info "Auto-detecting VPC ID..."
        VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION \
            --filters "Name=tag:Name,Values=*$CLUSTER_NAME*" \
            --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
        
        if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
            log_error "Could not auto-detect VPC ID. Please specify with --vpc-id"
            exit 1
        fi
        log_success "Detected VPC ID: $VPC_ID"
    fi
    
    if [[ -z "$SUBNET_IDS" ]]; then
        log_info "Auto-detecting subnet IDs..."
        SUBNET_IDS=$(aws ec2 describe-subnets --region $AWS_REGION \
            --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*worker*" \
            --query 'Subnets[].SubnetId' --output text 2>/dev/null | tr '\t' ',' || echo "")
        
        if [[ -z "$SUBNET_IDS" ]]; then
            log_error "Could not auto-detect subnet IDs. Please specify with --subnet-ids"
            exit 1
        fi
        log_success "Detected Subnet IDs: $SUBNET_IDS"
    fi
}

# Create multiple NLBs for scaling
create_nlbs() {
    log_info "Creating $NLB_COUNT NLBs for scaling..."
    auto_detect_network
    
    for i in $(seq 1 $NLB_COUNT); do
        local nlb_name="${NLB_BASE_NAME}-${i}"
        local start_port_range=$((START_PORT + (i-1) * PORTS_PER_NLB))
        local end_port_range=$((start_port_range + PORTS_PER_NLB - 1))
        
        log_info "Creating NLB $i: $nlb_name (ports $start_port_range-$end_port_range)"
        
        # Create NLB
        local nlb_arn=$(aws elbv2 create-load-balancer \
            --region $AWS_REGION \
            --name $nlb_name \
            --scheme internet-facing \
            --type network \
            --subnets $(echo $SUBNET_IDS | tr ',' ' ') \
            --tags Key=Name,Value=$nlb_name Key=Purpose,Value="ROSA-SSH-Scaling" Key=NLB-Index,Value=$i \
            --query 'LoadBalancers[0].LoadBalancerArn' --output text)
        
        if [[ $? -eq 0 ]]; then
            log_success "Created NLB: $nlb_name ($nlb_arn)"
            
            # Get NLB DNS name
            local nlb_dns=$(aws elbv2 describe-load-balancers \
                --region $AWS_REGION \
                --load-balancer-arns $nlb_arn \
                --query 'LoadBalancers[0].DNSName' --output text)
            
            log_info "NLB DNS: $nlb_dns"
            
            # Store NLB information for later use
            echo "$i,$nlb_name,$nlb_arn,$nlb_dns,$start_port_range,$end_port_range" >> /tmp/nlb-info.csv
            
        else
            log_error "Failed to create NLB: $nlb_name"
        fi
    done
    
    log_success "Created $NLB_COUNT NLBs successfully!"
    
    if [[ -n "$DOMAIN_NAME" ]]; then
        log_info "Generating DNS configuration..."
        generate_dns_config
    fi
}

# Update existing NLBs with new target groups
update_nlbs() {
    log_info "Updating existing NLBs..."
    
    # Get list of existing NLBs
    local nlb_arns=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
        --query "LoadBalancers[?contains(LoadBalancerName, '$NLB_BASE_NAME')].LoadBalancerArn" \
        --output text)
    
    if [[ -z "$nlb_arns" ]]; then
        log_warning "No existing NLBs found. Use --action create to create new ones."
        return
    fi
    
    for nlb_arn in $nlb_arns; do
        local nlb_name=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
            --load-balancer-arns $nlb_arn \
            --query 'LoadBalancers[0].LoadBalancerName' --output text)
        
        log_info "Updating NLB: $nlb_name"
        
        # Add logic here to create additional target groups and listeners
        # based on new VMs that need SSH access
    done
}

# Delete specified NLBs
delete_nlbs() {
    log_warning "Deleting NLBs..."
    
    # Get list of NLBs to delete
    local nlb_arns=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
        --query "LoadBalancers[?contains(LoadBalancerName, '$NLB_BASE_NAME')].LoadBalancerArn" \
        --output text)
    
    for nlb_arn in $nlb_arns; do
        local nlb_name=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
            --load-balancer-arns $nlb_arn \
            --query 'LoadBalancers[0].LoadBalancerName' --output text)
        
        log_warning "Deleting NLB: $nlb_name"
        
        # Delete listeners first
        local listener_arns=$(aws elbv2 describe-listeners --region $AWS_REGION \
            --load-balancer-arn $nlb_arn \
            --query 'Listeners[].ListenerArn' --output text)
        
        for listener_arn in $listener_arns; do
            aws elbv2 delete-listener --region $AWS_REGION --listener-arn $listener_arn
        done
        
        # Delete target groups
        local tg_arns=$(aws elbv2 describe-target-groups --region $AWS_REGION \
            --query "TargetGroups[?contains(LoadBalancerArns[0], '$nlb_arn')].TargetGroupArn" \
            --output text)
        
        for tg_arn in $tg_arns; do
            aws elbv2 delete-target-group --region $AWS_REGION --target-group-arn $tg_arn
        done
        
        # Delete NLB
        aws elbv2 delete-load-balancer --region $AWS_REGION --load-balancer-arn $nlb_arn
        log_success "Deleted NLB: $nlb_name"
    done
}

# Show status of all NLBs
show_status() {
    log_info "NLB Status Report"
    echo "=================="
    
    local nlb_arns=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
        --query "LoadBalancers[?contains(LoadBalancerName, '$NLB_BASE_NAME')].LoadBalancerArn" \
        --output text)
    
    if [[ -z "$nlb_arns" ]]; then
        log_warning "No NLBs found with base name: $NLB_BASE_NAME"
        return
    fi
    
    local count=0
    for nlb_arn in $nlb_arns; do
        count=$((count + 1))
        local nlb_info=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
            --load-balancer-arns $nlb_arn \
            --query 'LoadBalancers[0].[LoadBalancerName,DNSName,State.Code]' \
            --output text)
        
        local nlb_name=$(echo $nlb_info | cut -d' ' -f1)
        local nlb_dns=$(echo $nlb_info | cut -d' ' -f2)
        local nlb_state=$(echo $nlb_info | cut -d' ' -f3)
        
        echo "NLB $count: $nlb_name"
        echo "  DNS: $nlb_dns"
        echo "  State: $nlb_state"
        
        # Count listeners (active SSH ports)
        local listener_count=$(aws elbv2 describe-listeners --region $AWS_REGION \
            --load-balancer-arn $nlb_arn \
            --query 'length(Listeners)' --output text)
        
        echo "  Active SSH Ports: $listener_count"
        echo ""
    done
    
    log_success "Total NLBs: $count"
}

# Generate DNS configuration for domain provider
generate_dns_config() {
    log_info "Generating DNS configuration for domain: $DOMAIN_NAME"
    
    local dns_file="/tmp/dns-config-$(date +%Y%m%d-%H%M%S).txt"
    echo "# DNS Configuration for ROSA SSH Access" > $dns_file
    echo "# Domain: $DOMAIN_NAME" >> $dns_file
    echo "# Generated: $(date)" >> $dns_file
    echo "" >> $dns_file
    
    local nlb_arns=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
        --query "LoadBalancers[?contains(LoadBalancerName, '$NLB_BASE_NAME')].LoadBalancerArn" \
        --output text)
    
    local count=0
    for nlb_arn in $nlb_arns; do
        count=$((count + 1))
        local nlb_dns=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
            --load-balancer-arns $nlb_arn \
            --query 'LoadBalancers[0].DNSName' --output text)
        
        local subdomain=""
        if [[ $count -eq 1 ]]; then
            subdomain="$DOMAIN_BASE"
        else
            subdomain="${DOMAIN_BASE}${count}"
        fi
        
        echo "# NLB $count - Ports $((START_PORT + (count-1) * PORTS_PER_NLB))-$((START_PORT + count * PORTS_PER_NLB - 1))" >> $dns_file
        echo "${subdomain}.${DOMAIN_NAME}. IN CNAME ${nlb_dns}." >> $dns_file
        echo "" >> $dns_file
    done
    
    echo "" >> $dns_file
    echo "# Squarespace DNS Instructions:" >> $dns_file
    echo "# 1. Go to Settings > Domains > DNS Settings" >> $dns_file
    echo "# 2. Add CNAME records as shown above" >> $dns_file
    echo "# 3. TTL: 300 seconds (5 minutes)" >> $dns_file
    echo "" >> $dns_file
    echo "# Connection Examples:" >> $dns_file
    count=0
    for nlb_arn in $nlb_arns; do
        count=$((count + 1))
        local subdomain=""
        if [[ $count -eq 1 ]]; then
            subdomain="$DOMAIN_BASE"
        else
            subdomain="${DOMAIN_BASE}${count}"
        fi
        
        local start_port=$((START_PORT + (count-1) * PORTS_PER_NLB))
        echo "# ssh developer@${subdomain}.${DOMAIN_NAME}:${start_port}  # First VM on NLB $count" >> $dns_file
    done
    
    log_success "DNS configuration saved to: $dns_file"
    
    echo ""
    log_info "DNS Records to add in Squarespace:"
    cat $dns_file | grep "IN CNAME"
}

# Main execution
case $ACTION in
    "create")
        create_nlbs
        ;;
    "update")
        update_nlbs
        ;;
    "delete")
        delete_nlbs
        ;;
    "status")
        show_status
        ;;
    "dns")
        if [[ -z "$DOMAIN_NAME" ]]; then
            log_error "Domain name is required for DNS action. Use --domain yourdomain.com"
            exit 1
        fi
        generate_dns_config
        ;;
    *)
        log_error "Unknown action: $ACTION"
        log_info "Use --help for usage information"
        exit 1
        ;;
esac
