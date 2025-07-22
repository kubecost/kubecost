{{- define "kubecost.aggregator.name" -}}
{{- default "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.aggregator.fullname" -}}
{{- printf "%s-%s" .Release.Name "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.aggregator.serviceName" -}}
{{- printf "%s-%s" .Release.Name "aggregator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.aggregator.serviceAccountName" -}}
{{- if .Values.kubecost.aggregator.serviceAccountName -}}
    {{ .Values.kubecost.aggregator.serviceAccountName }}
{{- else -}}
    {{ template "kubecost.serviceAccountName" . }}
{{- end -}}
{{- end -}}

{{- define "kubecost.aggregator.commonLabels" -}}
{{ include "kubecost.chartLabels" . }}
app: aggregator
{{- end -}}

{{- define "kubecost.aggregator.selectorLabels" -}}
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