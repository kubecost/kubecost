{{/* vim: set filetype=mustache: */}}

{{/*
Kubecost 3.0 preconditions
*/}}
{{- define "kubecost.v3-preconditions" -}}
  {{/* Acknowledgment check for Kubecost 3.0 major upgrade - required for enterprise users */}}
  {{- if and .Values.kubecostProductConfigs.productKey.enabled (not .Values.global.acknowledged) -}}
    {{ fail "Kubecost 3.0 contains breaking changes and potential data disruption risks. Review release notes at https://github.com/kubecost/kubecost/releases before proceeding. To acknowledge and proceed, use the flag `--set global.acknowledged=true`" }}
  {{- end -}}

  {{/* Federated Storage config migration */}}
  {{- if (.Values.kubecostModel).federatedStorageConfig -}}
    {{ fail "`.Values.kubecostModel.federatedStorageConfig` is no longer supported. Please use `.Values.global.federatedStorage.config` instead." }}
  {{- end -}}
  {{- if (.Values.kubecostModel).federatedStorageConfigSecret -}}
    {{ fail "`.Values.kubecostModel.federatedStorageConfigSecret` is no longer supported. Please use `.Values.global.federatedStorage.existingSecret` instead." }}
  {{- end -}}
  {{- if (.Values.federatedETL).federatedCluster -}}
    {{ fail "`.Values.federatedETL.federatedCluster` is no longer supported. Please use `.Values.finopsagent.enabled=true` instead if you want to push this cluster's metrics to the federated storage." }}
  {{- end -}}
  {{- if (.Values.federatedETL).agentOnly -}}
    {{ fail "`.Values.federatedETL.agentOnly` is no longer supported. Please use `.Values.aggregator.enabled=false` instead. You may also choose to disable the frontend, cloudcost, and forecasting components." }}
  {{- end -}}
  {{- if (.Values.federatedETL).readOnlyPrimary -}}
    {{ fail "`.Values.federatedETL.readOnlyPrimary` is no longer supported. Please use `.Values.finopsagent.enabled=false` instead if you don't want to push this cluster's metrics to the federated storage." }}
  {{- end -}}
  {{- if .Values.federatedETL -}}
    {{ fail "`.Values.federatedETL` is no longer supported. Please remove this configuration." }}
  {{- end -}}

  {{/* Cloud Integration config migration */}}
  {{- if (.Values.kubecostProductConfigs).cloudIntegrationSecret -}}
    {{ fail "`.Values.kubecostProductConfigs.cloudIntegrationSecret` is no longer supported. Please use `.Values.cloudCost.cloudIntegrationSecret` instead." }}
  {{- end -}}
  {{- if (.Values.kubecostProductConfigs).cloudIntegrationJSON -}}
    {{ fail "`.Values.kubecostProductConfigs.cloudIntegrationJSON` is no longer supported. Please use `.Values.cloudCost.cloudIntegrationJSON` instead." }}
  {{- end -}}

  {{/* Component config migration */}}
  {{- if .Values.kubecostAggregator -}}
    {{ fail "`.Values.kubecostAggregator` is no longer supported. Please use `.Values.aggregator` instead." }}
  {{- end -}}
  {{- if .Values.kubecostFrontend -}}
    {{ fail "`.Values.kubecostFrontend` is no longer supported. Please use `.Values.frontend` instead." }}
  {{- end -}}
  {{- if .Values.kubecostModel -}}
    {{ fail "`.Values.kubecostModel` is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.service -}}
    {{ fail "`.Values.service` is no longer supported. Service configuration is now handled by `.Values.frontend.service`." }}
  {{- end -}}
  {{- if .Values.pricingCsv -}}
    {{ fail "`.Values.pricingCsv` is no longer supported. Please use `.Values.enterpriseCustomPricing` instead." }}
  {{- end -}}

  {{/* Removed configurations */}}
  {{- if .Values.etlUtils -}}
    {{ fail "`.Values.etlUtils` is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.kubecostMetrics -}}
    {{ fail "`.Values.kubecostMetrics` is no longer supported. Please remove this configuration." }}
  {{- end -}}

  {{/* Prometheus and Grafana removal */}}
  {{- if .Values.prometheus -}}
    {{ fail "`.Values.prometheus` is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.grafana -}}
    {{ fail "`.Values.grafana` is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.global.prometheus -}}
    {{ fail "`.Values.global.prometheus` is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.global.grafana -}}
    {{ fail "`.Values.global.grafana` is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.global.gmp -}}
    {{ fail "`.Values.global.gmp` (Google Managed Prometheus) is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.global.amp -}}
    {{ fail "`.Values.global.amp` (Amazon Managed Prometheus) is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.global.mimirProxy -}}
    {{ fail "`.Values.global.mimirProxy` (Grafana Mimir Proxy) is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.global.ammsp -}}
    {{ fail "`.Values.global.ammsp` (Azure Monitor Managed Service) is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.sigV4Proxy -}}
    {{ fail "`.Values.sigV4Proxy` is no longer supported. Please remove this configuration." }}
  {{- end -}}
  {{- if .Values.awsstore -}}
    {{ fail "`.Values.awsstore` is no longer supported. Please remove this configuration." }}
  {{- end -}}
{{- end -}}

{{/*
Kubecost 2.0 preconditions
*/}}
{{- define "kubecost.v2-preconditions" -}}
  {{/* Iterate through all StatefulSets in the namespace and check if any of them have a label indicating they are from
  a pre-2.0 Helm Chart (e.g. "helm.sh/chart: cost-analyzer-1.108.1"). If so, return an error message with details and
  documentation for how to properly upgrade to Kubecost 2.0 */}}
  {{- $sts := (lookup "apps/v1" "StatefulSet" .Release.Namespace "") -}}
  {{- if not (empty $sts.items) -}}
    {{- range $index, $sts := $sts.items -}}
      {{- if contains "aggregator" $sts.metadata.name -}}
        {{- if $sts.metadata.labels -}}
          {{- $stsLabels := $sts.metadata.labels -}}                  {{/* helm.sh/chart: cost-analyzer-1.108.1 */}}
          {{- if hasKey $stsLabels "helm.sh/chart" -}}
            {{- $chartLabel := index $stsLabels "helm.sh/chart" -}}   {{/* cost-analyzer-1.108.1 */}}
            {{- $chartNameAndVersion := split "-" $chartLabel -}}     {{/* _0:cost _1:analyzer _2:1.108.1 */}}
            {{- if gt (len $chartNameAndVersion) 2 -}}
              {{- $chartVersion := $chartNameAndVersion._2 -}}        {{/* 1.108.1 */}}
              {{- if semverCompare ">=1.0.0-0 <2.0.0-0" $chartVersion -}}
                {{- fail "\n\nAn existing Aggregator StatefulSet was found in your namespace.\nBefore upgrading to Kubecost 2.x, please `kubectl delete` this Statefulset.\nRefer to the following documentation for more information: https://www.ibm.com/docs/en/kubecost/self-hosted/2.x?topic=installation-kubecost-v2-installupgrade" -}}
              {{- end -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{/* Aggregator config reconciliation and common config */}}
  {{- if (not (.Values.aggregator).aggregatorDbStorage) -}}
    {{- fail "In Enterprise configuration, Aggregator DB storage is required" -}}
  {{- end -}}

  {{- if (.Values.podSecurityPolicy).enabled }}
    {{- fail "Kubecost no longer includes PodSecurityPolicy by default. Please take steps to preserve your existing PSPs before attempting the installation/upgrade again with the podSecurityPolicy values removed." }}
  {{- end }}
{{- end -}}

{{/*
RBAC exclusivity check: make sure either simple RBAC or RBAC Teams is configured, not both
*/}}
{{- define "kubecost.rbac.check" -}}
  {{- if and (or (.Values.saml).groups (.Values.oidc).groups) (.Values.teams).teamsConfig  -}}
    {{- fail "\nSimple RBAC and RBAC Teams are mutually exclusive. Please specify only one." -}}
  {{- end -}}
{{- end -}}

{{/*
Print a warning if PV is enabled AND EKS is detected AND the EBS-CSI driver is not installed.
Skip the check if CI/CD is enabled and skipSanityChecks is set. Argo CD, for
example, does not support templating a chart which uses the lookup function.
*/}}
{{- define "kubecost.eksStorage.check" }}
{{- if not (and .Values.global.platforms.cicd.enabled .Values.global.platforms.cicd.skipSanityChecks) }}
{{- $PVsEnabled := (or (.Values.persistentVolume).enabled) }}
{{- $isEKS := (regexMatch ".*eks.*" (.Capabilities.KubeVersion | quote) )}}
{{- $isGT22 := (semverCompare ">=1.23-0" .Capabilities.KubeVersion.GitVersion) }}
{{- $EBSCSINotExists := (empty (lookup "apps/v1" "Deployment" "kube-system" "ebs-csi-controller")) }}
{{- if (and $isEKS $isGT22 $PVsEnabled $EBSCSINotExists) -}}

ERROR: MISSING EBS-CSI DRIVER WHICH IS REQUIRED ON EKS v1.23+ TO MANAGE PERSISTENT VOLUMES. LEARN MORE HERE: https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=installations-amazon-eks-integration

{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Verify that the global cluster id is set
*/}}
{{- define "kubecost.clusterId.check" -}}
  {{- if ((((.Values.prometheus).server).global).external_labels).cluster_id }}
    {{ fail "\n\nIn Kubecost 3.0, `.Values.prometheus.server.global.external_labels.cluster_id` has been moved to `.Values.global.clusterId`\n" }}
  {{- end }}
  {{- if (.Values.kubecostProductConfigs).clusterName }}
    {{ fail "\n\nIn Kubecost 3.0, `.Values.kubecostProductConfigs.clusterName` has been moved to `.Values.global.clusterId`\n" }}
  {{- end }}
  {{- if not .Values.global.clusterId }}
    {{- fail "\n\nIn Kubecost 3.0, `.Values.global.clusterId` is required to be set"}}
  {{- end }}
  {{- if or .Values.global.federatedStorage.existingSecret .Values.global.federatedStorage.config }}
    {{- if eq .Values.global.clusterId "cluster-one" }}
      {{- printf "\n\nWarning: it is recommended to specify a unique `.Values.global.clusterId` for each cluster.\nNote this must be a globally unique identifier in multi-cluster environments.\n" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Verify the federated storage config secret exists with the expected key.
Skip the check if CI/CD is enabled and skipSanityChecks is set. Argo CD, for
example, does not support templating a chart which uses the lookup function.
*/}}
{{- define "kubecost.federatedStorage.secret.check" -}}
{{- if (.Values.global.federatedStorage).existingSecret }}
{{- if not (and .Values.global.platforms.cicd.enabled .Values.global.platforms.cicd.skipSanityChecks) }}
{{-  if .Capabilities.APIVersions.Has "v1/Secret" }}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace ((.Values.global).federatedStorage).existingSecret }}
  {{- $fileName := (include "kubecost.federatedStorage.fileName" .) }}
  {{- if or (not $secret) (not (index $secret.data )) }}
    {{- fail (printf "The federated storage config secret '%s' does not exist or does not contain the expected key '%s'" (.Values.global.federatedStorage).existingSecret $fileName ) }}
  {{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
Actions Storage source contents check. Either the Secret must be specified or the YAML, not both.
*/}}
{{- define "kubecost.actionsStorageSourceCheck" -}}
  {{- if ((.Values.kubecostProductConfigs).actions).enabled -}}
  {{- if and ((.Values.kubecostProductConfigs).actions).storageConfigSecret ((.Values.kubecostProductConfigs).actions).storageConfig -}}
    {{- fail "\nkubecostProductConfigs.actions.storageConfigSecret and kubecostProductConfigs.actions.storageConfig are mutually exclusive. Please specify only one." -}}
  {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.clusterId" }}
  {{- if ((((.Values.prometheus).server).global).external_labels).cluster_id }}
    {{- .Values.prometheus.server.global.external_labels.cluster_id }}
  {{- else if (.Values.kubecostProductConfigs).clusterName }}
    {{- .Values.kubecostProductConfigs.clusterName }}
  {{- else -}}
    {{- .Values.global.clusterId }}
  {{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "kubecost.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubecost.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kubecost.serviceName" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account
*/}}
{{- define "kubecost.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "kubecost.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kubecost.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the chart labels.
*/}}
{{- define "kubecost.chartLabels" -}}
helm.sh/chart: {{ include "kubecost.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.chartLabels }}
{{ toYaml .Values.chartLabels }}
{{- end }}
{{- end -}}

{{/*
Create the common labels.
*/}}
{{- define "kubecost.commonLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.name" . }}
helm.sh/chart: {{ include "kubecost.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: kubecost
{{- end -}}

{{/*
Create the selector labels.
*/}}
{{- define "kubecost.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: kubecost
{{- end -}}

{{/*
Create the selector labels for haMode frontend.
*/}}
{{- define "frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: kubecost
{{- end -}}

{{- define "aggregator.selectorLabels" -}}
{{- if eq (include "aggregator.deployMethod" .) "statefulset" }}
app.kubernetes.io/name: {{ include "aggregator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: aggregator
{{- else if eq (include "aggregator.deployMethod" .) "singlepod" }}
{{- include "kubecost.selectorLabels" . }}
{{- else }}
{{ fail "Failed to set aggregator.selectorLabels" }}
{{- end }}
{{- end }}

{{- define "cloudCost.selectorLabels" -}}
{{- if eq (include "aggregator.deployMethod" .) "statefulset" }}
app.kubernetes.io/name: {{ include "cloudCost.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "cloudCost.name" . }}
{{- else }}
{{- include "kubecost.selectorLabels" . }}
{{- end }}
{{- end }}

{{- define "forecasting.selectorLabels" -}}
app.kubernetes.io/name: {{ include "forecasting.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "forecasting.name" . }}
{{- end -}}
{{- define "etlUtils.selectorLabels" -}}
app.kubernetes.io/name: {{ include "etlUtils.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "etlUtils.name" . }}
{{- end -}}

{{/*
Recursive filter which accepts a map containing an input map (.v) and an output map (.r). The template
will traverse all values inside .v recursively writing non-map values to the output .r. If a nested map
is discovered, we look for an 'enabled' key. If it doesn't exist, we continue traversing the
map. If it does exist, we omit the inner map traversal iff enabled is false. This filter writes the
enabled only version to the output .r
*/}}
{{- define "kubecost.filter" -}}
{{- $v := .v }}
{{- $r := .r }}
{{- range $key, $value := .v }}
    {{- $tp := kindOf $value -}}
    {{- if eq $tp "map" -}}
        {{- $isEnabled := true -}}
        {{- if (hasKey $value "enabled") -}}
            {{- $isEnabled = $value.enabled -}}
        {{- end -}}
        {{- if $isEnabled -}}
            {{- $rr := "{}" | fromYaml }}
            {{- template "kubecost.filter" (dict "v" $value "r" $rr) }}
            {{- $_ := set $r $key $rr -}}
        {{- end -}}
    {{- else -}}
        {{- $_ := set $r $key $value -}}
    {{- end -}}
{{- end -}}
{{- end -}}


{{- define "common.systemProxy" -}}
{{- if .Values.systemProxy.enabled }}
- name: HTTP_PROXY
  value: {{ .Values.systemProxy.httpProxyUrl }}
- name: http_proxy
  value: {{ .Values.systemProxy.httpProxyUrl }}
- name: HTTPS_PROXY
  value: {{ .Values.systemProxy.httpsProxyUrl }}
- name: https_proxy
  value: {{ .Values.systemProxy.httpsProxyUrl }}
- name: NO_PROXY
  value: {{ .Values.systemProxy.noProxy }}
- name: no_proxy
  value: {{ .Values.systemProxy.noProxy }}
{{- end }}
{{- end -}}

{{/*
SSO enabled flag for nginx configmap
*/}}
{{- define "kubecost.sso.enabled" -}}
  {{- if or (.Values.saml).enabled (.Values.oidc).enabled -}}
    {{- printf "true" -}}
  {{- else -}}
    {{- printf "false" -}}
  {{- end -}}
{{- end -}}

{{/*
To use the Kubecost built-in RBAC Teams UI, you must enable SSO and RBAC and not specify any groups.
Groups is only used when using simple RBAC.
*/}}
{{- define "kubecost.rbacTeams.enabled" -}}
  {{- if or (.Values.saml).enabled (.Values.oidc).enabled -}}
    {{- if or ((.Values.saml).rbac).enabled ((.Values.oidc).rbac).enabled -}}
      {{- if not (or ((.Values.saml).rbac).groups ((.Values.oidc).rbac).groups) -}}
        {{- printf "true" -}}
        {{- else -}}
        {{- printf "false" -}}
      {{- end -}}
      {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
  {{- else -}}
    {{- printf "false" -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.rbacTeams.config.enabled" -}}
    {{- if  eq (include "kubecost.rbacTeams.enabled" .) "true" -}}
        {{- if or (.Values.teams).teamsConfig  (.Values.teams).teamsConfigMapName -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end }}
    {{- else -}}
        {{- printf "false" -}}
    {{- end }}
{{- end }}

{{- define "kubecost.authMasterKey.enabled" -}}
  {{- if or (.Values.saml).enabled (.Values.oidc).enabled -}}
    {{- if or (.Values.saml).apiMasterKey (.Values.oidc).apiMasterKey -}}
      {{- printf "true" -}}
    {{- else -}}
      {{- if or (.Values.saml).apiMasterKeySecret (.Values.oidc).apiMasterKeySecret -}}
        {{- printf "true" -}}
      {{- else -}}
        {{- printf "false" -}}
      {{- end -}}
    {{- end -}}
  {{- else -}}
    {{- printf "false" -}}
  {{- end -}}
{{- end -}}

{{/*
kubecost.costEventsAudit.enabled flag for nginx configmap
*/}}
{{- define "kubecost.costEventsAudit.enabled" -}}
  {{- if or (.Values.costEventsAudit).enabled -}}
    {{- printf "true" -}}
  {{- else -}}
    {{- printf "false" -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.caCertsSecretConfig.check" }}
  {{- if .Values.global.updateCaTrust.enabled }}
    {{- if and .Values.global.updateCaTrust.caCertsSecret .Values.global.updateCaTrust.caCertsConfig }}
      {{- fail "Both caCertsSecret and caCertsConfig are defined. Please specify only one." }}
    {{- else if and (not .Values.global.updateCaTrust.caCertsSecret) (not .Values.global.updateCaTrust.caCertsConfig) }}
      {{- fail "Neither caCertsSecret nor caCertsConfig is defined, but updateCaTrust is enabled. Please specify one." }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "kubecost.plugins.enabled" }}
{{- if (.Values.plugins).enabled }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- define "kubecost.carbonEstimates.enabled" }}
{{- if ((.Values.kubecostProductConfigs).carbonEstimates) }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- define "kubecost.turbonomic.enabled" }}
{{- if ((.Values.global.integrations.turbonomic).enabled) }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- /*
  Compute a checksum based on the rendered content of specific ConfigMaps and Secrets.
*/ -}}
{{- define "kubecost.configsChecksum" -}}
{{- $files := list
  "aggregator/actions-config-configmap.yaml"
  "aggregator/actions-store-secret.yaml"
  "aggregator/aggregator-ingestion-configmap.yaml"
  "aggregator/kubecost-account-mapping-configmap.yaml"
  "aggregator/kubecost-alerts-configmap.yaml"
  "aggregator/kubecost-asset-reports-configmap.yaml"
  "aggregator/kubecost-cloud-cost-reports-configmap.yaml"
  "aggregator/kubecost-clusters-configmap.yaml"
  "aggregator/kubecost-saved-reports-configmap.yaml"
  "aggregator/kubecost-smtp-secret.yaml"
  "aggregator/saml-configmap.yaml"
  "cloud-cost/cloud-cost-integration-secret.yaml"
  "cluster-controller/cluster-controller-secret.yaml"
  "frontend/frontend-configmap.yaml"
  "integrations-postgres-queries-configmap.yaml"
  "integrations-postgres-secret.yaml"
  "integrations-turbonomic-secret.yaml"
  "kubecost-container-request-rightsizing-reports-configmap.yaml"
  "kubecost-federated-storage-config-secret.yaml"
  "kubecost-oidc-configmap-template.yaml"
  "kubecost-oidc-secret-template.yaml"
  "kubecost-productkey-secret.yaml"
  "kubecost-rbac-secret-template.yaml"
  "kubecost-rbac-teams-configmap-template.yaml"
  "kubecost-saml-secret-template.yaml"
  "network-costs/network-costs-configmap.yaml"
  "savings-profiles-configmap.yaml"
  "savings-recommendations-allowlists-configmap-template.yaml"
  "savings-recommendations-nodegroup-configmap-template.yaml"
-}}
{{- $checksum := "" -}}
{{- range $files -}}
  {{- $content := include (print $.Template.BasePath (printf "/%s" .)) $ -}}
  {{- $checksum = printf "%s%s" $checksum $content | sha256sum -}}
{{- end -}}
{{- /* Add global values to the checksum */ -}}
{{- $globalChecksum := toYaml $.Values.global | sha256sum -}}
{{- $checksum = printf "%s%s" $checksum $globalChecksum | sha256sum -}}
{{- $checksum | sha256sum -}}
{{- end -}}


{{/*
Product key secret name with default fallback
*/}}
{{- define "kubecost.productKey.secretName" -}}
{{- default "product-key" .Values.kubecostProductConfigs.productKey.secretname -}}
{{- end -}}


{{/*
federated storage config helpers
*/}}

{{- define "kubecost.federatedStorage.secretName" }}
  {{- if .Values.global.federatedStorage.existingSecret  }}
    {{- .Values.global.federatedStorage.existingSecret }}
  {{- else -}}
    {{- .Release.Name }}-federated-storage-config
  {{- end }}
{{- end -}}

{{/*
NOTE: added kubecostModel for backward compatibility
*/}}
{{- define "kubecost.federatedStorage.config" }}
  {{- if .Values.global.federatedStorage.config -}}
    {{- .Values.global.federatedStorage.config -}}
  {{- else }}
    type: cluster
    config:
      host: {{ include "kubecost.localStore.serviceName" . }}.{{ .Release.Namespace }}.svc.cluster.local
      port: 9006
      http_config:
        tls_config:
          insecure_skip_verify: true
  {{- end -}}
{{- end -}}

{{- define "kubecost.federatedStorage.fileName" -}}
{{- default "federated-store.yaml" (.Values.global.federatedStorage).fileName }}
{{- end }}

{{- define "kubecost.localStoreClusterIdCheck" -}}
{{- if eq (include "kubecost.clusterId" .) "cluster-one" -}}
{{ printf "\n\nWARNING: The clusterId is set to the default value of 'cluster-one'. This is not recommended if you intend to use multi-cluster federation in the future. Please set a globally unique .Values.global.clusterId\n" }}
{{- end -}}
{{- end -}}

{{/*
Prior to kubecost 3.0.3, the finops-agent had a hyphen. It was removed in 3.0.3.
This will block upgrades until the new value is used, which very few would have changed.
*/}}
{{- define "kubecost.finopsagentCheck" -}}
{{- if index .Values "finops-agent" }}
  {{ fail "\nThe helm values for finops-agent have been updated.\nPlease change the finops-agent: key in your helm values to finopsagent:" }}
{{- end -}}
{{- end -}}

{{- define "kubecost.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{ range $.Values.global.imagePullSecrets }}
  - name: {{ . }}
{{ end }}
{{- else if .Values.imagePullSecrets }}
imagePullSecrets:
{{ range $.Values.imagePullSecrets }}
  - name: {{ .name }}
{{ end }}
{{- end -}}
{{- end -}}

{{- define "kubecost.v3-postconditions" -}}
{{- if .Values.imagePullSecrets }}
{{ printf "\nWARNING .Values.imagePullSecrets has been deprecated. Please use .Values.global.imagePullSecrets instead.\nThe finops-agent will only use the global.imagePullSecrets\n" }}
{{- end -}}
{{- end -}}
