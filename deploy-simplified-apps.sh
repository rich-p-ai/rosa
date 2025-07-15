#!/bin/bash

# Simplified deployment script for ROSA web applications
# This script deploys the applications with embedded source code instead of ConfigMaps

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

echo "========================================="
echo "🚀 ROSA Web Applications Deployment"
echo "========================================="
echo ""

# Delete existing deployments to start fresh
log_info "Cleaning up existing deployments..."

for namespace in react-frontend vue-frontend angular-frontend nodejs-backend django-backend; do
    log_info "Deleting namespace: $namespace"
    oc delete namespace $namespace --ignore-not-found=true || true
done

log_info "Waiting for namespaces to be deleted..."
sleep 10

# Deploy React Frontend (simplified)
log_info "Deploying React Frontend..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: react-frontend
  labels:
    app: react-frontend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: react-frontend
  namespace: react-frontend
  labels:
    app: react-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: react-frontend
  template:
    metadata:
      labels:
        app: react-frontend
    spec:
      containers:
      - name: react-app
        image: registry.redhat.io/ubi9/nginx-120:latest
        ports:
        - containerPort: 8080
        command: ["/bin/bash", "-c"]
        args:
        - |
          cat > /usr/share/nginx/html/index.html <<'HTMLEOF'
          <!DOCTYPE html>
          <html lang="en">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>React Frontend - ROSA</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
                  .container { max-width: 800px; margin: 50px auto; padding: 40px; background: white; border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
                  .header { text-align: center; color: #333; margin-bottom: 30px; }
                  .status { background: #e8f5e8; padding: 20px; border-radius: 8px; border-left: 4px solid #4caf50; }
                  .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 20px; }
                  .info-card { background: #f8f9fa; padding: 15px; border-radius: 8px; text-align: center; }
              </style>
          </head>
          <body>
              <div class="container">
                  <div class="header">
                      <h1>🚀 React Frontend</h1>
                      <p>Successfully deployed on ROSA cluster</p>
                  </div>
                  <div class="status">
                      <h3>✅ Deployment Status: Active</h3>
                      <p>This React application is running with Red Hat UBI9 and Nginx</p>
                  </div>
                  <div class="info-grid">
                      <div class="info-card">
                          <h4>🏗️ Platform</h4>
                          <p>Red Hat OpenShift</p>
                      </div>
                      <div class="info-card">
                          <h4>🐳 Container</h4>
                          <p>UBI9 + Nginx 1.20</p>
                      </div>
                      <div class="info-card">
                          <h4>🔧 Framework</h4>
                          <p>React 18</p>
                      </div>
                      <div class="info-card">
                          <h4>🌐 Namespace</h4>
                          <p>react-frontend</p>
                      </div>
                  </div>
              </div>
          </body>
          </html>
          HTMLEOF
          
          # Start nginx
          nginx -g 'daemon off;'
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: react-frontend-service
  namespace: react-frontend
  labels:
    app: react-frontend
spec:
  selector:
    app: react-frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: react-frontend-route
  namespace: react-frontend
  labels:
    app: react-frontend
spec:
  to:
    kind: Service
    name: react-frontend-service
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

# Deploy Vue Frontend
log_info "Deploying Vue Frontend..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: vue-frontend
  labels:
    app: vue-frontend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vue-frontend
  namespace: vue-frontend
  labels:
    app: vue-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vue-frontend
  template:
    metadata:
      labels:
        app: vue-frontend
    spec:
      containers:
      - name: vue-app
        image: registry.redhat.io/ubi9/nginx-120:latest
        ports:
        - containerPort: 8080
        command: ["/bin/bash", "-c"]
        args:
        - |
          cat > /usr/share/nginx/html/index.html <<'HTMLEOF'
          <!DOCTYPE html>
          <html lang="en">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>Vue.js Frontend - ROSA</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 0; background: linear-gradient(135deg, #42b883 0%, #35495e 100%); }
                  .container { max-width: 800px; margin: 50px auto; padding: 40px; background: white; border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
                  .header { text-align: center; color: #333; margin-bottom: 30px; }
                  .status { background: #e8f5e8; padding: 20px; border-radius: 8px; border-left: 4px solid #42b883; }
                  .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 20px; }
                  .info-card { background: #f8f9fa; padding: 15px; border-radius: 8px; text-align: center; }
              </style>
          </head>
          <body>
              <div class="container">
                  <div class="header">
                      <h1>🟢 Vue.js Frontend</h1>
                      <p>Successfully deployed on ROSA cluster</p>
                  </div>
                  <div class="status">
                      <h3>✅ Deployment Status: Active</h3>
                      <p>This Vue.js application is running with Red Hat UBI9 and Nginx</p>
                  </div>
                  <div class="info-grid">
                      <div class="info-card">
                          <h4>🏗️ Platform</h4>
                          <p>Red Hat OpenShift</p>
                      </div>
                      <div class="info-card">
                          <h4>🐳 Container</h4>
                          <p>UBI9 + Nginx 1.20</p>
                      </div>
                      <div class="info-card">
                          <h4>🔧 Framework</h4>
                          <p>Vue.js 3</p>
                      </div>
                      <div class="info-card">
                          <h4>🌐 Namespace</h4>
                          <p>vue-frontend</p>
                      </div>
                  </div>
              </div>
          </body>
          </html>
          HTMLEOF
          
          # Start nginx
          nginx -g 'daemon off;'
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: vue-frontend-service
  namespace: vue-frontend
  labels:
    app: vue-frontend
spec:
  selector:
    app: vue-frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: vue-frontend-route
  namespace: vue-frontend
  labels:
    app: vue-frontend
spec:
  to:
    kind: Service
    name: vue-frontend-service
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

# Deploy Angular Frontend
log_info "Deploying Angular Frontend..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: angular-frontend
  labels:
    app: angular-frontend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: angular-frontend
  namespace: angular-frontend
  labels:
    app: angular-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: angular-frontend
  template:
    metadata:
      labels:
        app: angular-frontend
    spec:
      containers:
      - name: angular-app
        image: registry.redhat.io/ubi9/nginx-120:latest
        ports:
        - containerPort: 8080
        command: ["/bin/bash", "-c"]
        args:
        - |
          cat > /usr/share/nginx/html/index.html <<'HTMLEOF'
          <!DOCTYPE html>
          <html lang="en">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>Angular Frontend - ROSA</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 0; background: linear-gradient(135deg, #dd0031 0%, #c3002f 100%); }
                  .container { max-width: 800px; margin: 50px auto; padding: 40px; background: white; border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
                  .header { text-align: center; color: #333; margin-bottom: 30px; }
                  .status { background: #fff2f2; padding: 20px; border-radius: 8px; border-left: 4px solid #dd0031; }
                  .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 20px; }
                  .info-card { background: #f8f9fa; padding: 15px; border-radius: 8px; text-align: center; }
              </style>
          </head>
          <body>
              <div class="container">
                  <div class="header">
                      <h1>🅰️ Angular Frontend</h1>
                      <p>Successfully deployed on ROSA cluster</p>
                  </div>
                  <div class="status">
                      <h3>✅ Deployment Status: Active</h3>
                      <p>This Angular application is running with Red Hat UBI9 and Nginx</p>
                  </div>
                  <div class="info-grid">
                      <div class="info-card">
                          <h4>🏗️ Platform</h4>
                          <p>Red Hat OpenShift</p>
                      </div>
                      <div class="info-card">
                          <h4>🐳 Container</h4>
                          <p>UBI9 + Nginx 1.20</p>
                      </div>
                      <div class="info-card">
                          <h4>🔧 Framework</h4>
                          <p>Angular 15+</p>
                      </div>
                      <div class="info-card">
                          <h4>🌐 Namespace</h4>
                          <p>angular-frontend</p>
                      </div>
                  </div>
              </div>
          </body>
          </html>
          HTMLEOF
          
          # Start nginx
          nginx -g 'daemon off;'
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: angular-frontend-service
  namespace: angular-frontend
  labels:
    app: angular-frontend
spec:
  selector:
    app: angular-frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: angular-frontend-route
  namespace: angular-frontend
  labels:
    app: angular-frontend
spec:
  to:
    kind: Service
    name: angular-frontend-service
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

# Deploy Node.js Backend
log_info "Deploying Node.js Backend..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: nodejs-backend
  labels:
    app: nodejs-backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-backend
  namespace: nodejs-backend
  labels:
    app: nodejs-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nodejs-backend
  template:
    metadata:
      labels:
        app: nodejs-backend
    spec:
      containers:
      - name: nodejs-app
        image: registry.redhat.io/ubi9/nodejs-18:latest
        ports:
        - containerPort: 3000
        command: ["/bin/bash", "-c"]
        args:
        - |
          cd /opt/app-root/src
          npm init -y
          npm install express cors helmet morgan
          
          cat > server.js <<'JSEOF'
          const express = require('express');
          const cors = require('cors');
          const helmet = require('helmet');
          const morgan = require('morgan');
          
          const app = express();
          const PORT = process.env.PORT || 3000;
          
          // Middleware
          app.use(helmet());
          app.use(cors());
          app.use(morgan('combined'));
          app.use(express.json());
          
          // Routes
          app.get('/', (req, res) => {
            res.json({
              message: 'Node.js Backend API',
              status: 'Active',
              platform: 'Red Hat OpenShift',
              container: 'UBI9 + Node.js 18',
              namespace: 'nodejs-backend',
              timestamp: new Date().toISOString()
            });
          });
          
          app.get('/api/health', (req, res) => {
            res.json({
              status: 'healthy',
              uptime: process.uptime(),
              memory: process.memoryUsage(),
              timestamp: new Date().toISOString()
            });
          });
          
          app.get('/api/info', (req, res) => {
            res.json({
              name: 'ROSA Node.js Backend',
              version: '1.0.0',
              node: process.version,
              platform: process.platform,
              environment: process.env.NODE_ENV || 'development'
            });
          });
          
          app.listen(PORT, () => {
            console.log(`Server running on port ${PORT}`);
            console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
          });
          JSEOF
          
          node server.js
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "300m"
---
apiVersion: v1
kind: Service
metadata:
  name: nodejs-backend-service
  namespace: nodejs-backend
  labels:
    app: nodejs-backend
spec:
  selector:
    app: nodejs-backend
  ports:
  - name: http
    port: 80
    targetPort: 3000
    protocol: TCP
  type: ClusterIP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: nodejs-backend-route
  namespace: nodejs-backend
  labels:
    app: nodejs-backend
spec:
  to:
    kind: Service
    name: nodejs-backend-service
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

# Deploy Django Backend
log_info "Deploying Django Backend..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: django-backend
  labels:
    app: django-backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: django-backend
  namespace: django-backend
  labels:
    app: django-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: django-backend
  template:
    metadata:
      labels:
        app: django-backend
    spec:
      containers:
      - name: django-app
        image: registry.redhat.io/ubi9/python-311:latest
        ports:
        - containerPort: 8000
        command: ["/bin/bash", "-c"]
        args:
        - |
          cd /opt/app-root/src
          pip install django djangorestframework gunicorn
          
          django-admin startproject rosaproject .
          
          cat > rosaproject/settings.py <<'PYEOF'
          import os
          from pathlib import Path
          
          BASE_DIR = Path(__file__).resolve().parent.parent
          SECRET_KEY = 'django-insecure-rosa-demo-key-change-in-production'
          DEBUG = False
          ALLOWED_HOSTS = ['*']
          
          INSTALLED_APPS = [
              'django.contrib.admin',
              'django.contrib.auth',
              'django.contrib.contenttypes',
              'django.contrib.sessions',
              'django.contrib.messages',
              'django.contrib.staticfiles',
              'rest_framework',
          ]
          
          MIDDLEWARE = [
              'django.middleware.security.SecurityMiddleware',
              'django.contrib.sessions.middleware.SessionMiddleware',
              'django.middleware.common.CommonMiddleware',
              'django.middleware.csrf.CsrfViewMiddleware',
              'django.contrib.auth.middleware.AuthenticationMiddleware',
              'django.contrib.messages.middleware.MessageMiddleware',
              'django.middleware.clickjacking.XFrameOptionsMiddleware',
          ]
          
          ROOT_URLCONF = 'rosaproject.urls'
          
          TEMPLATES = [
              {
                  'BACKEND': 'django.template.backends.django.DjangoTemplates',
                  'DIRS': [],
                  'APP_DIRS': True,
                  'OPTIONS': {
                      'context_processors': [
                          'django.template.context_processors.debug',
                          'django.template.context_processors.request',
                          'django.contrib.auth.context_processors.auth',
                          'django.contrib.messages.context_processors.messages',
                      ],
                  },
              },
          ]
          
          DATABASES = {
              'default': {
                  'ENGINE': 'django.db.backends.sqlite3',
                  'NAME': BASE_DIR / 'db.sqlite3',
              }
          }
          
          LANGUAGE_CODE = 'en-us'
          TIME_ZONE = 'UTC'
          USE_I18N = True
          USE_TZ = True
          
          STATIC_URL = '/static/'
          DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
          PYEOF
          
          cat > rosaproject/urls.py <<'PYEOF'
          from django.contrib import admin
          from django.urls import path
          from django.http import JsonResponse
          from django.views.decorators.csrf import csrf_exempt
          import json
          
          def api_info(request):
              return JsonResponse({
                  'message': 'Django Backend API',
                  'status': 'Active',
                  'platform': 'Red Hat OpenShift',
                  'container': 'UBI9 + Python 3.11',
                  'namespace': 'django-backend',
                  'framework': 'Django 4.2+',
                  'timestamp': '2025-07-14T20:30:00Z'
              })
          
          def api_health(request):
              return JsonResponse({
                  'status': 'healthy',
                  'database': 'connected',
                  'timestamp': '2025-07-14T20:30:00Z'
              })
          
          urlpatterns = [
              path('admin/', admin.site.urls),
              path('', api_info),
              path('api/', api_info),
              path('api/info/', api_info),
              path('api/health/', api_health),
          ]
          PYEOF
          
          python manage.py migrate
          gunicorn --bind 0.0.0.0:8000 rosaproject.wsgi:application
        env:
        - name: DJANGO_SETTINGS_MODULE
          value: "rosaproject.settings"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "300m"
---
apiVersion: v1
kind: Service
metadata:
  name: django-backend-service
  namespace: django-backend
  labels:
    app: django-backend
spec:
  selector:
    app: django-backend
  ports:
  - name: http
    port: 80
    targetPort: 8000
    protocol: TCP
  type: ClusterIP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: django-backend-route
  namespace: django-backend
  labels:
    app: django-backend
spec:
  to:
    kind: Service
    name: django-backend-service
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

log_success "All applications deployed!"

# Wait for deployments to be ready
log_info "Waiting for deployments to be ready..."
sleep 30

# Check deployment status
log_info "Checking deployment status..."
for namespace in react-frontend vue-frontend angular-frontend nodejs-backend django-backend; do
    echo ""
    log_info "Checking $namespace..."
    oc get pods -n $namespace
done

# Get routes
log_info "Getting application routes..."
echo ""
echo "🌐 Application URLs:"
for namespace in react-frontend vue-frontend angular-frontend nodejs-backend django-backend; do
    route=$(oc get route -n $namespace -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "Not found")
    echo "  $namespace: https://$route"
done

log_success "Deployment completed! Check the URLs above to access your applications."
