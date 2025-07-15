# Quick VM Deployment Guide

## ✅ Bare Metal Resources Cleaned Up
- Machine pool `bare-metal-test` deleted
- All bare metal machines removed
- Quota freed up successfully

## 🚀 Deploy Standard VM Instead

### Option 1: Simple Deployment
```bash
# Deploy the standard VM (recommended)
oc apply -f rhel9-webserver-namespace.yaml
oc apply -f rhel9-webserver-vm.yaml
oc apply -f rhel9-webserver-service.yaml
```

### Option 2: Alternative VM Configurations
Choose from these available VM configurations:
- `rhel9-webserver-vm-simple.yaml` - Minimal configuration
- `rhel9-webserver-vm-clean.yaml` - Clean template
- `rhel9-webserver-vm-emulated.yaml` - Software emulation
- `rhel9-webserver-vm-final.yaml` - Production ready

### Check VM Status
```bash
# Check VM status
oc get vm,vmi -n webserver

# Monitor VM startup
oc get events -n webserver --sort-by='.lastTimestamp'

# Get VM details
oc describe vm rhel9-webserver -n webserver
```

### Access the Web Server
```bash
# Check service
oc get svc -n webserver

# Get route (if created)
oc get route -n webserver

# Port forward for testing
oc port-forward -n webserver svc/rhel9-webserver-http 8080:80
```

### Troubleshooting
```bash
# Check VM logs
oc logs -n webserver deployment/vm-console

# Check virtualization operator status
oc get csv -n openshift-cnv

# Check node resources
oc describe nodes
```

## 💡 Benefits of Standard Deployment
- ✅ No quota constraints
- ✅ Faster provisioning
- ✅ Runs on any worker node
- ✅ Same functionality as bare metal
- ✅ Easier to manage

The standard VM deployment provides the same RHEL9 webserver functionality without requiring bare metal nodes!
