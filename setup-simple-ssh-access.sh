#!/bin/bash

# Automated script to create simple SSH access for 200+ projects
# Each project gets: project-N.ssh.p-ai.net

set -e

PROJECT_COUNT=${1:-200}
BASE_DOMAIN="p-ai.net"
SSH_SUBDOMAIN="ssh"

echo "🚀 Setting up simple SSH access for $PROJECT_COUNT projects"
echo "Each project will be accessible at: project-N.$SSH_SUBDOMAIN.$BASE_DOMAIN"
echo ""

# Create the SSH gateway namespace
echo "📁 Creating ssh-gateway namespace..."
oc create namespace ssh-gateway --dry-run=client -o yaml | oc apply -f -

# Deploy the WebSSH proxy
echo "🌐 Deploying WebSSH proxy..."
oc apply -f webssh-multi-project.yaml

# Function to generate project SSH service
generate_project_service() {
    local project_num=$1
    local project_name="project-${project_num}"
    
    cat << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${project_name}-ssh
  namespace: ${project_name}
  labels:
    app: ${project_name}
    ssh-enabled: "true"
spec:
  type: ClusterIP
  ports:
  - name: ssh
    port: 22
    targetPort: 22
    protocol: TCP
  selector:
    app: ${project_name}
EOF
}

# Function to generate project route
generate_project_route() {
    local project_num=$1
    local project_name="project-${project_num}"
    
    cat << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ${project_name}-ssh-route
  namespace: ssh-gateway
  labels:
    project: ${project_name}
spec:
  host: ${project_name}.${SSH_SUBDOMAIN}.${BASE_DOMAIN}
  to:
    kind: Service
    name: webssh-service
  port:
    targetPort: webssh
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None
EOF
}

# Generate all project configurations
echo "⚙️  Generating configurations for $PROJECT_COUNT projects..."

# Create a single file with all routes
echo "# Generated routes for $PROJECT_COUNT projects" > all-project-routes.yaml
echo "# Apply with: oc apply -f all-project-routes.yaml" >> all-project-routes.yaml
echo "" >> all-project-routes.yaml

for i in $(seq 1 $PROJECT_COUNT); do
    if [ $((i % 50)) -eq 0 ]; then
        echo "   Generated $i/$PROJECT_COUNT projects..."
    fi
    
    # Add separator
    echo "---" >> all-project-routes.yaml
    
    # Add route
    generate_project_route $i >> all-project-routes.yaml
done

# Create a single file with all services template
echo "# Template services for $PROJECT_COUNT projects" > all-project-services-template.yaml
echo "# These should be applied in each project's namespace" >> all-project-services-template.yaml
echo "" >> all-project-services-template.yaml

for i in $(seq 1 $PROJECT_COUNT); do
    echo "---" >> all-project-services-template.yaml
    generate_project_service $i >> all-project-services-template.yaml
done

echo ""
echo "✅ Configuration generated!"
echo ""
echo "📋 Next steps:"
echo "1. Apply the routes:"
echo "   oc apply -f all-project-routes.yaml"
echo ""
echo "2. For each project namespace, apply the SSH service:"
echo "   # Example for project-1:"
echo "   oc create namespace project-1"
echo "   oc apply -f - << EOF"
echo "   $(generate_project_service 1)"
echo "   EOF"
echo ""
echo "3. Set up DNS wildcard record in Squarespace:"
echo "   Type: CNAME"
echo "   Host: *.ssh"
echo "   Points to: <your-openshift-router-domain>"
echo ""
echo "🔗 Access pattern:"
echo "   https://project-1.ssh.p-ai.net"
echo "   https://project-2.ssh.p-ai.net"
echo "   ..."
echo "   https://project-$PROJECT_COUNT.ssh.p-ai.net"
echo ""
echo "💰 Cost: Uses shared OpenShift router (~\$20/month total)"
echo "   vs 200 Load Balancers (~\$3,200/month)"
echo ""
echo "📁 Files created:"
echo "   - all-project-routes.yaml (apply to cluster)"
echo "   - all-project-services-template.yaml (reference for each project)"
