{{- define "frontend.imageRegistry" -}}
  {{- if .Values.frontend.image.registry -}}
    {{- .Values.frontend.image.registry -}}
  {{- else -}}
    {{- .Values.global.imageRegistry -}}
  {{- end -}}
{{- end -}}

{{- define "kubecost.frontend.image" }}
  {{- if .Values.frontend.fullImageName }}
    {{- .Values.frontend.fullImageName }}
  {{- else if eq "development" .Chart.AppVersion -}}
    gcr.io/kubecost1/frontend-nightly:latest
  {{- else if .Values.frontend.image.tag -}}
    {{- include "frontend.imageRegistry" . }}/{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}
  {{- else -}}
    {{- include "frontend.imageRegistry" . }}/{{ .Values.frontend.image.repository }}:{{ $.Chart.AppVersion }}
  {{- end }}
{{- end }}

{{- define "kubecost.frontend.name" -}}
{{- default "frontend" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.frontend.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "kubecost.frontend.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubecost.frontend.serviceName" -}}
{{ include "kubecost.frontend.fullname" . }}
{{- end -}}

{{/*
Create the selector labels for haMode frontend.
*/}}
{{- define "kubecost.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubecost.frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: cost-analyzer
{{- end -}}

{{/*
Create the nginx config map name with fallback logic.
*/}}
{{- define "kubecost.frontend.nginxConfigMapName" -}}
{{- if .Values.frontend.nginxConfigMapName -}}
  {{- .Values.frontend.nginxConfigMapName -}}
{{- else -}}
  {{- printf "nginx-conf-%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create the branding config map name with fallback logic.
*/}}
{{- define "kubecost.frontend.logoConfigMapName" -}}
{{- if ((.Values.kubecostProductConfigs).branding).configmap -}}
  {{- ((.Values.kubecostProductConfigs).branding).configmap  -}}
{{- else -}}
  {{ printf "frontend-logo-%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}
{{- end -}}

{{/*
Merge bufferConfig.directives with extraServerConfig lines, render nginx directives.
*/}}
{{- define "kubecost.frontend.serverBlockConfig" -}}
  {{- $fromExtra := dict -}}
  {{- range $line := splitList "\n" (.Values.frontend.extraServerConfig | default "" | toString) -}}
    {{- $trimmed := $line | trim | trimSuffix ";" | trim -}}
    {{- if $trimmed -}}
      {{- $parts := regexSplit "\\s+" $trimmed 2 -}}
      {{- if ge (len $parts) 2 -}}
        {{- $fromExtra = mergeOverwrite $fromExtra (dict (index $parts 0) (index $parts 1)) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- $base := dict -}}
  {{- if .Values.frontend.bufferConfig.enabled -}}
    {{- $base = .Values.frontend.bufferConfig.directives | default dict -}}
  {{- end -}}
  {{- $merged := mergeOverwrite $base $fromExtra -}}

  {{- $out := "" -}}
  {{- range $key := sortAlpha (keys $merged) -}}
    {{- $out = printf "%s%s %s;\n" $out $key (index $merged $key) -}}
  {{- end -}}
  {{- trimSuffix "\n" $out -}}
{{- end -}}