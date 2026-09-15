# Kubecost Helm Chart

This repository contains the Helm chart templates for the development of [Kubecost](https://www.kubecost.com/), an enterprise-grade application to monitor and manage Kubernetes spend. Please see the [website](https://www.kubecost.com/) for more details on what Kubecost can do for you and the official documentation [IBM Docs](https://www.ibm.com/docs/en/kubecost/self-hosted/3.x), or contact [team-kubecost@wwpdl.vnet.ibm.com](mailto:team-kubecost@wwpdl.vnet.ibm.com) for assistance.

## 3.x Technical Overview

### Agent compatibility

Upgrade order: The Kubecost Primary should be upgraded before the agents. If the agents are upgraded first, no data is lost; however, the new agent data will remain incompatible with the primary cluster until the primary is upgraded, after which the queued agent data will be processed.

A Kubecost 3.x primary cluster is compatible with 2.x agents and newer.

### Migration path from 2.x to 3.x

In order to upgrade from Kubecost 2.x to 3.x, it is recommended that all agents be updated to 2.9 for two days prior to upgrading to 3.0. See <https://github.com/kubecost/kubecost/tree/v2.9/examples> for how to upgrade to 2.9 before upgrading to 3.x.

> Note: With the exception of the diagnostics compatibility section below, the agent data is backwards compatible with Kubecost 2.x. Which means there is flexibility in the order of upgrades.

### Key changes in 3.0

| Version | Database   | Metrics Source |
| ------- | ---------- | -------------- |
| 2.x     | DuckDB     | Prometheus     |
| 3.0     | ClickHouse | Direct         |

Due to the new database in 3.x, a complete re-ingestion of data will begin as soon as 3.x is installed. This will take anywhere from 20 minutes to 2 days to complete depending on the size of the dataset and performance of the storage backing the Persistent Volume. During this time, the UI will be available, but will show a progress indicator. Data will be imported from today and going backwards in time until the full history is available.

3.x has significant changes to the agent (previously called secondaries). The old agent container was called `cost-model`. The new agent is the `finops-agent`, delivered as a sub-chart (`finopsagent`).

The new agent has major benefits over the old agent:

- 10 minute metric granularity (cluster/node group/container right-sizing)
- Up to 50% less memory usage
- More diagnostics data

### Diagnostics compatibility

| Primary Cluster Version | Agent Version | Agent Diagnostics Available in UI | Notes                                   |
| ----------------------- | ------------- | --------------------------------- | --------------------------------------- |
| 2.x                     | 2.x           | Yes                               |                                         |
| 2.x                     | 3.x           | No                                | 10m metric granularity is not supported |
| 3.x                     | 2.x           | No                                |                                         |
| 3.x                     | 3.x           | Yes                               |                                         |

## Sub-charts

| Sub-chart      | Alias         | Default            | Description                                                                                           |
| -------------- | ------------- | ------------------ | ----------------------------------------------------------------------------------------------------- |
| `finops-agent` | `finopsagent` | enabled            | Lightweight agent for collecting metrics from the clusters                                            |
| `mcp-kubecost` | `mcp`         | follows aggregator | FinOps MCP server — exposes Kubecost analytics via the Model Context Protocol at `<release>-mcp:3030` |

The MCP server deploys when `aggregator.enabled` is true unless `mcp.enabled` is set. It is proxied through the Kubecost frontend at `/mcp`. Set `mcp.config.authMode` before exposing it outside the cluster. See [mcp-kubecost](https://github.com/kubecost/mcp-kubecost) for full configuration options.

## Installation

To install the latest version of Kubecost via Helm, run the following command:

```sh
helm install kubecost \
  --repo https://kubecost.github.io/kubecost kubecost \
  --namespace kubecost --create-namespace \
  --set global.clusterId=GLOBALLY_UNIQUE_CLUSTER_ID
```

Alternatively, add the Helm repository first and scan for updates:

```sh
helm repo add kubecost https://kubecost.github.io/kubecost/
helm repo update
helm install kubecost kubecost/kubecost \
  --namespace kubecost --create-namespace \
  --set global.clusterId=GLOBALLY_UNIQUE_CLUSTER_ID
```

The default branch of this repository is the `develop` branch. This branch is not stable and is subject to change. Please use the following command to show values available for the chart you are using:

```sh
helm show values kubecost/kubecost --version VERSION
```

## Beta/Release Candidates and Nightly Builds

To upgrade to the latest beta/release candidates pass the `--devel` flag:

```sh
helm upgrade kubecost \
  --repo https://kubecost.github.io/kubecost kubecost \
  --namespace kubecost \
  --devel
```

To install the nightly build, use the nightly-helm-chart repository:

```sh
helm install nightly \
  --repo https://kubecost.github.io/nightly-helm-chart kubecost \
  --namespace kubecost-nightly --create-namespace \
  --set global.clusterId=GLOBALLY_UNIQUE_CLUSTER_ID
```

## Example Configurations

The [`examples/`](examples/) directory contains reference values files for common deployment patterns:

- [`examples/agentOnly/`](examples/agentOnly/) — agent-only (secondary cluster) values for AWS, Azure, and GCP
- [`examples/federatedStorage/`](examples/federatedStorage/) — multi-cluster federated storage configurations

See [`examples/README.md`](examples/README.md) for usage guidance.

## Uninstall

Uninstall the chart:

```sh
helm uninstall kubecost --namespace kubecost
```

Persistent volumes are not deleted on uninstall. To remove them, delete the namespace:

```sh
kubectl delete namespace kubecost
```
