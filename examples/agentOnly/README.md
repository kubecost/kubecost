# Agent Only Configuration

This configuration is for running the finops-agent only. To install a Primary, follow [this guide](../README.md#primary-cluster)

With the exception of the `clusterId`, the agent configuration can be identical for all clusters, even in multi-cluster environments.

The multiple examples here are due to the difference in the object-storage configuration.

## Agent only configurations

- [AWS](./agentOnly/helmValues-kubecost-aws.yaml)
- [Azure](./agentOnly/helmValues-kubecost-azure.yaml)
- [GCP](./agentOnly/helmValues-kubecost-gcp.yaml)

After customizing the values, use the `-f` flag to pass them to the helm install command:

```bash
helm install kubecost-agent \
  --repo https://kubecost.github.io/kubecost/ kubecost \
  --namespace kubecost-agent \
  --create-namespace \
  -f helmValues-kubecost-agentOnly.yaml
```
