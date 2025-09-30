Kubecost gives teams visibility into current and historical Kubernetes spend and resource allocation. To see more on the functionality of the full Kubecost product, please visit the [features page](https://www.apptio.com/products/kubecost/) on our website. Some of Kubecost's features include:

- Real-time cost allocation by Kubernetes Service, Deployment, Namespace, label, StatefulSet, DaemonSet, Pod, and container
- Dynamic asset pricing enabled by integrations with AWS, Azure, and GCP billing APIs
- Supports on-premises Kubernetes clusters with custom pricing sheets
- Allocation for in-cluster resources like CPU, GPU, memory, and persistent volumes

## Getting Started

You can deploy Kubecost on any Kubernetes cluster in a matter of minutes, if not seconds. Visit the [Kubecost docs](https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=installation) for recommended install options. Compared to building from source, installing from Helm is faster and includes all necessary dependencies.

> **Note:** For Kubecost v1 or v2, please refer to the [cost-analyzer repository](https://github.com/kubecost/cost-analyzer) and use the following installation command:
>
> ```sh
> helm install cost-analyzer kubecost \
>   --repo https://kubecost.github.io/cost-analyzer \
>   --namespace kubecost --create-namespace
> ```

### Install Kubecost using Helm(v3+):

```sh
helm install kubecost kubecost \
  --repo https://kubecost.github.io/kubecost \
  --namespace kubecost --create-namespace \
  --set global.clusterId=someclustername
```


## Configuration

Kubecost can be configured using a values.yaml file. See the [values.yaml](https://github.com/kubecost/kubecost/blob/develop/kubecost/values.yaml) file for all available configuration options.

### To install with a custom values file:

```sh
helm install kubecost kubecost \
  --repo https://kubecost.github.io/kubecost \
  --namespace kubecost --create-namespace \
  --values values.yaml
```

## Documentation

For detailed configuration options and advanced usage, visit the [Kubecost documentation](https://www.ibm.com/docs/en/kubecost/self-hosted/3.x).

## Examples

Below are common installation scenarios.

### 1) Basic install
```sh
helm install kubecost kubecost \
  --repo https://kubecost.github.io/kubecost \
  --namespace kubecost --create-namespace \
  --set global.clusterId=<your-cluster-name>
```

### 2) Install with a custom values file
Use when you want to override defaults.
```sh
helm install kubecost kubecost \
  --repo https://kubecost.github.io/kubecost \
  --namespace kubecost --create-namespace \
  --values values.yaml
```

### 3) Federated storage (multi‑cluster)
Refer to the example values and documentation: https://github.com/kubecost/kubecost/blob/develop/examples/federatedStorage/README.md

### 4) Agent‑only mode (secondary clusters)
Deploy only the lightweight agent to secondary clusters that writes to the federated storage.

Agent‑only examples: https://github.com/kubecost/kubecost/tree/develop/examples/agentOnly

### 5) Uninstall
Remove the release and associated Kubernetes resources in the namespace.
```sh
helm uninstall kubecost --namespace kubecost
```

Note for GCP installs: a global key with a low limit is provided for evaluation. Supply your own key before moving to production.

## Maintainers

**IBM, Inc. All Rights Reserved.**  
[https://ibm.com](https://ibm.com)

## License

Licensed under the Apache License, Version 2.0 (the "License")


Please reach out with any additional questions by opening a GitHub issue or using our [Kubecost Slack](https://www.apptio.com/products/kubecost/join-slack/?src=kc-com) channel.


