# GitOps Web Applications

This directory contains 5 modern web applications deployed using GitOps methodology on OpenShift/ROSA cluster.

## 🚀 Applications Overview

| Application | Framework | Type | URL | Description |
|-------------|-----------|------|-----|-------------|
| **React Frontend** | React 18 | Frontend | https://react.apps.p-ai.net | Modern React SPA with Nginx |
| **Vue.js Frontend** | Vue 3 | Frontend | https://vue.apps.p-ai.net | Progressive Vue.js application |
| **Angular Frontend** | Angular 15+ | Frontend | https://angular.apps.p-ai.net | Enterprise Angular application |
| **Node.js Backend** | Express.js | Backend | https://nodejs.apps.p-ai.net | RESTful API with Express |
| **Django Backend** | Django 4.2 | Backend | https://django.apps.p-ai.net | Python web framework with DRF |

## 📁 Directory Structure

```
apps/
├── kustomization.yaml          # GitOps app-of-apps configuration
├── values.yaml                 # Helm values for ArgoCD applications
├── react-frontend/             # React.js application
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── route.yaml
│   └── configmap.yaml
├── vue-frontend/               # Vue.js application
│   └── ... (similar structure)
├── angular-frontend/           # Angular application
│   └── ... (similar structure)
├── nodejs-backend/             # Node.js Express API
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── route.yaml
│   ├── configmap.yaml
│   └── secret.yaml
└── django-backend/             # Django REST API
    ├── kustomization.yaml
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── route.yaml
    ├── configmap.yaml
    ├── secret.yaml
    └── pvc.yaml
```

## 🛠️ GitOps Architecture

### Sync Waves
Applications are deployed in the following order using ArgoCD sync waves:

1. **Wave 5**: Backend Services
   - Node.js Backend
   - Django Backend

2. **Wave 10**: Frontend Applications
   - React Frontend
   - Vue.js Frontend
   - Angular Frontend

### Automated GitOps Features
- ✅ **Auto-sync**: Applications automatically sync when Git repository changes
- ✅ **Self-healing**: Applications automatically recover from configuration drift
- ✅ **Pruning**: Removes resources deleted from Git
- ✅ **Namespace creation**: Automatically creates namespaces if they don't exist

## 🚀 Quick Start

### Container Images

All applications use **Red Hat Universal Base Images (UBI)** and certified Red Hat container images:

#### Frontend Applications
- **Web Server**: `registry.redhat.io/ubi9/nginx-120:latest`
- **Build Environment**: `registry.redhat.io/ubi9/nodejs-18:latest`

#### Backend Applications
- **Node.js**: `registry.redhat.io/ubi9/nodejs-18:latest`
- **Python/Django**: `registry.redhat.io/ubi9/python-311:latest`

#### Benefits of Red Hat Images
- ✅ Enterprise support and security updates
- ✅ CVE scanning and vulnerability management  
- ✅ Optimized for OpenShift/Kubernetes
- ✅ Compliance and audit-ready
- ✅ Long-term support lifecycle

See [RED-HAT-IMAGES.md](RED-HAT-IMAGES.md) for detailed information.

### 1. Deploy All Applications
```bash
./deploy-web-apps.sh deploy
```

### 2. Check Deployment Status
```bash
./deploy-web-apps.sh status
```

### 3. Wait for Applications to be Ready
```bash
./deploy-web-apps.sh wait
```

### 4. View Application URLs
```bash
./deploy-web-apps.sh urls
```

## 📊 Application Details

### Frontend Applications

#### React Frontend
- **Framework**: React 18 with modern hooks
- **Build**: Static build served by Nginx
- **Features**: 
  - Client-side routing
  - API proxy to backend services
  - Production optimized builds
  - Gzip compression

#### Vue.js Frontend
- **Framework**: Vue 3 with Composition API
- **Build**: Vite/Vue CLI build system
- **Features**:
  - Vue Router for SPA routing
  - API integration with backends
  - Security headers
  - Production builds

#### Angular Frontend
- **Framework**: Angular 15+ with TypeScript
- **Build**: Angular CLI with optimization
- **Features**:
  - Angular Router
  - Enterprise-ready architecture
  - Security headers and CSP
  - Lazy loading

### Backend Applications

#### Node.js Backend
- **Framework**: Express.js with modern ES6+
- **Features**:
  - RESTful API endpoints
  - Rate limiting
  - CORS support
  - Security middleware (Helmet)
  - JWT authentication ready
  - Health check endpoints

