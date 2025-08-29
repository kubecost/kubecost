# Kubecost Service Account Configuration

This guide explains how to configure service accounts for Kubecost components using the standardized service account system introduced in Kubecost 3.0.

## Overview

Kubecost uses a flexible service account configuration system that allows you to:

- Use a single global service account for all components (default)
- Create dedicated service accounts for individual components
- Configure component-specific annotations and labels
- Control service account token mounting per component

## Default Configuration

By default, Kubecost creates a single service account named `kubecost` that is used by all components except:

| Component | Default Account | Description | Kubernetes API Access | Cloud Provider Object-Storage Access |
|-----------|----------------|-------------|----------------------|----------------------------|
| `finops-agent` | `finops-agent` | metrics collection | clusterRole | true |
| `aggregator` | `kubecost` | Core cost data processing | local namespace | true |
| `cloudcost` | `kubecost` | Cloud provider billing integration | false | true |
| `frontend` | `kubecost` | Web UI and API gateway | false | false |
| `localstore` | `default` | Local storage for single cluster deployments | false | false |
| `forecasting` | `default` | forecasting and predictions | false | false |
| `clustercontroller` | `cluster-controller` | Cluster resource management | clusterRole | true |
| `networkcosts` | `kubecost` | Network cost tracking | false | false |


```yaml
serviceAccount:
  create: true
  name: ""  # Uses chart name: kubecost
  annotations: {}
  labels: {}
  automountServiceAccountToken: true
```

## Basic Configuration Examples

### 1. Global Service Account with Annotations

Add annotations to the global service account (affects all components using it):

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/kubecost-global"
  labels:
    team: "finops"
    environment: "production"
```

### 2. Enable Component-Specific Service Accounts

Create dedicated service accounts for specific components:

```yaml
serviceAccount:
  create: true
  components:
    aggregator:
      create: true
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/kubecost-aggregator"
    
    cloudcost:
      create: true
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/kubecost-cloud-billing"
    
    frontend:
      create: true
      automountServiceAccountToken: false  # Frontend doesn't need API access
```

### 3. Mixed Configuration

Some components use dedicated service accounts, others use the global one:

```yaml
serviceAccount:
  create: true
  name: "kubecost-shared"
  annotations:
    # Global annotations for shared components
    monitoring.coreos.com/app: "kubecost"
  
  components:
    # Only aggregator gets its own service account
    aggregator:
      create: true
      name: "kubecost-data-processor"
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/kubecost-data-access"
    
    # All other components use the global "kubecost-shared" service account
```

## Cloud Provider Examples

### AWS EKS with IRSA (IAM Roles for Service Accounts)

```yaml
serviceAccount:
  create: true
  components:
    aggregator:
      create: true
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/kubecost-aggregator-role"
    
    cloudcost:
      create: true
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/kubecost-billing-role"
    
    clustercontroller:
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/kubecost-cluster-mgmt-role"
```

### Azure AKS with Workload Identity

```yaml
serviceAccount:
  create: true
  components:
    aggregator:
      create: true
      annotations:
        azure.workload.identity/client-id: "12345678-1234-1234-1234-123456789012"
      labels:
        azure.workload.identity/use: "true"
    
    cloudcost:
      create: true
      annotations:
        azure.workload.identity/client-id: "87654321-4321-4321-4321-210987654321"
      labels:
        azure.workload.identity/use: "true"
```

### GCP GKE with Workload Identity

```yaml
serviceAccount:
  create: true
  components:
    aggregator:
      create: true
      annotations:
        iam.gke.io/gcp-service-account: "kubecost-aggregator@my-project.iam.gserviceaccount.com"
    
    cloudcost:
      create: true
      annotations:
        iam.gke.io/gcp-service-account: "kubecost-billing@my-project.iam.gserviceaccount.com"
```

## Component-Specific Configuration

### Component Configuration Options

```yaml
serviceAccount:
  components:
    <component-name>:
      create: false  # Create dedicated service account
      name: ""  # Custom name (default: kubecost-<component>)
      annotations: {}  # Component-specific annotations
      labels: {}  # Component-specific labels
      automountServiceAccountToken: true  # Mount service account token
