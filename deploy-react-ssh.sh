#!/bin/bash

# Deploy React Frontend with SSH Access
# This script deploys a React application with direct SSH access to pods

set -e

echo "🚀 Deploying React Frontend with SSH Access"
echo "============================================="

# Check if we're logged into OpenShift
if ! oc whoami &> /dev/null; then
    echo "❌ Error: Not logged into OpenShift. Please run 'oc login' first."
    exit 1
fi

# Clean up any existing deployment
echo "🧹 Cleaning up existing React deployment..."
oc delete deployment react-frontend -n react-frontend 2>/dev/null || true
oc delete service react-frontend-service -n react-frontend 2>/dev/null || true
oc delete route react-frontend-route -n react-frontend 2>/dev/null || true

# Deploy React with SSH
echo "📦 Deploying React frontend with SSH access..."
oc apply -k apps/react-frontend/ -f apps/react-frontend/kustomization-ssh.yaml

# Wait for deployment
echo "⏳ Waiting for React SSH deployment..."
oc wait --for=condition=available --timeout=300s deployment/react-frontend-ssh -n react-frontend

# Get access information
echo ""
echo "✅ React Frontend with SSH Deployed Successfully!"
echo "================================================="

echo ""
echo "📋 Access Information:"
echo "---------------------"

# Get React app URL
REACT_URL=$(oc get route react-frontend-ssh-route -n react-frontend -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
if [ "$REACT_URL" != "Not available" ]; then
    echo "🌐 React App URL: https://$REACT_URL"
fi

# Get SSH NodePort access
echo ""
echo "🔑 SSH Access (NodePort):"
echo "-------------------------"
echo "Port: 30222"
echo "Username: admin"
echo "Password: admin"

# Get worker node IPs
echo ""
echo "📡 Worker Node IPs for SSH:"
echo "---------------------------"
oc get nodes -o wide --no-headers | grep -v master | awk '{print "Node:", $1, "IP:", $7}' || echo "Could not get node IPs"

echo ""
echo "🔧 SSH Connection Examples:"
echo "---------------------------"
echo "# Get any worker node IP first:"
echo "NODE_IP=\$(oc get nodes -o wide --no-headers | grep -v master | awk '{print \$7}' | head -1)"
echo ""
echo "# Connect via SSH:"
echo "ssh -p 30222 admin@\$NODE_IP"
echo ""
echo "# Or connect directly (replace with actual node IP):"
FIRST_NODE_IP=$(oc get nodes -o wide --no-headers | grep -v master | awk '{print $7}' | head -1 2>/dev/null || echo "NODE_IP")
echo "ssh -p 30222 admin@$FIRST_NODE_IP"

echo ""
echo "🛠️ Available Commands in SSH:"
echo "-----------------------------"
echo "• edit-react    - Edit the React app HTML"
echo "• view-logs     - View nginx access/error logs"
echo "• test-app      - Test the React app locally"
echo "• welcome.sh    - Show welcome message again"

echo ""
echo "📊 Pod Status:"
echo "--------------"
oc get pods -n react-frontend -l app=react-frontend-ssh

echo ""
echo "🎯 Testing React App:"
echo "---------------------"
if [ "$REACT_URL" != "Not available" ]; then
    echo -n "Testing React app: "
    if curl -k -s -f "https://$REACT_URL" > /dev/null; then
        echo "✅ OK"
    else
        echo "❌ FAILED (might still be starting up)"
    fi
fi

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "💡 Next Steps:"
echo "--------------"
echo "1. Wait for pods to be fully ready"
echo "2. Get a worker node IP: oc get nodes -o wide"
echo "3. SSH to the pod: ssh -p 30222 admin@<node-ip>"
echo "4. Edit the React app: edit-react"
echo "5. View your changes at: https://$REACT_URL"
