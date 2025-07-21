{{- define "kubecost.aggregator.name" -}}
{{- default "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.aggregator.fullname" -}}
{{- printf "%s-%s" .Release.Name "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.aggregator.serviceName" -}}
{{- printf "%s-%s" .Release.Name "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "aggregator.serviceAccountName" -}}
{{- if .Values.aggregator.serviceAccountName -}}
    {{ .Values.aggregator.serviceAccountName }}
{{- else -}}
    {{ template "cost-analyzer.serviceAccountName" . }}
{{- end -}}
{{- end -}}

{{- define "aggregator.commonLabels" -}}
{{ include "cost-analyzer.chartLabels" . }}
app: aggregator
{{- end -}}

{{- define "aggregator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.aggregator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: aggregator
{{- end }}

{{- define "kubecost.aggregator.image" -}}
{{ include "kubecost.image" . }}
{{- end }}



{{- define "kubecost.actions.secretName" -}}
{{- if ((.Values.kubecostProductConfigs).actions).exportBucketSecret }}
{{- ((.Values.kubecostProductConfigs).actions).exportBucketSecret }}
{{- else }}
{{ .Release.Name }}-actions-export-bucket-config
{{- end }}
{{- end -}}