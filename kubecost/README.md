# Kubecost Helm Chart Values

The following table lists commonly used configuration parameters for the Kubecost Helm chart and their default values. Please see the [values file](values.yaml) for the complete set of definable values.

Additionally, see the root of the chart for examples of commonly changed values ("values-\*.yaml").

| Parameter                                     | Description                                                                                                                                                         | Default                                               |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `ingress.enabled`                             | If true, Ingress will be created                                                                                                                                    | `false`                                               |
| `ingress.className`                           | Ingress class name                                                                                                                                                  | unset                                                 |
| `ingress.labels`                              | Ingress labels                                                                                                                                                      | `{}`                                                  |
| `ingress.annotations`                         | Ingress annotations                                                                                                                                                 | `{}`                                                  |
| `ingress.paths`                               | Ingress paths                                                                                                                                                       | `["/"]`                                               |
| `ingress.pathType`                            | Ingress path type                                                                                                                                                   | `ImplementationSpecific`                              |
| `ingress.hosts`                               | Ingress hostnames                                                                                                                                                   | `[kubecost.local]`                                    |
| `ingress.tls`                                 | Ingress TLS configuration (YAML)                                                                                                                                    | `[]`                                                  |
| `httpRoute.enabled`                           | If true, a Gateway API HTTPRoute is created using only `httpRoute.*` values (no ingress fallback). Install fails if `parentRefs` is empty or first ref has no name. | `false`                                               |
| `httpRoute.parentRefs`                        | Gateway API parentRefs (Gateway(s) to attach to). Required when `httpRoute.enabled` is true; must set at least one entry with `name`.                               | `[{ name: gateway }]`                                 |
| `httpRoute.labels`                            | HTTPRoute labels                                                                                                                                                    | `{}`                                                  |
| `httpRoute.annotations`                       | HTTPRoute annotations                                                                                                                                               | `{}`                                                  |
| `httpRoute.hostnames`                         | HTTPRoute hostnames for Host header matching                                                                                                                        | `[kubecost.local]`                                    |
| `httpRoute.paths`                             | HTTPRoute path matches                                                                                                                                              | `["/"]`                                               |
| `httpRoute.pathType`                          | Gateway API path type (PathPrefix, Exact, or RegularExpression)                                                                                                     | `PathPrefix`                                          |
| `networkCosts.enabled`                        | If true, collect network allocation metrics [More info](https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=ui-network-monitoring)                           | `true`                                                |
| `networkCosts.podMonitor.enabled`             | If true, a PodMonitor for the network-cost daemonset is created                                                                                                     | `false`                                               |
| `serviceMonitor.enabled`                      | Set this to `true` to create ServiceMonitor for Prometheus operator                                                                                                 | `false`                                               |
| `serviceMonitor.additionalLabels`             | Additional labels that can be used so ServiceMonitor will be discovered by Prometheus                                                                               | `{}`                                                  |
| `serviceMonitor.relabelings`                  | Sets Prometheus metric_relabel_configs on the scrape job                                                                                                            | `[]`                                                  |
| `serviceMonitor.metricRelabelings`            | Sets Prometheus relabel_configs on the scrape job                                                                                                                   | `[]`                                                  |
| `serviceAccount.create`                       | Set this to `false` if you want to create the service account `kubecost-kubecost` on your own                                                                       | `true`                                                |
| `tolerations`                                 | node taints to tolerate                                                                                                                                             | `[]`                                                  |
| `affinity`                                    | pod affinity                                                                                                                                                        | `{}`                                                  |
| `kubecostProductConfigs.productKey.mountPath` | Use instead of `kubecostProductConfigs.productKey.secretname` to declare the path at which the product key file is mounted (eg. by a secrets provisioner)           | `N/A`                                                 |
| `frontend.api.fqdn`                           | Customize the upstream api FQDN                                                                                                                                     | `computed in terms of the service name and namespace` |
| `frontend.model.fqdn`                         | Customize the upstream model FQDN                                                                                                                                   | `computed in terms of the service name and namespace` |
| `clusterController.fqdn`                      | Customize the upstream cluster controller FQDN                                                                                                                      | `computed in terms of the service name and namespace` |
| `mcp.enabled`                                 | If true, the FinOps MCP server (mcp-kubecost subchart) is deployed                                                                                                  | `true`                                                |
| `mcp.config.kubecostApiBaseUrl`               | Base URL the MCP server uses to reach the Kubecost aggregator                                                                                                       | `http://{{ .Release.Name }}-aggregator`               |
| `mcp.config.kubecostApiPort`                  | Aggregator port for MCP queries. Use `9008` to bypass Kubecost's API authentication                                                                                 | `9004`                                                |
| `mcp.config.kubecostApiBasePath`              | API base path on the aggregator (it serves at the root, unlike the frontend's `/model` prefix)                                                                      | `/`                                                   |
| `mcp.config.authMode`                         | Authentication for the MCP HTTP endpoint: `none`, `open`, `oidc`, or `api_key` [More info](https://github.com/kubecost/mcp-kubecost/tree/main/docs/auth)            | `none`                                                |
| `mcp.config.externalUrl`                      | Public origin (scheme and host, no path) advertised in OAuth metadata. Required when `authMode` is `oidc` and MCP is proxied through the frontend                   | `""`                                                  |
| `mcp.kubecostApiKey`                          | Outbound Kubecost API key sent as `X-API-KEY`. Prefer `existingSecret` over inline `value`                                                                          | `{value: "", existingSecret: "", key: KUBECOST_API_KEY}` |
| `mcp.httpRoute.enabled`                       | If true, the MCP server gets its own Gateway API HTTPRoute and the frontend stops proxying `/mcp`                                                                   | `false`                                               |
| `mcp.ingress.enabled`                         | If true, the MCP server gets its own Ingress and the frontend stops proxying `/mcp`                                                                                 | `false`                                               |

## MCP server

The chart deploys the [mcp-kubecost](https://github.com/kubecost/mcp-kubecost) FinOps MCP server as a subchart. The table above lists the values most commonly changed; see the [subchart values file](https://github.com/kubecost/mcp-kubecost/blob/main/charts/mcp-kubecost/values.yaml) for the full set.

- The MCP endpoint is fixed at `/mcp` and its OAuth endpoints at `/oauth/mcp`.
- The server is reachable in-cluster at `<release>-mcp:3030`, and by default the Kubecost frontend proxies both paths so MCP is available on the same hostname as the Kubecost UI.
- Enabling `mcp.httpRoute.enabled` or `mcp.ingress.enabled` gives the MCP server its own external route, and the frontend then stops proxying `/mcp` and `/oauth/mcp`. Either route requires `mcp.config.authMode` to be set.
- The MCP server reads cost data through the Kubecost aggregator service. If Kubecost is deployed with SAML or OIDC authentication, the MCP server needs its own OIDC configuration under `mcp.config.oidc`; when it has its own authentication, consider setting `mcp.config.kubecostApiPort` to `9008` to bypass Kubecost's API authentication.
- When using `authMode: oidc`, register `https://<mcp.config.externalUrl host>/oauth/mcp/callback` as the redirect URI at the IdP. Leave `externalUrl` empty when the MCP server has its own ingress or HTTPRoute; the subchart infers it from that hostname.

## Testing

To perform local testing:

- Any test cluster works, e.g. [kind](https://github.com/kubernetes-sigs/kind)
- Use chart-testing to run ct (below) [ct](https://github.com/helm/chart-testing)

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
