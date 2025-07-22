
{{- define "clusterControllerEnabled" }}
{{- if (.Values.clusterController).enabled }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- define "kubecost.clusterController.name" -}}
{{- printf "%s-%s" .Release.Name "cluster-controller" -}}
{{- end -}}

