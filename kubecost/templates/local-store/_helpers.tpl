{{- define "kubecost.localStore.enabled" -}}
  {{- if .Values.global.federatedStorage.config -}}
    {{- "disabled" -}}
  {{- else if .Values.global.federatedStorage.existingSecret -}}
    {{- "disabled" -}}
  {{- else if not .Values.localStore.enabled -}}
    {{- "disabled" -}}
  {{- else -}}
    {{- "enabled" -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.localStore.image" }}
  {{- if .Values.localStore.fullImageName }}
    {{- .Values.localStore.fullImageName }}
  {{- else if .Values.kubecost.fullImageName }}
    {{- .Values.kubecost.fullImageName }}
  {{- else if eq "development" .Chart.AppVersion -}}
    gcr.io/kubecost1/cost-model-nightly:latest
  {{- else -}}
    {{- include "common.imageRegistry" . }}/{{ .Values.kubecost.image.repository }}:{{ .Values.kubecost.image.tag }}
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


