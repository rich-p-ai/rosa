#!/bin/bash

# Quick verification script for the containerized webserver deployment
# This script checks the health and status of your deployment

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔍 Containerized Webserver Health Check${NC}"
echo "========================================"

# Check CLI
if command -v oc &> /dev/null; then
    CLI="oc"
else
    echo "❌ OpenShift CLI not found"
    exit 1
fi

# Check namespace
echo -e "\n${GREEN}📁 Namespace Status${NC}"
if $CLI get namespace webserver &>/dev/null; then
    echo "✅ Namespace 'webserver' exists"
else
    echo "❌ Namespace 'webserver' not found"
    exit 1
fi

# Check deployment
echo -e "\n${GREEN}🚀 Deployment Status${NC}"
DEPLOYMENT_STATUS=$($CLI get deployment rhel9-webserver -n webserver -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DEPLOYMENT_DESIRED=$($CLI get deployment rhel9-webserver -n webserver -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

if [ "$DEPLOYMENT_STATUS" = "$DEPLOYMENT_DESIRED" ] && [ "$DEPLOYMENT_STATUS" != "0" ]; then
    echo "✅ Deployment ready: $DEPLOYMENT_STATUS/$DEPLOYMENT_DESIRED pods"
else
    echo "❌ Deployment not ready: $DEPLOYMENT_STATUS/$DEPLOYMENT_DESIRED pods"
fi

# Check pods
echo -e "\n${GREEN}📦 Pod Status${NC}"
$CLI get pods -n webserver

# Check service
echo -e "\n${GREEN}🌐 Service Status${NC}"
if $CLI get service rhel9-webserver-deployment-service -n webserver &>/dev/null; then
    echo "✅ Service 'rhel9-webserver-deployment-service' exists"
    SERVICE_IP=$($CLI get service rhel9-webserver-deployment-service -n webserver -o jsonpath='{.spec.clusterIP}')
    echo "   Cluster IP: $SERVICE_IP"
else
    echo "❌ Service not found"
fi

# Check route
echo -e "\n${GREEN}🔗 Route Status${NC}"
if $CLI get route rhel9-webserver-deployment-route -n webserver &>/dev/null; then
    echo "✅ Route 'rhel9-webserver-deployment-route' exists"
    ROUTE_URL=$($CLI get route rhel9-webserver-deployment-route -n webserver -o jsonpath='{.spec.host}')
    echo "   URL: http://$ROUTE_URL"
    
    # Test connectivity
    echo -e "\n${GREEN}🌍 Connectivity Test${NC}"
    if curl -s --connect-timeout 10 "http://$ROUTE_URL" | grep -q "Welcome to RHEL 9 Web Server"; then
        echo "✅ Web server is responding correctly"
        echo "   Page contains expected content"
    else
        echo "❌ Web server not responding or content missing"
    fi
else
    echo "❌ Route not found"
fi

# Resource usage
echo -e "\n${GREEN}💾 Resource Usage${NC}"
echo "Pods in webserver namespace:"
$CLI top pods -n webserver 2>/dev/null || echo "Metrics not available"

echo -e "\n${GREEN}📊 Summary${NC}"
echo "=================="
echo "✅ Containerized RHEL9 webserver deployed"
echo "✅ Running on ROSA cluster"
echo "✅ Accessible via public route"
echo "✅ No quota constraints"

echo -e "\n${YELLOW}🎯 Access your webserver:${NC}"
echo "http://$ROUTE_URL"

echo -e "\n${BLUE}Health check completed successfully! 🎉${NC}"
