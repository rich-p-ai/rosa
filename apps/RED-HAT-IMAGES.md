# Red Hat Images Configuration Guide

## Overview

All applications in this GitOps deployment use Red Hat Universal Base Images (UBI) and certified Red Hat container images for enhanced security, support, and compliance.

## Red Hat Images Used

### Frontend Applications

#### React Frontend
- **Web Server**: `registry.redhat.io/ubi9/nginx-120:latest`
  - Red Hat certified NGINX 1.20 on UBI 9
  - Production-ready with security updates
  - Optimized for OpenShift

- **Build Environment**: `registry.redhat.io/ubi9/nodejs-18:latest`
  - Red Hat certified Node.js 18 on UBI 9
  - Includes npm and development tools
  - Security-hardened base image

#### Vue.js Frontend
- **Web Server**: `registry.redhat.io/ubi9/nginx-120:latest`
- **Build Environment**: `registry.redhat.io/ubi9/nodejs-18:latest`

#### Angular Frontend
- **Web Server**: `registry.redhat.io/ubi9/nginx-120:latest`
- **Build Environment**: `registry.redhat.io/ubi9/nodejs-18:latest`

### Backend Applications

#### Node.js Backend
- **Runtime**: `registry.redhat.io/ubi9/nodejs-18:latest`
  - Full Node.js 18 runtime environment
  - Includes npm, yarn, and development tools
  - Regular security updates from Red Hat

#### Django Backend
- **Runtime**: `registry.redhat.io/ubi9/python-311:latest`
  - Python 3.11 runtime on UBI 9
  - Includes pip and development tools
  - Optimized for web applications

## Red Hat Image Benefits

### 1. Security
- Regular security updates and patches
- Minimal attack surface with UBI base
- CVE scanning and vulnerability management
- FIPS 140-2 compliance available

### 2. Support
- Enterprise support from Red Hat
- Long-term support lifecycle
- Documentation and best practices
- Community and enterprise forums

### 3. Compliance
- Meets enterprise compliance requirements
- Auditable supply chain
- License compliance
- Industry certifications

### 4. Performance
- Optimized for OpenShift/Kubernetes
- Smaller image sizes
- Faster startup times
- Efficient resource utilization

## Image Pull Secrets (if needed)

If your cluster requires authentication to pull Red Hat images:

```yaml
# Create image pull secret
apiVersion: v1
kind: Secret
metadata:
  name: redhat-registry-secret
  namespace: <namespace>
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

Add to deployment:
```yaml
spec:
  template:
    spec:
      imagePullSecrets:
      - name: redhat-registry-secret
```

## Alternative Red Hat Images

### Additional Options

#### Web Servers
- `registry.redhat.io/ubi9/nginx-122:latest` - NGINX 1.22
- `registry.redhat.io/ubi8/nginx-120:latest` - NGINX on UBI 8
- `registry.redhat.io/ubi9/httpd-24:latest` - Apache HTTP Server

#### Runtimes
- `registry.redhat.io/ubi9/nodejs-16:latest` - Node.js 16
- `registry.redhat.io/ubi9/nodejs-20:latest` - Node.js 20
- `registry.redhat.io/ubi9/python-39:latest` - Python 3.9
- `registry.redhat.io/ubi9/python-310:latest` - Python 3.10

#### Databases (if needed)
- `registry.redhat.io/rhel8/postgresql-13:latest`
- `registry.redhat.io/rhel8/mysql-80:latest`
- `registry.redhat.io/rhel8/redis-6:latest`

## Image Update Strategy

### Tagging Strategy
```yaml
# Use specific versions for production
image: registry.redhat.io/ubi9/nodejs-18:1-50

# Use latest for development
image: registry.redhat.io/ubi9/nodejs-18:latest
```

### Update Procedure
1. Test new image versions in development
2. Update GitOps manifests
3. Deploy through GitOps pipeline
4. Monitor application health
5. Rollback if issues occur

## Troubleshooting Red Hat Images

### Common Issues

#### Image Pull Errors
```bash
# Check image availability
podman pull registry.redhat.io/ubi9/nodejs-18:latest

# Verify registry access
oc get events | grep "Failed to pull image"
```

#### Permission Issues
```bash
# Check service account permissions
oc get sa default -o yaml

# Verify image pull secrets
oc get secrets | grep redhat
```

#### Build Failures
```bash
# Check build logs
oc logs <pod-name> -c <container-name>

# Verify package availability
oc exec <pod-name> -- yum list available
```

## Red Hat Registry Information

### Registry URLs
- **Public Registry**: `registry.redhat.io`
- **Partner Registry**: `registry.connect.redhat.com`
- **Certified Registry**: `registry.access.redhat.com`

### Authentication
- Red Hat Customer Portal account required for some images
- OpenShift clusters include pull secrets by default
- Additional authentication may be needed for restricted images

## Best Practices

### 1. Version Pinning
- Use specific image tags in production
- Test image updates in staging first
- Document image version changes

### 2. Security Scanning
- Enable container image scanning
- Monitor CVE reports
- Update images regularly

### 3. Resource Optimization
- Set appropriate resource limits
- Use multi-stage builds when possible
- Minimize image layers

### 4. Monitoring
- Monitor image pull metrics
- Track application performance
- Set up alerts for image pull failures

## Support and Documentation

### Red Hat Resources
- [Red Hat Container Catalog](https://catalog.redhat.com/software/containers/explore)
- [UBI Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/building_running_and_managing_containers/)
- [OpenShift Documentation](https://docs.openshift.com/)

### Community Resources
- [Red Hat Developer](https://developers.redhat.com/)
- [OpenShift Commons](https://commons.openshift.org/)
- [Red Hat Customer Portal](https://access.redhat.com/)
