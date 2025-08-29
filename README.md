# Kubecost Helm chart

This repository contains the Helm chart templates for the development of [Kubecost](https://www.kubecost.com/), an enterprise-grade application to monitor and manage Kubernetes spend. Please see the [website](https://www.kubecost.com/) for more details on what Kubecost can do for you and the official documentation [IBM Docs](https://www.ibm.com/docs/en/kubecost/self-hosted/2.x), or contact [team-kubecost@wwpdl.vnet.ibm.com](mailto:team-kubecost@wwpdl.vnet.ibm.com) for assistance.

## Version Support

Kubecost strives to support as many versions of Kubernetes as possible. Below is the version support matrix which has been tested. Versions outside of the stated range may still work but are untested.

| Chart Version                  | Kubernetes Min | Kubernetes Max |
|--------------------------------|----------------|----------------|
| 2.7                            | 1.22           | 1.32           |
| 2.8                            | 1.22           | 1.33           |

## Installation

***Note: Upcoming changes to the Kubecost Helm chart will require configuration changes***

To install the current GA version (2.8) of Kubecost via Helm, run the following command:

```sh
helm upgrade --install kubecost -n kubecost --create-namespace \
  --repo https://kubecost.github.io/cost-analyzer/ cost-analyzer
```

Alternatively, add the Helm repository first and scan for updates:

```sh
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update
helm install kubecost kubecost/cost-analyzer -n kubecost --create-namespace
```

The default branch of this repository is the `develop` branch. This branch is not stable and is subject to change. Please use the following command to show values available for the chart you are using:

```sh
helm show values kubecost/cost-analyzer --version 2.8.2
```

Or switch to the tag of the version you are using:

<https://github.com/kubecost/kubecost/tree/v2.8.2>

## Beta/Release Candidates

To install the beta/release candidates pass the `--devel` flag:

```sh
helm helm repo add kubecost-30-testing https://kubecost.github.io/kubecost/
helm repo update

helm install kubecost kubecost-30-testing/kubecost \
  --namespace kubecost \
  --create-namespace \
  --devel
```

See the [3.0 examples](examples/) for more information on changes required when upgrading to 3.0 beta.

## Development Branch

The `develop` branch is the development branch for the chart. It is not stable and is subject to instability.

```sh
git clone https://github.com/kubecost/kubecost.git
cd kubecost
helm dependency update ./kubecost
helm install kubecost ./kubecost \
  --namespace kubecost \
  --create-namespace
```

## Uninstall

Uninstall the chart:

```sh
helm uninstall kubecost-30-testing -n kubecost
```

Note that when uninstalling, the persistent volume for the Kubecost metrics are not deleted. You can delete them manually by deleting the namespace:

```sh
kubectl delete namespace kubecost
```
