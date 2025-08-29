# Kubecost Multi-Cluster Federated Storage

This directory contains examples of how to use multi-cluster Federated Storage with the Kubecost using shared secrets.

Shared secrets are not required, but are commonly used in multi-cloud environments. For single-cloud environments, it is recommended to use assumed roles without a shared secret.

The most common examples are for AWS, Azure, and GCP.

Other MinIO configurations (and additional settings) are possible, but only the most common examples are provided.

## Example Configurations

For all examples, the secret should be created using `federated-store.yaml` as the file name in the secret. Secret management is outside the scope of this document, though recommended practices are to use a secret manager for enterprise deployments. The intent of the example is to show the format of the secret.

```bash
kubectl create secret generic federated-store \
  --namespace kubecost \
  --from-file=federated-store.yaml
```

Kubecost helm values:

```yaml
global:
  ## clusterId is used to identify the cluster in the FinOps Agent
  ## when using the same cluster names in different regions, we suggest appending the region to the clusterId
  clusterId: globally-unique-cluster-id
  federatedStorage:
    existingSecret: federated-store
```

### AWS

[aws/federated-store.yaml](./aws/federated-store.yaml)

### Azure

[azure/federated-store.yaml](./azure/federated-store.yaml)

### GCP

[gcp/federated-store.yaml](./gcp/federated-store.yaml)
