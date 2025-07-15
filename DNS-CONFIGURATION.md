# DNS Configuration for ROSA Web Applications

## Custom Domain Setup: apps.p-ai.net

### OpenShift Cluster Information
- **Cluster Domain**: `apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com`
- **Router Load Balancer**: `a94d59eb4fe914de4b912d26707ec547-e1c41ec5b184e221.elb.us-east-2.amazonaws.com`
- **Router IP Address**: `3.149.48.254`

### Squarespace DNS Configuration

#### Option 1: Wildcard CNAME (Recommended)
```
Type: CNAME
Name: apps
Value: a94d59eb4fe914de4b912d26707ec547-e1c41ec5b184e221.elb.us-east-2.amazonaws.com
TTL: 300 (5 minutes)
```

#### Option 2: Individual A Records (if wildcard not supported)
```
Type: A
Name: angular.apps
Value: 3.149.48.254
TTL: 300

Type: A
Name: django.apps
Value: 3.149.48.254
TTL: 300

Type: A
Name: nodejs.apps
Value: 3.149.48.254
TTL: 300

Type: A
Name: react.apps
Value: 3.149.48.254
TTL: 300

Type: A
Name: vue.apps
Value: 3.149.48.254
TTL: 300
```

### Application URLs (Custom Domain)

| Application | Custom URL | OpenShift Default URL |
|-------------|------------|----------------------|
| **React Frontend** | https://react.apps.p-ai.net | https://react-frontend-ssh-route-react-frontend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com |
| **Angular Frontend** | https://angular.apps.p-ai.net | https://angular-frontend-route-angular-frontend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com |
| **Vue Frontend** | https://vue.apps.p-ai.net | https://vue-frontend-route-vue-frontend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com |
| **Node.js Backend** | https://nodejs.apps.p-ai.net | https://nodejs-backend-route-nodejs-backend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com |
| **Django Backend** | https://django.apps.p-ai.net | https://django-backend-route-django-backend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com |

### Steps to Configure DNS in Squarespace

1. **Log in to Squarespace**
   - Go to your Squarespace account
   - Navigate to Settings → Domains

2. **Access DNS Settings**
   - Click on your domain `p-ai.net`
   - Go to DNS Settings or Advanced Settings

3. **Add DNS Records**
   - Choose Option 1 (CNAME) or Option 2 (A records) from above
   - Save the changes

4. **Wait for Propagation**
   - DNS changes can take 5-60 minutes to propagate
   - Use `nslookup angular.apps.p-ai.net` to test

### Testing the Configuration

After DNS propagation, test each application:

```bash
# Test DNS resolution
nslookup react.apps.p-ai.net
nslookup angular.apps.p-ai.net
nslookup vue.apps.p-ai.net
nslookup nodejs.apps.p-ai.net
nslookup django.apps.p-ai.net

# Test HTTP access
curl -I https://react.apps.p-ai.net
curl -I https://angular.apps.p-ai.net
curl -I https://vue.apps.p-ai.net
curl -I https://nodejs.apps.p-ai.net
curl -I https://django.apps.p-ai.net
```

### Route Configuration Files

The custom routes are defined in these files:
- Angular: `/apps/angular-frontend/route.yaml`
- Vue: `/apps/vue-frontend/route.yaml`  
- React: `/apps/react-frontend/route.yaml`
- Node.js: `/apps/nodejs-backend/route.yaml`
- Django: `/apps/django-backend/route.yaml`

### Security Notes

- All routes use TLS/SSL termination (`edge/Redirect`)
- HTTP requests are automatically redirected to HTTPS
- OpenShift provides SSL certificates for custom domains
- The router load balancer is managed by AWS ELB

### Troubleshooting

If applications are not accessible after DNS configuration:

1. **Check DNS propagation**: Use online DNS checker tools
2. **Verify OpenShift routes**: `oc get routes --all-namespaces`
3. **Check pod status**: `oc get pods --all-namespaces`
4. **Test internal cluster access**: Use OpenShift default URLs
5. **Check router logs**: `oc logs -n openshift-ingress deployment/router-default`

### ArgoCD Access

ArgoCD is accessible at the OpenShift default URL:
- **ArgoCD**: https://openshift-gitops-server-openshift-gitops.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com

To add a custom domain for ArgoCD, add:
```
Type: CNAME
Name: argocd.apps  
Value: a94d59eb4fe914de4b912d26707ec547-e1c41ec5b184e221.elb.us-east-2.amazonaws.com
```

Then create a custom route for ArgoCD in the `openshift-gitops` namespace.
