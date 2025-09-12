{{- define "kubecost.forecasting.enabled" }}
{{- if (.Values.forecasting).enabled }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- define "forecasting.imageRegistry" -}}
  {{- if .Values.forecasting.image.registry -}}
    {{- .Values.forecasting.image.registry -}}
  {{- else -}}
    {{- .Values.global.imageRegistry -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.forecasting.image" }}
  {{- if .Values.forecasting.fullImageName }}
    {{- .Values.forecasting.fullImageName }}
  {{- else -}}
    {{- include "forecasting.imageRegistry" . }}/{{ .Values.forecasting.image.repository }}:{{ .Values.forecasting.image.tag }}
  {{- end }}
{{- end }}

{{- define "kubecost.forecasting.name" -}}
{{- default "forecasting" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.forecasting.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "kubecost.forecasting.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.forecasting.serviceName" -}}
{{ include "kubecost.forecasting.fullname" . }}
{{- end -}}

{{- define "kubecost.forecasting.commonLabels" -}}
{{ include "kubecost.chartLabels" . }}
{{ include "kubecost.forecasting.selectorLabels" . }}
{{- end -}}

{{- define "kubecost.forecasting.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.forecasting.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "kubecost.forecasting.name" . }}
{{- end -}}