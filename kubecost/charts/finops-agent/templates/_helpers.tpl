{{/*
Copyright IBM, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{- define "finops-agent.clusterId" -}}
{{- if .Values.global.clusterId -}}
{{ .Values.global.clusterId }}
{{- else if .Values.clusterId -}}
{{ .Values.clusterId }}
{{- else -}}
{{ fail "\n\nclusterId is required. Please set .Values.global.clusterId" }}
{{- end -}}
{{- end -}}

{{/*
Return the proper FinOps Agent Core image name
*/}}
{{- define "finops-agent.image" -}}
{{- if .Values.fullImageName -}}
{{ .Values.fullImageName }}
{{- else -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "finops-agent.imagePullSecrets" -}}
{{ include "common.images.pullSecrets" (dict "images" (list .Values.image ) "global" .Values.global) }}
{{- end -}}

{{/*
Create the name of the ServiceAccount to use
*/}}
{{- define "finops-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Check if the cluster is running on GCP and provide appropriate warnings
*/}}
{{- define "finops-agent.gcpCheck" -}}
{{- /* Check for GCP-specific node labels to auto-detect GCP clusters */ -}}
{{- $isGCP := false -}}
{{- range $node := (lookup "v1" "Node" "" "").items -}}
  {{- range $key, $value := $node.metadata.labels -}}
    {{- if contains "google" $key -}}
      {{- $isGCP = true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $isGCP -}}
{{- if not (or (.Values.global.cspPricingApiKey.apiKey) (.Values.global.cspPricingApiKey.existingSecret) (.Values.global.cspPricingApiKey.useDefaultApiKey)) }}
{{ printf "\nCONFIGURATION ERROR: GCP detected. For GCP clusters, an API key is required to access on-demand pricing data." }}
{{ fail "\nTo install, please set one of the following values:\n\nglobal.cspPricingApiKey.apiKey\nglobal.cspPricingApiKey.existingSecret\nglobal.cspPricingApiKey.useDefaultApiKey\n" }}
{{- end }}
{{- end }}
{{- end }}


{{/*
define the name of the secret with the federated bucket config
*/}}
{{- define "finops-agent.federatedStorageSecretName" }}
{{- if (.Values.global.federatedStorage).existingSecret }}
{{- .Values.global.federatedStorage.existingSecret }}
{{- else }}
{{- .Release.Name }}-federated-storage-config
{{- end }}
{{- end }}

{{- define "finops-agent.federatedStorageFileName" }}
{{- if .Values.global.federatedStorage.fileName }}
{{- .Values.global.federatedStorage.fileName }}
{{- else }}
{{- "federated-store.yaml" }}
{{- end }}
{{- end }}

{{/*
define the name of the cloudability secret
*/}}
{{- define "cloudability.secret.name" }}
{{- if .Values.agent.cloudability.secret.create }}
{{ .Release.Name }}-cloudability-secrets
{{- else if .Values.agent.cloudability.secret.existingSecret }}
{{.Values.agent.cloudability.secret.existingSecret}}
{{- else }}
{{- "" }}
{{- end }}
{{- end }}

{{/*
define the name of the csp pricing api key secret
*/}}
{{- define "finops-agent.cspPricingApiKeySecretName" }}
{{- if or .Values.global.cspPricingApiKey.apiKey .Values.global.cspPricingApiKey.useDefaultApiKey }}
{{ .Release.Name }}-csp-pricing-api-key-secret
{{- else if .Values.global.cspPricingApiKey.existingSecret }}
{{.Values.global.cspPricingApiKey.existingSecret}}
{{- else }}
{{- "disabled" }}
{{- end }}
{{- end }}

{{- define "finops-agent.exportBucketLegacyCheck" }}
{{- if (((.Values.exportBucket).secret).config) }}
{{- fail "\n\nexportBucket.secret.config has changed. Please use global.federatedStorage.config instead" }}
{{- end }}
{{- if (((.Values.exportBucket).secret).existingSecret) }}
{{- fail "\n\nexportBucket.secret.existingSecret has changed. Please use global.federatedStorage.existingSecret instead" }}
{{- end }}
{{- if ((.Values.federatedStorage).config) }}
{{- fail "\n\nfederatedStorage.config has changed. Please use global.federatedStorage.config instead" }}
{{- end }}
{{- if ((.Values.federatedStorage).existingSecret) }}
{{- fail "\n\nfederatedStorage.existingSecret has changed. Please use global.federatedStorage.existingSecret instead" }}
{{- end }}

{{- end }}

{{/*
check if the finops agent is configured to send data to the cloudability platform or kubecost.
We may want for this to be a failure if the agent cannot send historical data that was collected prior to being correctly configured.
*/}}
{{- define "finops-agent.configCheck" }}
{{- if not (or (.Values.global.federatedStorage.existingSecret) (.Values.global.federatedStorage.config) (.Values.agent.cloudability.enabled)) }}
{{ printf "\nCONFIGURATION WARNING: The finops agent requires configuration.\nFor Kubecost, please provide a federated storage config\nFor Cloudability, set agent.cloudability.enabled to true\n" }}
{{- else }}
{{ printf "You have successfully installed the IBM FinOps agent!" }}
{{- end }}
{{- end }}

{{- define "finops-agent.kubecostEnabled" }}
{{- if or (.Values.global.federatedStorage.existingSecret) (.Values.global.federatedStorage.config) (eq .Values.global.chartName "kubecost") }}
{{- true }}
{{- else }}
{{- false }}
{{- end }}
{{- end }}

{{- define "finops-agent.globalChecksum" -}}
{{- /* Add global values to the checksum */ -}}
{{- $globalChecksum := toYaml $.Values.global | sha256sum -}}
{{- $checksum = printf "%s%s" $checksum $globalChecksum | sha256sum -}}
{{- $checksum | sha256sum -}}
{{- end -}}

{{- define "finops-agent.caCertsSecretConfig.check" }}
  {{- if .Values.global.updateCaTrust.enabled }}
    {{- if and .Values.global.updateCaTrust.caCertsSecret .Values.global.updateCaTrust.caCertsConfig }}
      {{- fail "Both caCertsSecret and caCertsConfig are defined. Please specify only one." }}
    {{- else if and (not .Values.global.updateCaTrust.caCertsSecret) (not .Values.global.updateCaTrust.caCertsConfig) }}
      {{- fail "Neither caCertsSecret nor caCertsConfig is defined, but updateCaTrust is enabled. Please specify atleast one." }}
    {{- end }}
  {{- end }}
{{- end }}