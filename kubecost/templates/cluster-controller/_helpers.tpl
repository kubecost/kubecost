
{{- define "kubecost.clusterController.enabled" }}
{{- if (.Values.clusterController).enabled }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- define "kubecost.clusterController.name" -}}
{{- printf "%s-%s" .Release.Name "cluster-controller" -}}
{{- end -}}

{{- define "kubecost.clusterController.actionsBucketConfigSecretName" -}}
{{- if (.Values.clusterController).existingSecret }}
{{- printf "%s" .Values.clusterController.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "actions-bucket-config" | trunc 63 -}}
{{- end -}}
{{- end }}