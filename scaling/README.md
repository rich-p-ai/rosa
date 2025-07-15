# 🚀 ROSA VM Scaling Solution: 5 Apps to 200+ VMs

A comprehensive GitOps-based solution for scaling Red Hat OpenShift Service on AWS (ROSA) from 5 web applications to 200+ virtual machines with external SSH access via AWS Network Load Balancers.

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Scaling Strategy](#scaling-strategy)
- [Management Tools](#management-tools)
- [External Access](#external-access)
- [Cost Analysis](#cost-analysis)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## 🌟 Overview

This solution provides:

✅ **Seamless Scaling** - From 5 applications to 200+ VMs using the same architecture  
✅ **External SSH Access** - Simple IP/DNS-based SSH connectivity for developers  
✅ **GitOps Deployment** - ArgoCD-managed infrastructure as code  
✅ **Red Hat Images** - UBI9-based containers for enterprise compliance  
✅ **AWS Integration** - Network Load Balancer for external routing  
✅ **Cost Optimization** - Efficient port allocation and NLB management  

## 🚀 Quick Start

### 1. Deploy Your First VM Cluster

```bash
# Deploy 10 VMs with external SSH access
./scaling/deploy-vm-cluster.sh --vms 10 --domain yourdomain.com

# Interactive management interface
./scaling/manage-vms.sh
```

### 2. Monitor Your Deployment

```bash
# Check VM status
./scaling/monitor-vms.sh

# Run demo scaling simulation
./scaling/demo-scaling.sh
```

### 3. Scale Infrastructure

```bash
# Create additional NLBs for more VMs
./scaling/scale-nlb.sh --action create --nlb-count 4 --domain yourdomain.com
```

## 🏗️ Architecture

### Current Foundation (5 Applications)

Your existing setup includes:
- **React Frontend** (Port 2201)
- **Vue.js Frontend** (Port 2202)  
- **Angular Frontend** (Port 2203)
- **Node.js Backend** (Port 2204)
- **Django Backend** (Port 2205)

### Scaling Architecture (200+ VMs)

```
Internet
    │
AWS Network Load Balancer(s)
    │
┌───┴─────────────────────────────────────┐
│  NLB-1: ssh.domain.com:2201-2250       │
│  NLB-2: ssh2.domain.com:2201-2250      │  
│  NLB-3: ssh3.domain.com:2201-2250      │
│  NLB-4: ssh4.domain.com:2201-2250      │
└───┬─────────────────────────────────────┘
    │
ROSA Cluster (OpenShift)
    │
┌───┴─────────────────────────────────────┐
│  VM-01, VM-02, VM-03... VM-200          │
│  Each with SSH Sidecar Container        │
│  Red Hat UBI9 Base Images               │
└─────────────────────────────────────────┘
```

### VM Types Supported

- **Frontend** - React/Vue/Angular with Nginx + Node.js
- **Backend** - Node.js Express API or Python Django
- **Fullstack** - Combined frontend + backend
- **Minimal** - Basic development containers

## 📈 Scaling Strategy

### Phase 1: Small Scale (6-50 VMs)
- **Approach**: Extend current NLB
- **Ports**: 2206-2250
- **Cost**: ~$25/month
- **Management**: Manual deployment

### Phase 2: Medium Scale (51-100 VMs)
- **Approach**: Multi-NLB architecture
- **Ports**: 2201-2250 per NLB
- **Cost**: ~$50/month
- **Management**: Automated scripts

### Phase 3: Large Scale (101-200 VMs)
- **Approach**: Regional NLB clusters
- **Ports**: 4 NLBs × 50 ports each
- **Cost**: ~$90/month
- **Management**: Infrastructure as Code

### Phase 4: Enterprise Scale (200+ VMs)
- **Approach**: Multi-region deployment
- **Ports**: Geographic distribution
- **Cost**: $130+/month
- **Management**: Full automation

## 🛠️ Management Tools

### Interactive Management Interface

```bash
./scaling/manage-vms.sh
```

Features:
- 📊 VM Status Dashboard
- 🛠️ VM Deployment (Single & Bulk)
- 🌐 NLB Management
- 📋 Report Generation
- 🧹 Cleanup & Maintenance

### Command-Line Tools

| Script | Purpose | Example |
|--------|---------|---------|
| `create-vm.sh` | Deploy single VM | `./create-vm.sh --name my-app --type frontend` |
| `deploy-vm-cluster.sh` | Deploy multiple VMs | `./deploy-vm-cluster.sh --vms 50 --domain example.com` |
| `scale-nlb.sh` | Manage NLB infrastructure | `./scale-nlb.sh --action create --nlb-count 4` |
| `monitor-vms.sh` | Monitor VM status | `./monitor-vms.sh` |
| `demo-scaling.sh` | Scaling demonstration | `./demo-scaling.sh` |

## 🌐 External Access

### SSH Connection Examples

```bash
# Original applications
ssh developer@ssh.yourdomain.com:2201  # React Frontend
ssh developer@ssh.yourdomain.com:2202  # Vue Frontend
ssh developer@ssh.yourdomain.com:2203  # Angular Frontend
ssh developer@ssh.yourdomain.com:2204  # Node.js Backend
ssh developer@ssh.yourdomain.com:2205  # Django Backend

# Additional VMs
ssh developer@ssh.yourdomain.com:2206   # VM-01
ssh developer@ssh.yourdomain.com:2207   # VM-02
ssh developer@ssh2.yourdomain.com:2201  # VM-51 (on second NLB)
```

### DNS Configuration

For Squarespace or other DNS providers:

```dns
ssh.yourdomain.com    CNAME  nlb-123abc.elb.us-east-1.amazonaws.com
ssh2.yourdomain.com   CNAME  nlb-456def.elb.us-east-1.amazonaws.com
ssh3.yourdomain.com   CNAME  nlb-789ghi.elb.us-east-1.amazonaws.com
ssh4.yourdomain.com   CNAME  nlb-012jkl.elb.us-east-1.amazonaws.com
```

### Authentication

- **Username**: `developer`
- **Password**: `{VMName}Dev@2024` (e.g., `Vm-01Dev@2024`)
- **Sudo Access**: Full sudo privileges for development

## 💰 Cost Analysis

### AWS Network Load Balancer Pricing (US-East-1)

| Scale | VMs | NLBs | Base Cost | Data Processing | Total/Month |
|-------|-----|------|-----------|----------------|-------------|
| Small | 5-50 | 1 | $22.50 | ~$2-5 | ~$25-30 |
| Medium | 51-100 | 2 | $45.00 | ~$5-10 | ~$50-55 |
| Large | 101-200 | 4 | $90.00 | ~$10-20 | ~$100-110 |
| Enterprise | 200+ | 6+ | $135+ | ~$20+ | ~$155+ |

### Cost Optimization Tips

1. **Consolidate Ports**: Use fewer NLBs with more ports per NLB
2. **Regional Planning**: Deploy NLBs only in required regions
3. **Lifecycle Management**: Shut down development VMs when not in use
4. **Alternative Solutions**: Consider ALB for HTTP-based access

## 🔧 Advanced Usage

### Custom VM Deployment

```bash
# Deploy VM with specific configuration
./scaling/create-vm.sh \
  --name production-api-01 \
  --type backend \
  --port 2230 \
  --namespace-prefix prod

# Bulk deployment with custom settings
./scaling/deploy-vm-cluster.sh \
  --vms 25 \
  --prefix staging \
  --domain staging.company.com
```

### NLB Management

```bash
# Create regional NLB setup
./scaling/scale-nlb.sh --action create --nlb-count 4 --domain example.com

# Generate DNS configuration
./scaling/scale-nlb.sh --action dns --domain example.com

# Check NLB status
./scaling/scale-nlb.sh --action status
```

### Monitoring and Maintenance

```bash
# Full status report
./scaling/monitor-vms.sh

# SSH connectivity test
./scaling/monitor-vms.sh --ssh-test

# Generate deployment report
./scaling/manage-vms.sh
# Choose option 11: Generate Deployment Report
```

## 🔧 Troubleshooting

### Common Issues

#### VMs Not Starting
```bash
# Check pod status
oc get pods --all-namespaces | grep -E "vm-|frontend|backend"

# Check specific VM logs
oc logs -n vm-01 deployment/vm-01

# Restart failed pods
oc delete pod -n vm-01 -l app=vm-01
```

#### SSH Access Issues
```bash
# Test SSH connectivity
./scaling/monitor-vms.sh --ssh-test

# Check SSH service status
oc get services --all-namespaces | grep ssh-service

# Verify NodePort allocation
oc get services -o wide | grep NodePort
```

#### NLB Configuration Problems
```bash
# Check NLB status
./scaling/scale-nlb.sh --action status

# Verify AWS CLI access
aws sts get-caller-identity

# Test target group health
aws elbv2 describe-target-health --target-group-arn <arn>
```

### Log Collection

```bash
# Collect VM logs
mkdir -p /tmp/vm-logs
oc get pods --all-namespaces -o name | grep -E "vm-|frontend|backend" | while read pod; do
  oc logs $pod > /tmp/vm-logs/$(echo $pod | tr '/' '-').log
done

# Collect ArgoCD sync status
oc get applications -n openshift-gitops
```

### Recovery Procedures

#### Reset Single VM
```bash
# Delete VM namespace and resources
oc delete namespace vm-01

# Recreate VM
./scaling/create-vm.sh --name vm-01 --type frontend --port 2206
```

#### Emergency Scale Down
```bash
# Stop all test VMs
oc get namespaces | grep "test-" | awk '{print $1}' | xargs oc delete namespace

# Reduce NLB count
./scaling/scale-nlb.sh --action delete
```

## 📚 Additional Resources

- [EXTERNAL-SSH-GUIDE.md](EXTERNAL-SSH-GUIDE.md) - Detailed SSH access guide
- [SCALING-STRATEGY.md](SCALING-STRATEGY.md) - Technical scaling approach
- [Original GitOps Apps](../apps/) - Base application configurations
- [ArgoCD Configuration](../clusters/) - Cluster management setup

## 🤝 Contributing

To extend this solution:

1. **Add VM Types**: Modify `create-vm.sh` to support new application stacks
2. **Enhance Monitoring**: Extend `monitor-vms.sh` with additional health checks
3. **Optimize Costs**: Implement ALB alternatives or spot instance support
4. **Multi-Region**: Add geographic distribution capabilities

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**🚀 Ready to scale from 5 to 200+ VMs?**

Start with the interactive management interface:
```bash
./scaling/manage-vms.sh
```
