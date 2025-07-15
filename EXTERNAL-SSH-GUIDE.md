# 🚀 External SSH Access Guide for ROSA Applications

## Overview

This guide provides instructions for developers to access ROSA web applications via SSH using simple IP addresses or DNS names through AWS Network Load Balancer (NLB). This setup is designed to scale for 200+ VMs with easy PuTTY access.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet                                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              AWS Network Load Balancer                     │
│         ssh.yourdomain.com (Squarespace DNS)               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Port 2201 → React Frontend SSH                    │   │
│  │  Port 2202 → Vue.js Frontend SSH                   │   │
│  │  Port 2203 → Angular Frontend SSH                  │   │
│  │  Port 2204 → Node.js Backend SSH                   │   │
│  │  Port 2205 → Django Backend SSH                    │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 ROSA Cluster                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  Worker     │  │  Worker     │  │  Worker     │        │
│  │  Node 1     │  │  Node 2     │  │  Node 3     │        │
│  │             │  │             │  │             │        │
│  │ NodePort    │  │ NodePort    │  │ NodePort    │        │
│  │ Services    │  │ Services    │  │ Services    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│         │                 │                 │             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ SSH Server  │  │ SSH Server  │  │ SSH Server  │        │
│  │ Containers  │  │ Containers  │  │ Containers  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## 🔌 Connection Details

### SSH Access Ports
- **React Frontend**: Port 2201
- **Vue.js Frontend**: Port 2202  
- **Angular Frontend**: Port 2203
- **Node.js Backend**: Port 2204
- **Django Backend**: Port 2205

### Connection Information
- **Username**: `developer`
- **Authentication**: Password
- **DNS**: `ssh.yourdomain.com` (or use direct NLB DNS)

### Application Passwords
- **React Frontend**: `ReactDev@2024`
- **Vue.js Frontend**: `VueDev@2024`
- **Angular Frontend**: `AngularDev@2024`
- **Node.js Backend**: `NodeDev@2024`
- **Django Backend**: `DjangoDev@2024`

## 💻 Developer Access Methods

### Option 1: Using Single DNS with Different Ports (Recommended)

```bash
# React Frontend Development
ssh developer@ssh.yourdomain.com -p 2201

# Vue.js Frontend Development  
ssh developer@ssh.yourdomain.com -p 2202

# Angular Frontend Development
ssh developer@ssh.yourdomain.com -p 2203

# Node.js Backend Development
ssh developer@ssh.yourdomain.com -p 2204

# Django Backend Development
ssh developer@ssh.yourdomain.com -p 2205
```

### Option 2: Using Application-Specific DNS

```bash
# If you set up individual CNAME records
ssh developer@ssh-react.yourdomain.com -p 2201
ssh developer@ssh-vue.yourdomain.com -p 2202
ssh developer@ssh-angular.yourdomain.com -p 2203
ssh developer@ssh-nodejs.yourdomain.com -p 2204
ssh developer@ssh-django.yourdomain.com -p 2205
```

### Option 3: Direct NLB DNS (Fallback)

```bash
# If DNS isn't configured yet, use direct NLB address
ssh developer@rosa-ssh-nlb-1234567890.elb.us-east-1.amazonaws.com -p 2201
```

## 🖥️ PuTTY Configuration

### Basic Setup
1. **Open PuTTY**
2. **Session Configuration**:
   - Host Name: `ssh.yourdomain.com`
   - Port: `2201` (or appropriate port for your application)
   - Connection Type: `SSH`

3. **Authentication**:
   - Go to Connection → SSH → Auth
   - Check "Allow agent forwarding" if needed
   - Username: `developer`

4. **Save Session**:
   - Return to Session tab
   - Saved Sessions: `ROSA-React-Frontend` (or appropriate name)
   - Click "Save"

### Pre-configured Sessions

Create these saved sessions in PuTTY:

| Session Name | Host | Port | Description |
|-------------|------|------|-------------|
| ROSA-React | ssh.yourdomain.com | 2201 | React Frontend |
| ROSA-Vue | ssh.yourdomain.com | 2202 | Vue.js Frontend |
| ROSA-Angular | ssh.yourdomain.com | 2203 | Angular Frontend |
| ROSA-NodeJS | ssh.yourdomain.com | 2204 | Node.js Backend |
| ROSA-Django | ssh.yourdomain.com | 2205 | Django Backend |

