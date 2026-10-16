{{- define "kubecost.spark.fullname" -}}
{{- printf "%s-%s" .Release.Name "business-mapping-decorator" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.spark.clickhouseServiceName" -}}
{{- printf "%s-clickhouse" (include "kubecost.aggregator.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.spark.clickhouseUrl" -}}
{{- default (printf "jdbc:clickhouse://%s:8123" (include "kubecost.spark.clickhouseServiceName" .)) .Values.aggregator.kubecostSpark.clickhouseUrl -}}
{{- end -}}

{{- define "kubecost.spark.selectorLabels" -}}
app.kubernetes.io/name: business-mapping-decorator
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "kubecost.spark.fullname" . }}
{{- end -}}

{{- define "kubecost.spark.commonLabels" -}}
{{ include "kubecost.chartLabels" . }}
{{ include "kubecost.spark.selectorLabels" . }}
{{- end -}}
