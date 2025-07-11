# Troubleshooting Guide for ROSA

## Common Issues and Solutions

### Authentication Issues

#### AWS CLI Not Authenticated
**Error:** `Unable to locate credentials`

**Solution:**
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

**Verification:**
```bash
aws sts get-caller-identity
```

#### ROSA CLI Not Authenticated
**Error:** `not logged in`

**Solution:**
```bash
rosa login
# This will open a browser for authentication
```

**Verification:**
```bash
rosa whoami
```

### Quota Issues

#### Insufficient EC2 Quotas
**Error:** `quota exceeded`

**Solution:**
1. Check current quotas:
   ```bash
   rosa verify quota
   ```
2. Request quota increase in AWS Console:
   - Go to Service Quotas console
   - Search for "EC2"
   - Request increase for "Running On-Demand instances"

#### VPC Limit Reached
**Error:** `VPC limit exceeded`

**Solution:**
1. Check current VPC usage in AWS Console
2. Delete unused VPCs
3. Request VPC quota increase if needed

### Cluster Creation Issues

#### Invalid Machine Type
**Error:** `instance type not supported`

**Solution:**
Check available instance types:
```bash
# View available types for your region
aws ec2 describe-instance-types --region us-east-1
```

Common working types:
- m5.large, m5.xlarge, m5.2xlarge
- c5.large, c5.xlarge
- r5.large, r5.xlarge

#### Network Configuration Issues
**Error:** `subnet not available`

**Solution:**
1. Ensure you have at least 3 subnets in different AZs
2. Check subnet CIDR doesn't conflict
3. Use default networking if custom config fails

#### Installation Timeout
**Error:** `cluster installation timed out`

**Solution:**
1. Check installation logs:
   ```bash
   rosa logs install --cluster=<cluster-name>
   ```
2. Verify AWS permissions
3. Check service health:
   ```bash
   rosa verify permissions
   ```

### Node Issues

#### Nodes Not Ready
**Error:** `node not ready`

**Solution:**
1. Check node status:
   ```bash
   oc get nodes
   oc describe node <node-name>
   ```
2. Check machine pool status:
   ```bash
   rosa list machinepools --cluster=<cluster-name>
   ```
3. Scale up/down to refresh nodes:
   ```bash
   rosa edit machinepool --cluster=<cluster-name> --machinepool=worker --replicas=4
   ```

#### Pods Stuck in Pending
**Error:** `pod stuck in pending state`

**Solution:**
1. Check pod events:
   ```bash
   oc describe pod <pod-name> -n <namespace>
   ```
2. Check resource availability:
   ```bash
   oc adm top nodes
   ```
3. Check node selectors and taints

### Network Issues

#### Cannot Access Applications
**Error:** `connection refused`

**Solution:**
1. Check service status:
   ```bash
   oc get svc -n <namespace>
   ```
2. Check route configuration:
   ```bash
   oc get routes -n <namespace>
   ```
3. Test internal connectivity:
   ```bash
   oc port-forward pod/<pod-name> 8080:8080
   ```

#### LoadBalancer Stuck in Pending
**Error:** `external IP pending`

**Solution:**
1. Check AWS Load Balancer creation in EC2 console
2. Verify IAM permissions for ELB
3. Check security groups



### Performance Issues

#### High CPU/Memory Usage
**Problem:** Cluster performance degradation

**Solution:**
1. Check resource usage:
   ```bash
   oc adm top nodes
   oc adm top pods --all-namespaces
   ```
2. Scale machine pool:
   ```bash
   rosa edit machinepool --cluster=<cluster-name> --machinepool=worker --replicas=6
   ```
3. Enable autoscaling:
   ```bash
   rosa edit machinepool --cluster=<cluster-name> --machinepool=worker --enable-autoscaling --min-replicas=3 --max-replicas=10
   ```

#### Storage Issues
**Problem:** Persistent volume issues

**Solution:**
1. Check storage classes:
   ```bash
   oc get storageclass
   ```
2. Check PV/PVC status:
   ```bash
   oc get pv,pvc --all-namespaces
   ```
3. Verify EBS permissions in AWS

### Upgrade Issues

#### Cluster Upgrade Failed
**Error:** `upgrade failed`

**Solution:**
1. Check upgrade status:
   ```bash
   rosa describe cluster --cluster=<cluster-name>
   ```
2. Review upgrade logs:
   ```bash
   rosa logs install --cluster=<cluster-name>
   ```
3. Ensure all nodes are healthy before upgrade

### Cost Issues

#### Unexpected High Costs
**Problem:** AWS bill higher than expected

**Solution:**
1. Check running resources:
   ```bash
   rosa list clusters
   rosa describe cluster --cluster=<cluster-name>
   ```
2. Review AWS Cost Explorer
3. Check for zombie resources:
   - Unused Load Balancers
   - Unattached EBS volumes
   - Elastic IPs

### Deletion Issues

#### Cluster Won't Delete
**Error:** `cluster deletion failed`

**Solution:**
1. Force delete:
   ```bash
   rosa delete cluster --cluster=<cluster-name> --yes
   ```
2. Check for remaining resources in AWS Console:
   - Load Balancers
   - Security Groups
   - VPC resources
3. Manual cleanup if needed

#### Resources Left Behind
**Problem:** AWS resources not cleaned up

**Solution:**
1. Check CloudFormation stacks
2. Look for resources tagged with cluster name
3. Manual deletion of:
   ```bash
   aws elb describe-load-balancers
   aws ec2 describe-security-groups
   aws ec2 describe-volumes --filters "Name=tag:kubernetes.io/cluster/*,Values=owned"
   ```

## Getting Additional Help

### Log Collection
```bash
# Cluster installation logs
rosa logs install --cluster=<cluster-name>

# Node logs
oc adm node-logs <node-name>

# Pod logs
oc logs <pod-name> -n <namespace>

# Events
oc get events --all-namespaces --sort-by='.lastTimestamp'
```

### Support Resources
- ROSA Documentation: https://docs.openshift.com/rosa/
- Red Hat Support: https://access.redhat.com/support/
- AWS Support: https://aws.amazon.com/support/
- OpenShift Community: https://www.openshift.com/community/

### Useful Commands for Debugging
```bash
# Check cluster version and status
oc version
oc get clusterversion

# Check cluster operators
oc get clusteroperators

# Check machine config
oc get machineconfig

# Check network policies
oc get networkpolicy --all-namespaces

# Check storage
oc get storageclass
oc get pv,pvc --all-namespaces
```
