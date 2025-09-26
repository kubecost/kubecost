{{- define "kubecost.localStore.enabled" -}}
  {{- if .Values.localStore.enabled -}}
    {{- "enabled" -}}
  {{- else -}}
    {{- "disabled" -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.localStore.imageRegistry" -}}
  {{- if .Values.localStore.image.registry -}}
    {{- .Values.localStore.image.registry -}}
  {{- else -}}
    {{- .Values.global.imageRegistry -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.localStore.image" }}
  {{- if .Values.localStore.fullImageName }}
    {{- .Values.localStore.fullImageName }}
  {{- else if eq "development" .Chart.AppVersion -}}
    gcr.io/kubecost1/cost-model-nightly:latest
  {{- else if .Values.localStore.image.tag -}}
    {{- include "kubecost.localStore.imageRegistry" . }}/{{ .Values.localStore.image.repository }}:{{ .Values.localStore.image.tag }}
  {{- else -}}
    {{- include "kubecost.localStore.imageRegistry" . }}/{{ .Values.localStore.image.repository }}:{{ $.Chart.AppVersion }}
  {{- end }}
{{- end }}

{{- define "kubecost.localStore.fullname" -}}
{{- printf "%s-%s" .Release.Name "local-store" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.localStore.pvcName" -}}
{{- if .Values.localStore.persistentVolume.existingClaim -}}
  {{- .Values.localStore.persistentVolume.existingClaim -}}
{{- else if .Values.fullnameOverride -}}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
  {{- include "kubecost.localStore.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "kubecost.localStore.serviceName" -}}
{{ include "kubecost.localStore.fullname" . }}
{{- end -}}

{{- define "kubecost.localStore.commonLabels" -}}
{{ include "kubecost.chartLabels" . }}
{{ include "kubecost.localStore.selectorLabels" . }}
{{- end -}}

{{- define "kubecost.localStore.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.localStore.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "kubecost.localStore.fullname" . }}
{{- end }}


