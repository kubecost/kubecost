# In-Place Pod Resize Actions

## Overview

The In-Place Pod Resize action enables Kubecost to dynamically adjust CPU and memory resource requests and limits for running containers **without recreating pods**. This feature leverages Kubernetes v1.35's stable in-place pod resize capability to optimize resource allocation while minimizing application disruption.

## Benefits

- **Zero-downtime CPU adjustments**: Modify CPU resources without restarting containers
- **Controlled memory updates**: Adjust memory with optional container restarts when necessary
- **Cost optimization**: Right-size workloads based on actual usage patterns
- **Reduced disruption**: Avoid pod evictions and rescheduling overhead
- **Multi-cluster support**: Coordinate resize actions across federated clusters

## Requirements

### Kubernetes Version
- **Minimum**: Kubernetes v1.33
- **Recommended**: Kubernetes v1.35+ (stable feature)
- **Feature Gate**: `InPlacePodVerticalScaling` (enabled by default in v1.35)

### kubectl Version
- **Minimum**: v1.32 with `--subresource=resize` flag support

### Kubecost Version
- **Minimum**: Kubecost 3.0+

### RBAC Permissions
The cluster-controller requires the following permissions:
```yaml
- apiGroups: ['']
  resources: ['pods', 'pods/status']
  verbs: ['get', 'list', 'watch', 'patch']
- apiGroups: ['apps']
  resources: ['deployments', 'statefulsets', 'daemonsets', 'replicasets']
  verbs: ['get', 'list', 'watch']
- apiGroups: ['batch']
  resources: ['jobs', 'cronjobs']
  verbs: ['get', 'list', 'watch']
```

## Configuration

### Enable RBAC Permissions

In your `values.yaml`:

```yaml
clusterController:
  enabled: true
  rbac:
    inPlacePodResize: true
```

### Basic Configuration (Legacy Mode)

For Kubecost versions < 3.0 using legacy mode:

```yaml
clusterController:
  enabled: true
  legacyMode: true
  
  actionConfigs:
    inPlacePodResize:
      enabled: true
      minKubernetesVersion: "1.33"
      resizeWindow: "24h"
      targetUtilization:
        cpu: 0.7
        memory: 0.8
      resizePolicy:
        cpu: NotRequired
        memory: RestartContainer
      dryRun: false
```

### Advanced Configuration (Actions v2)

For Kubecost 3.0+ with multi-cluster actions:

```yaml
kubecostProductConfigs:
  actions:
    enabled: true
    
    config:
      global:
        inPlacePodResize:
          enabled: true
          minKubernetesVersion: "1.33"
          defaultResizePolicy:
            cpu: NotRequired
            memory: RestartContainer
          retryStrategy:
            maxRetries: 3
            backoffMultiplier: 2
            initialDelaySeconds: 30
      
      clusters:
        production-cluster:
          inPlacePodResize:
            enabled: true
            minKubernetesVersion: "1.35"
      
      actions:
        inPlacePodResize:
          production-workload-resize:
            enabled: true
            filter: "cluster:\"production\",namespace:\"default\""
            resizeWindow: "24h"
            targetUtilization:
              cpu: 0.7
              memory: 0.8
            resizePolicy:
              cpu: NotRequired
              memory: RestartContainer
            dryRun: false
            priorityThreshold: "high-priority"
```

## Resize Policies

### CPU: NotRequired (Default)
- **Behavior**: Apply CPU changes without restarting the container
- **Use Case**: Most applications can handle CPU changes dynamically
- **Downtime**: None
- **Example**:
  ```yaml
  resizePolicy:
    cpu: NotRequired
  ```

### Memory: RestartContainer (Recommended)
- **Behavior**: Restart the container to apply memory changes
- **Use Case**: Many applications cannot adjust memory allocation dynamically
- **Downtime**: Brief container restart
- **Example**:
  ```yaml
  resizePolicy:
    memory: RestartContainer
  ```

## Pod Resize Status

The resize operation progresses through several states:

### 1. Proposed
- Resize request submitted but not yet accepted by kubelet
- **Action**: Wait for kubelet acknowledgment

### 2. InProgress
- Kubelet has accepted and is applying the resize
- **Duration**: Usually brief (seconds to minutes)
- **Monitoring**: Check `status.containerStatuses[*].resources`

### 3. Deferred
- Resize not currently possible but may succeed later
- **Reasons**:
  - Insufficient node resources
  - Another pod needs to be removed first
- **Action**: Automatic retry based on priority

### 4. Infeasible
- Resize impossible on current node
- **Reasons**:
  - Requesting more resources than node has
  - Resource quota exceeded
- **Action**: Manual intervention required

## Retry Strategy

When resizes are deferred, Kubecost implements priority-based retry logic:

### Priority Order
1. **PriorityClass**: Higher priority pods resize first
2. **Resource Increase**: Larger increases prioritized
3. **Creation Time**: Oldest requests first

### Configuration
```yaml
retryStrategy:
  maxRetries: 3
  backoffMultiplier: 2
  initialDelaySeconds: 30
```

### Behavior
- Initial retry after 30 seconds
- Second retry after 60 seconds (30 * 2)
- Third retry after 120 seconds (60 * 2)
- After max retries, mark as failed

## Validation

### Pre-Resize Checks

