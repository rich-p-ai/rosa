#!/bin/bash

# Script to generate SSH bastion architecture for multiple projects
# This creates one entry point with internal routing to all projects

echo "Setting up scalable SSH architecture for 200+ projects..."

# Create namespace for SSH gateway
oc create namespace ssh-gateway --dry-run=client -o yaml > ssh-gateway-namespace.yaml

# Generate project template
generate_project_ssh_service() {
    local project_name=$1
    local project_number=$2
    
    cat > "project-${project_name}-ssh-service.yaml" << EOF
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

# Generate SSH proxy configuration
cat > ssh-proxy-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssh-proxy-config
  namespace: ssh-gateway
data:
  ssh_config: |
    # SSH Configuration for project routing
    Host project-*
        ProxyCommand ssh -W %h:%p bastion.ssh-gateway.svc.cluster.local
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
    
    # Individual project configurations will be added here
  
  projects.txt: |
    # Format: project-name:namespace:service-name
    webserver1:webserver:rhel9-webserver-deployment-service
    webserver2:webserver2:rhel9-webserver-deployment-service
    # Add more projects here...
EOF

echo "Generated SSH architecture files:"
echo "- ssh-gateway-namespace.yaml"
echo "- ssh-proxy-config.yaml"
echo "- project-*-ssh-service.yaml (template)"

echo ""
echo "Benefits of this approach:"
echo "✅ Single AWS Load Balancer (~\$16/month vs \$3200/month for 200 LBs)"
echo "✅ Single DNS entry (ssh.webserver.p-ai.net)"
echo "✅ No NodePort limitations"
echo "✅ Centralized SSH key management"
echo "✅ Internal ClusterIP services for all projects"
echo "✅ SSH ProxyCommand for seamless access"

echo ""
echo "Usage after setup:"
echo "ssh user@ssh.webserver.p-ai.net"
echo "Then from bastion: ssh project1@project1-ssh.project1.svc.cluster.local"