```

### Example: High-Security Configuration

For security-sensitive environments where components should have minimal permissions:

```yaml
serviceAccount:
  create: true
  automountServiceAccountToken: false  # Global default: no token mounting
  
  components:
    aggregator:
      create: true
      automountServiceAccountToken: true  # Needs API access
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/kubecost-aggregator-readonly"
    
    clustercontroller:
      automountServiceAccountToken: true  # Needs cluster management access
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/kubecost-cluster-admin"
    
    frontend:
      create: true
      automountServiceAccountToken: false  # No API access needed
    
    forecasting:
      create: true
      automountServiceAccountToken: false  # No API access needed
```

## Service Account Naming Convention

When creating component-specific service accounts, the naming follows this pattern:

- Global service account: `<release-name>` (default: `kubecost`)
- Component service accounts: `<release-name>-<component-name>`

Examples:

- Global: `kubecost`
- Aggregator: `kubecost-aggregator`
- Cloud Cost: `kubecost-cloudcost`
- Frontend: `kubecost-frontend`
- Forecasting: `kubecost-forecasting`
- Cluster Controller: `kubecost-clustercontroller`
- Network Costs: `kubecost-networkcosts`

You can override the name using the `name` field:

```yaml
serviceAccount:
  name: "my-kubecost"  # Global name override
  components:
    aggregator:
      create: true
      name: "my-aggregator"  # Component name override
```

## Verification Commands

After deploying, verify your service account configuration:

```bash
# List all Kubecost service accounts
kubectl get serviceaccounts -n kubecost -l app.kubernetes.io/name=kubecost

# Check which service account each pod is using
kubectl get pods -n kubecost -o custom-columns=NAME:.metadata.name,SERVICE_ACCOUNT:.spec.serviceAccountName

# View service account annotations
kubectl get serviceaccount kubecost-aggregator -n kubecost -o yaml
```

## Troubleshooting

### Common Issues

1. **Service account not found**

   ```
   Error: pods "kubecost-aggregator-xxx" is forbidden: error looking up service account kubecost/kubecost-aggregator
   ```

   - Ensure `serviceAccount.components.aggregator.create: true`
   - Check that the service account exists: `kubectl get sa -n kubecost`

2. **AWS IRSA not working**

   ```
   Error: unable to retrieve token from metadata service
   ```

   - Verify the IAM role ARN annotation is correct
   - Check that the IAM role trust policy includes the service account
   - Ensure the EKS cluster has an OIDC provider configured

3. **Permissions denied**

   ```
   Error: serviceaccounts is forbidden: User "system:serviceaccount:kubecost:kubecost-aggregator" cannot create resource
   ```

   - The service account lacks necessary RBAC permissions
   - Check that ClusterRoles and RoleBindings are properly configured
   - Verify the service account is correctly referenced in RBAC resources

### Debug Commands

```bash
# Check service account details
kubectl describe serviceaccount kubecost-aggregator -n kubecost

# View pod service account usage
kubectl describe pod <pod-name> -n kubecost | grep -A5 "Service Account"

# Check RBAC permissions
kubectl auth can-i --list --as=system:serviceaccount:kubecost:kubecost-aggregator

# Verify token mounting
kubectl exec -it <pod-name> -n kubecost -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/
```

## Migration Guide

### From Pre-3.0 Versions

If you're upgrading from an older version of Kubecost:

1. **Old configuration** (pre-3.0):

   ```yaml
   aggregator:
     serviceAccountName: "my-aggregator-sa"
   cloudcost:
     serviceAccountName: "my-cloud-cost-sa"
   ```

2. **New configuration** (3.0+):

   ```yaml
   serviceAccount:
     components:
       aggregator:
         create: false  # Using existing service account
         name: "my-aggregator-sa"
       cloudcost:
         create: false  # Using existing service account
         name: "my-cloud-cost-sa"
   ```

The old component-specific `serviceAccountName` fields are deprecated but the new system maintains backward compatibility.

## Best Practices

1. **Principle of Least Privilege**: Create component-specific service accounts with minimal required permissions
2. **Use Cloud IAM Integration**: Leverage IRSA, Workload Identity, or similar for cloud resource access
3. **Disable Token Mounting**: Set `automountServiceAccountToken: false` for components that don't need Kubernetes API access
4. **Consistent Naming**: Use the default naming convention unless you have specific requirements
5. **Test Configurations**: Always verify service account configuration in a development environment first

## Support

For issues with service account configuration:

1. Check the [Kubecost documentation](https://docs.kubecost.com/)
2. Review the troubleshooting section above
3. Open an issue on the [Kubecost GitHub repository](https://github.com/kubecost/cost-analyzer-helm-chart)