Enable validation to prevent failed resizes:

```yaml
validation:
  checkNodeCapacity: true
  checkResourceQuotas: true
  checkPodDisruptionBudgets: true
  minCPUMillicores: 100
  maxCPUMillicores: 8000
  minMemoryMiB: 128
  maxMemoryMiB: 16384
```

### Node Capacity Check
- Verifies node has sufficient resources
- Prevents `Infeasible` state

### Resource Quota Check
- Ensures namespace quota not exceeded
- Prevents quota violations

### Pod Disruption Budget Check
- Respects PDB constraints during restarts
- Prevents availability violations

## Monitoring

### Metrics

Enable Prometheus metrics:

```yaml
monitoring:
  enabled: true
  metricsPort: 9090
  metricsPath: "/metrics"
```

### Key Metrics
- `kubecost_inplace_resize_total`: Total resize attempts
- `kubecost_inplace_resize_success`: Successful resizes
- `kubecost_inplace_resize_failed`: Failed resizes
- `kubecost_inplace_resize_deferred`: Deferred resizes
- `kubecost_inplace_resize_duration_seconds`: Resize duration

### Alerts

Recommended alerts:
```yaml
- alert: InPlaceResizeHighFailureRate
  expr: rate(kubecost_inplace_resize_failed[5m]) > 0.1
  annotations:
    summary: "High in-place resize failure rate"

- alert: InPlaceResizeStuck
  expr: kubecost_inplace_resize_duration_seconds > 300
  annotations:
    summary: "In-place resize taking too long"
```

## Filtering

### Namespace Filtering
```yaml
filters:
  - namespace: "production"
  - namespace: "staging"
```

### Label Filtering
```yaml
filters:
  - namespace: "default"
    labels:
      app: "web-server"
      tier: "frontend"
```

### Exclude Labels
```yaml
filters:
  - namespace: "kube-system"
    excludeLabels:
      critical: "true"
```

## Dry Run Mode

Test resize actions without applying changes:

```yaml
dryRun: true
```

**Behavior**:
- Calculates recommended sizes
- Validates feasibility
- Logs actions that would be taken
- Does not modify pods

## Security Considerations

### Least Privilege
- Only grant `inPlacePodResize` RBAC when needed
- Use namespace-scoped roles when possible

### Resource Limits
- Always set `minCPUMillicores` and `maxCPUMillicores`
- Always set `minMemoryMiB` and `maxMemoryMiB`
- Prevents resource exhaustion attacks

### Validation
- Enable all validation checks in production
- Review resize recommendations before disabling dry run

### Audit Logging
- Enable Kubernetes audit logging for resize operations
- Monitor for unauthorized resize attempts

## Troubleshooting

### Resize Stuck in Proposed State
**Symptom**: Resize never progresses past Proposed
**Causes**:
- Kubernetes version < 1.33
- Feature gate not enabled
- kubectl version < 1.32

**Solution**:
```bash
# Check Kubernetes version
kubectl version --short

# Check feature gate
kubectl get --raw /metrics | grep InPlacePodVerticalScaling
```

### Resize Marked as Infeasible
**Symptom**: Resize immediately fails with Infeasible
**Causes**:
- Requesting more resources than node has
- Resource quota exceeded

**Solution**:
```bash
# Check node capacity
kubectl describe node <node-name>

# Check resource quotas
kubectl describe resourcequota -n <namespace>
```

### Resize Stuck in Deferred State
**Symptom**: Resize stays in Deferred for extended period
**Causes**:
- Node resources temporarily unavailable
- Other pods need to be removed first

**Solution**:
- Wait for automatic retry
- Check priority configuration
- Consider manual pod eviction

### Container Restart Failures
**Symptom**: Container fails to restart after memory resize
**Causes**:
- Application initialization issues
- Insufficient memory for startup

**Solution**:
- Increase `minMemoryMiB` threshold
- Review application logs
- Adjust `targetUtilization.memory`

## Best Practices

1. **Start with Dry Run**: Always test with `dryRun: true` first
2. **Use Conservative Targets**: Start with 70% CPU, 80% memory utilization
3. **Enable All Validations**: Prevent failed resizes with pre-checks
4. **Monitor Metrics**: Set up alerts for failures and stuck resizes
5. **Respect PriorityClass**: Use priority classes for critical workloads
6. **Test in Staging**: Validate resize behavior before production
7. **Document Exceptions**: Track workloads excluded from auto-resize
8. **Regular Review**: Periodically review resize recommendations

## Examples

See the following example configurations:
- [CPU-only resize](../kubecost/ci/inplace-resize-cpu-values.yaml)
- [Memory with restart](../kubecost/ci/inplace-resize-memory-values.yaml)
- [Combined CPU and memory](../kubecost/ci/inplace-resize-combined-values.yaml)

## References

- [Kubernetes In-Place Pod Resize Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/resize-container-resources/)
- [Kubecost Actions Documentation](https://www.ibm.com/docs/en/kubecost/self-hosted/3.x)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

## Support

For issues or questions:
- GitHub Issues: [kubecost/kubecost](https://github.com/kubecost/kubecost/issues)
- Email: team-kubecost@wwpdl.vnet.ibm.com
- Documentation: [IBM Docs](https://www.ibm.com/docs/en/kubecost/self-hosted/3.x)