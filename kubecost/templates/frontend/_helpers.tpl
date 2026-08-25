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

{{/*
Shared proxy directives for MCP upstream locations. Long read/send timeouts
and buffering off are required for FastMCP streamable HTTP.
When mcp.config.authMode is "none" the endpoint is unconfigured/unacknowledged;
return a 503 informational response instead of proxying to the MCP backend.
When mcp.config.authMode is "open" the operator has explicitly acknowledged
unauthenticated exposure — requests are proxied normally without auth enforcement.
*/}}
{{- define "kubecost.frontend.mcpProxyDirectives" -}}
{{- if eq (include "kubecost.mcp.authMode" .) "none" -}}
add_header Content-Type text/plain;
return 503 "MCP endpoint is not configured. Set mcp.config.authMode to enable access.";
{{- else -}}
proxy_connect_timeout       300;
proxy_send_timeout          3600;
proxy_read_timeout          3600;
proxy_pass http://mcpKubecost;
proxy_redirect off;
proxy_http_version 1.1;
proxy_set_header Connection "";
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_buffering off;
proxy_cache off;
chunked_transfer_encoding on;
{{- end -}}
{{- end -}}