# Web Applications Deployment Guide

This guide provides step-by-step instructions for deploying and managing the GitOps web applications on your ROSA cluster.

## 📋 Prerequisites

### 1. Cluster Requirements
- ✅ OpenShift/ROSA cluster with GitOps operator installed
- ✅ Sufficient cluster resources (minimum 4 CPU, 8GB RAM)
- ✅ Storage class available for persistent volumes
- ✅ Ingress/Router configured for external access

### 2. Local Requirements
- ✅ `oc` CLI installed and configured
- ✅ Access to the cluster with project creation permissions
- ✅ Git repository access (for GitOps)

### 3. DNS Configuration
Ensure your domain `*.apps.p-ai.net` is configured to point to your OpenShift router.

## 🚀 Deployment Methods

### Method 1: Script-based Deployment (Recommended)

#### Step 1: Deploy All Applications
```bash
# Navigate to the project directory
cd /Users/richardsawyers/work/rosa

# Make script executable (if not already)
chmod +x deploy-web-apps.sh

# Deploy all applications
./deploy-web-apps.sh deploy
```

#### Step 2: Monitor Deployment
```bash
# Check deployment status
./deploy-web-apps.sh status

# Wait for all applications to be ready
./deploy-web-apps.sh wait
```

#### Step 3: Access Applications
```bash
# Show all application URLs
./deploy-web-apps.sh urls
```

### Method 2: Manual Kustomize Deployment

#### Step 1: Deploy Backend Services First
```bash
# Deploy Node.js backend
oc apply -k apps/nodejs-backend/

# Deploy Django backend
oc apply -k apps/django-backend/
```

#### Step 2: Wait for Backends to be Ready
```bash
# Check Node.js backend
oc rollout status deployment/nodejs-backend -n nodejs-backend

# Check Django backend  
oc rollout status deployment/django-backend -n django-backend
```

#### Step 3: Deploy Frontend Applications
```bash
# Deploy React frontend
oc apply -k apps/react-frontend/

# Deploy Vue.js frontend
oc apply -k apps/vue-frontend/

# Deploy Angular frontend
oc apply -k apps/angular-frontend/
```

### Method 3: ArgoCD GitOps Deployment

#### Step 1: Apply App-of-Apps
```bash
# Deploy the ArgoCD application set
oc apply -k apps/
```

#### Step 2: Monitor in ArgoCD UI
1. Access ArgoCD dashboard
2. Monitor application sync status
3. Check for any sync failures

## 📊 Verification Steps

### 1. Check Pod Status
```bash
# Check all applications
for ns in react-frontend vue-frontend angular-frontend nodejs-backend django-backend; do
  echo "=== $ns ==="
  oc get pods -n $ns
  echo ""
done
```

### 2. Verify Services
```bash
# Check all services
for ns in react-frontend vue-frontend angular-frontend nodejs-backend django-backend; do
  echo "=== $ns Services ==="
  oc get svc -n $ns
  echo ""
done
```

### 3. Test Routes
```bash
# Check all routes
for ns in react-frontend vue-frontend angular-frontend nodejs-backend django-backend; do
  echo "=== $ns Routes ==="
  oc get routes -n $ns
  echo ""
done
```

### 4. Health Check Tests
```bash
# Test backend health endpoints
curl -k https://nodejs.apps.p-ai.net/health
curl -k https://django.apps.p-ai.net/health/

# Test frontend applications
curl -k https://react.apps.p-ai.net/
curl -k https://vue.apps.p-ai.net/
curl -k https://angular.apps.p-ai.net/
```

## 🔧 Configuration Management

### Environment Variables

#### Node.js Backend Configuration
```bash
# View current configuration
oc describe configmap nodejs-config -n nodejs-backend

# Update environment variables
oc patch configmap nodejs-config -n nodejs-backend --patch='
data:
  .env: |
    NODE_ENV=production
    PORT=3000
    LOG_LEVEL=debug
'
```

#### Django Backend Configuration
```bash
# View Django settings
oc describe configmap django-config -n django-backend

# Update Django settings
oc edit configmap django-config -n django-backend
```

### Secrets Management

#### Update Node.js Secrets
```bash
# Create new secret values (base64 encoded)
echo -n "new-database-url" | base64
echo -n "new-jwt-secret" | base64

# Update secrets
oc patch secret nodejs-secrets -n nodejs-backend --patch='
data:
  DATABASE_URL: <base64-encoded-value>
  JWT_SECRET: <base64-encoded-value>
'
```

#### Update Django Secrets
```bash
# Update Django secret key
oc patch secret django-secrets -n django-backend --patch='
data:
  SECRET_KEY: <base64-encoded-django-secret>
'
```

## 📈 Scaling Applications

### Horizontal Scaling

#### Scale Frontend Applications
```bash
# Scale React frontend
oc scale deployment react-frontend --replicas=3 -n react-frontend

# Scale Vue frontend
oc scale deployment vue-frontend --replicas=3 -n vue-frontend

# Scale Angular frontend
oc scale deployment angular-frontend --replicas=3 -n angular-frontend
```

#### Scale Backend Applications
```bash
# Scale Node.js backend
oc scale deployment nodejs-backend --replicas=5 -n nodejs-backend

# Scale Django backend
oc scale deployment django-backend --replicas=4 -n django-backend
```

