# Multi-cluster guide: Kubecost 2.x prep before upgrading to 3.0

Kubecost 3.0 introduces a new agent that removes the dependency on Prometheus. Because of this, steps must be taken to prevent a partial-day data-loss when upgrading. If the steps below are not followed, the data of the current day (UTC) prior to the upgrade will be lost when upgrading.

For net new clusters, this 2.9 release is not required, though it will work.

> Note: the primary cluster often runs the agent (cost-analyzer) in the same namespace, the values here can also be used for this configuration.

## Procedure

There are two values that will need to be modified before upgrading to 2.9, which also match what is used 3.0.

> The example here shows the minimum required values, you should keep all of the other values in your current values file.

1. Move the old `prometheus.server.global.external_labels.cluster_id` to `global.clusterId`
2. Move the federated storage configuration from the `kubecostModel` section to the `global` section.
3. If your existing Kubecost deployment uses an assumed role (opposed to an IAM user/key), you will need to configure the finops-agent to use the existing service account. In the values provided, uncomment the `serviceAccount` and `finops-agent` sections and set the `name` to the name of the service account used by the cost-analyzer pod.
![settings migration]](settings-migration-2.9.png)
4. Upgrade to 2.9.x

```bash
helm upgrade kubecost -n kubecost \
  --repo https://kubecost.github.io/cost-analyzer/ cost-analyzer \
  -f helmValues-kubecost2.9-agent-only.yaml
```

5. Verify that all pods are running, including a new finops-agent pod.
6. The finops-agent must run for 2 days before upgrading to 3.x. You can run 2.9 for as long as needed, though more PVC storage may be required if running for longer than 30 days.

For more information on the 3.0 upgrade process see [https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=installation](IBM docs)
Note that by following the above process, a parallel installation will not be needed.
