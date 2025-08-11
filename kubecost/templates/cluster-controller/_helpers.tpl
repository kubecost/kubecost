{{- define "kubecost.clusterController.enabled" }}
{{- if (.Values.clusterController).enabled }}
{{- printf "true" -}}
{{- else -}}
{{- printf "false" -}}
{{- end -}}
{{- end -}}

{{- define "kubecost.clusterController.image" }}
  {{- if .Values.clusterController.fullImageName }}
    {{- .Values.clusterController.fullImageName }}
  {{- else -}}
    {{- include "common.imageRegistry" . }}/{{ .Values.clusterController.image.repository }}:{{ .Values.clusterController.image.tag }}
  {{- end }}
{{- end }}

{{- define "kubecost.clusterController.name" -}}
{{- printf "%s-%s" .Release.Name "cluster-controller" -}}
{{- end -}}

{{- define "kubecost.clusterController.actionsBucketConfigSecretName" -}}
{{- if (.Values.clusterController).storageConfigSecret }}
{{- printf "%s" .Values.clusterController.storageConfigSecret -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "actions-bucket-config" | trunc 63 -}}
{{- end -}}
{{- end }}