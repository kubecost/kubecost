# Kubecost Helm Chart Example Configurations

> The basic examples provided in this repo are intended for those who have previous experience with the Kubecost Helm chart.

Extensive documentation is available at [<https://www.ibm.com/docs/en/kubecost/self-hosted/2.x>](https://www.ibm.com/docs/en/kubecost/self-hosted/2.x).

The 3.0 helm chart has been updated to simplify many of the configurations that had been added over time and will require some changes to the configurations used in previous versions.

## Agent Only Configurations

- [AWS](./agentOnly/helmValues-kubecost-aws.yaml)
- [Azure](./agentOnly/helmValues-kubecost-azure.yaml)
- [GCP](./agentOnly/helmValues-kubecost-gcp.yaml)

## Federated Storage Shared-Secret Configurations

Federated storage with shared-secrets [readme](./federatedStorage/README.md).

## Install Kubecost

> You should never pass the entire [values.yaml](../kubecost/values.yaml) file to the helm install command. These are default values. Adding them to your install command will dramatically increase the complexity when upgrading to future versions. Instead, only pass the values you need to customize from the defaults.

When you have your customized values, use the `-f` flag to pass them to the helm install command:

```bash
helm install kubecost \
  --repo https://kubecost.github.io/cost-analyzer/ kubecost \
  --namespace kubecost \
  --create-namespace \
  -f helmValues-kubecost-3.0.yaml
```
