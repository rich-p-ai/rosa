# SSH Access Guide for ROSA Web Applications

## Overview

All five web applications now include SSH access capabilities that allow developers to remotely edit application files in real-time. Each application has a dedicated SSH service container running alongside the main application.

## SSH Services Architecture

### Application Structure
```
┌─────────────────────────────────────────────────┐
│                ROSA Cluster                     │
├─────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐              │
│  │   Web App   │  │  SSH Server │              │
│  │ Container   │  │ Container   │              │
│  │             │  │             │              │
│  │ Port: 80/443│  │ Port: 22    │              │
│  └─────────────┘  └─────────────┘              │
│        │                 │                     │
│  ┌─────────────┐  ┌─────────────┐              │
│  │   Service   │  │SSH Service  │              │
│  │             │  │             │              │
│  └─────────────┘  └─────────────┘              │
│        │                 │                     │
│  ┌─────────────┐  ┌─────────────┐              │
│  │    Route    │  │ SSH Route   │              │
│  │             │  │             │              │
│  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────┘
```

## SSH Access Information

### Frontend Applications

#### React Frontend
- **Service**: `react-frontend-ssh-service.react-frontend.svc.cluster.local`
- **Username**: `developer`
- **Password**: `ReactDev@2024`
- **Workspace**: `/home/developer/workspace/src`
- **Editable Files**:
  - `App.js` - Main React component
  - `index.html` - HTML template
  - `styles.css` - CSS styles

#### Vue.js Frontend
- **Service**: `vue-frontend-ssh-service.vue-frontend.svc.cluster.local`
- **Username**: `developer`
- **Password**: `VueDev@2024`
- **Workspace**: `/home/developer/workspace/src`
- **Editable Files**:
  - `App.vue` - Main Vue component
  - `index.html` - HTML template
  - `styles.css` - CSS styles

#### Angular Frontend
- **Service**: `angular-frontend-ssh-service.angular-frontend.svc.cluster.local`
- **Username**: `developer`
- **Password**: `AngularDev@2024`
- **Workspace**: `/home/developer/workspace/src`
- **Editable Files**:
  - `app.component.ts` - Main Angular component
  - `index.html` - HTML template
  - `styles.css` - CSS styles

### Backend Applications

#### Node.js Backend
- **Service**: `nodejs-backend-ssh-service.nodejs-backend.svc.cluster.local`
- **Username**: `developer`
- **Password**: `NodeDev@2024`
- **Workspace**: `/home/developer/workspace/src`
- **Editable Files**:
  - `app.js` - Main Express application
  - `package.json` - Project configuration
  - `routes/api.js` - API routes
  - `README.md` - Documentation

#### Django Backend
- **Service**: `django-backend-ssh-service.django-backend.svc.cluster.local`
- **Username**: `developer`
- **Password**: `DjangoDev@2024`
- **Workspace**: `/home/developer/workspace/src`
- **Editable Files**:
  - `settings.py` - Django configuration
  - `views.py` - API views and logic
  - `urls.py` - URL routing
  - `requirements.txt` - Python dependencies

## Connection Methods

### Method 1: Direct SSH via Routes

Get the SSH route for any application:
```bash
# Check available SSH routes
oc get routes -A | grep ssh

# Get specific route
oc get route react-frontend-ssh-route -n react-frontend -o jsonpath='{.spec.host}'
```

Connect via SSH:
```bash
# Example for React frontend
ssh developer@<route-host> -p 22

# With password authentication
ssh -o PreferredAuthentications=password developer@<route-host> -p 22
```

### Method 2: Port Forwarding

If routes are not directly accessible, use port forwarding:

```bash
# React Frontend
oc port-forward -n react-frontend svc/react-frontend-ssh-service 2201:22
ssh developer@localhost -p 2201

# Vue Frontend
oc port-forward -n vue-frontend svc/vue-frontend-ssh-service 2202:22
ssh developer@localhost -p 2202

# Angular Frontend
oc port-forward -n angular-frontend svc/angular-frontend-ssh-service 2203:22
ssh developer@localhost -p 2203

# Node.js Backend
oc port-forward -n nodejs-backend svc/nodejs-backend-ssh-service 2204:22
ssh developer@localhost -p 2204

# Django Backend
oc port-forward -n django-backend svc/django-backend-ssh-service 2205:22
ssh developer@localhost -p 2205
```

### Method 3: Cluster Internal Access

