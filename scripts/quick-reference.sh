#!/bin/bash

# Quick ROSA Commands Reference
# This file contains commonly used ROSA commands for quick reference

echo "=== ROSA Quick Commands Reference ==="
echo ""

echo "🔧 Environment Setup:"
echo "  aws configure                     # Configure AWS credentials"
echo "  rosa login                        # Login to Red Hat"
echo "  rosa verify quota                 # Check AWS quotas"
echo "  rosa verify permissions           # Check AWS permissions"
echo ""

echo "🚀 Cluster Operations:"
echo "  rosa list clusters                # List all clusters"
echo "  rosa create cluster               # Create cluster (interactive)"
echo "  rosa describe cluster <name>      # Show cluster details"
echo "  rosa delete cluster <name>        # Delete cluster"
echo ""

echo "🔄 Node Management:"
echo "  rosa list machinepools <cluster>  # List machine pools"
echo "  rosa create machinepool           # Add machine pool"
echo "  rosa edit machinepool             # Modify machine pool"
echo "  rosa delete machinepool           # Remove machine pool"
echo ""

echo "🛠 Add-ons:"
echo "  rosa list addons                  # List available add-ons"
echo "  rosa install addon               # Install add-on"
echo "  rosa uninstall addon             # Remove add-on"
echo ""

echo "👤 Access Management:"
echo "  rosa create admin <cluster>       # Create cluster admin"
echo "  rosa delete admin <cluster>       # Remove cluster admin"
echo "  rosa list users <cluster>         # List cluster users"
echo ""

echo "📊 Monitoring:"
echo "  rosa logs install <cluster>       # Show installation logs"
echo "  rosa describe cluster <cluster>   # Cluster status"
echo ""

echo "🔍 OpenShift Commands:"
echo "  oc login <url>                    # Connect to cluster"
echo "  oc get nodes                      # List cluster nodes"
echo "  oc get pods --all-namespaces      # List all pods"
echo "  oc whoami                         # Show current user"
echo "  oc projects                       # List projects"
echo ""

echo "💰 Cost Management:"
echo "  aws ce get-cost-and-usage         # Check AWS costs"
echo "  rosa describe cluster <name>      # Check instance types"
echo ""

echo "📚 Help:"
echo "  rosa --help                       # ROSA CLI help"
echo "  oc --help                         # OpenShift CLI help"
echo "  aws --help                        # AWS CLI help"
