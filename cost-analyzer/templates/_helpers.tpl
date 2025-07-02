{{/* vim: set filetype=mustache: */}}

{{/*
Kubecost 2.0 preconditions
*/}}
{{- define "kubecostV2-preconditions" -}}
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
  {{- if (not (.Values.kubecostAggregator).aggregatorDbStorage) -}}
    {{- fail "In Enterprise configuration, Aggregator DB storage is required" -}}
  {{- end -}}


  {{- if (.Values.podSecurityPolicy).enabled }}
    {{- fail "Kubecost no longer includes PodSecurityPolicy by default. Please take steps to preserve your existing PSPs before attempting the installation/upgrade again with the podSecurityPolicy values removed." }}
  {{- end }}

{{- end -}}

{{- define "federatedStorageCheck" -}}
  {{- if or (.Values.federatedETL).federatedStore (.Values.kubecostModel).federatedStorageConfig }}
    {{- if and (not (eq (include "aggregator.deployMethod" .) "statefulset")) (not (.Values.federatedETL).agentOnly) }}
      {{- printf "\n\n***Configuration issue detected:***\nWhen a federated store is provided, Kubecost should either be running as agentOnly or as a statefulset.\n.Values.federatedETL.agentOnly=true\nOr\n.Values.kubecostAggregator.deployMethod=statefulset\n***" }}
    {{- end }}
  {{- end }}
{{- end }}



{{/*
RBAC exclusivity check: make sure either simple RBAC or RBAC Teams is configured, not both
*/}}
{{- define "rbacCheck" -}}
  {{- if and (or (.Values.saml).groups (.Values.oidc).groups) (.Values.teams).teamsConfig  -}}
    {{- fail "\nSimple RBAC and RBAC Teams are mutually exclusive. Please specify only one." -}}
  {{- end -}}
{{- end -}}

{{/*
Federated Storage source contents check. Either the Secret must be specified or the JSON, not both.
*/}}
{{- define "federatedStorageSourceCheck" -}}
  {{- if and (.Values.kubecostModel).federatedStorageConfigSecret (.Values.kubecostModel).federatedStorageConfig -}}
    {{- fail "\nkubecostModel.federatedStorageConfigSecret and kubecostModel.federatedStorageConfig are mutually exclusive. Please specify only one." -}}
  {{- end -}}
{{- end -}}

{{/*
Actions Storage source contents check. Either the Secret must be specified or the YAML, not both.
*/}}
{{- define "actionsStorageSourceCheck" -}}
  {{- if ((.Values.kubecostProductConfigs).actions).enabled -}}
  {{- if and ((.Values.kubecostProductConfigs).actions).storageConfigSecret ((.Values.kubecostProductConfigs).actions).storageConfig -}}
    {{- fail "\nkubecostProductConfigs.actions.storageConfigSecret and kubecostProductConfigs.actions.storageConfig are mutually exclusive. Please specify only one." -}}
  {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Print a warning if PV is enabled AND EKS is detected AND the EBS-CSI driver is not installed
*/}}
{{- define "eksCheck" }}
{{- $isEKS := (regexMatch ".*eks.*" (.Capabilities.KubeVersion | quote) )}}
{{- $isGT22 := (semverCompare ">=1.23-0" .Capabilities.KubeVersion.GitVersion) }}
{{- $PVNotExists := (empty (lookup "v1" "PersistentVolume" "" "")) }}
{{- $EBSCSINotExists := (empty (lookup "apps/v1" "Deployment" "kube-system" "ebs-csi-controller")) }}
{{- if (and $isEKS $isGT22 .Values.persistentVolume.enabled $EBSCSINotExists) -}}

ERROR: MISSING EBS-CSI DRIVER WHICH IS REQUIRED ON EKS v1.23+ TO MANAGE PERSISTENT VOLUMES. LEARN MORE HERE: https://www.ibm.com/docs/en/kubecost/self-hosted/2.x?topic=installations-amazon-eks-integration

{{- end -}}
{{- end -}}

