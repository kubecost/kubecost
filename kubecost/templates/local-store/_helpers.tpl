{{- define "kubecost.localStore.enabled" -}}
  {{- if (.Values.kubecostModel).localStoreConfigSecret }}
    {{- printf "Disabled" -}}
  {{- else if (.Values.global.localStore).existingSecret -}}
    {{- printf "Disabled" -}}
  {{- else if (.Values.kubecostModel).federatedStorageConfig -}}
    {{- printf "Disabled" -}}
  {{- else if (.Values.federatedStorage).config -}}
    {{- printf "Disabled" -}}
  {{- else if (.Values.global.federatedStorage).config -}}
    {{- printf "Disabled" -}}
  {{- else -}}
    {{- printf "Enabled" -}}
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

{{- define "kubecost.localStore.name" -}}
{{- default "local-object-store" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.localStore.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "kubecost.localStore.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.localStore.serviceName" -}}
{{ include "kubecost.localStore.fullname" . }}
{{- end -}}

{{- define "kubecost.localStore.commonLabels" -}}
{{ include "kubecost.chartLabels" . }}
{{ include "kubecost.localStore.selectorLabels" . }}
{{- end -}}

{{- define "kubecost.localStore.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.localStore.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "kubecost.localStore.name" . }}
{{- end }}


