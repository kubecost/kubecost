{{/* vim: set filetype=mustache: */}}

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

  {{/* TODO: update comments and rules for v3 */}}
  {{- if or ((.Values.saml).rbac).enabled ((.Values.oidc).rbac).enabled -}}
    {{- if (not (.Values.upgrade).tov3) -}}
      {{- printf "\n\nSSO with RBAC is enabled.\nNote that Kubecost 3.x has significant architectural changes that need to be TODO...\n\nWhen ready to upgrade, add `--set upgrade.tov3=true`." -}}
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
Print a warning if PV is enabled AND EKS is detected AND the EBS-CSI driver is not installed
*/}}
{{- define "kubecost.eksStorage.check" }}
{{- $PVsEnabled := (or (.Values.persistentVolume).enabled) }}
{{- $isEKS := (regexMatch ".*eks.*" (.Capabilities.KubeVersion | quote) )}}
{{- $isGT22 := (semverCompare ">=1.23-0" .Capabilities.KubeVersion.GitVersion) }}
{{- $EBSCSINotExists := (empty (lookup "apps/v1" "Deployment" "kube-system" "ebs-csi-controller")) }}
{{- if (and $isEKS $isGT22 $PVsEnabled $EBSCSINotExists) -}}

ERROR: MISSING EBS-CSI DRIVER WHICH IS REQUIRED ON EKS v1.23+ TO MANAGE PERSISTENT VOLUMES. LEARN MORE HERE: https://www.ibm.com/docs/en/kubecost/self-hosted/2.x?topic=installations-amazon-eks-integration

{{- end -}}
{{- end -}}

