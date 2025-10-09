# Kubecost Helm Chart Example Configurations

> The basic examples provided in this repo are intended for those who have previous experience with the Kubecost Helm chart.

Extensive documentation is available at [https://www.ibm.com/docs/en/kubecost/self-hosted/3.x](https://www.ibm.com/docs/en/kubecost/self-hosted/3.x).

The 3.0 helm chart has been updated to simplify many of the configurations that had been added over time.
Changes will be required when upgrading from previous versions.

## Federated Storage Configurations

Federated storage is used for multi-cluster environments. Kubecost can still be deployed "standalone" in a single cluster for testing and small scale environments.

To provide the object storage for federated storage, use a managed secret or via Helm values.

An example of Federated storage with shared-secrets [readme](./federatedStorage/README.md).

Examples of Federated storage with assumed roles via Helm values are in the agentOnly directory, and can be used for the primary as well. [readme](./agentOnly/README.md).

## Install Kubecost

> You should never pass the entire [values.yaml](../kubecost/values.yaml) file to the helm install command. These are default values. Adding them to your install command will dramatically increase the complexity when upgrading to future versions. Instead, only pass the values you need to customize from the defaults.

### Primary Cluster

See the example [helmValues-kubecost-primary.yaml](./helmValues-kubecost-primary.yaml) that includes the most common settings that are often customized.

When you have your customized values, use the `-f` flag to pass them to the helm install command:

```bash
helm install kubecost \
  --repo https://kubecost.github.io/kubecost/ kubecost \
  --namespace kubecost \
  --create-namespace \
  -f helmValues-kubecost-primary.yaml
```

### Agent Only / Secondary Cluster

> The terms "agent only" and "secondary cluster" are used interchangeably in this documentation.

Kubecost 3.x architecture was designed to allow for a single agent configuration to be pushed to all clusters including the primary.
This is not required, and users can continue to use the same design as previous versions.

When using a global agent configuration, the agent should be installed to a different namespace than is used for the primary cluster.

Agent only configurations:

- [AWS](./agentOnly/helmValues-kubecost-aws.yaml)
- [Azure](./agentOnly/helmValues-kubecost-azure.yaml)
- [GCP](./agentOnly/helmValues-kubecost-gcp.yaml)

When you have your customized values, use the `-f` flag to pass them to the helm install command:

```bash
helm install kubecost-agent \
  --repo https://kubecost.github.io/kubecost/ kubecost \
  --namespace kubecost-agent \
  --create-namespace \
  -f helmValues-kubecost-agentOnly.yaml
```