### Vertical Scaling (Resource Limits)

#### Update Resource Limits
```bash
# Example: Increase Node.js backend resources
oc patch deployment nodejs-backend -n nodejs-backend --patch='
spec:
  template:
    spec:
      containers:
      - name: nodejs-app
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
'
```

## 🔄 Application Updates

### Rolling Updates

#### Update Application Images
```bash
# Update Node.js backend image
oc set image deployment/nodejs-backend nodejs-app=node:18-alpine -n nodejs-backend

# Update frontend base image
oc set image deployment/react-frontend react-app=nginx:alpine -n react-frontend
```

#### Configuration Updates
```bash
# Trigger rolling update after config change
oc rollout restart deployment/nodejs-backend -n nodejs-backend
oc rollout restart deployment/django-backend -n django-backend
```

### Zero-Downtime Deployments
All applications are configured with:
- Rolling update strategy
- Readiness probes
- Multiple replicas
- Graceful shutdown

## 📊 Monitoring and Logging

### Application Logs

#### Stream Live Logs
```bash
# Node.js backend logs
oc logs -f deployment/nodejs-backend -n nodejs-backend

# Django backend logs
oc logs -f deployment/django-backend -n django-backend

# React frontend logs
oc logs -f deployment/react-frontend -n react-frontend
```

#### Aggregate Logs
```bash
# All logs from a namespace
oc logs --selector app=nodejs-backend -n nodejs-backend

# Previous pod logs (if pod restarted)
oc logs deployment/nodejs-backend -n nodejs-backend --previous
```

### Performance Monitoring

#### Resource Usage
```bash
# CPU and memory usage
oc adm top pods -n nodejs-backend
oc adm top pods -n django-backend
oc adm top pods -n react-frontend
```

#### Application Metrics
```bash
# Check application metrics endpoints
curl -k https://nodejs.apps.p-ai.net/metrics
curl -k https://django.apps.p-ai.net/admin/
```

## 🚨 Troubleshooting Guide

### Common Issues and Solutions

#### 1. Pods Not Starting

**Symptoms**: Pods stuck in `Pending` or `CrashLoopBackOff`

**Diagnosis**:
```bash
# Check pod events
oc describe pod <pod-name> -n <namespace>

# Check resource constraints
oc describe nodes
```

**Solutions**:
- Check resource quotas
- Verify image pull secrets
- Check node capacity

#### 2. Build Failures

**Symptoms**: Init containers failing during build

**Diagnosis**:
```bash
# Check init container logs
oc logs <pod-name> -c <init-container-name> -n <namespace>
```

**Solutions**:
- Increase build timeout
- Check network connectivity
- Verify package.json/requirements.txt

#### 3. Service Connectivity Issues

**Symptoms**: Frontend can't reach backend APIs

**Diagnosis**:
```bash
# Test internal connectivity
oc exec -it <frontend-pod> -n <frontend-namespace> -- curl http://nodejs-backend-service.nodejs-backend:3000/health
```

**Solutions**:
- Verify service names and ports
- Check network policies
- Verify CORS configuration

#### 4. Route/Ingress Issues

**Symptoms**: Applications not accessible externally

**Diagnosis**:
```bash
# Check route configuration
oc describe route <route-name> -n <namespace>

# Test router connectivity
curl -k https://<route-host>/
```

**Solutions**:
- Verify DNS configuration
- Check router logs
- Verify TLS certificates

### Emergency Procedures

#### Application Recovery
```bash
# Quick recovery - restart all applications
for ns in react-frontend vue-frontend angular-frontend nodejs-backend django-backend; do
  oc rollout restart deployment -n $ns
done
```

#### Complete Redeployment
```bash
# Clean slate redeployment
./deploy-web-apps.sh cleanup
sleep 30
./deploy-web-apps.sh deploy
```

## 📚 Additional Resources

### Documentation Links
- [OpenShift Documentation](https://docs.openshift.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)

### Monitoring Tools
- OpenShift Console: Application topology view
- ArgoCD Dashboard: GitOps application status
- Prometheus/Grafana: Metrics and dashboards

### Development Tools
- VS Code with Kubernetes extension
- kubectl/oc CLI with bash completion
- Helm for package management

## 🔐 Security Considerations

### Best Practices
- ✅ Use secrets for sensitive data
- ✅ Apply resource limits
- ✅ Enable network policies
- ✅ Regular security updates
- ✅ Monitor for vulnerabilities

### Security Scanning
```bash
# Scan images for vulnerabilities
oc adm must-gather --image=registry.redhat.io/rhel8/support-tools

# Check security context constraints
oc get scc
```

## 📞 Support

For issues with this deployment:

1. **Check application logs** first
2. **Review troubleshooting guide** above
3. **Verify cluster health** and resources
4. **Check network connectivity** between services
5. **Consult OpenShift documentation** for platform issues

## 🎯 Next Steps

After successful deployment:

1. **Set up monitoring** with Prometheus/Grafana
2. **Configure backup** strategies for persistent data
3. **Implement CI/CD** pipelines for automatic deployments
4. **Add database** services for production workloads
5. **Set up SSL certificates** for custom domains