### Connection Script for Windows

Create a batch file `connect-rosa.bat`:

```batch
@echo off
echo ROSA SSH Access Menu
echo.
echo 1. React Frontend (Port 2201)
echo 2. Vue.js Frontend (Port 2202)  
echo 3. Angular Frontend (Port 2203)
echo 4. Node.js Backend (Port 2204)
echo 5. Django Backend (Port 2205)
echo.
set /p choice="Select application (1-5): "

if "%choice%"=="1" putty -ssh ssh.yourdomain.com -P 2201 -l developer
if "%choice%"=="2" putty -ssh ssh.yourdomain.com -P 2202 -l developer
if "%choice%"=="3" putty -ssh ssh.yourdomain.com -P 2203 -l developer
if "%choice%"=="4" putty -ssh ssh.yourdomain.com -P 2204 -l developer
if "%choice%"=="5" putty -ssh ssh.yourdomain.com -P 2205 -l developer
```

## 📁 Development Workspace

### File Locations

After connecting via SSH, all editable files are located in:
```
/home/developer/workspace/src/
```

### Available Files by Application

#### React Frontend (`ssh ... -p 2201`)
```
/home/developer/workspace/src/
├── App.js              # Main React component
├── index.html          # HTML template  
├── styles.css          # CSS styles
└── README.md           # Documentation
```

#### Vue.js Frontend (`ssh ... -p 2202`)
```
/home/developer/workspace/src/
├── App.vue             # Main Vue component
├── index.html          # HTML template
├── styles.css          # CSS styles
└── README.md           # Documentation
```

#### Angular Frontend (`ssh ... -p 2203`)
```
/home/developer/workspace/src/
├── app.component.ts    # Main Angular component
├── index.html          # HTML template
├── styles.css          # CSS styles
└── README.md           # Documentation
```

#### Node.js Backend (`ssh ... -p 2204`)
```
/home/developer/workspace/src/
├── app.js              # Main Express application
├── package.json        # Project configuration
├── routes/
│   └── api.js          # API routes
└── README.md           # Documentation
```

#### Django Backend (`ssh ... -p 2205`)
```
/home/developer/workspace/src/
├── settings.py         # Django configuration
├── views.py            # API views and logic
├── urls.py             # URL routing
├── requirements.txt    # Python dependencies
└── README.md           # Documentation
```

## 🛠️ Development Tools

### Available Editors
- **vim**: `vim filename`
- **nano**: `nano filename`

### Available Tools
- **git**: Version control
- **curl**: HTTP client
- **wget**: File downloader
- **sudo**: Administrative access (developer user has sudo privileges)

### Package Managers
- **dnf**: System packages (RHEL UBI)
- **pip**: Python packages (Django backend)
- **npm**: Node.js packages (Node.js backend)

## 🔄 Development Workflow

### 1. Connect to Application
```bash
ssh developer@ssh.yourdomain.com -p 2201  # React example
# Enter password: ReactDev@2024
```

### 2. Navigate to Workspace
```bash
cd /home/developer/workspace/src
ls -la
```

### 3. Edit Files
```bash
# Edit main application file
vim App.js          # React
vim App.vue         # Vue.js  
vim app.component.ts # Angular
vim app.js          # Node.js
vim views.py        # Django
```

