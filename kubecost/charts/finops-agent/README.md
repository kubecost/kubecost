<!--- app-name: IBM FinOps Agent&trade; IBM FinOps Agent&trade; -->

# Helm Chart for the IBM FinOps Agent

This helm chart deploys the IBM FinOps Agent, which supports both Cloudability and Kubecost.

## TL;DR

```sh
helm repo add ibm-finops https://kubecost.github.io/finops-agent-chart
helm install ibm-finops-agent ibm-finops/finops-agent \
  --set global.clusterId="globally-unique-cluster-id"
```

Or a one-liner:

```sh
helm install ibm-finops-agent \
  --repo https://kubecost.github.io/finops-agent-chart finops-agent \
  --set global.clusterId="globally-unique-cluster-id"
```

## Introduction

This chart bootstraps an IBM FinOps Agent deployment on a [Kubernetes](https://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installing the Chart](#installing-the-chart)
- [Configuration and installation details](#configuration-and-installation-details)
- [Parameters](#parameters)

## Prerequisites

- Kubernetes 1.31+
- Helm 3.8.0+
- PV provisioner support in the underlying infrastructure

## Installing the Chart

To install the chart with the release name `ibm-finops-agent`:

```sh
helm repo add ibm-finops https://kubecost.github.io/finops-agent-chart
helm install ibm-finops-agent ibm-finops/finops-agent \
  --set global.clusterId="globally-unique-cluster-id"
```

These commands deploy the FinOps Agent on the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Configuration and installation details

### FinOps Agent pod Service

This chart installs a deployment with the following configuration:

```text
                 ----------------
                |  FinOps Agent  |
                |      svc       |
                 ----------------
                        |
                        \/
                  --------------
                 | FinOps Agent |
                 |     Pod      |
                  --------------
```

The service is used primarily to provide diagnostics information and a scrape target. The FinOps Agent itself does not provide data querying, that is supported by the suite of IBM products that utilize the agent data.

### Configure the Federated Storage

The IBM FinOps Agent can collect and store limited data on its local storage. To be viewed and used for FinOps activities, however, the data must be uploaded to an federated object store so that it can be consumed by products in the IBM FinOps suite like Cloudability and Kubecost.

The bucket secret syntax itself is specified further in TODO - INSERT LINK

To provide a secret, see the `federatedStorage` settings in the parameters section. The chart allows the user to provide an already installed secret via the `.Values.global.federatedStorage.existingSecret` parameter. Alternatively setting `.Values.federatedStorage.config` will create a secret with the provided config value in it.

### Resource requests and limits

Bitnami charts allow setting resource requests and limits for all containers inside the chart deployment. These are inside the `resources` value (check parameter table). Setting requests is essential for production workloads and these should be adapted to your specific use case.

To make this process easier, the chart contains the `resourcesPreset` values, which automatically sets the `resources` section according to different presets. Check these presets in [the bitnami/common chart](https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15). However, in production workloads using `resourcesPreset` is discouraged as it may not fully adapt to your specific needs. Find more information on container resource management in the [official Kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).

### Prometheus metrics

This chart can be integrated with Prometheus by setting `metrics.enabled` to `true`. This will add the required annotations on the FinOps Agent service to be automatically scraped by Prometheus.

#### Prometheus requirements

It is necessary to have a working installation of Prometheus or Prometheus Operator for the integration to work. Install the [Bitnami Prometheus helm chart](https://github.com/bitnami/charts/tree/main/bitnami/prometheus) or the [Bitnami Kube Prometheus helm chart](https://github.com/bitnami/charts/tree/main/bitnami/kube-prometheus) to easily have a working Prometheus in your cluster.

#### Integration with Prometheus Operator

The chart can deploy `ServiceMonitor` objects for integration with Prometheus Operator installations. To do so, set the value `metrics.serviceMonitor.enabled=true`. Ensure that the Prometheus Operator `CustomResourceDefinitions` are installed in the cluster or it will fail with the following error:

```text
no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
```

### Adding extra environment variables

In case you want to add extra environment variables, you can use the `extraEnvVars` property.

```yaml
extraEnvVars:
  - name: MY_EXTRA_ENV_VAR
    value: "true"
```

### Setting Pod's affinity

This chart allows you to set your custom affinity using the `affinity` parameter(s). Find more information about Pod's affinity in the [kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity).

As an alternative, you can use of the preset configurations for pod affinity, pod anti-affinity, and node affinity available at the [bitnami/common](https://github.com/bitnami/charts/tree/main/bitnami/common#affinities) chart. To do so, set the `podAffinityPreset`, `podAntiAffinityPreset`, or `nodeAffinityPreset` parameters.

## Persistence

Local data can be persisted by default using PVC(s), to survive restarts until uploaded to bucket storage. You can disable the persistence setting the `persistence.enabled` parameter to `false`.

A default `StorageClass` is needed in the Kubernetes cluster to dynamically provision the volumes. Specify another StorageClass in the `persistence.storageClass` or set `persistence.existingClaim` if you have already existing persistent volumes to use.

## Parameters

### Global parameters

| Name                                                  | Description                                                                                                                                                                                                                                                                                                                                                         | Value   |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `global.clusterId`                                    | The globally unique id of the cluster. Consider appending the region if using the same cluster name in multiple regions.                                                                                                                                                                                                                                                                                                                                              | `""`    |
| `global.imageRegistry`                                | Global Docker image registry                                                                                                                                                                                                                                                                                                                                        | `""`    |
| `global.imagePullSecrets`                             | Global Docker registry secret names as an array                                                                                                                                                                                                                                                                                                                     | `[]`    |
| `global.defaultStorageClass`                          | Global default StorageClass for Persistent Volume(s)                                                                                                                                                                                                                                                                                                                | `""`    |
| `global.security.allowInsecureImages`                 | Allows skipping image verification                                                                                                                                                                                                                                                                                                                                  | `false` |
| `global.compatibility.openshift.adaptSecurityContext` | Adapt the securityContext sections of the deployment to make them compatible with Openshift restricted-v2 SCC: remove runAsUser, runAsGroup and fsGroup and let the platform use their allowed default IDs. Possible values: auto (apply if the detected running cluster is Openshift), force (perform the adaptation always), disabled (do not perform adaptation) | `auto`  |
| `global.federatedStorage.config`                      | The config for the federated storage                                                                                                                                                                                                                                                                                                                                | `""`    |
| `global.federatedStorage.existingSecret`              | The name of an existing secret to use for the federated storage config. Note, you cannot set both `config` and `existingSecret`.                                                                                                                                                                                                                                    | `""`    |

### Common parameters

| Name                | Description                                                                                                                                               | Value           |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| `kubeVersion`       | Override Kubernetes version                                                                                                                               | `""`            |
| `apiVersions`       | Override Kubernetes API versions reported by .Capabilities                                                                                                | `[]`            |
| `nameOverride`      | String to partially override common.names.name                                                                                                            | `""`            |
| `fullnameOverride`  | String to fully override common.names.fullname                                                                                                            | `""`            |
| `namespaceOverride` | String to fully override common.names.namespace. This would be used to deploy the finops-agent resources to a different namespace than the release itself | `""`            |
| `clusterDomain`     | Default Kubernetes cluster domain                                                                                                                         | `cluster.local` |
| `commonAnnotations` | Annotations to add to all deployed objects                                                                                                                | `{}`            |
| `commonLabels`      | Labels to add to all deployed objects                                                                                                                     | `{}`            |
| `extraDeploy`       | Array of extra objects to deploy with the release                                                                                                         | `[]`            |
| `useHelmHooks`      | Enable use of Helm hooks if needed, e.g. on pre-install jobs                                                                                              | `true`          |

### IBM FinOps Agent Core parameters

| Name                                                 | Description                                                                                                                                                                                | Value                                          |
|------------------------------------------------------| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| `image.registry`                                     | IBM FinOps Agent image registry                                                                                                                                                            | `icr.io`                                       |
| `image.repository`                                   | IBM FinOps Agent image repository                                                                                                                                                          | `ibm-finops/agent`                             |
| `image.digest`                                       | IBM FinOps Agent image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag                                                                           | `""`                                           |
| `image.pullPolicy`                                   | IBM FinOps Agent image pull policy                                                                                                                                                         | `IfNotPresent`                                 |
| `image.pullSecrets`                                  | Specify docker-registry secret names as an array                                                                                                                                           | `[]`                                           |
| `image.debug`                                        | Specify if debug logs should be enabled                                                                                                                                                    | `false`                                        |
| `fullImageName`                                      | If set, this will override the image name and tag.                                                                                                                                         | `""`                                           |
| `cspPricingApiKey.existingSecret`                    | The name of an existing secret to use for the GCP API key. If this is set, the secret will be used. Leave empty to create a new secret.                                                    | `""`                                           |
| `cspPricingApiKey.apiKey`                            | The GCP API key value. If this is set, the secret will be created. Leave empty to use an existing secret.                                                                                  | `""`                                           |
| `cspPricingApiKey.useDefaultApiKey`                  | When true, the default GCP API key will be used.                                                                                                                                          | `true`                                         |
| `logLevel`                                           | The log level for the finops agent                                                                                                                                                         | `info`                                         |
| `federatedStorage.config`                            | The config for the federated storage                                                                                                                                                       | `""`                                           |
| `federatedStorage.existingSecret`                    | The name of an existing secret to use for the federated storage config. Note, you cannot set both `config` and `existingSecret`.                                                           | `""`                                           |
| `agent.collectorDataSource.enabled`                  | Enable the collector data source                                                                                                                                                           | `true`                                         |
| `agent.collectorDataSource.scrapeInterval`           | The scrape interval for the collector data source                                                                                                                                          | `30s`                                          |
| `agent.collectorDataSource.networkPort`              | The network port for the collector data source                                                                                                                                             | `3001`                                         |
| `agent.collectorDataSource.retention10m`             | The number of 10m samples to retain for querying. The default of 6 captures 1h of historical data at 10m resolution.                                                                       | `6`                                            |
| `agent.collectorDataSource.retention1h`              | The number of 1h samples to retain for querying. The default of 3 captures 3h of historical data at 1h resolution.                                                                         | `3`                                            |
| `agent.collectorDataSource.retention1d`              | The number of 1d samples to retain for querying. The default of 2 captures 2d of historical data at 1d resolution.                                                                         | `2`                                            |
| `agent.exporter.emissionInterval`                    | A duration string of how often the core agent exporter will emit new data snapshots to the enabled emitters.                                                                               | `1m`                                           |
| `agent.cloudability.enabled`                         | Enable the cloudability data source                                                                                                                                                        | `false`                                        |
| `agent.cloudability.pathToCloudabilitySecrets`       | the path to the location on the filesystem the cloudability secrets are stored                                                                                                             | `/opt/cloudability`                            |
| `agent.cloudability.keyAccessFile`                   | the name of the keyAccessFile                                                                                                                                                              | `CLOUDABILITY_KEY_ACCESS`                      |
| `agent.cloudability.keySecretFile`                   | the name of the keySecretFile                                                                                                                                                              | `CLOUDABILITY_KEY_SECRET`                      |
| `agent.cloudability.envIDFile`                       | the name of the envIDFile                                                                                                                                                                  | `CLOUDABILITY_ENV_ID`                          |
| `agent.cloudability.localWorkingDir`                 | The local working directory for the cloudability data source                                                                                                                               | `/tmp`                                         |
| `agent.cloudability.uploadRegion`                    | The upload region for the cloudability data source                                                                                                                                         | `us`                                           |
| `agent.cloudability.httpsClientTimeout`              | Amount (in seconds) of time the http client has before timing out requests. Might need to be increased to clusters with large payloads.                                                    | `60`                                           |
| `agent.cloudability.uploadRetryCount`                | Number of attempts the agent will retry to upload a payload                                                                                                                                | `5`                                            |
| `agent.cloudability.outboundProxyInsecure`           | When true, does not verify certificates when making TLS connections.                                                                                                                       | `false`                                        |
| `agent.cloudability.parseMetricData`                 | When true, core files will be parsed and non-relevant data will be removed prior to upload.                                                                                                | `false`                                        |
| `agent.cloudability.emissionInterval`                | A duration string of how often samples are emitted to the cloudability uploader                                                                                                            | `3m`                                           |
| `agent.cloudability.outboundProxy`                   | The URL of an outbound HTTP/HTTPS proxy for the agent to use (eg: <http://x.x.x.x:8080>). The URL must contain the scheme prefix (http:// or https://)                                       | `""`                                           |
| `agent.cloudability.outboundProxyAuth`               | Basic Authentication credentials to be used with the defined outbound proxy. If your outbound proxy requires basic authentication credentials can be defined in the form username:password | `""`                                           |
| `agent.cloudability.useProxyForGettingUploadURLonly`               | When true, the cloudability client will only use the proxy for clusters/upload and frontdoor apikey login | `false`                                           |
| `agent.cloudability.customS3UploadBucket`            | S3 bucket for custom uploading agent                                                                                                                                                       | `""`                                           |
| `agent.cloudability.customS3UploadRegion`            | S3 region for custom uploading agent                                                                                                                                                       | `""`                                           |
| `agent.cloudability.customAzureBlobContainerName`    | Azure blob name for custom uploading agent                                                                                                                                                 | `""`                                           |
| `agent.cloudability.customAzureBlobURL`              | Azure blob url for custom uploading agent                                                                                                                                                  | `""`                                           |
| `agent.cloudability.customAzureTenantID`             | Azure tenantID for custom uploading agent                                                                                                                                                  | `""`                                           |
| `agent.cloudability.customAzureClientID`             | Azure clientID for custom uploading agent                                                                                                                                                  | `""`                                           |
| `agent.cloudability.customAzureBlobClientSecretFile` | the name of the customAzureBlobClientSecretFile                                                                                                                                            | `CLOUDABILITY_CUSTOM_AZURE_BLOB_CLIENT_SECRET` |
| `agent.cloudability.secret.existingSecret`           | The name of an existing secret to use for the cloudability data source. Note, you cannot set both `create` and `existingSecret`.                                                           | `""`                                           |
| `agent.cloudability.secret.create`                   | Create a secret for the cloudability data source. cannot be used with existingSecret                                                                                                       | `true`                                         |
| `agent.cloudability.secret.cloudabilityAccessKey`    | The cloudability access key for the cloudability data source                                                                                                                               | `""`                                           |
| `agent.cloudability.secret.cloudabilitySecretKey`    | The cloudability secret key for the cloudability data source                                                                                                                               | `""`                                           |
| `agent.cloudability.secret.cloudabilityEnvId`        | The cloudability env id for the cloudability data source                                                                                                                                   | `""`                                           |
| `agent.cloudability.secret.customAzureClientSecret`  | The cloudability client secret for azure blob upload                                                                                                                                       | `""`                                           |
| `command`                                            | Override default container command (useful when using custom images)                                                                                                                       | `[]`                                           |
| `args`                                               | Override default container args (useful when using custom images)                                                                                                                          | `[]`                                           |
| `extraEnvVars`                                       | Array with extra environment variables to add to the FinOps Agent container                                                                                                                | `[]`                                           |
| `extraEnvVarsCM`                                     | Name of existing ConfigMap containing extra env vars for the FinOps Agent container                                                                                                        | `""`                                           |
| `extraEnvVarsSecret`                                 | Name of existing Secret containing extra env vars for the FinOps Agent container                                                                                                           | `""`                                           |
| `containerPorts.http`                                | The FinOps Agent container HTTP port                                                                                                                                                       | `9003`                                         |
| `extraContainerPorts`                                | Optionally specify extra list of additional ports for the FinOps Agent container                                                                                                           | `[]`                                           |
| `resourcesPreset`                                    | Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if resources is set.                    | `small`                                        |
| `resources`                                          | Set container requests and limits for different resources like CPU or memory, if the presents won't work                                                                                   | `{}`                                           |
| `podSecurityContext.enabled`                         | Enable the FinOps Agent pod's Security Context                                                                                                                                             | `true`                                         |
| `podSecurityContext.fsGroupChangePolicy`             | Set filesystem group change policy                                                                                                                                                         | `Always`                                       |
| `podSecurityContext.sysctls`                         | Set kernel settings using the sysctl interface                                                                                                                                             | `[]`                                           |
| `podSecurityContext.supplementalGroups`              | Set filesystem extra groups                                                                                                                                                                | `[]`                                           |
| `podSecurityContext.fsGroup`                         | Set the FinOps Agent pod's Security Context fsGroup                                                                                                                                        | `1001`                                         |
| `containerSecurityContext.enabled`                   | Enable container Security Context                                                                                                                                                          | `true`                                         |
| `containerSecurityContext.seLinuxOptions`            | Set SELinux options in container                                                                                                                                                           | `{}`                                           |
| `containerSecurityContext.runAsUser`                 | Set containers' Security Context runAsUser                                                                                                                                                 | `1001`                                         |
| `containerSecurityContext.runAsGroup`                | Set containers' Security Context runAsGroup                                                                                                                                                | `1001`                                         |
| `containerSecurityContext.runAsNonRoot`              | Set container's Security Context runAsNonRoot                                                                                                                                              | `true`                                         |
| `containerSecurityContext.privileged`                | Set container's Security Context privileged                                                                                                                                                | `false`                                        |
| `containerSecurityContext.readOnlyRootFilesystem`    | Set container's Security Context readOnlyRootFilesystem                                                                                                                                    | `true`                                         |
| `containerSecurityContext.allowPrivilegeEscalation`  | Set container's Security Context allowPrivilegeEscalation                                                                                                                                  | `false`                                        |
| `containerSecurityContext.capabilities.drop`         | List of capabilities to be dropped                                                                                                                                                         | `["ALL"]`                                      |
| `containerSecurityContext.seccompProfile.type`       | Set container's Security Context seccomp profile                                                                                                                                           | `RuntimeDefault`                               |
| `startupProbe.enabled`                               | Enable startupProbe on the container                                                                                                                                                       | `false`                                        |
| `startupProbe.initialDelaySeconds`                   | Initial delay seconds for startupProbe                                                                                                                                                     | `10`                                           |
| `startupProbe.periodSeconds`                         | Period seconds for startupProbe                                                                                                                                                            | `10`                                           |
| `startupProbe.timeoutSeconds`                        | Timeout seconds for startupProbe                                                                                                                                                           | `1`                                            |
| `startupProbe.failureThreshold`                      | Failure threshold for startupProbe                                                                                                                                                         | `3`                                            |
| `startupProbe.successThreshold`                      | Success threshold for startupProbe                                                                                                                                                         | `1`                                            |
| `livenessProbe.enabled`                              | Enable livenessProbe on FinOps Agent container                                                                                                                                             | `true`                                         |
| `livenessProbe.initialDelaySeconds`                  | Initial delay seconds for livenessProbe                                                                                                                                                    | `60`                                           |
| `livenessProbe.periodSeconds`                        | Period seconds for livenessProbe                                                                                                                                                           | `10`                                           |
| `livenessProbe.timeoutSeconds`                       | Timeout seconds for livenessProbe                                                                                                                                                          | `1`                                            |
| `livenessProbe.failureThreshold`                     | Failure threshold for livenessProbe                                                                                                                                                        | `3`                                            |
| `livenessProbe.successThreshold`                     | Success threshold for livenessProbe                                                                                                                                                        | `1`                                            |
| `readinessProbe.enabled`                             | Enable readinessProbe on FinOps Agent container                                                                                                                                            | `true`                                         |
| `readinessProbe.initialDelaySeconds`                 | Initial delay seconds for readinessProbe                                                                                                                                                   | `10`                                           |
| `readinessProbe.periodSeconds`                       | Period seconds for readinessProbe                                                                                                                                                          | `10`                                           |
| `readinessProbe.timeoutSeconds`                      | Timeout seconds for readinessProbe                                                                                                                                                         | `1`                                            |
| `readinessProbe.failureThreshold`                    | Failure threshold for readinessProbe                                                                                                                                                       | `3`                                            |
| `readinessProbe.successThreshold`                    | Success threshold for readinessProbe                                                                                                                                                       | `1`                                            |
| `customStartupProbe`                                 | Override default startup probe                                                                                                                                                             | `{}`                                           |
| `customLivenessProbe`                                | Override default liveness probe                                                                                                                                                            | `{}`                                           |
| `customReadinessProbe`                               | Override default readiness probe                                                                                                                                                           | `{}`                                           |
| `podAffinityPreset`                                  | FinOps Agent Pod affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                           | `""`                                           |
| `podAntiAffinityPreset`                              | FinOps Agent Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                      | `soft`                                         |
| `nodeAffinityPreset.type`                            | FinOps Agent Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                     | `""`                                           |
| `nodeAffinityPreset.key`                             | FinOps Agent Node label key to match Ignored if `affinity` is set.                                                                                                                         | `""`                                           |
| `nodeAffinityPreset.values`                          | FinOps Agent Node label values to match. Ignored if `affinity` is set.                                                                                                                     | `[]`                                           |
| `affinity`                                           | FinOps Agent Affinity for pod assignment                                                                                                                                                   | `{}`                                           |
| `nodeSelector`                                       | FinOps Agent Node labels for pod assignment                                                                                                                                                | `{}`                                           |
| `tolerations`                                        | FinOps Agent Tolerations for pod assignment                                                                                                                                                | `[]`                                           |
| `podAnnotations`                                     | Annotations for FinOps Agent pod                                                                                                                                                           | `{}`                                           |
| `podLabels`                                          | Extra labels for FinOps Agent pod                                                                                                                                                          | `{}`                                           |
| `hostAliases`                                        | FinOps Agent pods host aliases                                                                                                                                                             | `[]`                                           |
| `updateStrategy.type`                                | FinOps Agent deployment strategy type                                                                                                                                                      | `Recreate`                                     |
| `priorityClassName`                                  | FinOps Agent pods' priorityClassName                                                                                                                                                       | `""`                                           |
| `revisionHistoryLimit`                               | FinOps Agent deployment revision history limit                                                                                                                                             | `10`                                           |
| `schedulerName`                                      | Name of the k8s scheduler (other than default)                                                                                                                                             | `""`                                           |
| `topologySpreadConstraints`                          | Topology Spread Constraints for pod assignment                                                                                                                                             | `[]`                                           |
| `lifecycleHooks`                                     | for the FinOps Agent container(s) to automate configuration before or after startup                                                                                                        | `{}`                                           |
| `extraVolumeMounts`                                  | Optionally specify extra list of additional volumeMounts for the FinOps Agent pods                                                                                                         | `[]`                                           |
| `extraVolumes`                                       | Optionally specify extra list of additional volumes for the FinOps Agent pods                                                                                                              | `[]`                                           |
| `sidecars`                                           | Add additional sidecar containers to the FinOps Agent pod(s)                                                                                                                               | `[]`                                           |
| `initContainers`                                     | Add additional init-containers to the FinOps Agent pod(s)                                                                                                                                  | `[]`                                           |

### Service parameters

| Name                  | Description                                                | Value       |
| --------------------- | ---------------------------------------------------------- | ----------- |
| `service.enabled`     | Enable a clusterIP service for the FinOps Agent            | `true`      |
| `service.type`        | Kubernetes service type                                    | `ClusterIP` |
| `service.ports.http`  | The FinOps Agent HTTP port                                 | `80`        |
| `service.clusterIP`   | The FinOps Agent service Cluster IP                        | `""`        |
| `service.extraPorts`  | Extra port to expose on the FinOps Agent service           | `[]`        |
| `service.annotations` | Additional custom annotations for the FinOps Agent service | `{}`        |

### Metrics parameters

| Name                                       | Description                                                                                            | Value   |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------ | ------- |
| `metrics.enabled`                          | Enable the export of Prometheus metrics                                                                | `false` |
| `metrics.serviceMonitor.enabled`           | if `true`, creates a Prometheus Operator ServiceMonitor (also requires `metrics.enabled` to be `true`) | `false` |
| `metrics.serviceMonitor.namespace`         | Namespace in which Prometheus is running                                                               | `""`    |
| `metrics.serviceMonitor.labels`            | Additional labels that can be used so ServiceMonitor will be discovered by Prometheus                  | `{}`    |
| `metrics.serviceMonitor.interval`          | Interval at which metrics should be scraped.                                                           | `""`    |
| `metrics.serviceMonitor.scrapeTimeout`     | Timeout after which the scrape is ended                                                                | `""`    |
| `metrics.serviceMonitor.relabelings`       | RelabelConfigs to apply to samples before scraping                                                     | `[]`    |
| `metrics.serviceMonitor.metricRelabelings` | MetricRelabelConfigs to apply to samples before ingestion                                              | `[]`    |
| `metrics.serviceMonitor.selector`          | Prometheus instance selector labels                                                                    | `{}`    |
| `metrics.serviceMonitor.honorLabels`       | honorLabels chooses the metric's labels on collisions with target labels                               | `false` |

### Persistence parameters

| Name                                              | Description                                                                                                                                                                | Value               |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| `persistence.enabled`                             | Enable FinOps Agent data persistence for WAL and other local data                                                                                                          | `true`              |
| `persistence.existingClaim`                       | A manually managed Persistent Volume and Claim                                                                                                                             | `""`                |
| `persistence.storageClass`                        | PVC Storage Class for the FinOps Agent data volume                                                                                                                         | `""`                |
| `persistence.accessModes`                         | Persistent Volume Access Modes                                                                                                                                             | `["ReadWriteOnce"]` |
| `persistence.size`                                | PVC Storage Request for the FinOps Agent data volume                                                                                                                       | `8Gi`               |
| `persistence.dataSource`                          | Custom PVC data source                                                                                                                                                     | `{}`                |
| `persistence.annotations.helm.sh/resource-policy` | The \"helm.sh/resource-policy: keep\" annotation is used to prevent the persistent volume from being deleted when uninstalling or moving to a different deployment method. | `keep`              |
| `persistence.selector`                            | Selector to match an existing Persistent Volume for the FinOps Agent data PVC. If set, the PVC can't have a PV dynamically provisioned for it                              | `{}`                |
| `persistence.mountPath`                           | Mount path of the IBM FinOps Agent data volume                                                                                                                             | `/opt/finops-agent` |

### Other Parameters

| Name                                          | Description                                                                                                                                       | Value   |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `serviceAccount.create`                       | Enable creation of ServiceAccount for IBM FinOps Agent pods                                                                                       | `true`  |
| `serviceAccount.name`                         | Name of the service account to use. If not set and `create` is `true`, a name is generated                                                        | `""`    |
| `serviceAccount.automountServiceAccountToken` | Allows auto mount of ServiceAccountToken on the serviceAccount created                                                                            | `true`  |
| `serviceAccount.annotations`                  | Additional custom annotations for the ServiceAccount                                                                                              | `{}`    |
| `rbac.create`                                 | Whether to create & use RBAC resources or not                                                                                                     | `true`  |
| `rbac.clusterRole.create`                     | Whether to create & use ClusterRole resources or not                                                                                              | `true`  |
| `localStoreEnabled`                           | this values is only used by the Kubecost main chart, it must be set to false for the FinOps Agent to work when deployed by the FinOps Agent chart | `false` |
| `extraObjects`                                | Additional custom objects to deploy with the chart                                                                                                | `[]`    |

## License

[Apache License 2.0](../../LICENSE)
