{{- define "kubecost.clusterStorage.image" }}
  {{- if .Values.clusterStorage.fullImageName }}
    {{- .Values.clusterStorage.fullImageName }}
  {{- else if .Values.kubecost.fullImageName }}
    {{- .Values.kubecost.fullImageName }}
  {{- else if eq "development" .Chart.AppVersion -}}
    gcr.io/kubecost1/cost-model-nightly:latest
  {{- else -}}
    {{- include "common.imageRegistry" . }}/{{ .Values.kubecost.image.repository }}:{{ .Values.kubecost.image.tag }}
  {{- end }}
{{- end }}

{{- define "kubecost.clusterStorage.name" -}}
{{- default "cluster-storage" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.clusterStorage.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "kubecost.clusterStorage.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.clusterStorage.serviceName" -}}
{{ include "kubecost.clusterStorage.fullname" . }}
{{- end -}}

{{- define "kubecost.clusterStorage.commonLabels" -}}
{{ include "kubecost.chartLabels" . }}
{{ include "kubecost.clusterStorage.selectorLabels" . }}
{{- end -}}

{{- define "kubecost.clusterStorage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.clusterStorage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "kubecost.clusterStorage.name" . }}
{{- end }}


