{{- define "kubecost.aggregator.image" }}
  {{- if .Values.aggregator.fullImageName }}
    {{- .Values.aggregator.fullImageName }}
  {{- else if .Values.kubecost.fullImageName }}
    {{- .Values.kubecost.fullImageName }}
  {{- else if eq "development" .Chart.AppVersion -}}
    gcr.io/kubecost1/cost-model-nightly:latest
  {{- else if .Values.kubecost.image.tag -}}
    {{- include "common.imageRegistry" . }}/{{ .Values.kubecost.image.repository }}:{{ .Values.kubecost.image.tag }}
  {{- else -}}
    {{- include "common.imageRegistry" . }}/{{ .Values.kubecost.image.repository }}:{{ $.Chart.AppVersion }}
  {{- end }}
{{- end }}

{{- define "kubecost.aggregator.name" -}}
{{- default "aggregator" | trunc 63 | trimSuffix "-" -}}
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