# Kubecost Helm Chart

This repository contains the official Helm chart for **Kubecost v3+**, providing cost monitoring and optimization for Kubernetes clusters.

> **Note:** For Kubecost v1 or v2, please refer to the [cost-analyzer repository](https://github.com/kubecost/cost-analyzer) and use the following installation command:
>
> ```sh
> helm install cost-analyzer kubecost \
>   --repo https://kubecost.github.io/cost-analyzer \
>   --namespace kubecost --create-namespace
> ```

## Quick Start

Install Kubecost using Helm:

```sh
helm install kubecost kubecost \
  --repo https://kubecost.github.io/kubecost \
  --namespace kubecost --create-namespace \
  --set global.clusterId=someclustername
```

## Configuration

Kubecost can be configured using a values.yaml file. See the [values.yaml](https://github.com/kubecost/kubecost/blob/develop/kubecost/values.yaml) file for all available configuration options.

To install with a custom values file:

```sh
helm install kubecost kubecost \
  --repo https://kubecost.github.io/kubecost \
  --namespace kubecost --create-namespace \
  --values values.yaml
```

## Documentation

For detailed configuration options and advanced usage, visit the [Kubecost documentation](https://docs.kubecost.com/).
