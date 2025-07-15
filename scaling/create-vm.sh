#!/bin/bash

# VM Creation Script for Scaling ROSA SSH Access
# Usage: ./create-vm.sh --name myapp --type frontend --port 2206
# 
# This script generates GitOps manifests for a new VM with SSH access
# following the established patterns from your existing 5 applications.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default values
VM_NAME=""
VM_TYPE="frontend"
SSH_PORT=""
BASE_PORT=2205
NAMESPACE_PREFIX=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            VM_NAME="$2"
            shift 2
            ;;
        --type)
            VM_TYPE="$2"
            shift 2
            ;;
        --port)
            SSH_PORT="$2"
            shift 2
            ;;
        --namespace-prefix)
            NAMESPACE_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            cat <<EOF
VM Creation Script for ROSA SSH Access

Usage: $0 --name <vm-name> [options]

Required:
  --name <name>              VM name (will be used for namespace and resources)

Optional:
  --type <type>              VM type: frontend, backend, fullstack (default: frontend)
  --port <port>              SSH port number (auto-assigned if not specified)
  --namespace-prefix <prefix> Namespace prefix (default: none)

Examples:
  $0 --name my-react-app --type frontend
  $0 --name api-service --type backend --port 2210
  $0 --name dev-vm-01 --type fullstack --namespace-prefix dev

Supported VM Types:
  frontend   - React/Vue/Angular frontend with Nginx + Node.js
  backend    - Node.js Express API or Python Django
  fullstack  - Frontend + Backend in one container
  minimal    - Basic UBI9 container with SSH only

EOF
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$VM_NAME" ]]; then
    log_error "VM name is required. Use --name <vm-name>"
    exit 1
fi

# Auto-assign SSH port if not specified
if [[ -z "$SSH_PORT" ]]; then
    # Find next available port by scanning existing apps
    USED_PORTS=($(find /Users/richardsawyers/work/rosa/apps -name "ssh-service.yaml" -exec grep -h "nodePort:" {} \; | awk '{print $2}' | sort -n))
    NEXT_PORT=$((BASE_PORT + 1))
    
    for port in "${USED_PORTS[@]}"; do
        if [[ $port -ge $NEXT_PORT ]]; then
            NEXT_PORT=$((port + 1))
        fi
    done
    
    SSH_PORT=$NEXT_PORT
    log_info "Auto-assigned SSH port: $SSH_PORT"
fi

# Set namespace
if [[ -n "$NAMESPACE_PREFIX" ]]; then
    NAMESPACE="${NAMESPACE_PREFIX}-${VM_NAME}"
else
    NAMESPACE="$VM_NAME"
fi

# Create directory structure
VM_DIR="/Users/richardsawyers/work/rosa/apps/${VM_NAME}"
log_info "Creating VM directory: $VM_DIR"

if [[ -d "$VM_DIR" ]]; then
    log_warning "Directory $VM_DIR already exists. Overwriting..."
    rm -rf "$VM_DIR"
fi

mkdir -p "$VM_DIR"

# Generate password for this VM
VM_PASSWORD=$(echo "${VM_NAME^}Dev@2024")

log_info "Creating GitOps manifests for VM: $VM_NAME"
log_info "VM Type: $VM_TYPE"
log_info "Namespace: $NAMESPACE"
log_info "SSH Port: $SSH_PORT"
log_info "SSH Password: $VM_PASSWORD"

# Create namespace.yaml
cat > "$VM_DIR/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    app: $VM_NAME
    vm-type: $VM_TYPE
    ssh-enabled: "true"
EOF

# Create main application deployment based on VM type
case $VM_TYPE in
    "frontend")
        create_frontend_deployment
        ;;
    "backend")
        create_backend_deployment
        ;;
    "fullstack")
        create_fullstack_deployment
        ;;
    "minimal")
        create_minimal_deployment
        ;;
    *)
        log_error "Unknown VM type: $VM_TYPE"
        exit 1
        ;;
esac

# Create SSH deployment (same for all types)
create_ssh_deployment

# Create services
create_services

# Create routes
create_routes

