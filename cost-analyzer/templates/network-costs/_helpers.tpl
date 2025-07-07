{{/*
Network Costs name used to tie autodiscovery of metrics to daemon set pods
*/}}
{{- define "cost-analyzer.networkCostsName" -}}
{{- printf "%s-%s" .Release.Name "network-costs" -}}
{{- end -}}

{{/*
Create the networkcosts common labels. Note that because this is a daemonset, we don't want app.kubernetes.io/instance: to take the release name, which allows the scrape config to be static.
*/}}
{{- define "networkcosts.commonLabels" -}}
app.kubernetes.io/instance: kubecost
app.kubernetes.io/name: network-costs
helm.sh/chart: {{ include "cost-analyzer.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ template "cost-analyzer.networkCostsName" . }}
{{- end -}}
{{- define "networkcosts.selectorLabels" -}}
app: {{ template "cost-analyzer.networkCostsName" . }}
{{- end }}
