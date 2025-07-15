# VM Bare Metal Auto-Deployment Guide

This guide provides multiple approaches to automatically deploy a RHEL9 webserver VM when a new bare metal node becomes available.

## Prerequisites

1. OpenShift cluster with KubeVirt installed
2. Bare metal nodes with label `node.kubernetes.io/instance-type=m5.metal`
3. OpenShift Virtualization OS Images (RHEL9 DataSource)
4. Storage class `gp3-csi` available

## Deployment Options

### Option 1: Manual Script (Recommended for testing)

Use the provided shell script for manual or scripted deployment:

```bash
# Make the script executable
chmod +x deploy-vm-on-bare-metal.sh

# Wait for bare metal node and deploy automatically
./deploy-vm-on-bare-metal.sh --wait

# Deploy immediately if bare metal node is available
./deploy-vm-on-bare-metal.sh --deploy

# Check current status
./deploy-vm-on-bare-metal.sh --status

# Monitor VM status
./deploy-vm-on-bare-metal.sh --monitor
```

### Option 2: Kubernetes Job (One-time deployment)

Deploy a Kubernetes Job that waits for bare metal nodes and deploys the VM:

```bash
# Create namespace first
oc apply -f rhel9-webserver-namespace.yaml

# Deploy the job
oc apply -f vm-deployer-job.yaml

# Monitor job progress
oc logs -f job/vm-bare-metal-deployer -n webserver
```

### Option 3: CronJob (Continuous monitoring)

Deploy a CronJob that checks every 5 minutes for bare metal nodes and VM status:

```bash
# Create namespace first
oc apply -f rhel9-webserver-namespace.yaml

# Deploy the cronjob
oc apply -f vm-monitor-cronjob.yaml

# Monitor cronjob
oc get cronjob -n webserver
oc get jobs -n webserver
```

## Files Overview

- `rhel9-webserver-vm-bare-metal.yaml` - VM definition for bare metal deployment
- `rhel9-webserver-namespace.yaml` - Namespace definition
- `rhel9-webserver-service.yaml` - Service and route definitions
- `deploy-vm-on-bare-metal.sh` - Manual deployment script
- `vm-deployer-job.yaml` - One-time deployment job
- `vm-monitor-cronjob.yaml` - Continuous monitoring cronjob

## VM Configuration

The VM is configured with:
- **CPU**: 2 cores, 1 socket, 1 thread
- **Memory**: 4Gi
- **Storage**: 30Gi (gp3-csi)
- **OS**: RHEL9 from DataSource
- **Services**: Apache HTTP Server, Firewall, SSH
- **Node Selector**: `node.kubernetes.io/instance-type=m5.metal`

## Monitoring and Troubleshooting

### Check bare metal nodes
```bash
oc get nodes -l "node.kubernetes.io/instance-type=m5.metal"
```

### Check VM status
```bash
oc get vm -n webserver
oc get vmi -n webserver
```

### Check deployment logs
```bash
# For Job deployment
oc logs job/vm-bare-metal-deployer -n webserver

# For CronJob deployment
oc get jobs -n webserver
oc logs job/<job-name> -n webserver
```

### Access the web server
Once deployed, you can access the web server through:
- NodePort: http://<node-ip>:30080
- Route: Check route details with `oc get route -n webserver`

## Security Notes

- Default VM credentials: admin/redhat123 (change in production)
- SSH access available on port 22 (NodePort 30022)
- Firewall configured to allow HTTP, HTTPS, and SSH

## Customization

To modify the VM configuration:
1. Edit `rhel9-webserver-vm-bare-metal.yaml`
2. Update node selector if using different bare metal node labels
3. Modify cloud-init configuration for different software packages or configurations
4. Adjust resource requests based on your requirements
