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

{{- define "kubecost.frontend.mcpProxyDirectives" -}}
{{/*
Shared proxy directives for MCP upstream locations. Long read/send timeouts
and buffering off are required for FastMCP streamable HTTP.

The add_header block relaxes `form-action` for these locations. The OAuth
consent page POSTs back to this host and is then redirected on to the external
IdP, and the IdP callback is redirected on again to the MCP client's own
redirect_uri. Chromium enforces `form-action` across that whole redirect chain,
so the server-level `form-action 'self'` blocks the POST and parks the browser
on the consent page -- the login just appears to hang after Approve. Only the
consent page needs this, but it rides along with every MCP location for
simplicity: the others serve JSON or an SSE stream, never a document, so a CSP
on them is inert.

A location-level add_header discards every header inherited from the server
block, so the operator's own frontend.nginxHeaders.server entries are repeated
here, minus any Content-Security-Policy, before the relaxed one.
*/}}
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
{{- range .Values.frontend.nginxHeaders.server }}
{{- if not (contains "Content-Security-Policy" (toString .)) }}
  add_header {{ . }}
{{- end }}
{{- end }}
  add_header Content-Security-Policy "default-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'; form-action *;";
{{- end -}}

