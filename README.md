# Kubecost Helm Chart

This repository contains the Helm chart templates for the development of [Kubecost](https://www.kubecost.com/), an enterprise-grade application to monitor and manage Kubernetes spend. Please see the [website](https://www.kubecost.com/) for more details on what Kubecost can do for you and the official documentation [IBM Docs](https://www.ibm.com/docs/en/kubecost/self-hosted/3.x), or contact [team-kubecost@wwpdl.vnet.ibm.com](mailto:team-kubecost@wwpdl.vnet.ibm.com) for assistance.

## 3.0 Technical Overview

Kubecost strives to support as many versions of Kubernetes as possible. Below is the version support matrix which has been tested. Versions outside of the stated range may still work but are untested.

| Chart Version | Kubernetes Min | Kubernetes Max | Notes                                 |
|---------------|----------------|----------------|---------------------------------------|
| 2.8           | 1.22           | 1.34           | Final feature release of Kubecost 2.x |
| 2.9           | 1.22           | 1.34           | Intermediate step to upgrade to 3.x   |
| 3.0           | 1.29           | 1.34           | First release of Kubecost 3.x         |

### Migration path from 2.x to 3.x

In order to upgrade from Kubecost 2.x to 3.x, it is recommended that all agents be updated to 2.9 for two days prior to upgrading to 3.0. See <https://github.com/kubecost/kubecost/tree/v2.9/examples> for how to upgrade to 2.9 before upgrading to 3.0.

> Note: With the exception of the diagnostics compatibility section below, the agent data is backwards compatible with Kubecost 2.x. Which means there is flexibility in the order of upgrades. For example, the primary does not need to be upgraded first, though it is recommended to do so.

### Key changes in 3.0

| Version | Database | Metrics Source |
|---------|----------|----------------|
| 2.x     | DuckDB | Prometheus |
| 3.0     | ClickHouse | Direct  |

Due to the new database, a complete re-ingestion of data will begin as soon as 3.x is installed. This will take anywhere from 20 minutes to 2 days to complete depending on the size of the dataset and performance of the storage backing the Persistent Volume. During this time, the UI will be available, but will show a progress indicator. Data will be imported from today and going backwards in time until the full history is available.

### Agent compatibility

A Kubecost 3.0 primary cluster is compatible with 2.x agents and newer.
3.0 has significant changes to the agent (previously called secondaries). The old agent container was called cost-model. The new agent is now called the finops-agent.

The new agent has major benefits over the old agent:

- 10 minute metric granularity (cluster/node group/container right-sizing)
- up to 50% less memory usage
- more diagnostics data

### Diagnostics compatibility

| Primary Cluster Version | Agent Version | Agent Diagnostics Available in UI | Notes |
|-------------------------|---------------|-----------------------------------|-------|
| 2.x                     | 2.x           | Yes               |       |
| 2.x                     | 3.x           | No                | 10m metric granularity is not supported       |
| 3.x                     | 2.x           | No                |       |
| 3.x                     | 3.x           | Yes               |       |

## Installation

To install the latest version of Kubecost via Helm, run the following command:

```sh
helm install kubecost \
  --repo https://kubecost.github.io/kubecost kubecost \
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
helm show values kubecost/kubecost --version 3.0.3
```

## Beta/Release Candidates and Nightly Builds

To install the beta/release candidates pass the `--devel` flag:

```sh
helm install kubecost \
  --repo https://kubecost.github.io/kubecost kubecost \
  --namespace kubecost --create-namespace \
  --devel
```

To install the nightly build, use the nightly-helm-chart repository:

```sh
helm install nightly \
  --repo https://kubecost.github.io/nightly-helm-chart kubecost \
  --namespace kubecost-nightly --create-namespace
```

## Features

### In-Place Pod Resize (New in 3.1+)

Kubecost now supports Kubernetes in-place pod resize for dynamic resource optimization without pod recreation. This feature enables:

- **Zero-downtime CPU adjustments**: Modify CPU resources without restarting containers
- **Controlled memory updates**: Adjust memory with optional container restarts
- **Cost optimization**: Right-size workloads based on actual usage patterns

**Requirements**: Kubernetes v1.33+ with `InPlacePodVerticalScaling` feature gate enabled (default in v1.35+)

For detailed configuration and usage, see the [In-Place Pod Resize Documentation](docs/inplace-pod-resize.md).

## Uninstall

Uninstall the chart:

```sh
helm uninstall kubecost -n kubecost
```

Note that when uninstalling, the persistent volume for the Kubecost metrics are not deleted. You can delete them manually by deleting the namespace:

```sh
kubectl delete namespace kubecost
```
