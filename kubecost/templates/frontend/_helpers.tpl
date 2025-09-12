{{- define "kubecost.frontend.image" }}
  {{- if .Values.frontend.fullImageName }}
    {{- .Values.frontend.fullImageName }}
  {{- else if eq "development" .Chart.AppVersion -}}
    gcr.io/kubecost1/frontend-nightly:latest
  {{- else if .Values.frontend.image.tag -}}
    {{- include "common.imageRegistry" . }}/{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}
  {{- else -}}
    {{- include "common.imageRegistry" . }}/{{ .Values.frontend.image.repository }}:{{ $.Chart.AppVersion }}
  {{- end }}
{{- end }}

{{- define "kubecost.frontend.name" -}}
{{- default "frontend" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.frontend.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "kubecost.frontend.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.frontend.serviceName" -}}
{{ include "kubecost.frontend.fullname" . }}
{{- end -}}

{{/*
Create the selector labels for haMode frontend.
*/}}
{{- define "kubecost.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: cost-analyzer
{{- end -}}