#### Django Backend
- **Framework**: Django 4.2 with Django REST Framework
- **Features**:
  - Admin interface
  - RESTful API with DRF
  - Database migrations
  - Static/Media file handling
  - CORS configured for frontends
  - Persistent storage for media files

## 🔧 Configuration

### Environment Variables
Each application supports environment-specific configuration:

**Backend Applications**:
- Database URLs (configured via secrets)
- API keys and JWT secrets
- Debug settings
- CORS origins

**Frontend Applications**:
- API endpoints
- Environment detection
- Build optimization flags

### Secrets Management
Sensitive data is stored in Kubernetes secrets:
- `nodejs-secrets`: Database URL, JWT secret, API keys
- `django-secrets`: Secret key, database URL, Redis URL

### Persistent Storage
- Django backend uses PVC for media file storage
- Database data (when using external databases)

## 🌐 Networking

### Internal Communication
- Frontend applications proxy API requests to backend services
- Backend services communicate via internal ClusterIP services
- Cross-origin requests are properly configured

### External Access
- All applications accessible via OpenShift Routes with TLS
- Custom domain: `*.apps.p-ai.net`
- Automatic HTTPS with edge termination

## 📋 Health Checks

All applications include comprehensive health checks:

### Liveness Probes
- HTTP GET requests to health endpoints
- Automatic pod restart on failure

### Readiness Probes
- Ensures applications are ready to serve traffic
- Prevents traffic routing to unhealthy pods

## 🔒 Security Features

### Frontend Security
- Content Security Policy (CSP) headers
- X-Frame-Options for clickjacking protection
- XSS protection headers
- Secure static file serving

### Backend Security
- Rate limiting to prevent abuse
- CORS properly configured
- Security headers via Helmet.js (Node.js)
- Django security middleware
- Secrets stored securely in Kubernetes

## 📈 Scaling and Performance

### Horizontal Scaling
- React Frontend: 2 replicas
- Vue Frontend: 2 replicas  
- Angular Frontend: 2 replicas
- Node.js Backend: 3 replicas
- Django Backend: 2 replicas

### Resource Limits
All applications have appropriate resource requests and limits set for:
- CPU: 50m-1000m
- Memory: 64Mi-2Gi (depending on application)

## 🔍 Monitoring and Logging

### Application Logs
```bash
# View logs for specific application
oc logs -f deployment/react-frontend -n react-frontend
oc logs -f deployment/nodejs-backend -n nodejs-backend
```

### Health Check Endpoints
- Node.js: `GET /health`
- Django: `GET /health/`
- Frontend apps: `GET /` (root path)

## 🛠️ Development Workflow

### 1. Local Development
Each application can be developed locally using standard tools:
- React: `npm start`
- Vue: `npm run serve`
- Angular: `ng serve`
- Node.js: `npm run dev`
- Django: `python manage.py runserver`

### 2. GitOps Deployment
1. Make changes to application code
2. Update container images or configuration
3. Commit changes to Git repository
4. ArgoCD automatically syncs changes
5. Applications update with zero downtime

### 3. Environment Promotion
Applications can be promoted across environments:
- Development → Staging → Production
- Branch-based deployments
- Configuration overlays per environment

## 🚨 Troubleshooting

### Common Issues

#### Application Not Starting
```bash
# Check pod status
oc get pods -n <namespace>

# Check events
oc get events -n <namespace>

# Check logs
oc logs -f deployment/<app-name> -n <namespace>
```

#### Build Failures
```bash
# Check init container logs (for frontend builds)
oc logs <pod-name> -c <init-container-name> -n <namespace>
```

#### Network Issues
```bash
# Test service connectivity
oc exec -it <pod-name> -n <namespace> -- curl http://<service-name>:<port>
```

### Application Recovery
```bash
# Restart deployment
oc rollout restart deployment/<app-name> -n <namespace>

# Scale down and up
oc scale deployment/<app-name> --replicas=0 -n <namespace>
oc scale deployment/<app-name> --replicas=2 -n <namespace>
```

## 📚 References

- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenShift Routes](https://docs.openshift.com/container-platform/4.12/networking/routes/route-configuration.html)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-app`
3. Make changes following GitOps principles
4. Test deployment: `./deploy-web-apps.sh deploy`
5. Submit pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
