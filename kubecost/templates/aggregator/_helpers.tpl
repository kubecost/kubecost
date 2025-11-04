{{- define "kubecost.aggregator.imageRegistry" -}}
  {{- if .Values.aggregator.image.registry -}}
    {{- .Values.aggregator.image.registry -}}
  {{- else -}}
    {{- .Values.global.imageRegistry -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.aggregator.image" }}
  {{- if .Values.aggregator.fullImageName }}
    {{- .Values.aggregator.fullImageName }}
  {{- else if eq "development" .Chart.AppVersion -}}
    gcr.io/kubecost1/cost-model-nightly:latest
  {{- else if .Values.aggregator.image.tag -}}
    {{- include "kubecost.aggregator.imageRegistry" . }}/{{ .Values.aggregator.image.repository }}:{{ .Values.aggregator.image.tag }}
  {{- else -}}
    {{- include "kubecost.aggregator.imageRegistry" . }}/{{ .Values.aggregator.image.repository }}:{{ $.Chart.AppVersion }}
  {{- end }}
{{- end }}

{{- define "kubecost.aggregator.name" -}}
{{- default "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.aggregator.cm.helmvalues.name" -}}
{{- printf "helm-values-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.aggregator.fullname" -}}
{{- printf "%s-%s" .Release.Name "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.aggregator.serviceName" -}}
{{- printf "%s-%s" .Release.Name "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.aggregator.serviceAccountName" -}}
{{- if .Values.aggregator.serviceAccountName -}}
    {{ .Values.aggregator.serviceAccountName }}
{{- else -}}
    {{ template "kubecost.serviceAccountName" . }}
{{- end -}}
{{- end -}}

{{- define "kubecost.aggregator.commonLabels" -}}
{{ include "kubecost.chartLabels" . }}
app: aggregator
{{- end -}}

{{- define "kubecost.aggregator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.aggregator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: aggregator
{{- end }}

{{- define "kubecost.actions.secretName" -}}
{{- if ((.Values.kubecostProductConfigs).actions).storageConfigSecret -}}
  {{- ((.Values.kubecostProductConfigs).actions).storageConfigSecret -}}
{{- else -}}
  {{ .Release.Name }}-actions-storage-config
{{- end -}}
{{- end -}}

{{- define "kubecost.smtp.secretName" -}}
{{- if ((.Values.kubecostProductConfigs).smtp).secretname -}}
  {{- ((.Values.kubecostProductConfigs).smtp).secretname -}}
{{- else -}}
  {{ default (printf "smtp-configs-%s" .Release.Name | trunc 63 | trimSuffix "-") .Values.smtpConfigmapName }}
{{- end -}}
{{- end -}}

{{- define "kubecost.actions.configMapName" -}}
{{- if ((.Values.kubecostProductConfigs).actions).configMapName -}}
  {{- ((.Values.kubecostProductConfigs).actions).configMapName -}}
{{- else -}}
{{ printf "actions-config-%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}
{{- end -}}