# Create configmap
create_configmap

# Create kustomization
create_kustomization

# Create SSH secret
create_ssh_secret

log_success "VM '$VM_NAME' created successfully!"
log_info "Directory: $VM_DIR"
log_info "To deploy this VM:"
echo "  1. Add '$VM_NAME/' to /Users/richardsawyers/work/rosa/apps/kustomization.yaml"
echo "  2. Commit and push to trigger ArgoCD sync"
echo "  3. Update AWS NLB to include port $SSH_PORT"
echo ""
log_info "SSH Access:"
echo "  ssh developer@your-nlb-dns:$SSH_PORT"
echo "  Password: $VM_PASSWORD"

# Function definitions
create_frontend_deployment() {
    cat > "$VM_DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $VM_NAME
  namespace: $NAMESPACE
  labels:
    app: $VM_NAME
    vm-type: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $VM_NAME
  template:
    metadata:
      labels:
        app: $VM_NAME
    spec:
      containers:
      - name: nginx
        image: registry.redhat.io/ubi9/nginx-120:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        - name: app-content
          mountPath: /usr/share/nginx/html
      - name: nodejs
        image: registry.redhat.io/ubi9/nodejs-18:latest
        ports:
        - containerPort: 3000
        workingDir: /workspace
        command: ["/bin/bash", "-c"]
        args: ["npm init -y && npm install express && echo 'const express = require(\"express\"); const app = express(); app.get(\"/\", (req, res) => res.send(\"$VM_NAME Frontend - Ready for Development!\")); app.listen(3000, () => console.log(\"Server running on port 3000\"));' > server.js && node server.js"]
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "300m"
        volumeMounts:
        - name: workspace
          mountPath: /workspace
      volumes:
      - name: nginx-config
        configMap:
          name: $VM_NAME-nginx-config
      - name: app-content
        configMap:
          name: $VM_NAME-app-content
      - name: workspace
        emptyDir: {}
EOF
}

create_backend_deployment() {
    cat > "$VM_DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $VM_NAME
  namespace: $NAMESPACE
  labels:
    app: $VM_NAME
    vm-type: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $VM_NAME
  template:
    metadata:
      labels:
        app: $VM_NAME
    spec:
      containers:
      - name: nodejs-api
        image: registry.redhat.io/ubi9/nodejs-18:latest
        ports:
        - containerPort: 3000
        workingDir: /workspace
        command: ["/bin/bash", "-c"]
        args: ["npm init -y && npm install express cors && echo 'const express = require(\"express\"); const cors = require(\"cors\"); const app = express(); app.use(cors()); app.get(\"/api/health\", (req, res) => res.json({status: \"healthy\", service: \"$VM_NAME\"})); app.get(\"/api/info\", (req, res) => res.json({name: \"$VM_NAME\", type: \"backend\", version: \"1.0.0\"})); app.listen(3000, () => console.log(\"$VM_NAME API running on port 3000\"));' > server.js && node server.js"]
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "300m"
        volumeMounts:
        - name: workspace
          mountPath: /workspace
      volumes:
      - name: workspace
        emptyDir: {}
EOF
}

create_fullstack_deployment() {
    cat > "$VM_DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $VM_NAME
  namespace: $NAMESPACE
  labels:
    app: $VM_NAME
    vm-type: fullstack
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $VM_NAME
  template:
    metadata:
      labels:
        app: $VM_NAME
    spec:
      containers:
      - name: fullstack-app
        image: registry.redhat.io/ubi9/nodejs-18:latest
        ports:
        - containerPort: 3000
        - containerPort: 8080
        workingDir: /workspace
        command: ["/bin/bash", "-c"]
        args: ["npm init -y && npm install express cors && mkdir -p public && echo '<html><body><h1>$VM_NAME Fullstack</h1><div id=\"api-data\">Loading...</div><script>fetch(\"/api/info\").then(r=>r.json()).then(d=>document.getElementById(\"api-data\").innerHTML=JSON.stringify(d,null,2))</script></body></html>' > public/index.html && echo 'const express = require(\"express\"); const cors = require(\"cors\"); const path = require(\"path\"); const app = express(); app.use(cors()); app.use(express.static(\"public\")); app.get(\"/api/info\", (req, res) => res.json({name: \"$VM_NAME\", type: \"fullstack\", frontend: \"included\", backend: \"included\"})); app.listen(3000, () => console.log(\"$VM_NAME Fullstack running on port 3000\"));' > server.js && node server.js"]
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        volumeMounts:
        - name: workspace
          mountPath: /workspace
      volumes:
      - name: workspace
        emptyDir: {}
EOF
}

