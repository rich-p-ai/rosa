#!/bin/bash

# AWS Quota Request Helper for ROSA
# This script helps you request the necessary AWS service quotas for ROSA
# Usage: ./request-aws-quotas.sh

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

# Check current quotas
check_current_quotas() {
    log_info "Checking current AWS service quotas..."
    
    echo ""
    echo "🔍 Current EC2 Quotas:"
    
    # Check Running On-Demand instances quota
    local ec2_quota=$(aws service-quotas get-service-quota \
        --service-code ec2 \
        --quota-code L-1216C47A \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "Unable to fetch")
    
    echo "  Running On-Demand Standard Instances: $ec2_quota"
    
    # Check VPC quotas
    echo ""
    echo "🔍 Current VPC Quotas:"
    
    local vpc_quota=$(aws service-quotas get-service-quota \
        --service-code vpc \
        --quota-code L-F678F1CE \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "Unable to fetch")
    
    echo "  VPCs per Region: $vpc_quota"
    
    # Check ELB quotas
    echo ""
    echo "🔍 Current Load Balancer Quotas:"
    
    local elb_quota=$(aws service-quotas get-service-quota \
        --service-code elasticloadbalancing \
        --quota-code L-53EA2B76 \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "Unable to fetch")
    
    echo "  Network Load Balancers per Region: $elb_quota"
}

# Show required quotas for ROSA
show_required_quotas() {
    echo ""
    log_info "Required AWS quotas for ROSA:"
    echo ""
    echo "📋 Minimum Requirements:"
    echo "  ✅ Running On-Demand Standard Instances: 100 (current: varies)"
    echo "  ✅ VPCs per Region: 5 (usually sufficient)"
    echo "  ✅ Network Load Balancers per Region: 50"
    echo "  ✅ Application Load Balancers per Region: 50"
    echo "  ✅ Internet Gateways per Region: 5"
    echo ""
    echo "📋 Recommended for Production:"
    echo "  🚀 Running On-Demand Standard Instances: 200+"
    echo "  🚀 Spot Instances: 100+"
    echo "  🚀 Elastic IPs: 100"
}

# Generate quota increase requests
generate_quota_requests() {
    log_info "Generating quota increase requests..."
    
    echo ""
    echo "🚀 Use these AWS CLI commands to request quota increases:"
    echo ""
    
    # EC2 On-Demand instances
    echo "# Request EC2 On-Demand instances quota increase"
    echo "aws service-quotas request-service-quota-increase \\"
    echo "  --service-code ec2 \\"
    echo "  --quota-code L-1216C47A \\"
    echo "  --desired-value 100"
    echo ""
    
    # Network Load Balancers
    echo "# Request Network Load Balancer quota increase"
    echo "aws service-quotas request-service-quota-increase \\"
    echo "  --service-code elasticloadbalancing \\"
    echo "  --quota-code L-53EA2B76 \\"
    echo "  --desired-value 50"
    echo ""
    
    # Application Load Balancers
    echo "# Request Application Load Balancer quota increase"
    echo "aws service-quotas request-service-quota-increase \\"
    echo "  --service-code elasticloadbalancing \\"
    echo "  --quota-code L-53EA2B76 \\"
    echo "  --desired-value 50"
    echo ""
}

# Interactive quota request
interactive_quota_request() {
    log_info "Interactive quota request assistant..."
    
    echo ""
    read -p "Do you want to request EC2 On-Demand instances quota increase to 100? (yes/no): " request_ec2
    
    if [[ "$request_ec2" == "yes" ]]; then
        log_info "Requesting EC2 quota increase..."
        if aws service-quotas request-service-quota-increase \
            --service-code ec2 \
            --quota-code L-1216C47A \
            --desired-value 100 >/dev/null 2>&1; then
            log_success "EC2 quota increase request submitted!"
        else
            log_error "Failed to submit EC2 quota request. You may need to use the AWS Console."
        fi
    fi
    
    echo ""
    read -p "Do you want to request Network Load Balancer quota increase to 50? (yes/no): " request_nlb
    
    if [[ "$request_nlb" == "yes" ]]; then
        log_info "Requesting Network Load Balancer quota increase..."
        if aws service-quotas request-service-quota-increase \
            --service-code elasticloadbalancing \
            --quota-code L-53EA2B76 \
            --desired-value 50 >/dev/null 2>&1; then
            log_success "Network Load Balancer quota increase request submitted!"
        else
            log_error "Failed to submit NLB quota request. You may need to use the AWS Console."
        fi
    fi
}

