{{/*
Cloud integration source contents check. Either the Secret must be specified or the JSON, not both.
Additionally, for upgrade protection,  Users are asked to select one of the two presently-available sources for cloud integration information.
*/}}
{{- define "kubecost.cloudCost.secret-config-check" -}}
  {{- if and (.Values.cloudCost).cloudIntegrationSecret (.Values.cloudCost).cloudIntegrationJSON -}}
    {{- fail "\ncloudCost.cloudIntegrationSecret and cloudCost.cloudIntegrationJSON are mutually exclusive. Please specify only one." -}}
  {{- end -}}
{{- end -}}


{{/*
Verify the cloud integration secret exists with the expected key when cloud integration is enabled.
Skip the check if CI/CD is enabled and skipSanityChecks is set. Argo CD, for example, does not
support templating a chart which uses the lookup function.
*/}}
{{- define "kubecost.cloudCost.secret-valid-check" -}}
{{- if (.Values.cloudCost).cloudIntegrationSecret }}
{{- if not (and .Values.global.platforms.cicd.enabled .Values.global.platforms.cicd.skipSanityChecks) }}
{{-  if .Capabilities.APIVersions.Has "v1/Secret" }}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.cloudCost.cloudIntegrationSecret }}
  {{- if or (not $secret) (not (index $secret.data "cloud-integration.json")) }}
    {{- fail (printf "The cloud integration secret '%s' does not exist or does not contain the expected key 'cloud-integration.json'\nIf you are using `--dry-run`, please add `--dry-run=server`. This requires Helm 3.13+." .Values.cloudCost.cloudIntegrationSecret) }}
  {{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "cloudCost.name" -}}
{{- default "cloud-cost" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cloudCost.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "cloudCost.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cloudCost.serviceName" -}}
{{ include "cloudCost.fullname" . }}
{{- end -}}

{{- define "cloudCost.serviceAccountName" -}}
{{- if (.Values.cloudCost).serviceAccountName -}}
    {{ (.Values.cloudCost).serviceAccountName }}
{{- else -}}
    {{ template "cost-analyzer.serviceAccountName" . }}
{{- end -}}
{{- end -}}

{{- define "cloudCost.commonLabels" -}}
{{ include "cost-analyzer.chartLabels" . }}
{{ include "cloudCost.selectorLabels" . }}
{{- end -}}

{{- define "cloudCost.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudCost.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "cloudCost.name" . }}
{{- end }}

{{- define "kubecost.cloudCost.image" -}}
{{ include "kubecost.image" . }}
{{- end }}

{{- define "kubecost.cloudCost.secretName" -}}
{{- if (.Values.cloudCost).cloudIntegrationSecret }}
(.Values.cloudCost).cloudIntegrationSecret
{{- else }}
{{ .Release.Name }}-cloud-cost-integration
{{- end }}
{{- end }}



{{- define "gcpCloudIntegrationJSON" }}
Kubecost 2.x requires a change to the method that cloud-provider billing integrations are configured.
Please use this output to create a cloud-integration.json config. See:
<https://www.ibm.com/docs/en/kubecost/self-hosted/2.x?topic=installation-cloud-billing-integrations>
for more information

  {
    "gcp":
      {
        [
          {
              "bigQueryBillingDataDataset": "{{ .Values.kubecostProductConfigs.bigQueryBillingDataDataset }}",
              "bigQueryBillingDataProject": "{{ .Values.kubecostProductConfigs.bigQueryBillingDataProject }}",
              "bigQueryBillingDataTable": "{{ .Values.kubecostProductConfigs.bigQueryBillingDataTable }}",
              "projectID": "{{ .Values.kubecostProductConfigs.projectID }}"
          }
        ]
      }
  }
{{- end }}

{{- define "gcpCloudIntegrationCheck" }}
{{- if ((.Values.kubecostProductConfigs).bigQueryBillingDataDataset) }}
{{- fail (include "gcpCloudIntegrationJSON" .) }}
{{- end }}
{{- end }}

{{- define "azureCloudIntegrationJSON" }}

Kubecost 2.x requires a change to the method that cloud-provider billing integrations are configured.
Please use this output to create a cloud-integration.json config. See:
<https://www.ibm.com/docs/en/kubecost/self-hosted/2.x?topic=installation-cloud-billing-integrations>
for more information
  {
    "azure":
      [
        {
            "azureStorageContainer": "{{ .Values.kubecostProductConfigs.azureStorageContainer }}",
            "azureSubscriptionID": "{{ .Values.kubecostProductConfigs.azureSubscriptionID }}",
            "azureStorageAccount": "{{ .Values.kubecostProductConfigs.azureStorageAccount }}",
            "azureStorageAccessKey": "{{ .Values.kubecostProductConfigs.azureStorageKey }}",
            "azureContainerPath": "{{ .Values.kubecostProductConfigs.azureContainerPath }}",
            "azureCloud": "{{ .Values.kubecostProductConfigs.azureCloud }}"
        }
      ]
  }
{{- end }}

{{- define "azureCloudIntegrationCheck" }}
{{- if ((.Values.kubecostProductConfigs).azureStorageContainer) }}
{{- fail (include "azureCloudIntegrationJSON" .) }}
{{- end }}
{{- end }}