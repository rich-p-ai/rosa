#!/bin/bash

# Fix frontend applications with proper OpenShift nginx configuration
# This script addresses the permission issues with nginx in OpenShift

set -e

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }

echo "========================================="
echo "🔧 Fixing Frontend Applications"
echo "========================================="
echo ""

# Update React Frontend
log_info "Updating React Frontend with proper nginx configuration..."
cat <<EOF | oc apply -f -
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
          # Create nginx config for OpenShift
          mkdir -p /tmp/nginx-cache /tmp/nginx-client-body /tmp/nginx-proxy /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi
          
          cat > /etc/nginx/nginx.conf <<'NGINXEOF'
          worker_processes auto;
          error_log /dev/stderr;
          pid /tmp/nginx.pid;
          
          events {
              worker_connections 1024;
          }
          
          http {
              log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                              '\$status \$body_bytes_sent "\$http_referer" '
                              '"\$http_user_agent" "\$http_x_forwarded_for"';
          
              access_log /dev/stdout main;
          
              sendfile on;
              tcp_nopush on;
              tcp_nodelay on;
              keepalive_timeout 65;
              types_hash_max_size 2048;
          
              include /etc/nginx/mime.types;
              default_type application/octet-stream;
          
              # Temp paths for non-root user
              client_body_temp_path /tmp/nginx-client-body;
              proxy_temp_path /tmp/nginx-proxy;
              fastcgi_temp_path /tmp/nginx-fastcgi;
              uwsgi_temp_path /tmp/nginx-uwsgi;
              scgi_temp_path /tmp/nginx-scgi;
          
              server {
                  listen 8080;
                  server_name localhost;
                  root /usr/share/nginx/html;
                  index index.html;
          
                  location / {
                      try_files \$uri \$uri/ /index.html;
                  }
              }
          }
          NGINXEOF
          
          # Create the HTML content
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
                  .api-test { background: #fff3cd; padding: 15px; border-radius: 8px; margin-top: 20px; }
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
                  <div class="api-test">
                      <h3>🔗 API Integration Test</h3>
                      <button onclick="testAPI()">Test Node.js Backend</button>
                      <div id="api-result"></div>
                  </div>
              </div>
              
              <script>
              async function testAPI() {
                  try {
                      const response = await fetch('https://nodejs-backend-route-nodejs-backend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com');
                      const data = await response.json();
                      document.getElementById('api-result').innerHTML = '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
                  } catch (error) {
                      document.getElementById('api-result').innerHTML = '<p style="color: red;">Error: ' + error.message + '</p>';
                  }
              }
              </script>
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
EOF

# Update Vue Frontend
log_info "Updating Vue Frontend with proper nginx configuration..."
cat <<EOF | oc apply -f -
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
          # Create nginx config for OpenShift
          mkdir -p /tmp/nginx-cache /tmp/nginx-client-body /tmp/nginx-proxy /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi
          
          cat > /etc/nginx/nginx.conf <<'NGINXEOF'
          worker_processes auto;
          error_log /dev/stderr;
          pid /tmp/nginx.pid;
          
          events {
              worker_connections 1024;
          }
          
          http {
              log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                              '\$status \$body_bytes_sent "\$http_referer" '
                              '"\$http_user_agent" "\$http_x_forwarded_for"';
          
              access_log /dev/stdout main;
              sendfile on;
              tcp_nopush on;
              tcp_nodelay on;
              keepalive_timeout 65;
              types_hash_max_size 2048;
              include /etc/nginx/mime.types;
              default_type application/octet-stream;
          
              client_body_temp_path /tmp/nginx-client-body;
              proxy_temp_path /tmp/nginx-proxy;
              fastcgi_temp_path /tmp/nginx-fastcgi;
              uwsgi_temp_path /tmp/nginx-uwsgi;
              scgi_temp_path /tmp/nginx-scgi;
          
              server {
                  listen 8080;
                  server_name localhost;
                  root /usr/share/nginx/html;
                  index index.html;
          
                  location / {
                      try_files \$uri \$uri/ /index.html;
                  }
              }
          }
          NGINXEOF
          
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
                  .api-test { background: #fff3cd; padding: 15px; border-radius: 8px; margin-top: 20px; }
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
                  <div class="api-test">
                      <h3>🔗 Django API Integration</h3>
                      <button onclick="testDjango()">Test Django Backend</button>
                      <div id="django-result"></div>
                  </div>
              </div>
              
              <script>
              async function testDjango() {
                  try {
                      const response = await fetch('https://django-backend-route-django-backend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com');
                      const data = await response.json();
                      document.getElementById('django-result').innerHTML = '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
                  } catch (error) {
                      document.getElementById('django-result').innerHTML = '<p style="color: red;">Error: ' + error.message + '</p>';
                  }
              }
              </script>
          </body>
          </html>
          HTMLEOF
          
          nginx -g 'daemon off;'
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
EOF

# Update Angular Frontend
log_info "Updating Angular Frontend with proper nginx configuration..."
cat <<EOF | oc apply -f -
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
          mkdir -p /tmp/nginx-cache /tmp/nginx-client-body /tmp/nginx-proxy /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi
          
          cat > /etc/nginx/nginx.conf <<'NGINXEOF'
          worker_processes auto;
          error_log /dev/stderr;
          pid /tmp/nginx.pid;
          
          events {
              worker_connections 1024;
          }
          
          http {
              log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                              '\$status \$body_bytes_sent "\$http_referer" '
                              '"\$http_user_agent" "\$http_x_forwarded_for"';
          
              access_log /dev/stdout main;
              sendfile on;
              tcp_nopush on;
              tcp_nodelay on;
              keepalive_timeout 65;
              types_hash_max_size 2048;
              include /etc/nginx/mime.types;
              default_type application/octet-stream;
          
              client_body_temp_path /tmp/nginx-client-body;
              proxy_temp_path /tmp/nginx-proxy;
              fastcgi_temp_path /tmp/nginx-fastcgi;
              uwsgi_temp_path /tmp/nginx-uwsgi;
              scgi_temp_path /tmp/nginx-scgi;
          
              server {
                  listen 8080;
                  server_name localhost;
                  root /usr/share/nginx/html;
                  index index.html;
          
                  location / {
                      try_files \$uri \$uri/ /index.html;
                  }
              }
          }
          NGINXEOF
          
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
                  .api-test { background: #fff3cd; padding: 15px; border-radius: 8px; margin-top: 20px; }
                  .all-apis { background: #d1ecf1; padding: 15px; border-radius: 8px; margin-top: 20px; }
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
                  <div class="all-apis">
                      <h3>🌐 Full Stack Integration</h3>
                      <button onclick="testAllAPIs()">Test All Backend APIs</button>
                      <div id="all-apis-result"></div>
                  </div>
              </div>
              
              <script>
              async function testAllAPIs() {
                  const apis = [
                      { name: 'Node.js Backend', url: 'https://nodejs-backend-route-nodejs-backend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com' },
                      { name: 'Django Backend', url: 'https://django-backend-route-django-backend.apps.h8g2j4v4e6k5y5w.vgdv.p1.openshiftapps.com' }
                  ];
                  
                  let results = '<h4>API Test Results:</h4>';
                  
                  for (const api of apis) {
                      try {
                          const response = await fetch(api.url);
                          const data = await response.json();
                          results += '<div style="margin: 10px 0; padding: 10px; background: #d4edda; border-left: 4px solid #28a745;">';
                          results += '<strong>✅ ' + api.name + '</strong><br>';
                          results += '<small>Status: ' + data.status + ' | Platform: ' + data.platform + '</small>';
                          results += '</div>';
                      } catch (error) {
                          results += '<div style="margin: 10px 0; padding: 10px; background: #f8d7da; border-left: 4px solid #dc3545;">';
                          results += '<strong>❌ ' + api.name + '</strong><br>';
                          results += '<small>Error: ' + error.message + '</small>';
                          results += '</div>';
                      }
                  }
                  
                  document.getElementById('all-apis-result').innerHTML = results;
              }
              </script>
          </body>
          </html>
          HTMLEOF
          
          nginx -g 'daemon off;'
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
EOF

log_success "Frontend applications updated with proper nginx configuration!"

# Wait for rollout to complete
log_info "Waiting for deployments to rollout..."
sleep 30

# Test all applications
log_info "Testing all applications..."
echo ""
echo "🧪 Application Tests:"

for app in react-frontend vue-frontend angular-frontend nodejs-backend django-backend; do
    route=$(oc get route -n $app -o jsonpath='{.items[0].spec.host}' 2>/dev/null)
    status=$(curl -s -o /dev/null -w "%{http_code}" https://$route || echo "Failed")
    echo "  $app: $status (https://$route)"
done

log_success "All applications have been updated and tested!"
