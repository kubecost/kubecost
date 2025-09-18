{{- define "networkCosts.imageRegistry" -}}
  {{- if .Values.networkCosts.image.registry -}}
    {{- .Values.networkCosts.image.registry -}}
  {{- else -}}
    {{- .Values.global.imageRegistry -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.networkCosts.image" }}
  {{- if .Values.networkCosts.fullImageName }}
    {{- .Values.networkCosts.fullImageName }}
  {{- else -}}
    {{- include "networkCosts.imageRegistry" . }}/{{ .Values.networkCosts.image.repository }}:{{ .Values.networkCosts.image.tag }}
  {{- end }}
{{- end }}

{{/*
Network Costs name used to tie autodiscovery of metrics to daemon set pods
*/}}
{{- define "kubecost.networkCosts.name" -}}
{{- printf "%s-%s" .Release.Name "network-costs" -}}
{{- end -}}

{{/*
Create the networkcosts common labels. Note that because this is a daemonset, we don't want app.kubernetes.io/instance: to take the release name, which allows the scrape config to be static.
*/}}
{{- define "kubecost.networkCosts.commonLabels" -}}
app.kubernetes.io/instance: kubecost
app.kubernetes.io/name: network-costs
helm.sh/chart: {{ include "kubecost.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ template "kubecost.networkCosts.name" . }}
{{- end -}}

{{- define "kubecost.networkCosts.selectorLabels" -}}
app: {{ template "kubecost.networkCosts.name" . }}
{{- end }}
