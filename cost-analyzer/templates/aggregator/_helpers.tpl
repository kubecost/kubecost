{{- define "aggregator.name" -}}
{{- default "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "aggregator.fullname" -}}
{{- printf "%s-%s" .Release.Name "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "aggregator.serviceName" -}}
{{- printf "%s-%s" .Release.Name "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "aggregator.serviceAccountName" -}}
{{- if .Values.kubecostAggregator.serviceAccountName -}}
    {{ .Values.kubecostAggregator.serviceAccountName }}
{{- else -}}
    {{ template "cost-analyzer.serviceAccountName" . }}
{{- end -}}
{{- end -}}

{{- define "aggregator.commonLabels" -}}
{{ include "cost-analyzer.chartLabels" . }}
app: aggregator
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