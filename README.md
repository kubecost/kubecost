# Kubecost Helm chart

This repository contains the Helm chart templates for the development of [Kubecost](https://www.kubecost.com/), an enterprise-grade application to monitor and manage Kubernetes spend. Please see the [website](https://www.kubecost.com/) for more details on what Kubecost can do for you and the official documentation [IBM Docs](https://www.ibm.com/docs/en/kubecost/self-hosted/2.x), or contact [team-kubecost@wwpdl.vnet.ibm.com](mailto:team-kubecost@wwpdl.vnet.ibm.com) for assistance.

## Version Support

Kubecost strives to support as many versions of Kubernetes as possible. Below is the version support matrix which has been tested. Versions outside of the stated range may still work but are untested.
While the below versions may work with the given versions of Kubernetes, Kubecost generally supports the current and previous version

| Chart Version                  | Kubernetes Min | Kubernetes Max |
|--------------------------------|----------------|----------------|
| 2.7                            | 1.22           | 1.32           |
| 2.8                            | 1.22           | 1.33           |

## Installation

***Note: Upcoming changes to the Kubecost Helm chart will require changes.***

To install the current GA version (2.8) of Kubecost via Helm, run the following command.

```sh
helm upgrade --install kubecost -n kubecost --create-namespace \
  --repo https://kubecost.github.io/cost-analyzer/ cost-analyzer
```

Alternatively, add the Helm repository first and scan for updates.

```sh
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update
helm install kubecost kubecost/cost-analyzer -n kubecost --create-namespace
```

The default branch of this repository is the `develop` branch. This branch is not stable and is subject to change. Please use the following command to show values available for the chart you are using:

```sh
helm show values kubecost/cost-analyzer --version 2.8.1
```

Or switch to the tag of the version you are using:

<https://github.com/kubecost/kubecost/tree/v2.8.1>