From within the cluster (e.g., from another pod):
```bash
# Direct service access
ssh developer@react-frontend-ssh-service.react-frontend.svc.cluster.local -p 22
ssh developer@vue-frontend-ssh-service.vue-frontend.svc.cluster.local -p 22
ssh developer@angular-frontend-ssh-service.angular-frontend.svc.cluster.local -p 22
ssh developer@nodejs-backend-ssh-service.nodejs-backend.svc.cluster.local -p 22
ssh developer@django-backend-ssh-service.django-backend.svc.cluster.local -p 22
```

## Testing SSH Access

Use the provided testing script:
```bash
# Run comprehensive SSH tests
./test-ssh-access.sh

# Check only service status
./test-ssh-access.sh check

# Get route information
./test-ssh-access.sh routes

# Test connectivity
./test-ssh-access.sh test

# Show instructions
./test-ssh-access.sh instructions

# Setup port forwarding
./test-ssh-access.sh port-forward
```

## Development Workflow

### 1. Connect to SSH Service
```bash
# Example: Connect to React frontend
ssh developer@<react-ssh-route> -p 22
# Enter password: ReactDev@2024
```

### 2. Navigate to Workspace
```bash
cd /home/developer/workspace/src
ls -la
```

### 3. Edit Files
```bash
# Edit with vim
vim App.js

# Edit with nano
nano index.html

# View files
cat styles.css
```

### 4. Available Tools
- **Text Editors**: vim, nano
- **Development**: git, curl, wget
- **Package Managers**: dnf (system), pip (Python), npm (Node.js)
- **System**: sudo access for developer user

### 5. File Persistence
- Files in `/home/developer/workspace/` persist during container lifetime
- Changes are lost when pods restart
- For permanent changes, update the GitOps manifests

## Security Features

### SSH Configuration
- Password authentication enabled
- Public key authentication supported
- Root login disabled
- Non-privileged user (`developer`) with sudo access

### Container Security
- Red Hat UBI base images
- Minimal attack surface
- Resource limits applied
- Security contexts configured

### Network Security
- ClusterIP services (internal access)
- OpenShift Routes with TLS termination
- Network policies can be applied

## Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check pod status
   oc get pods -n <namespace> -l app=<app>-ssh
   
   # Check service
   oc get svc -n <namespace> <app>-ssh-service
   
   # Check route
   oc get route -n <namespace> <app>-ssh-route
   ```

2. **Authentication Failed**
   - Verify password from secret: `oc get secret <app>-ssh-secret -n <namespace> -o yaml`
   - Use correct username: `developer`
   - Try forcing password auth: `ssh -o PreferredAuthentications=password`

3. **Route Not Accessible**
   - Use port forwarding as alternative
   - Check OpenShift router configuration
   - Verify network connectivity

### Debugging Commands

```bash
# Check SSH deployment logs
oc logs -n <namespace> deployment/<app>-ssh

# Describe SSH service
oc describe svc -n <namespace> <app>-ssh-service

# Check pod events
oc describe pod -n <namespace> -l app=<app>-ssh

# Test internal connectivity
oc run test-pod --image=registry.redhat.io/ubi9/ubi:latest --rm -it -- /bin/bash
# From inside: telnet <service-name>.<namespace>.svc.cluster.local 22
```

## GitOps Integration

### ArgoCD Sync Waves
- **Wave 10**: SSH Secrets
- **Wave 15**: SSH Deployments, Services, Routes

### Kustomization Structure
Each application includes:
```yaml
resources:
- ssh-secret.yaml
- ssh-deployment.yaml
- ssh-service.yaml
- ssh-route.yaml
```

### Deployment Commands

```bash
# Deploy all applications with SSH access
oc apply -k apps/

# Deploy specific application
oc apply -k apps/react-frontend/

# Check ArgoCD sync status
oc get applications -n openshift-gitops
```

## Best Practices

1. **Password Management**
   - Change default passwords in production
   - Use strong, unique passwords
   - Consider SSH key authentication for enhanced security

2. **Access Control**
   - Limit SSH access to authorized users
   - Monitor SSH sessions and logs
   - Implement network policies if needed

3. **Development Workflow**
   - Make small, incremental changes
   - Test changes before committing
   - Use version control for important modifications

4. **Security**
   - Regular security updates for base images
   - Monitor for vulnerabilities
   - Rotate SSH credentials periodically

## Integration with Main Applications

The SSH services run as sidecar containers and don't interfere with the main application functionality. Both the web application and SSH service can run simultaneously, allowing for:

- Real-time editing without downtime
- Debugging and troubleshooting
- Live configuration changes
- Development and testing

This setup provides a powerful development environment while maintaining the production-ready nature of the applications.