{{/*
Verify a cluster_id is set in the Prometheus global config
*/}}
{{- define "clusterIDCheck" -}}
  {{- if ((((.Values.prometheus).server).global).external_labels).cluster_id }}
    {{- printf "\n\nIn Kubecost 3.0, `.Values.prometheus.server.global.external_labels.cluster_id` is no longer required.\nWhen it is set, it is used for backwards compatibility. \nPlease replace this value with `.Values.kubecostProductConfigs.clusterName`\nSee TODO for more information.\n" -}}
  {{- end -}}
  {{- if or (.Values.kubecostModel).federatedStorageConfigSecret (.Values.kubecostModel).federatedStorageConfig }}
    {{- if eq .Values.kubecostProductConfigs.clusterName "cluster-one" }}
      {{- printf "\n\nWarning: it is recommended to specify a unique `.Values.kubecostProductConfigs.clusterName` for each cluster.\nNote this must be a globally unique identifier in multi-cluster environments.\n" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.clusterName" -}}
  {{- if.Values.kubecostProductConfigs.clusterName }}
    {{- printf "%s" .Values.kubecostProductConfigs.clusterName }}
  {{- else }}
    {{- if(((((.Values.prometheus).server).global).external_labels).cluster_id) }}
      {{- printf "%s" (((((.Values.prometheus).server).global).external_labels).cluster_id) }}
    {{- else }}
      {{- fail "\n\nWhen using multi-cluster Prometheus, you must specify a unique `(((((.Values.prometheus).server).global).external_labels).cluster_id)` for each cluster.\nNote this must be a globally unique identifier.\n" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Verify the federated storage config secret exists with the expected key.
Skip the check if CI/CD is enabled and skipSanityChecks is set. Argo CD, for
example, does not support templating a chart which uses the lookup function.
*/}}
{{- define "federatedStorageConfigSecretCheck" -}}
{{- if (.Values.kubecostModel).federatedStorageConfigSecret }}
{{- if not (and .Values.global.platforms.cicd.enabled .Values.global.platforms.cicd.skipSanityChecks) }}
{{-  if .Capabilities.APIVersions.Has "v1/Secret" }}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.kubecostModel.federatedStorageConfigSecret }}
  {{- if or (not $secret) (not (index $secret.data "federated-store.yaml")) }}
    {{- fail (printf "The federated storage config secret '%s' does not exist or does not contain the expected key 'federated-store.yaml'" .Values.kubecostModel.federatedStorageConfigSecret) }}
  {{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "cost-analyzer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
Before changing this, please see:
https://github.com/kubecost/cost-analyzer-helm-chart/blob/0f27b723cc395910b4b9667925d43001304e877d/cost-analyzer/templates/ingress-template.yaml#L7-L9
*/}}
{{- define "cost-analyzer.fullname" -}}
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

