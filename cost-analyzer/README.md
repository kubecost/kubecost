# Kubecost Helm chart

This is the official Helm chart for [Kubecost](https://www.kubecost.com/), an enterprise-grade application to monitor and manage Kubernetes spend. Please see the [website](https://www.kubecost.com/) for more details on what Kubecost can do for you and the official documentation [here](https://docs.kubecost.com/), or contact [team@kubecost.com](mailto:team@kubecost.com) for assistance.

To install via Helm, run the following command.

```sh
helm upgrade --install kubecost -n kubecost --create-namespace \
  --repo https://kubecost.github.io/cost-analyzer/ cost-analyzer \
  --set kubecostToken="aGVsbUBrdWJlY29zdC5jb20=xm343yadf98"
```

Alternatively, add the Helm repository first and scan for updates.

```sh
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update
```

Next, install the chart.

```sh
helm install kubecost kubecost/cost-analyzer -n kubecost --create-namespace \
  --set kubecostToken="aGVsbUBrdWJlY29zdC5jb20=xm343yadf98"
```

While Helm is the [recommended install path](http://kubecost.com/install) for Kubecost especially in production, Kubecost can alternatively be deployed with a single-file manifest using the following command. Keep in mind when choosing this method, Kubecost will be installed from a development branch and may include unreleased changes.

```sh
kubectl apply -f https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/develop/kubecost.yaml
```

The following table lists commonly used configuration parameters for the Kubecost Helm chart and their default values. Please see the [values file](values.yaml) for the complete set of definable values.

| Parameter                                                                          | Description                                                                                                                                                  | Default                                               |
|------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| `global.prometheus.enabled`                                                        | If false, use an existing Prometheus install. [More info](http://docs.kubecost.com/custom-prom).                                                             | `true`                                                |
| `prometheus.server.persistentVolume.enabled`                                       | If true, Prometheus server will create a Persistent Volume Claim.                                                                                            | `true`                                                |
| `prometheus.server.persistentVolume.size`                                          | Prometheus server data Persistent Volume size. Default set to retain ~6000 samples per second for 15 days.                                                   | `32Gi`                                                |
| `prometheus.server.retention`                                                      | Determines when to remove old data.                                                                                                                          | `15d`                                                 |
| `prometheus.server.resources`                                                      | Prometheus server resource requests and limits.                                                                                                              | `{}`                                                  |
| `prometheus.nodeExporter.resources`                                                | Node exporter resource requests and limits.                                                                                                                  | `{}`                                                  |
| `prometheus.nodeExporter.enabled` `prometheus.serviceAccounts.nodeExporter.create` | If false, do not crate NodeExporter daemonset.                                                                                                               | `true`                                                |
| `prometheus.alertmanager.persistentVolume.enabled`                                 | If true, Alertmanager will create a Persistent Volume Claim.                                                                                                 | `true`                                                |
| `prometheus.pushgateway.persistentVolume.enabled`                                  | If true, Prometheus Pushgateway will create a Persistent Volume Claim.                                                                                       | `true`                                                |
| `persistentVolume.enabled`                                                         | If true, Kubecost will create a Persistent Volume Claim for product config data.                                                                             | `true`                                                |
| `persistentVolume.size`                                                            | Define PVC size for cost-analyzer                                                                                                                            | `32.0Gi`                                              |
| `persistentVolume.dbSize`                                                          | Define PVC size for cost-analyzer's flat file database                                                                                                       | `32.0Gi`                                              |
| `ingress.enabled`                                                                  | If true, Ingress will be created                                                                                                                             | `false`                                               |
| `ingress.annotations`                                                              | Ingress annotations                                                                                                                                          | `{}`                                                  |
| `ingress.className`                                                                | Ingress class name                                                                                                                                           | `{}`                                                  |
| `ingress.paths`                                                                    | Ingress paths                                                                                                                                                | `["/"]`                                               |
| `ingress.hosts`                                                                    | Ingress hostnames                                                                                                                                            | `[cost-analyzer.local]`                               |
| `ingress.tls`                                                                      | Ingress TLS configuration (YAML)                                                                                                                             | `[]`                                                  |
| `networkPolicy.enabled`                                                            | If true, create a NetworkPolicy to deny egress                                                                                                               | `false`                                               |
| `networkPolicy.costAnalyzer.enabled`                                               | If true, create a newtork policy for cost-analzyer                                                                                                           | `false`                                               |
| `networkPolicy.costAnalyzer.annotations`                                           | Annotations to be added to the network policy                                                                                                                | `{}`                                                  |
| `networkPolicy.costAnalyzer.additionalLabels`                                      | Additional labels to be added to the network policy                                                                                                          | `{}`                                                  |
| `networkPolicy.costAnalyzer.ingressRules`                                          | A list of network policy ingress rules                                                                                                                       | `null`                                                |
| `networkPolicy.costAnalyzer.egressRules`                                           | A list of network policy egress rules                                                                                                                        | `null`                                                |
| `networkCosts.enabled`                                                             | If true, collect network allocation metrics [More info](http://docs.kubecost.com/network-allocation)                                                         | `false`                                               |
| `networkCosts.podMonitor.enabled`                                                  | If true, a [PodMonitor](https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#podmonitor) for the network-cost daemonset is created | `false`                                               |
| `serviceMonitor.enabled`                                                           | Set this to `true` to create ServiceMonitor for Prometheus operator                                                                                          | `false`                                               |
| `serviceMonitor.additionalLabels`                                                  | Additional labels that can be used so ServiceMonitor will be discovered by Prometheus                                                                        | `{}`                                                  |
| `serviceMonitor.relabelings`                                                       | Sets Prometheus metric_relabel_configs on the scrape job                                                                                                     | `[]`                                                  |
| `serviceMonitor.metricRelabelings`                                                 | Sets Prometheus relabel_configs on the scrape job                                                                                                            | `[]`                                                  |
| `prometheusRule.enabled`                                                           | Set this to `true` to create PrometheusRule for Prometheus operator                                                                                          | `false`                                               |
| `prometheusRule.additionalLabels`                                                  | Additional labels that can be used so PrometheusRule will be discovered by Prometheus                                                                        | `{}`                                                  |
| `grafana.resources`                                                                | Grafana resource requests and limits.                                                                                                                        | `{}`                                                  |
| `grafana.serviceAccount.create`                                                    | If true, create a Service Account for Grafana.                                                                                                               | `true`                                                |
| `grafana.serviceAccount.name`                                                      | Grafana Service Account name.                                                                                                                                | `{}`                                                  |
| `grafana.sidecar.datasources.defaultDatasourceEnabled`                             | Set this to `false` to disable creation of Prometheus datasource in Grafana                                                                                  | `true`                                                |
| `serviceAccount.create`                                                            | Set this to `false` if you want to create the service account `kubecost-cost-analyzer` on your own                                                           | `true`                                                |
| `tolerations`                                                                      | node taints to tolerate                                                                                                                                      | `[]`                                                  |
| `affinity`                                                                         | pod affinity                                                                                                                                                 | `{}`                                                  |
| `kubecostProductConfigs.productKey.mountPath`                                      | Use instead of `kubecostProductConfigs.productKey.secretname` to declare the path at which the product key file is mounted (eg. by a secrets provisioner)    | `N/A`                                                 |
| `kubecostFrontend.api.fqdn`                                                        | Customize the upstream api FQDN                                                                                                                              | `computed in terms of the service name and namespace` |
| `kubecostFrontend.model.fqdn`                                                      | Customize the upstream model FQDN                                                                                                                            | `computed in terms of the service name and namespace` |
| `clusterController.fqdn`                                                           | Customize the upstream cluster controller FQDN                                                                                                               | `computed in terms of the service name and namespace` |
| `global.grafana.fqdn`                                                              | Customize the upstream grafana FQDN                                                                                                                          | `computed in terms of the release name and namespace` |

## Adjusting Log Output

The log output can be customized during deployment by using the `LOG_LEVEL` and/or `LOG_FORMAT` environment variables.

### Adjusting Log Level

Adjusting the log level increases or decreases the level of verbosity written to the logs. To set the log level to `trace`, the following flag can be added to the `helm` command.

```sh
--set 'kubecostModel.extraEnv[0].name=LOG_LEVEL,kubecostModel.extraEnv[0].value=trace'
```

### Adjusting Log Format

Adjusting the log format changes the format in which the logs are output making it easier for log aggregators to parse and display logged messages. The `LOG_FORMAT` environment variable accepts the values `JSON`, for a structured output, and `pretty` for a nice, human-readable output.

| Value  | Output                                                                                                                     |
|--------|----------------------------------------------------------------------------------------------------------------------------|
| `JSON`   | `{"level":"info","time":"2006-01-02T15:04:05.999999999Z07:00","message":"Starting cost-model (git commit \"1.91.0-rc.0\")"}` |
| `pretty` | `2006-01-02T15:04:05.999999999Z07:00 INF Starting cost-model (git commit "1.91.0-rc.0")`                                     |

## Testing
To perform local testing do next:
- install locally [kind](https://github.com/kubernetes-sigs/kind) according to documentation.
- install locally [ct](https://github.com/helm/chart-testing) according to documentation.
- create local cluster using `kind` \
use image version from https://github.com/kubernetes-sigs/kind/releases e.g. `kindest/node:v1.25.11@sha256:227fa11ce74ea76a0474eeefb84cb75d8dad1b08638371ecf0e86259b35be0c8`
```shell
kind create cluster --image kindest/node:v1.25.11@sha256:227fa11ce74ea76a0474eeefb84cb75d8dad1b08638371ecf0e86259b35be0c8
```
- perform ct execution
```shell
ct install  --chart-dirs="." --charts="."
```

