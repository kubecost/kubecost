# Kubecost Helm Chart Values

The following table lists commonly used configuration parameters for the Kubecost Helm chart and their default values. Please see the [values file](values.yaml) for the complete set of definable values.

| Parameter                                                                          | Description                                                                                                                                                  | Default                                               |
|------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| `ingress.enabled`                                                                  | If true, Ingress will be created                                                                                                                             | `false`                                               |
| `ingress.annotations`                                                              | Ingress annotations                                                                                                                                          | `{}`                                                  |
| `ingress.className`                                                                | Ingress class name                                                                                                                                           | `{}`                                                  |
| `ingress.paths`                                                                    | Ingress paths                                                                                                                                                | `["/"]`                                               |
| `ingress.hosts`                                                                    | Ingress hostnames                                                                                                                                            | `[kubecost.local]`                               |
| `ingress.tls`                                                                      | Ingress TLS configuration (YAML)                                                                                                                             | `[]`                                                  |
| `networkCosts.enabled`                                                             | If true, collect network allocation metrics [More info](https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=ui-network-monitoring)                                                         | `false`                                               |
| `networkCosts.podMonitor.enabled`                                                  | If true, a PodMonitor for the network-cost daemonset is created | `false`                                               |
| `serviceMonitor.enabled`                                                           | Set this to `true` to create ServiceMonitor for Prometheus operator                                                                                          | `false`                                               |
| `serviceMonitor.additionalLabels`                                                  | Additional labels that can be used so ServiceMonitor will be discovered by Prometheus                                                                        | `{}`                                                  |
| `serviceMonitor.relabelings`                                                       | Sets Prometheus metric_relabel_configs on the scrape job                                                                                                     | `[]`                                                  |
| `serviceMonitor.metricRelabelings`                                                 | Sets Prometheus relabel_configs on the scrape job                                                                                                            | `[]`                                                  |
| `serviceAccount.create`                                                            | Set this to `false` if you want to create the service account `kubecost-kubecost` on your own                                                           | `true`                                                |
| `tolerations`                                                                      | node taints to tolerate                                                                                                                                      | `[]`                                                  |
| `affinity`                                                                         | pod affinity                                                                                                                                                 | `{}`                                                  |
| `kubecostProductConfigs.productKey.mountPath`                                      | Use instead of `kubecostProductConfigs.productKey.secretname` to declare the path at which the product key file is mounted (eg. by a secrets provisioner)    | `N/A`                                                 |
| `frontend.api.fqdn`                                                        | Customize the upstream api FQDN                                                                                                                              | `computed in terms of the service name and namespace` |
| `frontend.model.fqdn`                                                      | Customize the upstream model FQDN                                                                                                                            | `computed in terms of the service name and namespace` |
| `clusterController.fqdn`                                                           | Customize the upstream cluster controller FQDN                                                                                                               | `computed in terms of the service name and namespace` |

## Adjusting Log Output

You can adjust the log output by using the `logLevel` Helm value and/or the `LOG_FORMAT` environment variable.

### Adjusting Log Level

Adjusting the log level increases or decreases the level of verbosity written to the logs. The `logLevel` property accepts the following values:

* `trace`
* `debug`
* `info`
* `warn`
* `error`
* `fatal`

### Adjusting Log Format

Adjusting the log format changes the format in which the logs are output making it easier for log aggregators to parse and display logged messages. The `LOG_FORMAT` environment variable accepts the values `JSON`, for a structured output, and `pretty` for a nice, human-readable output.

| Value  | Output                                                                                                                     |
|--------|----------------------------------------------------------------------------------------------------------------------------|
| `JSON`   | `{"level":"info","time":"2006-01-02T15:04:05.999999999Z07:00","message":"Starting cost-model (git commit \"1.91.0-rc.0\")"}` |
| `pretty` | `2006-01-02T15:04:05.999999999Z07:00 INF Starting cost-model (git commit "1.91.0-rc.0")`                                     |

## Testing

To perform local testing:

* install locally [kind](https://github.com/kubernetes-sigs/kind) according to documentation.
* install locally [ct](https://github.com/helm/chart-testing) according to documentation.
* create local cluster using `kind` \
use image version from <https://github.com/kubernetes-sigs/kind/releases> e.g. `kindest/node:v1.25.11@sha256:227fa11ce74ea76a0474eeefb84cb75d8dad1b08638371ecf0e86259b35be0c8`

```shell
kind create cluster --image kindest/node:v1.25.11@sha256:227fa11ce74ea76a0474eeefb84cb75d8dad1b08638371ecf0e86259b35be0c8
```

* perform ct execution

```sh
ct install  --chart-dirs="." --charts="."
```
