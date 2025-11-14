{{/*
Cloud integration source contents check. Either the Secret must be specified or the JSON, not both.
Additionally, for upgrade protection,  Users are asked to select one of the two presently-available sources for cloud integration information.
*/}}
{{- define "kubecost.cloudCost.secretConfigCheck" -}}
  {{- if and .Values.cloudCost.cloudIntegrationSecret .Values.cloudCost.cloudIntegrationJSON -}}
    {{- fail "\ncloudCost.cloudIntegrationSecret and cloudCost.cloudIntegrationJSON are mutually exclusive. Please specify only one." -}}
  {{- end -}}
{{- end -}}


{{/*
Verify the cloud integration secret exists with the expected key when cloud integration is enabled.
Skip the check if CI/CD is enabled and skipSanityChecks is set. Argo CD, for example, does not
support templating a chart which uses the lookup function.
*/}}
{{- define "kubecost.cloudCost.secretValidCheck" -}}
{{- if .Values.cloudCost.cloudIntegrationSecret }}
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

{{- define "kubecost.cloudCost.imageRegistry" -}}
  {{- if .Values.cloudCost.image.registry -}}
    {{- .Values.cloudCost.image.registry -}}
  {{- else -}}
    {{- .Values.global.imageRegistry -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.cloudCost.image" }}
  {{- if .Values.cloudCost.fullImageName }}
    {{- .Values.cloudCost.fullImageName }}
  {{- else if eq "development" .Chart.AppVersion -}}
    gcr.io/kubecost1/cost-model-nightly:latest
  {{- else if .Values.cloudCost.image.tag -}}
    {{- include "kubecost.cloudCost.imageRegistry" . }}/{{ .Values.cloudCost.image.repository }}:{{ .Values.cloudCost.image.tag }}
  {{- else -}}
    {{- include "kubecost.cloudCost.imageRegistry" . }}/{{ .Values.cloudCost.image.repository }}:{{ $.Chart.AppVersion }}
  {{- end }}
{{- end }}

{{- define "kubecost.cloudCost.name" -}}
{{- default "cloud-cost" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.cloudCost.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "kubecost.cloudCost.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.cloudCost.serviceName" -}}
{{ include "kubecost.cloudCost.fullname" . }}
{{- end -}}

{{- define "kubecost.cloudCost.serviceAccountName" -}}
{{- if .Values.cloudCost.serviceAccountName -}}
    {{ .Values.cloudCost.serviceAccountName }}
{{- else -}}
    {{ template "kubecost.serviceAccountName" . }}
{{- end -}}
{{- end -}}

{{- define "kubecost.cloudCost.commonLabels" -}}
{{ include "kubecost.chartLabels" . }}
{{ include "kubecost.cloudCost.selectorLabels" . }}
{{- end -}}

{{- define "kubecost.cloudCost.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.cloudCost.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "kubecost.cloudCost.name" . }}
{{- end }}

{{- define "kubecost.cloudCost.secretName" }}
{{- if .Values.cloudCost.cloudIntegrationSecret }}
{{- .Values.cloudCost.cloudIntegrationSecret }}
{{- else }}
{{- .Release.Name }}-cloud-cost-integration
{{- end }}
{{- end }}

{{- define "kubecost.cloudCost.awsAthena.CloudIntegrationJSON" }}
Kubecost 3.x requires a change to the method that cloud-provider billing integrations are configured.
Please use this output to create a cloud-integration.json config. See:
<https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=installation-cloud-billing-integrations>
for more information

{
    "aws": {
        athena: [
            "bucket": "{{ .Values.kubecostProductConfigs.athenaBucketName }}",
            "region": "{{ .Values.kubecostProductConfigs.athenaRegion }}",
            "database": "{{ .Values.kubecostProductConfigs.athenaDatabase }}",
            "table": "{{ .Values.kubecostProductConfigs.athenaTable }}",
            "projectID": "{{ .Values.kubecostProductConfigs.athenaProjectID }}",
            "workgroup": "{{ default "primary" (.Values.kubecostProductConfigs).athenaWorkgroup }}",
            "authorizer": {
                {{- if (.Values.kubecostProductConfigs).masterPayerARN }}
                "authorizerType": "AWSAssumeRole",
                "roleARN": "{{ .Values.kubecostProductConfigs.masterPayerARN }}"
                "authorizer" {
                    {{- if  and ((.Values.kubecostProductConfigs).awsServiceKeyName) ((.Values.kubecostProductConfigs).awsServiceKeyPassword) }}
                    "authorizerType": "AWSAccessKey",
                    "id": "{{ .Values.kubecostProductConfigs.awsServiceKeyName }}",
                    "secret": "{{ .Values.kubecostProductConfigs.awsServiceKeyPassword }}"
                    {{- else }}
                    "authorizerType": "AWSServiceAccount",
                    {{- end }}
                }
                {{- else if  and ((.Values.kubecostProductConfigs).awsServiceKeyName) ((.Values.kubecostProductConfigs).awsServiceKeyPassword) }}
                "authorizerType": "AWSAccessKey",
                "id": "{{ .Values.kubecostProductConfigs.awsServiceKeyName }}",
                "secret": "{{ .Values.kubecostProductConfigs.awsServiceKeyPassword }}"
                {{- else }}
                "authorizerType": "AWSServiceAccount",
                {{- end }}
            }
        ]
    }
}
{{- end }}

{{- define "kubecost.cloudCost.awsAthena.CloudIntegrationCheck" }}
{{- if ((.Values.kubecostProductConfigs).bigQueryBillingDataDataset) }}
{{- fail (include "kubecost.cloudCost.awsAthena.CloudIntegrationJSON" .) }}
{{- end }}
{{- end }}

{{- define "kubecost.cloudCost.gcpBigQuery.CloudIntegrationJSON" }}
Kubecost 3.x requires a change to the method that cloud-provider billing integrations are configured.
Please use this output to create a cloud-integration.json config. See:
<https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=installation-cloud-billing-integrations>
for more information

{
    "gcp": {
        bigQuery: [
            {
                "dataset": "{{ .Values.kubecostProductConfigs.bigQueryBillingDataDataset }}",
                "table": "{{ .Values.kubecostProductConfigs.bigQueryBillingDataTable }}",
                "projectID": "{{ .Values.kubecostProductConfigs.projectID }}",
                "authorizer": {
                    "authorizerType": "GCPServiceAccountKey",
                    "key": <Service-Account-Key-JSON>
                }
            }
        ]
    }
}
{{- end }}

{{- define "kubecost.cloudCost.gcpBigQuery.CloudIntegrationCheck" }}
{{- if ((.Values.kubecostProductConfigs).bigQueryBillingDataDataset) }}
{{- fail (include "kubecost.cloudCost.gcpBigQuery.CloudIntegrationJSON" .) }}
{{- end }}
{{- end }}

{{- define "kubecost.cloudCost.azureStorage.CloudIntegrationJSON" }}

Kubecost 3.x requires a change to the method that cloud-provider billing integrations are configured.
Please use this output to create a cloud-integration.json config. See:
<https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=installation-cloud-billing-integrations>
for more information

{
    "azure": {
        "storage": [
            {
                "container": "{{ .Values.kubecostProductConfigs.azureStorageContainer }}",
                "subscriptionID": "{{ .Values.kubecostProductConfigs.azureSubscriptionID }}",
                "account": "{{ .Values.kubecostProductConfigs.azureStorageAccount }}",
                "azureStorageAccessKey": "{{ .Values.kubecostProductConfigs.azureStorageKey }}",
                "path": "{{ .Values.kubecostProductConfigs.azureContainerPath }}",
                "cloud": "{{ .Values.kubecostProductConfigs.azureCloud }}"
                "authorizer": {
                    "authorizerType": "AzureAccessKey",
                    "account": "{{ .Values.kubecostProductConfigs.azureStorageAccount }}",
                    "accessKey": "{{ .Values.kubecostProductConfigs.azureStorageKey }}"
                }
            }
        ]
    }
}
{{- end }}

{{- define "kubecost.cloudCost.azureStorage.CloudIntegrationCheck" }}
{{- if ((.Values.kubecostProductConfigs).azureStorageContainer) }}
{{- fail (include "kubecost.cloudCost.azureStorage.CloudIntegrationJSON" .) }}
{{- end }}
{{- end }}