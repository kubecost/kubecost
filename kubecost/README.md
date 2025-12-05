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

## Testing

To perform local testing:

* Any test cluster works, e.g. [kind](https://github.com/kubernetes-sigs/kind)
* Use chart-testing to run ct (below) [ct](https://github.com/helm/chart-testing)

This will install kubecost in a chart-testing namespace and run the tests. Note that some clusters may not support all features, in the example below we disable network costs.

```sh
ct lint-and-install \
    --chart-dirs=./kubecost \
    --charts=./kubecost \
    --validate-maintainers=false \
    --namespace=kubecost-chart-testing \
    --helm-extra-set-args "--set networkCosts.enabled=false --create-namespace"
```

If successful, you should see the following output:

```sh
All charts linted and installed successfully
```