{{/*
Verify that the global cluster id is set
*/}}
{{- define "kubecost.clusterId.check" -}}
  {{- if ((((.Values.prometheus).server).global).external_labels).cluster_id }}
    {{- printf "\n\nIn Kubecost 3.0, `.Values.prometheus.server.global.external_labels.cluster_id` is no longer required.\nWhen it is set, it is used for backwards compatibility. \nSee TODO for more information.\n" -}}
  {{- end }}
  {{- if (.Values.kubecostProductConfigs).clusterName }}
    {{- printf "\n\nIn Kubecost 3.0, `.Values.prometheus.server.global.external_labels.cluster_id` is no longer required.\nWhen it is set, it is used for backwards compatibility. \nSee TODO for more information.\n" -}}
  {{- end }}
  {{- if not .Values.global.clusterId }}
    {{- fail "\n\nIn Kubecost 3.0, `.Values.global.clusterId` is required to be set"}}
  {{- end }}
  {{- if or (.Values.global.exportBucket).existingSecret ((.Values.exportBucket).secret).config }}
    {{- if eq .Values.global.clusterId "cluster-one" }}
      {{- printf "\n\nWarning: it is recommended to specify a unique `.Values.global.clusterId` for each cluster.\nNote this must be a globally unique identifier in multi-cluster environments.\n" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Verify the federated stoerage config secret exists with the expected key.
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
    {{- fail (printf "The export bucket storage config secret '%s' does not exist or does not contain the expected key '%s'" (.Values.global.federatedStorage).existingSecret $fileName ) }}
  {{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
export bucket source check. Either the Secret must be specified or the JSON, not both.
*/}}
{{- define "kubecost.federatedStorage.source.check" -}}
  {{- if and ((.Values.global).federatedStorage).existingSecret ((.Values.federatedStorage).secret).config -}}
    {{- fail "\n.Values.global.federatedStorage.existingSecret and .Values.federatedStorage.secret.config both set, please specify only one." -}}
  {{- end -}}
{{- end -}}

{{/*
Actions Storage source contents check. Either the Secret must be specified or the YAML, not both.
*/}}
{{- define "kubecost.actionsStorage.source.check" -}}
  {{- if ((.Values.kubecostProductConfigs).actions).enabled -}}
  {{- if and ((.Values.kubecostProductConfigs).actions).storageConfigSecret ((.Values.kubecostProductConfigs).actions).storageConfig -}}
    {{- fail "\nkubecostProductConfigs.actions.storageConfigSecret and kubecostProductConfigs.actions.storageConfig are mutually exclusive. Please specify only one." -}}
  {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.clusterId" }}
{{ .Values.global.clusterId }}
{{- end }}

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
Before changing this, please see:
https://github.com/kubecost/cost-analyzer-helm-chart/blob/0f27b723cc395910b4b9667925d43001304e877d/cost-analyzer/templates/ingress-template.yaml#L7-L9
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
app: cost-analyzer
{{- end -}}

{{/*
Create the selector labels.
*/}}
{{- define "kubecost.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: cost-analyzer
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
{{- if (.Values.kubecost.plugins).enabled }}
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

{{- /*
  Compute a checksum based on the rendered content of specific ConfigMaps and Secrets.
*/ -}}
{{- define "kubecost.configsChecksum" -}}
{{- $files := list
  "aggregator/actions-config-configmap.yaml"
  "aggregator/actions-store-secret.yaml"
  "cloud-cost/cloud-cost-integration-secret.yaml"
  "aggregator/cost-analyzer-account-mapping-configmap.yaml"
  "aggregator/cost-analyzer-alerts-configmap.yaml"
  "aggregator/cost-analyzer-asset-reports-configmap.yaml"
  "aggregator/cost-analyzer-cloud-cost-reports-configmap.yaml"
  "frontend/frontend-configmap.yaml"
  "cost-analyzer-metrics-config-map-template.yaml"
  "network-costs/network-costs-configmap.yaml"
  "cost-analyzer-oidc-config-map-template.yaml"
  "cost-analyzer-pkey-secret.yaml"
  "aggregator/saml-configmap.yaml"
  "aggregator/cost-analyzer-saved-reports-configmap.yaml"
  "aggregator/cost-analyzer-smtp-configmap.yaml"
  "install-plugins.yaml"
  "integrations-postgres-queries-configmap.yaml"
  "integrations-postgres-secret.yaml"
  "cluster-controller/cluster-controller-actions-config.yaml"
  "cluster-controller/cluster-controller-secret.yaml"
  "kubecost-oidc-secret-template.yaml"
  "kubecost-saml-secret-template.yaml"
  "savings-recommendations-allowlists-config-map-template.yaml"
  "savings-recommendations-nodegroup-config-map-template.yaml"
-}}
{{- $checksum := "" -}}
{{- range $files -}}
  {{- $content := include (print $.Template.BasePath (printf "/%s" .)) $ -}}
  {{- $checksum = printf "%s%s" $checksum $content | sha256sum -}}
{{- end -}}
{{- $checksum | sha256sum -}}
{{- end -}}


{{/*
Product key secret name with default fallback
*/}}
{{- define "cost-analyzer.productKeySecretName" -}}
{{- default "product-key" .Values.kubecostProductConfigs.productKey.secretname -}}
{{- end -}}

{{/*
Kubecost image to be used by all apps which run, can be overridden in each apps specific configs
*/}}
{{- define "kubecost.image" }}
{{- .Values.kubecost.image.registry }}/{{ .Values.kubecost.image.repository }}:{{ .Values.kubecost.image.tag }}
{{- end }}

{{/*
storage config helpers
*/}}

{{- define "kubecost.exportBucket.secretName" }}
{{- if (.Values.global.exportBucket).existingSecret -}}
(.Values.global.exportBucket).existingSecret
{{- else -}}
{{ .Release.Name }}-export-bucket-config
{{- end }}
{{- end -}}

{{- define "kubecost.exportBucket.config" }}
{{- if (.Values.exportBucket).configYAML }}
{{ (.Values.exportBucket).configYAML }}
{{ else }}
{{/*
Default export bucket config if no values are set
*/}}
type: cluster
{{- end }}
{{- end }}

{{- define "kubecost.exportBucket.fileName" -}}
{{ default "storage-config.yaml" (.Values.global.exportBucket).fileName }}
{{- end -}}
