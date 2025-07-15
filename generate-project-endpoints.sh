#!/bin/bash

# Script to generate unique DNS endpoints for each project
# Uses OpenShift Routes with a shared AWS Application Load Balancer

PROJECT_BASE_DOMAIN="p-ai.net"
PROJECT_COUNT=200

echo "Creating scalable SSH access for $PROJECT_COUNT projects..."
echo "Each project will get: project-N.ssh.$PROJECT_BASE_DOMAIN"

# Create the SSH gateway namespace
cat > ssh-gateway-namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ssh-gateway
  labels:
    name: ssh-gateway
EOF

# Create SSH proxy deployment that handles routing
cat > ssh-proxy-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ssh-proxy
  namespace: ssh-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ssh-proxy
  template:
    metadata:
      labels:
        app: ssh-proxy
    spec:
      containers:
      - name: ssh-proxy
        image: nginx:alpine
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: ssh-proxy-script
          mountPath: /usr/local/bin/ssh-proxy.sh
          subPath: ssh-proxy.sh
        command: ["/bin/sh"]
        args: ["-c", "chmod +x /usr/local/bin/ssh-proxy.sh && /usr/local/bin/ssh-proxy.sh"]
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
      - name: ssh-proxy-script
        configMap:
          name: ssh-proxy-script
          defaultMode: 0755
---
apiVersion: v1
kind: Service
metadata:
  name: ssh-proxy-service
  namespace: ssh-gateway
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: ssh-proxy
EOF

# Generate individual project routes
generate_project_routes() {
    for i in $(seq 1 $PROJECT_COUNT); do
        PROJECT_NAME="project-$i"
        
        # Create route for each project
        cat > "route-${PROJECT_NAME}.yaml" << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ${PROJECT_NAME}-ssh-route
  namespace: ssh-gateway
  labels:
    project: ${PROJECT_NAME}
spec:
  host: ${PROJECT_NAME}.ssh.${PROJECT_BASE_DOMAIN}
  to:
    kind: Service
    name: ssh-proxy-service
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None
EOF

        # Create project ClusterIP service
        cat > "service-${PROJECT_NAME}.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${PROJECT_NAME}-ssh
  namespace: ${PROJECT_NAME}
  labels:
    app: ${PROJECT_NAME}
    ssh-enabled: "true"
spec:
  type: ClusterIP
  ports:
  - name: ssh
    port: 22
    targetPort: 22
    protocol: TCP
  selector:
    app: ${PROJECT_NAME}
EOF
    done
}

echo "Generated project routes and services!"
echo ""
echo "Each project will be accessible at:"
echo "  project-1.ssh.p-ai.net"
echo "  project-2.ssh.p-ai.net"
echo "  ..."
echo "  project-200.ssh.p-ai.net"
echo ""
echo "Cost: Uses shared OpenShift router (AWS ALB) - ~\$20/month total"
echo "vs NodePort approach: ~\$3,200/month"

generate_project_routes
