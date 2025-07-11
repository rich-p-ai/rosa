# ROSA Best Practices

## Cluster Design

### Sizing Guidelines

**Development Clusters:**
- Machine Type: m5.large or m5.xlarge
- Node Count: 3-6 nodes
- Autoscaling: 3-6 nodes

**Production Clusters:**
- Machine Type: m5.xlarge or larger
- Node Count: 6+ nodes
- Autoscaling: 6-20 nodes
- Multi-AZ deployment

### Network Planning

**CIDR Recommendations:**
- Machine CIDR: /16 (e.g., 10.0.0.0/16)
- Service CIDR: /16 (e.g., 172.30.0.0/16)
- Pod CIDR: /14 (e.g., 10.128.0.0/14)

**Connectivity:**
- Use private clusters for production
- Plan VPC peering for hybrid connectivity
- Consider AWS PrivateLink for secure access

## Security Best Practices

### Access Management

1. **Use IAM roles instead of access keys**
2. **Enable MFA on all accounts**
3. **Follow principle of least privilege**
4. **Regularly audit access permissions**

### Cluster Security

1. **Enable encryption at rest**
2. **Use private clusters for sensitive workloads**
3. **Implement network policies**
4. **Regular security updates**

### Monitoring

1. **Enable cluster logging**
2. **Set up monitoring dashboards**
3. **Configure alerting**
4. **Regular health checks**

## Cost Optimization

### Right-Sizing

**Monitor Resource Usage:**
```bash
# Check node utilization
oc adm top nodes

# Check pod resource usage
oc adm top pods --all-namespaces
```

**Instance Type Selection:**
- Use compute-optimized (c5) for CPU-intensive workloads
- Use memory-optimized (r5) for memory-intensive workloads
- Use general-purpose (m5) for balanced workloads

### Autoscaling

**Configure Horizontal Pod Autoscaler:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Enable Cluster Autoscaler:**
```bash
rosa edit machinepool --cluster=my-cluster --machinepool=worker \
  --enable-autoscaling --min-replicas=3 --max-replicas=10
```

### Cost Monitoring

1. **Use AWS Cost Explorer**
2. **Set up billing alerts**
3. **Tag resources appropriately**
4. **Regular cost reviews**

## Operational Excellence

### Backup Strategy

1. **ETCD backups (automated by Red Hat)**
2. **Application data backups**
3. **Configuration backups**
4. **Disaster recovery planning**

### Monitoring and Alerting

**Key Metrics to Monitor:**
- Cluster health
- Node resource utilization
- Pod restart rates
- Network latency
- Storage usage

**Alerting Setup:**
```bash
# Install cluster monitoring
rosa install addon --cluster=my-cluster cluster-logging-operator

# Configure alerts (via OpenShift console)
```

### Maintenance

**Regular Tasks:**
- Update OpenShift version
- Update node AMIs
- Security patching
- Certificate renewal

**Automation:**
```bash
# Enable automatic updates
rosa edit cluster --cluster=my-cluster --enable-autoupgrade
```

## High Availability

### Multi-AZ Deployment

```bash
# Create cluster across multiple AZs
rosa create cluster --cluster-name=ha-cluster \
  --multi-az \
  --region=us-east-1 \
  --availability-zones=us-east-1a,us-east-1b,us-east-1c
```

### Application Design

**Pod Disruption Budgets:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-app
```

**Anti-Affinity Rules:**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - my-app
              topologyKey: kubernetes.io/hostname
```

## Troubleshooting

### Common Issues

**Node Issues:**
```bash
# Check node status
oc get nodes
oc describe node <node-name>

# Check node logs
oc adm node-logs <node-name>
```

**Pod Issues:**
```bash
# Check pod status
oc get pods --all-namespaces
oc describe pod <pod-name> -n <namespace>

# Check pod logs
oc logs <pod-name> -n <namespace>
```

**Cluster Issues:**
```bash
# Check cluster status
rosa describe cluster --cluster=my-cluster

# Check cluster logs
rosa logs install --cluster=my-cluster
```

### Performance Optimization

**Resource Requests and Limits:**
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "25m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

**Storage Optimization:**
- Use appropriate storage classes
- Implement storage monitoring
- Regular cleanup of unused volumes

## Compliance and Governance

### Audit Logging

```bash
# Enable audit logging
rosa install addon --cluster=my-cluster audit-log-forwarding
```

### Policy Management

**Network Policies:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Security Context Constraints:**
```bash
# List SCCs
oc get scc

# Create custom SCC
oc create -f custom-scc.yaml
```

## Migration Strategies

### Application Migration

1. **Assessment phase**
2. **Containerization**
3. **Testing**
4. **Gradual migration**
5. **Validation**

### Data Migration

1. **Database migration tools**
2. **Volume migration**
3. **Backup and restore**
4. **Replication strategies**
