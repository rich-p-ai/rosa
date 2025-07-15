#!/bin/bash

# Deploy SSH Access for ROSA Web Applications
# This script deploys a centralized SSH bastion host for accessing all applications

set -e

echo "🚀 Deploying SSH Access for ROSA Web Applications"
echo "=================================================="

# Check if we're logged into OpenShift
if ! oc whoami &> /dev/null; then
    echo "❌ Error: Not logged into OpenShift. Please run 'oc login' first."
    exit 1
fi

# Deploy SSH access
echo "📦 Deploying SSH access infrastructure..."
oc apply -k apps/ssh-access/

# Wait for deployment
echo "⏳ Waiting for SSH bastion deployment..."
oc wait --for=condition=available --timeout=300s deployment/ssh-bastion -n ssh-access

# Get external access information
echo ""
echo "✅ SSH Access Deployed Successfully!"
echo "===================================="

echo ""
echo "📋 SSH Access Information:"
echo "--------------------------"

# Get LoadBalancer external IP
EXTERNAL_IP=$(oc get service ssh-bastion-external -n ssh-access -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
if [ "$EXTERNAL_IP" != "Pending..." ] && [ -n "$EXTERNAL_IP" ]; then
    echo "🌐 External SSH Access: ssh developer@$EXTERNAL_IP"
    echo "🔑 Password: RosaSSH2025!"
else
    echo "⏳ External IP is still being assigned..."
    echo "   Run: oc get svc ssh-bastion-external -n ssh-access"
fi

# Get route information
ROUTE_HOST=$(oc get route ssh-bastion-route -n ssh-access -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
if [ "$ROUTE_HOST" != "Not available" ]; then
    echo "🔗 Route Access: $ROUTE_HOST (port 2222)"
fi

echo ""
echo "📱 Available Applications from SSH:"
echo "-----------------------------------"
echo "📱 React Frontend:  https://react-frontend-route-react-frontend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com"
echo "🎯 Vue Frontend:    https://vue-frontend-route-vue-frontend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com"
echo "⚡ Angular Frontend: https://angular-frontend-route-angular-frontend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com"
echo "🟢 Node.js Backend: https://nodejs-backend-route-nodejs-backend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com"
echo "🐍 Django Backend:  https://django-backend-route-django-backend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com"

echo ""
echo "🛠️ SSH Bastion Features:"
echo "------------------------"
echo "• Password-based authentication (RosaSSH2025!)"
echo "• Pre-installed development tools (curl, git, vim, nano)"
echo "• Application testing utilities (test-apps command)"
echo "• High availability (2 replicas)"
echo "• LoadBalancer for external access"

echo ""
echo "📖 Usage Examples:"
echo "------------------"
echo "# Connect via external LoadBalancer:"
echo "ssh developer@\$EXTERNAL_IP"
echo ""
echo "# Test all applications:"
echo "test-apps"
echo ""
echo "# Check application status:"
echo "curl -k https://react-frontend-route-react-frontend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com"

echo ""
echo "✅ SSH deployment completed successfully!"
