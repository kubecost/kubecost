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
  {{- if or (.Values.global.federatedStorage).existingSecret ((.Values.federatedStorage).secret).config }}
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
    {{- fail (printf "The federated storage config secret '%s' does not exist or does not contain the expected key '%s'" (.Values.global.federatedStorage).existingSecret $fileName ) }}
  {{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
federated storage source check. Either the Secret must be specified or the JSON, not both.
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
  {{- if ((((.Values.prometheus).server).global).external_labels).cluster_id }}
    {{- .Values.prometheus.server.global.external_labels.cluster_id }}
  {{- else if (.Values.kubecostProductConfigs).clusterName }}
    {{- .Values.kubecostProductConfigs.clusterName }}
  {{- else if .Values.clusterId }}
    {{- .Values.clusterId }}
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
Create the selector labels for haMode frontend.
*/}}
{{- define "frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: cost-analyzer
{{- end -}}

{{- define "aggregator.selectorLabels" -}}
{{- if eq (include "aggregator.deployMethod" .) "statefulset" }}
app.kubernetes.io/name: {{ include "aggregator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: aggregator
{{- else if eq (include "aggregator.deployMethod" .) "singlepod" }}
{{- include "cost-analyzer.selectorLabels" . }}
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
{{- include "cost-analyzer.selectorLabels" . }}
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
{{- define "cost-analyzer.filter" -}}
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
            {{- template "cost-analyzer.filter" (dict "v" $value "r" $rr) }}
            {{- $_ := set $r $key $rr -}}
        {{- end -}}
    {{- else -}}
        {{- $_ := set $r $key $value -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{/*
This template accepts a map and returns a base64 encoded json version of the map where all disabled
leaf nodes are omitted.

The implied use case is {{ template "cost-analyzer.filterEnabled" .Values }}
*/}}
{{- define "cost-analyzer.filterEnabled" -}}
{{- $result := "{}" | fromYaml }}
{{- template "cost-analyzer.filter" (dict "v" . "r" $result) }}
{{- $result | toJson | b64enc }}
{{- end -}}

{{/*
==============================================================
Begin Prometheus templates
==============================================================
*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "prometheus.name" -}}
{{- "prometheus" -}}
{{- end -}}

{{/*
Define common selector labels for all Prometheus components
*/}}
{{- define "prometheus.common.matchLabels" -}}
app: {{ template "prometheus.name" . }}
release: {{ .Release.Name }}
{{- end -}}

{{/*
Define common top-level labels for all Prometheus components
*/}}
{{- define "prometheus.common.metaLabels" -}}
heritage: {{ .Release.Service }}
{{- end -}}

{{/*
Define top-level labels for Alert Manager
*/}}
{{- define "prometheus.alertmanager.labels" -}}
{{ include "prometheus.alertmanager.matchLabels" . }}
{{ include "prometheus.common.metaLabels" . }}
{{- end -}}

{{/*
Define selector labels for Alert Manager
*/}}
{{- define "prometheus.alertmanager.matchLabels" -}}
component: {{ .Values.prometheus.alertmanager.name | quote }}
{{ include "prometheus.common.matchLabels" . }}
{{- end -}}

{{/*
Define top-level labels for Node Exporter
*/}}
{{- define "prometheus.nodeExporter.labels" -}}
{{ include "prometheus.nodeExporter.matchLabels" . }}
{{ include "prometheus.common.metaLabels" . }}
{{- end -}}

{{/*
Define selector labels for Node Exporter
*/}}
{{- define "prometheus.nodeExporter.matchLabels" -}}
component: {{ .Values.prometheus.nodeExporter.name | quote }}
{{ include "prometheus.common.matchLabels" . }}
{{- end -}}

{{/*
Define top-level labels for Push Gateway
*/}}
{{- define "prometheus.pushgateway.labels" -}}
{{ include "prometheus.pushgateway.matchLabels" . }}
{{ include "prometheus.common.metaLabels" . }}
{{- end -}}

{{/*
Define selector labels for Push Gateway
*/}}
{{- define "prometheus.pushgateway.matchLabels" -}}
component: {{ .Values.prometheus.pushgateway.name | quote }}
{{ include "prometheus.common.matchLabels" . }}
{{- end -}}

{{/*
Define top-level labels for Server
*/}}
{{- define "prometheus.server.labels" -}}
{{ include "prometheus.server.matchLabels" . }}
{{ include "prometheus.common.metaLabels" . }}
{{- end -}}

{{/*
Define selector labels for Server
*/}}
{{- define "prometheus.server.matchLabels" -}}
component: {{ .Values.prometheus.server.name | quote }}
{{ include "prometheus.common.matchLabels" . }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.fullname" -}}
{{- if .Values.prometheus.fullnameOverride -}}
{{- .Values.prometheus.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "prometheus" .Values.prometheus.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified alertmanager name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "prometheus.alertmanager.fullname" -}}
{{- if .Values.prometheus.alertmanager.fullnameOverride -}}
{{- .Values.prometheus.alertmanager.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "prometheus" .Values.prometheus.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.prometheus.alertmanager.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.prometheus.alertmanager.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
Create a fully qualified node-exporter name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.nodeExporter.fullname" -}}
{{- if .Values.prometheus.nodeExporter.fullnameOverride -}}
{{- .Values.prometheus.nodeExporter.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "prometheus" .Values.prometheus.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.prometheus.nodeExporter.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.prometheus.nodeExporter.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified Prometheus server name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.server.fullname" -}}
{{- if .Values.prometheus.server.fullnameOverride -}}
{{- .Values.prometheus.server.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "prometheus" .Values.prometheus.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.prometheus.server.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.prometheus.server.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified pushgateway name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.pushgateway.fullname" -}}
{{- if .Values.prometheus.pushgateway.fullnameOverride -}}
{{- .Values.prometheus.pushgateway.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "prometheus" .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.prometheus.pushgateway.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.prometheus.pushgateway.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the alertmanager component
*/}}
{{- define "prometheus.serviceAccountName.alertmanager" -}}
{{- if .Values.prometheus.serviceAccounts.alertmanager.create -}}
    {{ default (include "prometheus.alertmanager.fullname" .) .Values.prometheus.serviceAccounts.alertmanager.name }}
{{- else -}}
    {{ default "default" .Values.prometheus.serviceAccounts.alertmanager.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the nodeExporter component
*/}}
{{- define "prometheus.serviceAccountName.nodeExporter" -}}
{{- if .Values.prometheus.serviceAccounts.nodeExporter.create -}}
    {{ default (include "prometheus.nodeExporter.fullname" .) .Values.prometheus.serviceAccounts.nodeExporter.name }}
{{- else -}}
    {{ default "default" .Values.prometheus.serviceAccounts.nodeExporter.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the pushgateway component
*/}}
{{- define "prometheus.serviceAccountName.pushgateway" -}}
{{- if .Values.prometheus.serviceAccounts.pushgateway.create -}}
    {{ default (include "prometheus.pushgateway.fullname" .) .Values.prometheus.serviceAccounts.pushgateway.name }}
{{- else -}}
    {{ default "default" .Values.prometheus.serviceAccounts.pushgateway.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the server component
*/}}
{{- define "prometheus.serviceAccountName.server" -}}
{{- if .Values.prometheus.serviceAccounts.server.create -}}
    {{ default (include "prometheus.server.fullname" .) .Values.prometheus.serviceAccounts.server.name }}
{{- else -}}
    {{ default "default" .Values.prometheus.serviceAccounts.server.name }}
{{- end -}}
{{- end -}}

{{/*
==============================================================
Begin Grafana templates
==============================================================
*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "grafana.name" -}}
{{- "grafana" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "grafana.fullname" -}}
{{- if .Values.grafana.fullnameOverride -}}
{{- .Values.grafana.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "grafana" .Values.grafana.nameOverride -}}
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
{{- define "grafana.serviceAccountName" -}}
{{- if .Values.grafana.serviceAccount.create -}}
    {{ default (include "grafana.fullname" .) .Values.grafana.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.grafana.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
==============================================================
Begin Kubecost 2.0 templates
==============================================================
*/}}

{{- define "aggregator.containerTemplate" }}
- name: aggregator
{{- if .Values.kubecostAggregator.containerSecurityContext }}
  securityContext:
    {{- toYaml .Values.kubecostAggregator.containerSecurityContext | nindent 4 }}
{{- else if .Values.global.containerSecurityContext }}
  securityContext:
    {{- toYaml .Values.global.containerSecurityContext | nindent 4 }}
{{- end }}
  {{- if .Values.kubecostModel }}
  {{- if .Values.kubecostAggregator.fullImageName }}
  image: {{ .Values.kubecostAggregator.fullImageName }}
  {{- else if .Values.imageVersion }}
  image: {{ .Values.kubecostModel.image }}:{{ .Values.imageVersion }}
  {{- else if eq "development" .Chart.AppVersion }}
  image: gcr.io/kubecost1/cost-model-nightly:latest
  {{- else }}
  image: {{ .Values.kubecostModel.image }}:prod-{{ $.Chart.AppVersion }}
  {{- end }}
  {{- else }}
  image: gcr.io/kubecost1/cost-model:prod-{{ $.Chart.AppVersion }}
  {{- end }}
  {{- if .Values.kubecostAggregator.readinessProbe.enabled }}
  readinessProbe:
    httpGet:
      path: /healthz
      port: 9004
    initialDelaySeconds: {{ .Values.kubecostAggregator.readinessProbe.initialDelaySeconds }}
    periodSeconds: {{ .Values.kubecostAggregator.readinessProbe.periodSeconds }}
    failureThreshold: {{ .Values.kubecostAggregator.readinessProbe.failureThreshold }}
  {{- end }}
  {{- if .Values.kubecostAggregator.imagePullPolicy }}
  imagePullPolicy: {{ .Values.kubecostAggregator.imagePullPolicy }}
  {{- else }}
  imagePullPolicy: Always
  {{- end }}
  args: ["waterfowl"]
  ports:
    - name: tcp-api
      containerPort: 9004
      protocol: TCP
  {{- with.Values.kubecostAggregator.extraPorts }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  resources:
    {{- toYaml .Values.kubecostAggregator.resources | nindent 4 }}
  volumeMounts:
    - name: persistent-configs
      mountPath: /var/configs
    {{- if or (.Values.kubecostModel).federatedStorageConfigSecret (.Values.kubecostModel).federatedStorageConfig }}
    - name: federated-storage-config
      mountPath: /var/configs/etl
      readOnly: true
    {{- end }}
    {{- if and .Values.persistentVolume.dbPVEnabled (eq (include "aggregator.deployMethod" .) "singlepod") }}
    - name: persistent-db
      mountPath: /var/db
      # aggregator should only need read access to ETL data
      readOnly: true
    {{- end }}
    {{- if eq (include "aggregator.deployMethod" .) "statefulset" }}
    - name: aggregator-db-storage
      mountPath: /var/configs/waterfowl/duckdb
    - name: aggregator-staging
      # Aggregator uses /var/configs/waterfowl as a "staging" directory for
      # things like intermediate-state files pre-ingestion. In order to avoid a
      # permission problem similar to
      # https://github.com/kubernetes/kubernetes/issues/81676, we create an
      # emptyDir at this path.
      #
      # This hasn't been observed as a problem in cost-analyzer, likely because
      # of the init container that gives everything under /var/configs 777.
      mountPath: /var/configs/waterfowl
      {{- if (not .Values.kubecostAggregator.legacyMode ) }}
      # mount the clickhouse directories on the same PV as the duckdb, 
      # this way they can seamlessly share the same PV before, during, and after the upgrade
    - name: aggregator-db-storage
      mountPath: /var/lib/clickhouse
      {{- end }}
    {{- end }}
    {{- if and (not .Values.kubecostAggregator.legacyMode) (eq (include "aggregator.deployMethod" .) "singlepod") }}
    - name: persistent-configs
      mountPath: /var/lib/clickhouse
    {{- end }}
    {{- if ((.Values.kubecostProductConfigs).productKey).enabled }}
    - name: productkey-secret
      mountPath: /var/configs/productkey
    {{- end }}
    {{- if and ((.Values.kubecostProductConfigs).smtp).secretname (eq (include "aggregator.deployMethod" .) "statefulset") }}
    - name: smtp-secret
      mountPath: /var/configs/smtp
    {{- end }}
    {{- if .Values.saml }}
    {{- if .Values.saml.enabled }}
    {{- if .Values.saml.secretName }}
    - name: secret-volume
      mountPath: /var/configs/secret-volume
    {{- end }}
    {{- if .Values.saml.encryptionCertSecret }}
    - name: saml-encryption-cert
      mountPath: /var/configs/saml-encryption-cert
    {{- end }}
    {{- if .Values.saml.decryptionKeySecret }}
    - name: saml-decryption-key
      mountPath: /var/configs/saml-decryption-key
    {{- end }}
    {{- if .Values.saml.metadataSecretName }}
    - name: metadata-secret-volume
      mountPath: /var/configs/metadata-secret-volume
    {{- end }}
    - name: saml-auth-secret
      mountPath: /var/configs/saml-auth-secret
    {{- if .Values.saml.rbac.enabled }}
    - name: saml-roles
      mountPath: /var/configs/saml
    {{- end }}
    {{- end }}
    {{- end }}
    {{- if .Values.oidc }}
    {{- if .Values.oidc.enabled }}
    - name: oidc-config
      mountPath: /var/configs/oidc
    {{- if or .Values.oidc.existingCustomSecret.name .Values.oidc.secretName }}
    - name: oidc-client-secret
      mountPath: /var/configs/oidc-client-secret
    {{- end }}
    {{- end }}
    {{- end }}
    {{- if eq (include "rbacTeamsEnabled" .) "true" }}
    - name: kubecost-rbac-secret
      mountPath: /var/configs/kubecost-rbac-secret
    {{- end }}
    {{- if eq (include "authMasterKeyEnabled" .) "true" }}
    - name: kubecost-master-api-key
      mountPath: /var/configs/auth
    {{- end }}
    {{- if eq (include "rbacTeamsConfigEnabled" .) "true" }}
    - name: kubecost-rbac-teams-config
      mountPath: /var/configs/rbac-teams-configs
    {{- end }}
    {{- if .Values.global.integrations.postgres.enabled }}
    - name: postgres-creds
      mountPath: /var/configs/integrations/postgres-creds
    - name: postgres-queries
      mountPath: /var/configs/integrations/postgres-queries
    {{- end }}
    {{- if .Values.global.updateCaTrust.enabled }}
    - name: ca-certs-secret
      mountPath: {{ .Values.global.updateCaTrust.caCertsMountPath | quote }}
    - name: ssl-path
      mountPath: "/etc/pki/ca-trust/extracted"
      readOnly: false
    {{- end }}
    {{- if (.Values.enterpriseCustomPricing).enabled }}
    - name: kubecost-enterprise-pricing
      mountPath: /var/configs/enterprise-pricing
    {{- end }}
    {{- if and (.Values.instanceTypes.enabled) (.Values.instanceTypes.custom) }}
    - name: custom-instance-types
      mountPath: /var/configs/instance-types
    {{- end }}
    {{- if ((.Values.kubecostProductConfigs).actions).config }}
    - name: actions-config
      mountPath: /var/configs/actions
    {{- end }}
    {{- if ((.Values.kubecostProductConfigs).actions).enabled }}
    {{- if and (not (((.Values.kubecostProductConfigs).actions).storageConfigSecret)) (not (((.Values.kubecostProductConfigs).actions).storageConfig)) }}
    - name: actions-storage
      mountPath: /var/configs/actions/storage
    - name: federated-storage-config
      mountPath: /var/configs/actions/storage/actions-store.yaml
      subPath: federated-store.yaml
      readOnly: true
    {{- end }}
    {{- if ((.Values.kubecostProductConfigs).actions).storageConfig }}
    - name: actions-storage-config
      mountPath: /var/configs/actions/storage
    {{- end }}
    {{- if ((.Values.kubecostProductConfigs).actions).storageConfigSecret }}
    {{- if eq ((.Values.kubecostProductConfigs).actions).storageConfigSecret (.Values.kubecostModel).federatedStorageConfigSecret }}
    - name: actions-storage
      mountPath: /var/configs/actions/storage
    - name: federated-storage-config
      mountPath: /var/configs/actions/storage/actions-store.yaml
      subPath: federated-store.yaml
      readOnly: true
    {{- else }}
    - name: actions-storage-config
      mountPath: /var/configs/actions/storage
    {{- end }}
    {{- end }}
    {{- end }}
    {{- /* Only adds extraVolumeMounts if aggregator is running as its own pod */}}
    {{- if and .Values.kubecostAggregator.extraVolumeMounts (eq (include "aggregator.deployMethod" .) "statefulset") }}
    {{- toYaml .Values.kubecostAggregator.extraVolumeMounts | nindent 4 }}
    {{- end }}
    {{- if .Values.global.integrations.turbonomic.enabled }}
    - name: turbonomic-credentials
      mountPath: /var/configs/turbonomic
    {{- end }}
  env:
    {{- if and (.Values.prometheus.server.global.external_labels.cluster_id) (not .Values.prometheus.server.clusterIDConfigmap) }}
    - name: CLUSTER_ID
      value: {{ .Values.prometheus.server.global.external_labels.cluster_id }}
    {{- end }}
    {{- if .Values.prometheus.server.clusterIDConfigmap }}
    - name: CLUSTER_ID
      valueFrom:
        configMapKeyRef:
          name: {{ .Values.prometheus.server.clusterIDConfigmap }}
          key: CLUSTER_ID
    {{- end }}
    {{- if and ((.Values.kubecostProductConfigs).productKey).mountPath (eq (include "aggregator.deployMethod" .) "statefulset") }}
    - name: PRODUCT_KEY_MOUNT_PATH
      value: {{ .Values.kubecostProductConfigs.productKey.mountPath }}
    {{- end }}
    {{- if and ((.Values.kubecostProductConfigs).smtp).mountPath (eq (include "aggregator.deployMethod" .) "statefulset") }}
    - name: SMTP_CONFIG_MOUNT_PATH
      value: {{ .Values.kubecostProductConfigs.smtp.mountPath }}
    {{- end }}
    {{- if .Values.smtpConfigmapName }}
    - name: SMTP_CONFIGMAP_NAME
      value: {{ .Values.smtpConfigmapName }}
    {{- end }}
    {{- if (gt (int .Values.kubecostAggregator.numDBCopyPartitions) 0) }}
    - name: NUM_DB_COPY_CHUNKS
      value: {{ .Values.kubecostAggregator.numDBCopyPartitions | quote }}
    {{- end }}
    {{- if .Values.kubecostAggregator.legacyMode }}
    - name: LEGACY_MODE
      value: "true"
    {{- end }}
    {{- if .Values.kubecostAggregator.jaeger.enabled }}
    - name: TRACING_URL
      value: "http://localhost:14268/api/traces"
    {{- end }}
    - name: CONFIG_PATH
      value: /var/configs/
    {{- if and .Values.persistentVolume.dbPVEnabled (eq (include "aggregator.deployMethod" .) "singlepod") }}
    - name: ETL_PATH_PREFIX
      value: "/var/db"
    {{- end }}
    - name: CLOUD_PROVIDER_API_KEY
      value: "AIzaSyDXQPG_MHUEy9neR7stolq6l0ujXmjJlvk" # The GCP Pricing API key.This GCP api key is expected to be here and is limited to accessing google's billing API.'
    {{- if .Values.global.integrations.postgres.enabled }}
    - name: AGGREGATOR_ADDRESS
    {{- if or .Values.saml.enabled .Values.oidc.enabled }}
      value: localhost:9008
    {{- else }}
      value: localhost:9004
    {{- end }}
    - name: INT_PG_ENABLED
      value: "true"
    - name: INT_PG_RUN_INTERVAL
      value: {{ quote .Values.global.integrations.postgres.runInterval }}
    {{- end }}
    - name: READ_ONLY
      value: {{ (quote .Values.readonly) | default (quote false) }}
    {{- if .Values.systemProxy.enabled }}
    - name: HTTP_PROXY
      value: {{ .Values.systemProxy.httpProxyUrl }}
    - name: http_proxy
      value: {{ .Values.systemProxy.httpProxyUrl }}
    - name: HTTPS_PROXY
      value:  {{ .Values.systemProxy.httpsProxyUrl }}
    - name: https_proxy
      value:  {{ .Values.systemProxy.httpsProxyUrl }}
    - name: NO_PROXY
      value:  {{ .Values.systemProxy.noProxy }}
    - name: no_proxy
      value:  {{ .Values.systemProxy.noProxy }}
    {{- end }}
    {{- if ((.Values.kubecostProductConfigs).carbonEstimates) }}
    - name: CARBON_ESTIMATES_ENABLED
      value: "true"
    {{- end }}
    - name: CUSTOM_COST_ENABLED
      value: {{ .Values.kubecostModel.plugins.enabled | quote }}
    {{- if .Values.diagnostics.enabled }}
    - name: DIAGNOSTICS_ENABLED
      value: "true"
    - name: DIAGNOSTICS_RETENTION
      value: {{ .Values.diagnostics.retention | quote }}
    {{- end }}
    {{- if .Values.kubecostAggregator.extraEnv -}}
    {{- toYaml .Values.kubecostAggregator.extraEnv | nindent 4 }}
    {{- end }}
    {{- if eq (include "aggregator.deployMethod" .) "statefulset" }}
    # If this isn't set, we pretty much have to be in a read only state,
    # initialization will probably fail otherwise.
    - name: ETL_BUCKET_CONFIG
      {{- if and (not .Values.kubecostModel.federatedStorageConfigSecret) (not .Values.kubecostModel.federatedStorageConfig) }}
      value: /var/configs/etl/object-store.yaml
      {{- else }}
      value: /var/configs/etl/federated-store.yaml
    - name: FEDERATED_STORE_CONFIG
      value: /var/configs/etl/federated-store.yaml
    - name: FEDERATED_PRIMARY_CLUSTER # this ensures the ingester runs assuming federated primary paths in the bucket
      value: "true"
    - name: FEDERATED_CLUSTER # this ensures the ingester runs assuming federated primary paths in the bucket
      value: "true"
    {{- if (.Values.kubecostProductConfigs).standardDiscount }}
    {{- if .Values.ingestionConfigmapName }}
    - name: INGESTION_CONFIGMAP_NAME
      value: {{ .Values.ingestionConfigmapName }}
    {{- end }}
    {{- end }}
      {{- end }}
    {{- end }}
    - name: LOG_LEVEL
      value: {{ .Values.kubecostAggregator.logLevel }}
    - name: DB_READ_THREADS
      value: {{ .Values.kubecostAggregator.dbReadThreads | quote }}
    - name: DB_WRITE_THREADS
      value: {{ .Values.kubecostAggregator.dbWriteThreads | quote }}
    - name: DB_CONCURRENT_INGESTION_COUNT
      value: {{ .Values.kubecostAggregator.dbConcurrentIngestionCount | quote }}
    {{- if ne .Values.kubecostAggregator.dbMemoryLimit "0GB" }}
    - name: DB_MEMORY_LIMIT
      value: {{ .Values.kubecostAggregator.dbMemoryLimit | quote }}
    {{- end }}
    {{- if ne .Values.kubecostAggregator.dbWriteMemoryLimit "0GB" }}
    - name: DB_WRITE_MEMORY_LIMIT
      value: {{ .Values.kubecostAggregator.dbWriteMemoryLimit | quote }}
    {{- end }}
    - name: ETL_DAILY_STORE_DURATION_DAYS
      value: {{ .Values.kubecostAggregator.etlDailyStoreDurationDays | quote }}
    - name: ETL_HOURLY_STORE_DURATION_HOURS
      value: {{ .Values.kubecostAggregator.etlHourlyStoreDurationHours | quote }}
    - name: CONTAINER_RESOURCE_USAGE_RETENTION_DAYS
      value: {{ .Values.kubecostAggregator.containerResourceUsageRetentionDays | quote }}
    - name: DB_TRIM_MEMORY_ON_CLOSE
      value: {{ .Values.kubecostAggregator.dbTrimMemoryOnClose | quote }}
    - name: KUBECOST_NAMESPACE
      value: {{ .Release.Namespace }}
    {{- if .Values.global.grafana }}
    - name: GRAFANA_ENABLED
      value: "{{ template "cost-analyzer.grafanaEnabled" . }}"
    {{- end}}
    {{- if .Values.oidc.enabled }}
    - name: OIDC_ENABLED
      value: "true"
    - name: OIDC_SKIP_ONLINE_VALIDATION
      value: {{ (quote .Values.oidc.skipOnlineTokenValidation) | default (quote false) }}
    {{- end}}
    {{- if eq (include "rbacTeamsEnabled" .) "true" }}
    {{- if .Values.oidc.enabled }}
    - name: OIDC_RBAC_TEAMS_ENABLED
      value: "true"
    {{- end }}
    {{- if .Values.saml.enabled }}
    - name: SAML_RBAC_TEAMS_ENABLED
      value: "true"
    {{- end }}
    {{- end }}
    {{- if eq (include "authMasterKeyEnabled" .) "true" }}
    - name: AUTH_MASTER_API_KEY_ENABLED
      value: "true"
    {{- end }}
    {{- if eq (include "rbacTeamsConfigEnabled" .) "true" }}
    - name: RBAC_TEAMS_HELM_CONFIG_PATH
      value: "/var/configs/rbac-teams-configs/rbac-teams-configs.json"
    {{- end }}
    {{- if .Values.kubecostAggregator }}
    {{- if .Values.kubecostAggregator.collections }}
    {{- if (((.Values.kubecostAggregator).collections).cache) }}
    - name: COLLECTIONS_MEMORY_CACHE_ENABLED
      value: {{ (quote .Values.kubecostAggregator.collections.cache.enabled) | default (quote true) }}
    {{- end }}
    {{- end }}
    {{- end }}
    {{- if .Values.global.integrations.turbonomic.enabled }}
    - name: TURBONOMIC_ENABLED
      value: "true"
    {{- end }}
    {{- if .Values.saml }}
    {{- if .Values.saml.enabled }}
    - name: SAML_ENABLED
      value: "true"
    - name: IDP_URL
      value: {{ .Values.saml.idpMetadataURL }}
    - name: SP_HOST
      value: {{ .Values.saml.appRootURL }}
    {{- if .Values.saml.audienceURI }}
    - name: AUDIENCE_URI
      value: {{ .Values.saml.audienceURI }}
    {{- end }}
    {{- if .Values.saml.isGLUUProvider }}
    - name: GLUU_SAML_PROVIDER
      value: {{ (quote .Values.saml.isGLUUProvider) }}
    {{- end }}
    {{- if .Values.saml.nameIDFormat }}
    - name: NAME_ID_FORMAT
      value: {{ .Values.saml.nameIDFormat }}
    {{- end}}
    {{- if .Values.saml.authTimeout }}
    - name: AUTH_TOKEN_TIMEOUT
      value: {{ (quote .Values.saml.authTimeout) }}
    {{- end}}
    {{- if .Values.saml.redirectURL }}
    - name: LOGOUT_REDIRECT_URL
      value: {{ .Values.saml.redirectURL }}
    {{- end}}
    {{- if .Values.saml.rbac.enabled }}
    {{- if eq (include "rbacTeamsEnabled" .) "false" }}
    - name: SAML_RBAC_ENABLED
      value: "true"
    {{- end }}
    {{- end }}
    {{- if and .Values.saml.encryptionCertSecret .Values.saml.decryptionKeySecret }}
    - name: SAML_RESPONSE_ENCRYPTED
      value: "true"
    {{- end}}
    {{- end }}
    {{- end }}
    {{- if (.Values.enterpriseCustomPricing).enabled }}
    - name: ENTERPRISE_CUSTOM_PRICING_ENABLED
      value: "true"
    - name: ENTERPRISE_CUSTOM_PRICING_CSV_LOCATION_URI
      value: {{ (quote .Values.enterpriseCustomPricing.location.URI) }}
    - name: ENTERPRISE_CUSTOM_PRICING_APPLY_RETROACTIVELY
      value: "true"
    {{- end }}
    {{- if (.Values.instanceTypes).enabled }}
    - name: CUSTOM_TYPE_INSTANCES_URI
      value: {{ (quote .Values.instanceTypes.custom.location.URI) }}
    {{- end }}
    {{- if or ((.Values.kubecostProductConfigs).actions).enabled }}
    - name: ACTIONS_BUCKET_CONFIG
      value: /var/configs/actions/storage/actions-store.yaml
    {{- end }}
{{- end }}


{{- define "aggregator.jaeger.sidecarContainerTemplate" }}
- name: embedded-jaeger
  env:
  - name: SPAN_STORAGE_TYPE
    value: badger
  - name: BADGER_EPHEMERAL
    value: "true"
  - name: BADGER_DIRECTORY_VALUE
    value: /tmp/badger/data
  - name: BADGER_DIRECTORY_KEY
    value: /tmp/badger/key
  securityContext:
    {{- toYaml .Values.kubecostAggregator.jaeger.containerSecurityContext | nindent 4 }}
  image: {{ .Values.kubecostAggregator.jaeger.image }}:{{ .Values.kubecostAggregator.jaeger.imageVersion }}
{{- end }}


{{- define "aggregator.cloudCost.containerTemplate" }}
- name: cloud-cost
  {{- if .Values.kubecostModel }}
  {{- if .Values.kubecostAggregator.fullImageName }}
  image: {{ .Values.kubecostAggregator.fullImageName }}
  {{- else if .Values.kubecostModel.fullImageName }}
  image: {{ .Values.kubecostModel.fullImageName }}
  {{- else if .Values.imageVersion }}
  image: {{ .Values.kubecostModel.image }}:{{ .Values.imageVersion }}
  {{- else if eq "development" .Chart.AppVersion }}
  image: gcr.io/kubecost1/cost-model-nightly:latest
  {{- else }}
  image: {{ .Values.kubecostModel.image }}:prod-{{ $.Chart.AppVersion }}
  {{ end }}
  {{- else }}
  image: gcr.io/kubecost1/cost-model:prod-{{ $.Chart.AppVersion }}
  {{ end }}
  {{- if .Values.kubecostAggregator.cloudCost.readinessProbe.enabled }}
  readinessProbe:
    httpGet:
      path: /healthz
      port: 9005
    initialDelaySeconds: {{ .Values.kubecostAggregator.cloudCost.readinessProbe.initialDelaySeconds }}
    periodSeconds: {{ .Values.kubecostAggregator.cloudCost.readinessProbe.periodSeconds }}
    failureThreshold: {{ .Values.kubecostAggregator.cloudCost.readinessProbe.failureThreshold }}
  {{- end }}
  {{- if .Values.kubecostAggregator.imagePullPolicy }}
  imagePullPolicy: {{ .Values.kubecostAggregator.imagePullPolicy }}
  {{- else }}
  imagePullPolicy: Always
  {{- end }}
  args: ["cloud-cost"]
  ports:
    - name: tcp-api
      containerPort: 9005
      protocol: TCP
  resources:
    {{- toYaml .Values.kubecostAggregator.cloudCost.resources | nindent 4 }}
  securityContext:
    {{- if .Values.global.containerSecurityContext }}
    {{- toYaml .Values.global.containerSecurityContext | nindent 4 }}
    {{- end }}
  volumeMounts:
    - name: persistent-configs
      mountPath: /var/configs
  {{- if or (.Values.kubecostModel).federatedStorageConfigSecret (.Values.kubecostModel).federatedStorageConfig }}
    - name: federated-storage-config
      mountPath: /var/configs/etl/federated
      readOnly: true
  {{- end }}
  {{- if or (.Values.kubecostProductConfigs).cloudIntegrationSecret (.Values.kubecostProductConfigs).cloudIntegrationJSON ((.Values.kubecostProductConfigs).athenaBucketName) }}
    - name: cloud-integration
      mountPath: /var/configs/cloud-integration
  {{- end }}
    {{- if .Values.kubecostModel.plugins.enabled }}
    - mountPath: {{ .Values.kubecostModel.plugins.folder }}
      name: plugins-dir
      readOnly: false
    - name: tmp
      mountPath: /tmp
    - mountPath: {{ $.Values.kubecostModel.plugins.folder }}/config
      name: plugins-config
      readOnly: true
    {{- end }}
    {{- if .Values.global.updateCaTrust.enabled }}
    - name: ca-certs-secret
      mountPath: {{ .Values.global.updateCaTrust.caCertsMountPath | quote }}
    - name: ssl-path
      mountPath: "/etc/pki/ca-trust/extracted"
      readOnly: false
    {{- end }}
  {{- /* Only adds extraVolumeMounts when cloudcosts is running as its own pod */}}
  {{- if and .Values.kubecostAggregator.cloudCost.extraVolumeMounts (eq (include "aggregator.deployMethod" .) "statefulset") }}
    {{- toYaml .Values.kubecostAggregator.cloudCost.extraVolumeMounts | nindent 4 }}
  {{- end }}
  env:
    - name: CONFIG_PATH
      value: /var/configs/
    {{- if or .Values.kubecostModel.federatedStorageConfigSecret .Values.kubecostModel.federatedStorageConfig }}
    - name: FEDERATED_STORE_CONFIG
      value: /var/configs/etl/federated/federated-store.yaml
    - name: FEDERATED_CLUSTER
      value: "true"
    {{- end}}
    - name: ETL_DAILY_STORE_DURATION_DAYS
      value: {{ (quote .Values.kubecostModel.etlDailyStoreDurationDays) }}
    - name: CLOUD_COST_REFRESH_RATE_HOURS
      value: {{ .Values.kubecostAggregator.cloudCost.refreshRateHours | default 6 | quote }}
    - name: CLOUD_COST_QUERY_WINDOW_DAYS
      value: {{ .Values.kubecostAggregator.cloudCost.queryWindowDays | default 7 | quote }}
    - name: CLOUD_COST_RUN_WINDOW_DAYS
      value: {{ .Values.kubecostAggregator.cloudCost.runWindowDays | default 3 | quote }}
    - name: CUSTOM_COST_ENABLED
      value: {{ .Values.kubecostModel.plugins.enabled | quote }}
    {{- range $key, $value := .Values.kubecostAggregator.cloudCost.env }}
    - name: {{ $key | quote }}
      value: {{ $value | quote }}
    {{- end }}
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
{{- end }}

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
{{- define "kubecost.productKey.secretName" -}}
{{- default "product-key" .Values.kubecostProductConfigs.productKey.secretname -}}
{{- end -}}

{{/*
Kubecost image to be used by all apps which run, can be overridden in each apps specific configs
*/}}
{{- define "kubecost.image" }}
{{- .Values.kubecost.image.registry }}/{{ .Values.kubecost.image.repository }}:{{ .Values.kubecost.image.tag }}
{{- end }}

{{/*
federated storage config helpers
*/}}

{{- define "kubecost.federatedStorage.secretName" }}
{{- if (.Values.global.federatedStorage).existingSecret -}}
(.Values.global.federatedStorage).existingSecret
{{- else -}}
{{ .Release.Name }}-federated-storage-config
{{- end }}
{{- end -}}

{{- define "kubecost.federatedStorage.config" }}
{{- if .Values.kubecostModel.federatedStorageConfig -}}
{{ (.Values.kubecostModel).federatedStorageConfig }}
{{- else if (.Values.federatedStorage).config }}
{{ (.Values.federatedStorage).config }}
{{ else }}
{{/*
TODO:Default federated storage config 
for single cluster environments
*/}}
type: cluster
{{- end }}
{{- end }}

{{- define "kubecost.federatedStorage.fileName" -}}
{{ default "federated-store.yaml" (.Values.global.federatedStorage).fileName }}
{{- end -}}
