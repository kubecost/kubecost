{{- define "forecastingEnabled" }}
{{- if (.Values.forecasting).enabled }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- define "forecasting.name" -}}
{{- default "forecasting" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "forecasting.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "forecasting.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "forecasting.serviceName" -}}
{{ include "forecasting.fullname" . }}
{{- end -}}

{{- define "forecasting.commonLabels" -}}
{{ include "cost-analyzer.chartLabels" . }}
{{ include "forecasting.selectorLabels" . }}
{{- end -}}

{{- define "forecasting.selectorLabels" -}}
app.kubernetes.io/name: {{ include "forecasting.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "forecasting.name" . }}
{{- end -}}