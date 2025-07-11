#!/bin/bash

# ROSA Environment Summary
# This script provides a complete overview of your ROSA environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "==========================================="
echo "🚀 ROSA Environment Ready!"
echo "==========================================="
echo -e "${NC}"

echo ""
echo -e "${GREEN}✅ Environment Setup Complete!${NC}"
echo ""

echo "📁 Directory Structure:"
echo "├── scripts/           # Management scripts"
echo "├── configs/          # Configuration templates & environment"
echo "├── templates/        # Kubernetes/OpenShift templates"
echo "├── docs/            # Documentation and guides"
echo "├── logs/            # Operation logs (created when needed)"
echo "└── README.md        # Complete documentation"
echo ""

echo "🛠  Available Management Scripts:"
echo "├── ./setup-rosa-environment.sh    # Initial environment setup"
echo "├── ./scripts/check-environment.sh # Verify tools and authentication"
echo "├── ./scripts/create-rosa-cluster.sh # Create new ROSA clusters"
echo "├── ./scripts/cluster-status.sh    # Check cluster status and health"
echo "├── ./scripts/scale-cluster.sh     # Scale cluster resources"
echo "├── ./scripts/delete-rosa-cluster.sh # Safely delete clusters"
echo "└── ./scripts/quick-reference.sh   # Common commands reference"
echo ""

echo "⚙️  Configuration Files:"
echo "├── configs/aws-config-template.txt      # AWS CLI configuration template"
echo "├── configs/aws-credentials-template.txt # AWS credentials template"
echo "├── configs/rosa-cluster-config.yaml     # Cluster configuration template"
echo "└── configs/rosa-env.sh                  # Environment variables and aliases"
echo ""

echo "📚 Documentation:"
echo "├── README.md                    # Complete setup and usage guide"
echo "├── docs/setup-guide.md         # Step-by-step setup instructions"
echo "├── docs/best-practices.md      # ROSA best practices and optimization"
echo "└── docs/troubleshooting.md     # Common issues and solutions"
echo ""

echo -e "${YELLOW}📋 Next Steps:${NC}"
echo ""
echo "1. 🔐 Configure AWS credentials:"
echo "   aws configure"
echo ""
echo "2. 🔑 Login to Red Hat:"
echo "   rosa login"
echo ""
echo "3. ✅ Verify your setup:"
echo "   ./scripts/check-environment.sh"
echo ""
echo "4. 🚀 Create your first ROSA cluster:"
echo "   ./scripts/create-rosa-cluster.sh"
echo ""

echo -e "${BLUE}💡 Quick Tips:${NC}"
echo ""
echo "• Load environment variables: source configs/rosa-env.sh"
echo "• View quick reference: ./scripts/quick-reference.sh"
echo "• Check environment: ./scripts/check-environment.sh"
echo "• All scripts support --help flag for detailed usage"
echo ""

echo -e "${GREEN}🎉 Your ROSA environment is ready for Red Hat OpenShift on AWS!${NC}"
echo ""

# Check if AWS and ROSA are authenticated
echo -e "${BLUE}Current Authentication Status:${NC}"
if aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "AWS CLI: ${GREEN}✅ Authenticated${NC}"
else
    echo -e "AWS CLI: ${YELLOW}⚠️  Not authenticated${NC} (run 'aws configure')"
fi

if rosa whoami >/dev/null 2>&1; then
    echo -e "ROSA CLI: ${GREEN}✅ Authenticated${NC}"
else
    echo -e "ROSA CLI: ${YELLOW}⚠️  Not authenticated${NC} (run 'rosa login')"
fi

echo ""
echo -e "${BLUE}For detailed documentation, see README.md${NC}"