### 4. View Changes
Changes are visible immediately in the running application (depending on the application's hot-reload capabilities).

### 5. Save and Commit
```bash
# If git is configured
git add .
git commit -m "Updated application via SSH"
```

## 🌐 DNS Configuration (Admin Only)

### Squarespace DNS Setup

Add these CNAME records in Squarespace DNS settings:

```
Host: ssh             Record Type: CNAME    Data: rosa-ssh-nlb-xyz.elb.us-east-1.amazonaws.com
Host: ssh-react       Record Type: CNAME    Data: rosa-ssh-nlb-xyz.elb.us-east-1.amazonaws.com
Host: ssh-vue         Record Type: CNAME    Data: rosa-ssh-nlb-xyz.elb.us-east-1.amazonaws.com
Host: ssh-angular     Record Type: CNAME    Data: rosa-ssh-nlb-xyz.elb.us-east-1.amazonaws.com
Host: ssh-nodejs      Record Type: CNAME    Data: rosa-ssh-nlb-xyz.elb.us-east-1.amazonaws.com
Host: ssh-django      Record Type: CNAME    Data: rosa-ssh-nlb-xyz.elb.us-east-1.amazonaws.com
```

### Route 53 Setup (Alternative)

If using Route 53 instead of Squarespace:

```bash
# Create hosted zone
aws route53 create-hosted-zone --name yourdomain.com --caller-reference $(date +%s)

# Add CNAME records
aws route53 change-resource-record-sets --hosted-zone-id Z123456789 --change-batch file://dns-records.json
```

## 🔐 Security Considerations

### Password Security
- **Change Default Passwords**: Update passwords in production
- **Use Strong Passwords**: 12+ characters with mixed case, numbers, symbols
- **Regular Rotation**: Change passwords quarterly

### Access Control
- **VPN Integration**: Consider adding VPN access for additional security
- **IP Whitelisting**: Restrict access to known developer IPs
- **Multi-Factor Authentication**: Implement MFA for sensitive environments

### Monitoring
- **SSH Session Logging**: Monitor SSH access and usage
- **Failed Login Alerts**: Set up alerts for failed authentication attempts
- **Regular Audits**: Review access logs periodically

## 🚨 Troubleshooting

### Connection Issues

#### Cannot Connect to Host
```bash
# Test DNS resolution
nslookup ssh.yourdomain.com

# Test port connectivity  
telnet ssh.yourdomain.com 2201

# Check from different network
```

#### Authentication Failed
- Verify username: `developer`
- Check password for specific application
- Try different application port to isolate issue

#### Port Not Responding
- Check if specific application is running
- Verify NLB target health in AWS console
- Contact cluster administrator

### Common Solutions

#### DNS Not Resolving
1. Wait for DNS propagation (up to 24 hours)
2. Try direct NLB DNS name as fallback
3. Clear local DNS cache: `ipconfig /flushdns` (Windows)

#### Connection Timeout
1. Check network firewall settings
2. Verify corporate proxy configuration
3. Try from different network/location

#### SSH Key Errors
This setup uses password authentication, so SSH key errors can be ignored:
```bash
ssh -o PreferredAuthentications=password developer@ssh.yourdomain.com -p 2201
```

## 📞 Support

### Self-Service Checks
1. **Test Basic Connectivity**: `telnet ssh.yourdomain.com <port>`
2. **Verify DNS**: `nslookup ssh.yourdomain.com`
3. **Check Port**: Ensure using correct port for your application
4. **Confirm Password**: Verify application-specific password

### Escalation Process
1. **Level 1**: Check this documentation
2. **Level 2**: Contact your team lead
3. **Level 3**: Submit infrastructure ticket
4. **Level 4**: Contact ROSA administrator

### Information to Provide
- Application name (React, Vue, Angular, Node.js, Django)
- Port number attempted
- Error message received
- Your IP address/location
- Time of attempted connection

## 📈 Scaling for 200+ VMs

### Port Range Planning
- **Current**: Ports 2201-2205 (5 applications)
- **Future**: Ports 2206-2405 (200 additional VMs)
- **Reserved**: Ports 2406-2500 (future expansion)

### DNS Strategy
Option 1: **Port-based** (recommended)
```
ssh.yourdomain.com:2201 → VM1
ssh.yourdomain.com:2202 → VM2
...
ssh.yourdomain.com:2405 → VM200
```

Option 2: **Subdomain-based**
```
vm001.ssh.yourdomain.com:22 → VM1
vm002.ssh.yourdomain.com:22 → VM2
...
vm200.ssh.yourdomain.com:22 → VM200
```

### Management Tools
- **Connection Manager**: Scripts for easy VM selection
- **Health Monitoring**: Automated connectivity testing
- **Bulk Operations**: Deploy/update multiple VMs simultaneously

This guide provides your developers with everything they need for simple, reliable SSH access to ROSA applications using familiar tools like PuTTY and standard SSH clients.
