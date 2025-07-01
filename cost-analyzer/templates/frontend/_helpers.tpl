{{- define "frontend.name" -}}
{{- default "frontend" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "frontend.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "frontend.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "frontend.serviceName" -}}
{{ include "frontend.fullname" . }}
{{- end -}}

{{/*
Create the selector labels for haMode frontend.
*/}}
{{- define "frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: cost-analyzer
{{- end -}}