{{- define "cost-analyzer.serviceName" -}}
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
{{- define "cost-analyzer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "cost-analyzer.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cost-analyzer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the chart labels.
*/}}
{{- define "cost-analyzer.chartLabels" -}}
helm.sh/chart: {{ include "cost-analyzer.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.chartLabels }}
{{ toYaml .Values.chartLabels }}
{{- end }}
{{- end -}}

{{/*
Create the common labels.
*/}}
{{- define "cost-analyzer.commonLabels" -}}
app.kubernetes.io/name: {{ include "cost-analyzer.name" . }}
helm.sh/chart: {{ include "cost-analyzer.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: cost-analyzer
{{- end -}}

{{/*
Create the selector labels.
*/}}
{{- define "cost-analyzer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cost-analyzer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: cost-analyzer
{{- end -}}

{{/*
SSO enabled flag for nginx configmap
*/}}
{{- define "ssoEnabled" -}}
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
{{- define "rbacTeamsEnabled" -}}
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

{{- define "rbacTeamsConfigEnabled" -}}
    {{- if  eq (include "rbacTeamsEnabled" .) "true" -}}
        {{- if or (.Values.teams).teamsConfig  (.Values.teams).teamsConfigMapName -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end }}
    {{- else -}}
        {{- printf "false" -}}
    {{- end }}
{{- end }}

{{- define "authMasterKeyEnabled" -}}
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
Backups configured flag for nginx configmap
*/}}
{{- define "dataBackupConfigured" -}}
  {{- if or (.Values.kubecostModel).federatedStorageConfigSecret (.Values.kubecostModel).federatedStorageConfig -}}
    {{- printf "true" -}}
  {{- else -}}
    {{- printf "false" -}}
  {{- end -}}
{{- end -}}

{{/*
costEventsAuditEnabled flag for nginx configmap
*/}}
{{- define "costEventsAuditEnabled" -}}
  {{- if or (.Values.costEventsAudit).enabled -}}
    {{- printf "true" -}}
  {{- else -}}
    {{- printf "false" -}}
  {{- end -}}
{{- end -}}

{{- define "caCertsSecretConfigCheck" }}
  {{- if .Values.global.updateCaTrust.enabled }}
    {{- if and .Values.global.updateCaTrust.caCertsSecret .Values.global.updateCaTrust.caCertsConfig }}
      {{- fail "Both caCertsSecret and caCertsConfig are defined. Please specify only one." }}
    {{- else if and (not .Values.global.updateCaTrust.caCertsSecret) (not .Values.global.updateCaTrust.caCertsConfig) }}
      {{- fail "Neither caCertsSecret nor caCertsConfig is defined, but updateCaTrust is enabled. Please specify one." }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "pluginsEnabled" }}
{{- if (.Values.kubecostModel.plugins).enabled }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- define "carbonEstimatesEnabled" }}
{{- if ((.Values.kubecostProductConfigs).carbonEstimates) }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- /*
  Compute a checksum based on the rendered content of specific ConfigMaps and Secrets.
*/ -}}
{{- define "configsChecksum" -}}
{{- $files := list
  "actions-config-configmap.yaml"
  "actions-store-secret.yaml"
  "alibaba-service-key-secret.yaml"
  "aws-service-key-secret.yaml"
  "azure-service-key-secret.yaml"
  "cloud-cost-integration-secret.yaml"
  "cost-analyzer-account-mapping-configmap.yaml"
  "cost-analyzer-alerts-configmap.yaml"
  "cost-analyzer-asset-reports-configmap.yaml"
  "cost-analyzer-cloud-cost-reports-configmap.yaml"
  "frontend-configmap.yaml"\
  "cost-analyzer-metrics-config-map-template.yaml"
  "network-costs-configmap.yaml"
  "cost-analyzer-oidc-config-map-template.yaml"
  "cost-analyzer-pkey-secret.yaml"
  "cost-analyzer-pricing-configmap.yaml"
  "cost-analyzer-saml-config-map-template.yaml"
  "cost-analyzer-saved-reports-configmap.yaml"
  "cost-analyzer-server-configmap.yaml"
  "cost-analyzer-smtp-configmap.yaml"
  "install-plugins.yaml"
  "integrations-postgres-queries-configmap.yaml"
  "integrations-postgres-secret.yaml"
  "cluster-controller-actions-config.yaml"
  "cluster-controller-secret.yaml"
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

{{- define "cost-model.image" }}
{{- if .Values.kubecostModel }}
  {{- if .Values.kubecostModel.fullImageName }}
    {{ .Values.kubecostModel.fullImageName }}
  {{- else if .Values.imageVersion }}
    {{ .Values.kubecostModel.image }}:{{ .Values.imageVersion }}
  {{- else if eq "development" .Chart.AppVersion }}
    gcr.io/guestbook-227502/agent:latest
  {{- else }}
    {{ .Values.kubecostModel.image }}:prod-{{ $.Chart.AppVersion }}
  {{- end }}
{{- else }}
  gcr.io/kubecost1/cost-model:prod-{{ $.Chart.AppVersion }}
{{- end }}
{{- end }}

{{- define "cost-model.imagetag" }}
{{- $image := include "cost-model.image" . }}
{{- $parts := splitList ":" $image }}
{{- $tag := last $parts }}
{{- $tag }}
{{- end }}

{{/*
Product key secret name with default fallback
*/}}
{{- define "cost-analyzer.productKeySecretName" -}}
{{- default "product-key" .Values.kubecostProductConfigs.productKey.secretname -}}
{{- end -}}