create_minimal_deployment() {
    cat > "$VM_DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $VM_NAME
  namespace: $NAMESPACE
  labels:
    app: $VM_NAME
    vm-type: minimal
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $VM_NAME
  template:
    metadata:
      labels:
        app: $VM_NAME
    spec:
      containers:
      - name: minimal-vm
        image: registry.redhat.io/ubi9/ubi:latest
        command: ["/bin/bash", "-c"]
        args: ["while true; do echo '$VM_NAME minimal VM - $(date)'; sleep 60; done"]
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
        volumeMounts:
        - name: workspace
          mountPath: /workspace
      volumes:
      - name: workspace
        emptyDir: {}
EOF
}

create_ssh_deployment() {
    cat > "$VM_DIR/ssh-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $VM_NAME-ssh
  namespace: $NAMESPACE
  labels:
    app: $VM_NAME-ssh
  annotations:
    argocd.argoproj.io/sync-wave: "15"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $VM_NAME-ssh
  template:
    metadata:
      labels:
        app: $VM_NAME-ssh
    spec:
      containers:
      - name: ssh-server
        image: registry.redhat.io/ubi9/ubi:latest
        ports:
        - containerPort: 22
        command: ["/bin/bash", "-c"]
        args: 
        - |
          set -e
          
          # Install SSH server
          yum install -y openssh-server sudo
          
          # Create developer user
          useradd -m -s /bin/bash developer
          echo "developer:$VM_PASSWORD" | chpasswd
          echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
          
          # Setup SSH
          ssh-keygen -A
          mkdir -p /home/developer/.ssh
          chmod 700 /home/developer/.ssh
          chown developer:developer /home/developer/.ssh
          
          # Create workspace directory with sample files
          mkdir -p /home/developer/workspace/$VM_NAME
          cat > /home/developer/workspace/$VM_NAME/README.md <<EOF2
          # $VM_NAME Development Environment
          
          Welcome to your $VM_TYPE VM!
          
          ## Quick Start
          \`\`\`bash
          cd ~/workspace/$VM_NAME
          # Your development files are here
          \`\`\`
          
          ## VM Details
          - Name: $VM_NAME
          - Type: $VM_TYPE  
          - SSH Port: $SSH_PORT
          - Namespace: $NAMESPACE
          EOF2
          
          # Create development files based on VM type
          case "$VM_TYPE" in
            "frontend")
              cat > /home/developer/workspace/$VM_NAME/index.html <<EOF2
          <!DOCTYPE html>
          <html>
          <head><title>$VM_NAME</title></head>
          <body>
            <h1>$VM_NAME Frontend</h1>
            <p>Edit this file to customize your frontend!</p>
          </body>
          </html>
          EOF2
              ;;
            "backend")
              cat > /home/developer/workspace/$VM_NAME/app.js <<EOF2
          const express = require('express');
          const app = express();
          
          app.get('/', (req, res) => {
            res.json({ message: '$VM_NAME API is running!' });
          });
          
          app.listen(3000, () => {
            console.log('$VM_NAME API listening on port 3000');
          });
          EOF2
              ;;
          esac
          
          chown -R developer:developer /home/developer/workspace
          
          # Configure SSH
          sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
          sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
          echo "AllowUsers developer" >> /etc/ssh/sshd_config
          
          # Start SSH daemon
          exec /usr/sbin/sshd -D
        env:
        - name: VM_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $VM_NAME-ssh-secret
              key: password
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        livenessProbe:
          tcpSocket:
            port: 22
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          tcpSocket:
            port: 22
          initialDelaySeconds: 10
          periodSeconds: 10
EOF
}

create_services() {
    # Main application service
    cat > "$VM_DIR/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $VM_NAME-service
  namespace: $NAMESPACE
  labels:
    app: $VM_NAME
spec:
  selector:
    app: $VM_NAME
  ports:
  - name: http
    port: 80
    targetPort: 3000
    protocol: TCP
  type: ClusterIP
EOF

    # SSH service
    cat > "$VM_DIR/ssh-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $VM_NAME-ssh-service
  namespace: $NAMESPACE
  labels:
    app: $VM_NAME-ssh
  annotations:
    argocd.argoproj.io/sync-wave: "15"
spec:
  selector:
    app: $VM_NAME-ssh
  ports:
  - name: ssh
    port: 22
    targetPort: 22
    nodePort: $SSH_PORT
    protocol: TCP
  type: NodePort
EOF
}

create_routes() {
    # Main application route
    cat > "$VM_DIR/route.yaml" <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: $VM_NAME-route
  namespace: $NAMESPACE
  labels:
    app: $VM_NAME
spec:
  to:
    kind: Service
    name: $VM_NAME-service
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

    # SSH route (for internal cluster access)
    cat > "$VM_DIR/ssh-route.yaml" <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: $VM_NAME-ssh-route
  namespace: $NAMESPACE
  labels:
    app: $VM_NAME-ssh
  annotations:
    argocd.argoproj.io/sync-wave: "15"
spec:
  to:
    kind: Service
    name: $VM_NAME-ssh-service
  port:
    targetPort: ssh
  tls:
    termination: passthrough
EOF
}

create_configmap() {
    cat > "$VM_DIR/configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $VM_NAME-nginx-config
  namespace: $NAMESPACE
data:
  default.conf: |
    server {
        listen 8080;
        server_name localhost;
        
        location / {
            proxy_pass http://localhost:3000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $VM_NAME-app-content
  namespace: $NAMESPACE
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>$VM_NAME</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .container { max-width: 800px; margin: 0 auto; }
            .header { background: #0066cc; color: white; padding: 20px; border-radius: 5px; }
            .content { padding: 20px; border: 1px solid #ddd; margin-top: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>$VM_NAME</h1>
                <p>VM Type: $VM_TYPE | SSH Port: $SSH_PORT</p>
            </div>
            <div class="content">
                <h2>Welcome to your development environment!</h2>
                <p>This VM is ready for development. Connect via SSH to start coding:</p>
                <pre>ssh developer@your-nlb-dns:$SSH_PORT</pre>
                <p><strong>Password:</strong> $VM_PASSWORD</p>
                
                <h3>VM Information</h3>
                <ul>
                    <li><strong>Name:</strong> $VM_NAME</li>
                    <li><strong>Type:</strong> $VM_TYPE</li>
                    <li><strong>Namespace:</strong> $NAMESPACE</li>
                    <li><strong>SSH Port:</strong> $SSH_PORT</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
EOF
}

create_ssh_secret() {
    cat > "$VM_DIR/ssh-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $VM_NAME-ssh-secret
  namespace: $NAMESPACE
  annotations:
    argocd.argoproj.io/sync-wave: "10"
type: Opaque
data:
  password: $(echo -n "$VM_PASSWORD" | base64)
  username: $(echo -n "developer" | base64)
EOF
}

create_kustomization() {
    cat > "$VM_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: $NAMESPACE

resources:
- namespace.yaml
- deployment.yaml
- service.yaml
- route.yaml
- configmap.yaml
- ssh-deployment.yaml
- ssh-service.yaml
- ssh-route.yaml
- ssh-secret.yaml

commonLabels:
  vm-name: $VM_NAME
  vm-type: $VM_TYPE
  ssh-port: "$SSH_PORT"

images:
- name: registry.redhat.io/ubi9/nginx-120
  newTag: latest
- name: registry.redhat.io/ubi9/nodejs-18
  newTag: latest
- name: registry.redhat.io/ubi9/ubi
  newTag: latest
EOF
}
