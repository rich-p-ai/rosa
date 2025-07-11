# ROSA Environment Variables
# Source this file to set up environment variables for ROSA management
# Usage: source configs/rosa-env.sh

# AWS Configuration
export AWS_DEFAULT_REGION="us-east-1"
export AWS_DEFAULT_OUTPUT="json"

# ROSA Configuration
export ROSA_DEFAULT_REGION="us-east-1"
export ROSA_DEFAULT_VERSION="4.14"
export ROSA_DEFAULT_MACHINE_TYPE="m5.xlarge"
export ROSA_DEFAULT_REPLICAS="3"

# OpenShift Configuration
export KUBECONFIG="$HOME/.kube/config"

# Logging
export ROSA_LOG_LEVEL="info"

# Colors for terminal output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Helper functions
rosa_status() {
    echo -e "${BLUE}[INFO]${NC} Checking ROSA environment status..."
    ./scripts/check-environment.sh summary
}

rosa_clusters() {
    echo -e "${BLUE}[INFO]${NC} Listing all ROSA clusters..."
    rosa list clusters
}

rosa_quick_help() {
    ./scripts/quick-reference.sh
}

# Aliases for common commands
alias rosas='rosa_status'
alias rosac='rosa_clusters'
alias rosah='rosa_quick_help'
alias rc='rosa list clusters'
alias rcd='rosa describe cluster'
alias ocn='oc get nodes'
alias ocp='oc get pods --all-namespaces'

echo -e "${GREEN}[SUCCESS]${NC} ROSA environment variables loaded!"
echo "Available aliases: rosas, rosac, rosah, rc, rcd, ocn, ocp"
