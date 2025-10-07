# Kubecost Helm chart

This repository contains the Helm chart templates for the development of [Kubecost](https://www.kubecost.com/), an enterprise-grade application to monitor and manage Kubernetes spend. Please see the [website](https://www.kubecost.com/) for more details on what Kubecost can do for you and the official documentation [IBM Docs](https://www.ibm.com/docs/en/kubecost/self-hosted/2.x), or contact [team-kubecost@wwpdl.vnet.ibm.com](mailto:team-kubecost@wwpdl.vnet.ibm.com) for assistance.

## Version Support

Kubecost strives to support as many versions of Kubernetes as possible. Below is the version support matrix which has been tested. Versions outside of the stated range may still work but are untested.

| Chart Version                  | Kubernetes Min | Kubernetes Max |
|--------------------------------|----------------|----------------|
| 2.7                            | 1.22           | 1.32           |
| 2.8                            | 1.22           | 1.33           |

## Installation

To install the latest version of Kubecost via Helm, run the following command:

```sh
helm install kubecost kubecost \
  --repo https://kubecost.github.io/kubecost \
  --namespace kubecost --create-namespace \
  --set global.clusterId=someclustername
```

Alternatively, add the Helm repository first and scan for updates:

```sh
helm repo add kubecost https://kubecost.github.io/kubecost/
helm repo update
helm install kubecost kubecost/kubecost -n kubecost --create-namespace
```

The default branch of this repository is the `develop` branch. This branch is not stable and is subject to change. Please use the following command to show values available for the chart you are using:

```sh
helm show values kubecost/kubecost --version 3.0.0
```

## Beta/Release Candidates and Nightly Builds

To install the beta/release candidates pass the `--devel` flag:

```sh
helm install kubecost kubecost \
  --repo https://kubecost.github.io/kubecost \
  --namespace kubecost --create-namespace \
  --devel
```

To install the nightly build, use the nightly-helm-chart repository:

```sh
helm install nightly kubecost \
  --repo https://kubecost.github.io/nightly-helm-chart \
  --namespace kubecost-nightly --create-namespace
```

## Uninstall

Uninstall the chart:

```sh
helm uninstall kubecost -n kubecost
```

Note that when uninstalling, the persistent volume for the Kubecost metrics are not deleted. You can delete them manually by deleting the namespace:

```sh
kubectl delete namespace kubecost
```