# Open AWS Console
open_aws_console() {
    log_info "Opening AWS Service Quotas console..."
    
    local region=$(aws configure get region)
    local console_url="https://${region}.console.aws.amazon.com/servicequotas/home?region=${region}#/services"
    
    echo ""
    echo "🌐 AWS Service Quotas Console:"
    echo "   $console_url"
    echo ""
    echo "📋 Search for these services:"
    echo "   1. Amazon Elastic Compute Cloud (Amazon EC2)"
    echo "   2. Amazon Virtual Private Cloud (Amazon VPC)"
    echo "   3. Elastic Load Balancing (ELB)"
    echo ""
    
    if command -v open >/dev/null 2>&1; then
        read -p "Open AWS Console in browser? (yes/no): " open_browser
        if [[ "$open_browser" == "yes" ]]; then
            open "$console_url"
        fi
    fi
}

# Check quota request status
check_quota_requests() {
    log_info "Checking quota increase request status..."
    
    echo ""
    echo "📋 Recent quota increase requests:"
    
    if aws service-quotas list-requested-service-quota-change-history \
        --max-items 10 \
        --query 'RequestedQuotas[?Status==`PENDING`].[ServiceCode,QuotaCode,DesiredValue,Status,Created]' \
        --output table 2>/dev/null; then
        echo ""
        log_info "Pending requests shown above"
    else
        log_warning "Unable to fetch quota request history"
    fi
    
    echo ""
    log_info "Note: Quota increases typically take 24-48 hours to process"
}

# Show alternative regions
show_alternative_regions() {
    log_info "Alternative AWS regions for ROSA with potentially better quotas:"
    
    echo ""
    echo "🌍 Recommended ROSA regions:"
    echo "  • us-east-1 (N. Virginia) - Primary region, best availability"
    echo "  • us-west-2 (Oregon) - Good alternative"
    echo "  • eu-west-1 (Ireland) - European option"
    echo "  • ap-southeast-1 (Singapore) - Asian option"
    echo ""
    echo "💡 Tips:"
    echo "  • New regions may have higher default quotas"
    echo "  • Some regions have faster quota approval"
    echo "  • Choose based on your geographic location for latency"
    echo ""
    
    read -p "Do you want to try creating a cluster in us-east-1 instead? (yes/no): " try_different_region
    
    if [[ "$try_different_region" == "yes" ]]; then
        log_info "You can modify the test cluster script to use us-east-1:"
        echo "  Edit scripts/create-test-cluster-for-virt.sh"
        echo "  Change TEST_REGION=\"us-east-1\""
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "========================================="
    echo "AWS Quota Management for ROSA"
    echo "========================================="
    echo "1. Check current quotas"
    echo "2. Show required quotas"
    echo "3. Generate quota request commands"
    echo "4. Interactive quota request"
    echo "5. Open AWS Console"
    echo "6. Check quota request status"
    echo "7. Show alternative regions"
    echo "8. Exit"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "========================================="
    echo "🔧 AWS Quota Request Helper for ROSA"
    echo "========================================="
    
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select an option (1-8): " choice
            
            case $choice in
                1)
                    check_current_quotas
                    ;;
                2)
                    show_required_quotas
                    ;;
                3)
                    generate_quota_requests
                    ;;
                4)
                    interactive_quota_request
                    ;;
                5)
                    open_aws_console
                    ;;
                6)
                    check_quota_requests
                    ;;
                7)
                    show_alternative_regions
                    ;;
                8)
                    log_info "Exiting..."
                    exit 0
                    ;;
                *)
                    log_error "Invalid option. Please try again."
                    ;;
            esac
            
            echo ""
            read -p "Press Enter to continue..."
        done
    else
        # Command line mode
        case $1 in
            check)
                check_current_quotas
                ;;
            required)
                show_required_quotas
                ;;
            request)
                interactive_quota_request
                ;;
            status)
                check_quota_requests
                ;;
            console)
                open_aws_console
                ;;
            *)
                echo "Usage: $0 [check|required|request|status|console]"
                echo "  check     - Check current quotas"
                echo "  required  - Show required quotas"
                echo "  request   - Interactive quota request"
                echo "  status    - Check request status"
                echo "  console   - Open AWS console"
                echo ""
                echo "Run without arguments for interactive mode"
                exit 1
                ;;
        esac
    fi
}

main "$@"
