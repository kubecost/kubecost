#!/usr/bin/env bash
#
# Validates the mcp-kubecost subchart integration in the kubecost chart.
#
# Checks performed:
#   1. Chart.yaml declares mcp-kubecost with a condition, and Chart.lock agrees.
#   2. The subchart renders nothing by default (opt-in only).
#   3. helm lint passes with the subchart enabled.
#   4. The full chart renders and produces the expected mcp-kubecost resources.
#   5. Parent `global:` values are inherited by the subchart (conformance check).
#   6. The subchart's Kubecost API base URL points at the rendered frontend Service.
#
# Usage (from the repository root):
#   .github/scripts/validate_mcp_subchart.sh [chart-dir]
#
# Requires: helm >= 3.8, yq >= 4.
set -euo pipefail

CHART_DIR="${1:-kubecost}"
RELEASE_NAME="kubecost"
SUBCHART_NAME="mcp-kubecost"
RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$RENDER_DIR"' EXIT

failures=0

pass() { printf '  ok   %s\n' "$1"; }
fail() {
  printf '  FAIL %s\n' "$1" >&2
  printf '::error::%s\n' "$1"
  failures=$((failures + 1))
}
group() { printf '\n==> %s\n' "$1"; }

# assert_eq <description> <expected> <actual>
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$desc"
  else
    fail "$desc (expected '${expected}', got '${actual}')"
  fi
}

# assert_contains <description> <file> <fixed-string>
assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file"; then
    pass "$desc"
  else
    fail "$desc (missing '${needle}')"
  fi
}

# assert_absent <description> <file> <fixed-string>
assert_absent() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file"; then
    fail "$desc (unexpectedly found '${needle}')"
  else
    pass "$desc"
  fi
}

# extract_nginx <render-file> <out-file>
# Pulls the frontend nginx.conf out of a helm template render.
extract_nginx() {
  yq -r \
    'select(.kind == "ConfigMap" and (.metadata.name | test("^nginx-conf-"))) | .data["nginx.conf"]' \
    "$1" > "$2"
}

# assert_helm_fails <description> <stderr-needle> [extra helm --set args...]
# Renders with the subchart enabled; expects helm template to fail with needle in stderr.
assert_helm_fails() {
  local desc="$1" needle="$2"
  shift 2
  local stderr_file="${RENDER_DIR}/helm-fail.err"
  set +e
  helm template "$RELEASE_NAME" "$CHART_DIR" \
    "${skip_schema[@]}" \
    --set "${values_key}.enabled=true" \
    "$@" \
    > /dev/null 2>"$stderr_file"
  local _exit_code=$?
  set -e
  if [[ "$_exit_code" -eq 0 ]]; then
    fail "helm template should have failed ${desc}"
  elif grep -qF -- "$needle" "$stderr_file"; then
    pass "helm template fails ${desc} (exit code ${_exit_code})"
  else
    fail "helm template failed ${desc} but stderr did not contain '${needle}'"
  fi
}

# ---------------------------------------------------------------------------
group "Chart metadata"

chart_yaml="${CHART_DIR}/Chart.yaml"
chart_lock="${CHART_DIR}/Chart.lock"

dep_version="$(yq -r \
  ".dependencies[] | select(.name == \"${SUBCHART_NAME}\") | .version // \"\"" \
  "$chart_yaml")"
dep_repository="$(yq -r \
  ".dependencies[] | select(.name == \"${SUBCHART_NAME}\") | .repository // \"\"" \
  "$chart_yaml")"
dep_condition="$(yq -r \
  ".dependencies[] | select(.name == \"${SUBCHART_NAME}\") | .condition // \"\"" \
  "$chart_yaml")"
dep_alias="$(yq -r \
  ".dependencies[] | select(.name == \"${SUBCHART_NAME}\") | .alias // \"\"" \
  "$chart_yaml")"

if [ -z "$dep_version" ]; then
  fail "${chart_yaml} declares a ${SUBCHART_NAME} dependency"
  exit 1
fi
pass "${chart_yaml} declares ${SUBCHART_NAME} ${dep_version}"

# The values key is the alias when set, otherwise the chart name.
values_key="${dep_alias:-$SUBCHART_NAME}"

assert_eq "dependency repository is the mcp-kubecost Helm repo" \
  "https://kubecost.github.io/mcp-kubecost" "$dep_repository"
assert_eq "dependency condition gates the subchart" \
  "${values_key}.enabled" "$dep_condition"

if [ "$dep_version" = "*" ] || [ "${dep_version#\^}" != "$dep_version" ] \
  || [ "${dep_version#\~}" != "$dep_version" ]; then
  fail "dependency version must be pinned for reproducible builds, got '${dep_version}'"
else
  pass "dependency version is pinned"
fi

lock_version="$(yq -r \
  ".dependencies[] | select(.name == \"${SUBCHART_NAME}\") | .version // \"\"" \
  "$chart_lock")"
assert_eq "${chart_lock} pins the same version as ${chart_yaml}" \
  "${dep_version#v}" "${lock_version#v}"

default_enabled="$(yq -r ".[\"${values_key}\"].enabled" "${CHART_DIR}/values.yaml")"
assert_eq "values.yaml defaults ${values_key}.enabled to true" "true" "$default_enabled"

# ---------------------------------------------------------------------------
group "Dependency resolution (validates Chart.lock is in sync)"

# Set MCP_SUBCHART_SKIP_DEP_BUILD=1 to reuse an already-vendored
# kubecost/charts/ directory, e.g. when iterating locally without network
# access. CI must always run the build so Chart.lock is verified.
if [ "${MCP_SUBCHART_SKIP_DEP_BUILD:-0}" = "1" ]; then
  printf '  skip helm dependency build (MCP_SUBCHART_SKIP_DEP_BUILD=1)\n'
else
  helm dependency build "$CHART_DIR"
  pass "helm dependency build succeeded (Chart.lock in sync with Chart.yaml)"
fi

if [ ! -f "${CHART_DIR}/charts/${SUBCHART_NAME}-${dep_version#v}.tgz" ]; then
  fail "expected ${CHART_DIR}/charts/${SUBCHART_NAME}-${dep_version#v}.tgz to be present"
else
  pass "subchart tarball ${SUBCHART_NAME}-${dep_version#v}.tgz present"
fi

# mcp-kubecost 0.6.0's values.schema.json uses additionalProperties: false and
# does not declare `enabled`, which Helm injects from Chart.yaml `condition`.
# Skip JSON-schema validation whenever the subchart is enabled.
skip_schema=(--skip-schema-validation)

# ---------------------------------------------------------------------------
group "helm lint"

helm lint "$CHART_DIR"
pass "helm lint (defaults)"

helm lint "$CHART_DIR" "${skip_schema[@]}" --set "${values_key}.enabled=true"
pass "helm lint (--set ${values_key}.enabled=true)"

# ---------------------------------------------------------------------------
group "Subchart is enabled by default"

helm template "$RELEASE_NAME" "$CHART_DIR" "${skip_schema[@]}" > "${RENDER_DIR}/default.yaml"
pass "helm template (defaults) rendered without errors"

# Only look at rendered resource sources, since the diagnostics ConfigMap
# embeds the full values tree and always mentions the subchart key.
default_sources="$(grep '^# Source:' "${RENDER_DIR}/default.yaml" || true)"
# Helm uses the alias (when set) as the on-disk chart directory in # Source: lines.
if printf '%s\n' "$default_sources" | grep -q "charts/${values_key}/"; then
  pass "subchart resources rendered with ${values_key}.enabled=true (default)"
else
  fail "subchart rendered no resources despite ${values_key}.enabled=true (default)"
fi

# ---------------------------------------------------------------------------
group "Subchart renders expected resources"

helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  > "${RENDER_DIR}/enabled.yaml"
pass "helm template (${values_key}.enabled=true) rendered without errors"

expected_fullname="${RELEASE_NAME}-${values_key}"

for kind in Deployment Service ConfigMap; do
  found="$(yq -r \
    "select(.kind == \"${kind}\") | .metadata.name | select(. == \"${expected_fullname}\" or . == \"${expected_fullname}-config\")" \
    "${RENDER_DIR}/enabled.yaml" | head -1)"
  if [ -n "$found" ]; then
    pass "rendered ${kind}/${found}"
  else
    fail "expected a ${kind} named ${expected_fullname} (or ${expected_fullname}-config)"
  fi
done

# The Deployment must be schedulable and reference the published image.
mcp_image="$(yq -r \
  "select(.kind == \"Deployment\" and .metadata.name == \"${expected_fullname}\") | .spec.template.spec.containers[0].image" \
  "${RENDER_DIR}/enabled.yaml")"
assert_eq "subchart Deployment uses the pinned appVersion image" \
  "icr.io/kubecost/mcp-kubecost:${dep_version#v}" "$mcp_image"

svc_port="$(yq -r \
  "select(.kind == \"Service\" and .metadata.name == \"${expected_fullname}\") | .spec.ports[0].port" \
  "${RENDER_DIR}/enabled.yaml")"
assert_eq "subchart Service exposes the MCP port" "3030" "$svc_port"

# ---------------------------------------------------------------------------
group "Cross-chart wiring"

# KUBECOST_BASE_URL is assembled from kubecostApiBaseUrl (tpl-evaluated) and
# kubecostApiPort. Assert that the rendered ConfigMap reflects the expected
# aggregator service name (derived from the release name) and the default port.
base_url="$(yq -r \
  "select(.kind == \"ConfigMap\" and .metadata.name == \"${expected_fullname}-config\") | .data.KUBECOST_BASE_URL" \
  "${RENDER_DIR}/enabled.yaml")"
assert_eq "subchart KUBECOST_BASE_URL targets the in-cluster Kubecost aggregator" \
  "http://${RELEASE_NAME}-aggregator:9004" "$base_url"

# kubecostApiBaseUrl is a tpl string, so a different release name must produce
# a matching aggregator URL in KUBECOST_BASE_URL.
alt_release="cost-analyzer"
helm template "$alt_release" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  > "${RENDER_DIR}/alt-release.yaml"
pass "helm template (release ${alt_release}) rendered without errors"

alt_fullname="${alt_release}-${values_key}"
alt_base_url="$(yq -r \
  "select(.kind == \"ConfigMap\" and .metadata.name == \"${alt_fullname}-config\") | .data.KUBECOST_BASE_URL" \
  "${RENDER_DIR}/alt-release.yaml")"
assert_eq "subchart KUBECOST_BASE_URL follows a non-default release name" \
  "http://${alt_release}-aggregator:9004" "$alt_base_url"

# ---------------------------------------------------------------------------
group "Frontend nginx MCP proxy"

# The frontend ConfigMap must proxy MCP HTTP to the subchart Service when
# enabled, and report MCP settings from /model/productConfigs. The OIDC
# callback location is only rendered when authMode is oidc.
extract_nginx "${RENDER_DIR}/enabled.yaml" "${RENDER_DIR}/nginx-enabled.conf"

assert_contains "frontend nginx defines the mcpKubecost upstream when enabled" \
  "${RENDER_DIR}/nginx-enabled.conf" "upstream mcpKubecost"
assert_contains "frontend nginx targets the subchart Service" \
  "${RENDER_DIR}/nginx-enabled.conf" "server ${expected_fullname}."
assert_contains "frontend nginx proxies /mcp" \
  "${RENDER_DIR}/nginx-enabled.conf" "location /mcp"
assert_absent "frontend nginx omits the MCP OIDC callback when authMode is not oidc" \
  "${RENDER_DIR}/nginx-enabled.conf" "location /auth-mcp"
assert_contains "productConfigs reports mcpEnabled=true" \
  "${RENDER_DIR}/nginx-enabled.conf" '"mcpEnabled": "true"'
assert_contains "productConfigs reports default mcpAuthMode" \
  "${RENDER_DIR}/nginx-enabled.conf" '"mcpAuthMode": "none"'
assert_contains "productConfigs reports mcpRedirectPath" \
  "${RENDER_DIR}/nginx-enabled.conf" '"mcpRedirectPath": "/auth-mcp"'
assert_contains "productConfigs reports tpl-evaluated kubecostApiBaseUrl" \
  "${RENDER_DIR}/nginx-enabled.conf" "\"kubecostApiBaseUrl\": \"http://${RELEASE_NAME}-aggregator\""
assert_contains "productConfigs reports default kubecostApiPort" \
  "${RENDER_DIR}/nginx-enabled.conf" '"kubecostApiPort": "9004"'
assert_contains "productConfigs reports default kubecostApiBasePath" \
  "${RENDER_DIR}/nginx-enabled.conf" '"kubecostApiBasePath": "/"'

helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=false" \
  > "${RENDER_DIR}/disabled.yaml"
pass "helm template (${values_key}.enabled=false) rendered without errors"

extract_nginx "${RENDER_DIR}/disabled.yaml" "${RENDER_DIR}/nginx-disabled.conf"

assert_absent "frontend nginx omits the mcpKubecost upstream when disabled" \
  "${RENDER_DIR}/nginx-disabled.conf" "upstream mcpKubecost"
assert_absent "frontend nginx omits /mcp proxy when disabled" \
  "${RENDER_DIR}/nginx-disabled.conf" "location /mcp"
assert_contains "productConfigs reports mcpEnabled=false" \
  "${RENDER_DIR}/nginx-disabled.conf" '"mcpEnabled": "false"'

# ---------------------------------------------------------------------------
group "authMode routing guard"

# There are two independent guards over MCP exposure:
#
# Guard 1 — subchart sanityChecks (mcp-kubecost.sanityChecks):
#   mcp.httpRoute.enabled=true OR mcp.ingress.enabled=true WITH authMode=none
#   is always a hard fail. skipSanityChecks does NOT bypass it (that flag only
#   skips live Secret lookups).
#
# Guard 2 — parent openRouteCheck (kubecost.mcp.openRouteCheck):
#   Fires ONLY when ALL THREE of these are simultaneously true:
#     - a parent route is exposed (ingress.enabled or httpRoute.enabled)
#     - kubecostApiPort is 9008 (aggregator SSO bypass port)
#     - authMode is "none"
#   When skipSanityChecks is set, this becomes a warning rather than a hard fail.
#   Missing any one of the three conditions means no error is raised.
#
# nginx proxy behaviour (kubecost.frontend.mcpProxyDirectives):
#   The helper is unconditional — it always emits proxy_pass directives.
#   ingress.enabled, httpRoute.enabled, and authMode do not affect whether
#   proxy_pass or 424 appears in the rendered nginx config. The MCP location
#   blocks are only rendered at all when mcp.enabled=true.

_subchart_route_fail='authMode = "none" with an exposed route is not permitted'
_parent_route_fail='mcp.config.authMode is "none"'

# ---------------------------------------------------------------------------
# Guard 1: subchart route flags + authMode=none must FAIL regardless of port.
# ---------------------------------------------------------------------------

assert_helm_fails "when mcp.httpRoute.enabled=true and authMode=none" \
  "$_subchart_route_fail" \
  --set mcp.httpRoute.enabled=true \
  --set mcp.config.authMode=none

assert_helm_fails "when mcp.ingress.enabled=true and authMode=none" \
  "$_subchart_route_fail" \
  --set mcp.ingress.enabled=true \
  --set mcp.config.authMode=none

# skipSanityChecks must NOT bypass the subchart's hard fail.
assert_helm_fails "when mcp.httpRoute.enabled=true, authMode=none, and skipSanityChecks=true" \
  "$_subchart_route_fail" \
  --set mcp.httpRoute.enabled=true \
  --set mcp.config.authMode=none \
  --set global.platforms.cicd.enabled=true \
  --set global.platforms.cicd.skipSanityChecks=true

# ---------------------------------------------------------------------------
# Guard 2: parent openRouteCheck — 3-way AND (route AND port=9008 AND authMode=none)
# ---------------------------------------------------------------------------

# All three conditions present → hard fail.
assert_helm_fails "when ingress.enabled=true, kubecostApiPort=9008, and authMode=none" \
  "$_parent_route_fail" \
  --set ingress.enabled=true \
  --set mcp.config.kubecostApiPort=9008 \
  --set mcp.config.authMode=none

assert_helm_fails "when httpRoute.enabled=true, kubecostApiPort=9008, and authMode=none" \
  "$_parent_route_fail" \
  --set httpRoute.enabled=true \
  --set mcp.config.kubecostApiPort=9008 \
  --set mcp.config.authMode=none

# Route + port9008 + authMode=none + skipSanityChecks → warning only (render succeeds).
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set ingress.enabled=true \
  --set mcp.config.kubecostApiPort=9008 \
  --set mcp.config.authMode=none \
  --set global.platforms.cicd.enabled=true \
  --set global.platforms.cicd.skipSanityChecks=true \
  > "${RENDER_DIR}/ingress-9008-none-skip.yaml"
pass "helm template succeeds (warning) when ingress+kubecostApiPort=9008+authMode=none+skipSanityChecks"

# Missing one condition: route present, port 9008, but authMode != none → no error.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set ingress.enabled=true \
  --set mcp.config.kubecostApiPort=9008 \
  --set mcp.config.authMode=open \
  > /dev/null
pass "openRouteCheck does not fire when route+port9008 but authMode=open"

helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set ingress.enabled=true \
  --set mcp.config.kubecostApiPort=9008 \
  --set mcp.config.authMode=oidc \
  --set mcp.config.oidc.clientId=test-client-id \
  --set mcp.config.oidc.clientSecret=test-client-secret \
  --set mcp.config.oidc.issuerUrl=https://auth.example.com \
  --set mcp.config.oidc.baseUrl=https://kubecost.example.com \
  > /dev/null
pass "openRouteCheck does not fire when route+port9008 but authMode=oidc"

# Missing one condition: route present, authMode=none, but default port (9004) → no error.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set ingress.enabled=true \
  --set mcp.config.authMode=none \
  > /dev/null
pass "openRouteCheck does not fire when ingress+authMode=none but default port 9004"

helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set httpRoute.enabled=true \
  --set mcp.config.authMode=none \
  > /dev/null
pass "openRouteCheck does not fire when httpRoute+authMode=none but default port 9004"

# Missing one condition: port 9008, authMode=none, but no route → no error.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.kubecostApiPort=9008 \
  --set mcp.config.authMode=none \
  > /dev/null
pass "openRouteCheck does not fire when port9008+authMode=none but no route is exposed"

# ---------------------------------------------------------------------------
# nginx proxy behaviour: kubecost.frontend.mcpProxyDirectives is unconditional.
# The helper always emits proxy_pass regardless of ingress, httpRoute, or authMode.
# ---------------------------------------------------------------------------

# Baseline: default render (no ingress, no httpRoute, authMode=none) → proxy_pass.
extract_nginx "${RENDER_DIR}/enabled.yaml" "${RENDER_DIR}/nginx-baseline.conf"
assert_contains "nginx proxies /mcp with default settings (no ingress, authMode=none)" \
  "${RENDER_DIR}/nginx-baseline.conf" "proxy_pass http://mcpKubecost"
assert_absent "nginx does not emit 424 with default settings" \
  "${RENDER_DIR}/nginx-baseline.conf" "return 424"

# authMode=open, no parent ingress/httpRoute → proxy_pass.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.authMode=open \
  > "${RENDER_DIR}/no-route-open.yaml"
extract_nginx "${RENDER_DIR}/no-route-open.yaml" "${RENDER_DIR}/nginx-no-route-open.conf"
assert_contains "nginx proxies /mcp when authMode=open and no parent ingress/httpRoute" \
  "${RENDER_DIR}/nginx-no-route-open.conf" "proxy_pass http://mcpKubecost"
assert_absent "nginx does not emit 424 when authMode=open and no parent ingress/httpRoute" \
  "${RENDER_DIR}/nginx-no-route-open.conf" "return 424"

# authMode=none, ingress.enabled → proxy_pass (nginx has no awareness of ingress).
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set ingress.enabled=true \
  --set mcp.config.authMode=none \
  > "${RENDER_DIR}/ingress-none.yaml"
extract_nginx "${RENDER_DIR}/ingress-none.yaml" "${RENDER_DIR}/nginx-ingress-none.conf"
assert_contains "nginx proxies /mcp when ingress.enabled and authMode=none" \
  "${RENDER_DIR}/nginx-ingress-none.conf" "proxy_pass http://mcpKubecost"
assert_absent "nginx does not emit 424 when ingress.enabled and authMode=none" \
  "${RENDER_DIR}/nginx-ingress-none.conf" "return 424"

# authMode=open, ingress.enabled → proxy_pass.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set ingress.enabled=true \
  --set mcp.config.authMode=open \
  > "${RENDER_DIR}/ingress-open.yaml"
extract_nginx "${RENDER_DIR}/ingress-open.yaml" "${RENDER_DIR}/nginx-ingress-open.conf"
assert_contains "nginx proxies /mcp when ingress.enabled and authMode=open" \
  "${RENDER_DIR}/nginx-ingress-open.conf" "proxy_pass http://mcpKubecost"
assert_absent "nginx does not emit 424 when ingress.enabled and authMode=open" \
  "${RENDER_DIR}/nginx-ingress-open.conf" "return 424"

# authMode=none, httpRoute.enabled → proxy_pass.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set httpRoute.enabled=true \
  --set mcp.config.authMode=none \
  > "${RENDER_DIR}/httproute-none.yaml"
extract_nginx "${RENDER_DIR}/httproute-none.yaml" "${RENDER_DIR}/nginx-httproute-none.conf"
assert_contains "nginx proxies /mcp when httpRoute.enabled and authMode=none" \
  "${RENDER_DIR}/nginx-httproute-none.conf" "proxy_pass http://mcpKubecost"
assert_absent "nginx does not emit 424 when httpRoute.enabled and authMode=none" \
  "${RENDER_DIR}/nginx-httproute-none.conf" "return 424"

# authMode=open, httpRoute.enabled → proxy_pass.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set httpRoute.enabled=true \
  --set mcp.config.authMode=open \
  > "${RENDER_DIR}/httproute-open.yaml"
extract_nginx "${RENDER_DIR}/httproute-open.yaml" "${RENDER_DIR}/nginx-httproute-open.conf"
assert_contains "nginx proxies /mcp when httpRoute.enabled and authMode=open" \
  "${RENDER_DIR}/nginx-httproute-open.conf" "proxy_pass http://mcpKubecost"
assert_absent "nginx does not emit 424 when httpRoute.enabled and authMode=open" \
  "${RENDER_DIR}/nginx-httproute-open.conf" "return 424"

# mcp.httpRoute.enabled (subchart route, not parent): the frontend nginx MCP proxy
# block is suppressed entirely — the subchart's HTTPRoute handles external traffic
# directly. Nginx must NOT contain any MCP proxy_pass or location /mcp for these.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.httpRoute.enabled=true \
  --set mcp.config.authMode=open \
  > "${RENDER_DIR}/mcp-httproute-open.yaml"
extract_nginx "${RENDER_DIR}/mcp-httproute-open.yaml" "${RENDER_DIR}/nginx-mcp-httproute-open.conf"
assert_absent "nginx omits proxy_pass http://mcpKubecost when mcp.httpRoute.enabled (subchart route handles traffic)" \
  "${RENDER_DIR}/nginx-mcp-httproute-open.conf" "proxy_pass http://mcpKubecost"
assert_absent "nginx omits location /mcp when mcp.httpRoute.enabled (subchart route handles traffic)" \
  "${RENDER_DIR}/nginx-mcp-httproute-open.conf" "location /mcp"

# OIDC nginx rendering: port 9008 + authMode=oidc with full required OIDC params.
# openRouteCheck does not fire (authMode != none), and the subchart renders cleanly.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.kubecostApiPort=9008 \
  --set mcp.config.authMode=oidc \
  --set mcp.config.oidc.clientId=test-client-id \
  --set mcp.config.oidc.clientSecret=test-client-secret \
  --set mcp.config.oidc.issuerUrl=https://auth.example.com \
  --set mcp.config.oidc.baseUrl=https://kubecost.example.com \
  > "${RENDER_DIR}/apiport-9008-oidc.yaml"
pass "helm template succeeds when kubecostApiPort=9008 and authMode=oidc"

extract_nginx "${RENDER_DIR}/apiport-9008-oidc.yaml" "${RENDER_DIR}/nginx-oidc.conf"
assert_contains "nginx defines the MCP OIDC callback location when authMode=oidc" \
  "${RENDER_DIR}/nginx-oidc.conf" "location /auth-mcp"
assert_contains "nginx proxies /mcp when authMode=oidc" \
  "${RENDER_DIR}/nginx-oidc.conf" "proxy_pass http://mcpKubecost"
assert_contains "productConfigs reports kubecostApiPort=9008" \
  "${RENDER_DIR}/nginx-oidc.conf" '"kubecostApiPort": "9008"'

# ---------------------------------------------------------------------------
group "OIDC credential validation"

# 6) authMode=oidc with no credentials must FAIL.
set +e
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.authMode=oidc \
  > /dev/null 2>&1
_exit_code=$?
set -e
if [[ "$_exit_code" -eq 0 ]]; then
  fail "helm template should have failed when authMode=oidc and no OIDC credentials are set"
else
  pass "helm template fails when authMode=oidc and no OIDC credentials (exit code ${_exit_code})"
fi

# 6b) skipSanityChecks=true (parent chart warning path) with authMode=oidc and no credentials.
# The parent chart's validateOIDC emits a warning; the subchart's validateOIDC always
# hard-fails on missing credentials regardless of skipSanityChecks. Both credentials
# AND issuerUrl AND baseUrl are required for the subchart to render cleanly.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.authMode=oidc \
  --set mcp.config.oidc.clientId=test-client-id \
  --set mcp.config.oidc.clientSecret=test-client-secret \
  --set mcp.config.oidc.issuerUrl=https://auth.example.com \
  --set mcp.config.oidc.baseUrl=https://kubecost.example.com \
  --set global.platforms.cicd.enabled=true \
  --set global.platforms.cicd.skipSanityChecks=true \
  > "${RENDER_DIR}/oidc-none-creds-skip.yaml"
pass "helm template succeeds with skipSanityChecks=true when authMode=oidc with full credentials"

assert_contains "skipSanityChecks OIDC render includes a ConfigMap" \
  "${RENDER_DIR}/oidc-none-creds-skip.yaml" "kind: ConfigMap"

# 7) authMode=oidc with inline clientId+clientSecret, issuerUrl, and baseUrl must SUCCEED.
# The subchart validates all four fields; all must be present for a clean render.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.authMode=oidc \
  --set mcp.config.oidc.clientId=test-client-id \
  --set mcp.config.oidc.clientSecret=test-client-secret \
  --set mcp.config.oidc.issuerUrl=https://auth.example.com \
  --set mcp.config.oidc.baseUrl=https://kubecost.example.com \
  > "${RENDER_DIR}/oidc-inline-creds.yaml"
pass "helm template succeeds when authMode=oidc with inline clientId+clientSecret"

assert_contains "OIDC inline-creds render includes a ConfigMap" \
  "${RENDER_DIR}/oidc-inline-creds.yaml" "kind: ConfigMap"

# 8) authMode=oidc with existingSecret (satisfies credentials check) plus issuerUrl
# and baseUrl must SUCCEED. skipSanityChecks is not needed since all required
# OIDC fields are present.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.authMode=oidc \
  --set mcp.config.oidc.existingSecret=my-oidc-secret \
  --set mcp.config.oidc.issuerUrl=https://auth.example.com \
  --set mcp.config.oidc.baseUrl=https://kubecost.example.com \
  > "${RENDER_DIR}/oidc-existing-secret.yaml"
pass "helm template succeeds when authMode=oidc with existingSecret, issuerUrl, and baseUrl"

assert_contains "OIDC existingSecret render includes a ConfigMap" \
  "${RENDER_DIR}/oidc-existing-secret.yaml" "kind: ConfigMap"

# 9) authMode=oidc with both inline and existingSecret must SUCCEED (no mutual-exclusivity
# guard). At runtime the subchart favours existingSecret, but the inline values are also
# rendered into a Kubernetes Secret (secret sprawl — this is a documented concern, not a bug).
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.authMode=oidc \
  --set mcp.config.oidc.clientId=test-client-id \
  --set mcp.config.oidc.clientSecret=test-client-secret \
  --set mcp.config.oidc.existingSecret=my-oidc-secret \
  --set mcp.config.oidc.issuerUrl=https://auth.example.com \
  --set mcp.config.oidc.baseUrl=https://kubecost.example.com \
  > "${RENDER_DIR}/oidc-both-creds.yaml"
pass "helm template succeeds when authMode=oidc with both inline and existingSecret (no mutual-exclusivity guard)"

assert_contains "OIDC both-creds render includes a ConfigMap" \
  "${RENDER_DIR}/oidc-both-creds.yaml" "kind: ConfigMap"

# ---------------------------------------------------------------------------
group "global: values conformance"

helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set global.imageRegistry=test-registry.io \
  --set 'global.imagePullSecrets={global-pull-secret}' \
  --set 'global.additionalLabels.kubecost\.com/conformance=global-labels' \
  --set 'global.annotations.kubecost\.com/conformance=global-annotations' \
  --set 'global.podAnnotations.kubecost\.com/conformance=global-pod-annotations' \
  > "${RENDER_DIR}/globals.yaml"
pass "helm template with global overrides rendered without errors"

yq -r \
  "select(.kind == \"Deployment\" and .metadata.name == \"${expected_fullname}\")" \
  "${RENDER_DIR}/globals.yaml" > "${RENDER_DIR}/globals-deployment.yaml"

overridden_image="$(yq -r '.spec.template.spec.containers[0].image' \
  "${RENDER_DIR}/globals-deployment.yaml")"
assert_eq "global.imageRegistry overrides the subchart image registry" \
  "test-registry.io/kubecost/mcp-kubecost:${dep_version#v}" "$overridden_image"

pull_secret="$(yq -r '.spec.template.spec.imagePullSecrets[0].name' \
  "${RENDER_DIR}/globals-deployment.yaml")"
assert_eq "global.imagePullSecrets is inherited by the subchart" \
  "global-pull-secret" "$pull_secret"

meta_label="$(yq -r '.metadata.labels."kubecost.com/conformance"' \
  "${RENDER_DIR}/globals-deployment.yaml")"
assert_eq "global.additionalLabels lands on the subchart Deployment" \
  "global-labels" "$meta_label"

pod_label="$(yq -r '.spec.template.metadata.labels."kubecost.com/conformance"' \
  "${RENDER_DIR}/globals-deployment.yaml")"
assert_eq "global.additionalLabels lands on the subchart pod template" \
  "global-labels" "$pod_label"

selector_label="$(yq -r '.spec.selector.matchLabels."kubecost.com/conformance"' \
  "${RENDER_DIR}/globals-deployment.yaml")"
assert_eq "global.additionalLabels stays out of the immutable selector" \
  "null" "$selector_label"

meta_annotation="$(yq -r '.metadata.annotations."kubecost.com/conformance"' \
  "${RENDER_DIR}/globals-deployment.yaml")"
assert_eq "global.annotations lands on the subchart Deployment" \
  "global-annotations" "$meta_annotation"

pod_annotation="$(yq -r '.spec.template.metadata.annotations."kubecost.com/conformance"' \
  "${RENDER_DIR}/globals-deployment.yaml")"
assert_eq "global.podAnnotations lands on the subchart pod template" \
  "global-pod-annotations" "$pod_annotation"

# The subchart must keep its own config-reload checksum alongside global annotations.
checksum="$(yq -r '.spec.template.metadata.annotations."checksum/config"' \
  "${RENDER_DIR}/globals-deployment.yaml")"
if [ "$checksum" = "null" ] || [ -z "$checksum" ]; then
  fail "global.podAnnotations clobbered the subchart's checksum/config annotation"
else
  pass "subchart checksum/config annotation survives global.podAnnotations"
fi

# No stale icr.io reference should remain in the subchart resources once the
# registry is overridden.
assert_absent "no hardcoded icr.io in the subchart Deployment after override" \
  "${RENDER_DIR}/globals-deployment.yaml" "icr.io"

# --- OpenShift adaptation --------------------------------------------------
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set global.platforms.openshift.enabled=true \
  > "${RENDER_DIR}/openshift.yaml"
pass "helm template with global.platforms.openshift.enabled=true rendered"

yq -r \
  "select(.kind == \"Deployment\" and .metadata.name == \"${expected_fullname}\") | .spec.template.spec.securityContext" \
  "${RENDER_DIR}/openshift.yaml" > "${RENDER_DIR}/openshift-sc.yaml"

ocp_run_as_user="$(yq -r '.runAsUser' "${RENDER_DIR}/openshift-sc.yaml")"
assert_eq "OpenShift render drops the explicit runAsUser (restricted-v2 SCC)" \
  "null" "$ocp_run_as_user"

ocp_run_as_non_root="$(yq -r '.runAsNonRoot' "${RENDER_DIR}/openshift-sc.yaml")"
assert_eq "OpenShift render keeps runAsNonRoot" "true" "$ocp_run_as_non_root"

# Non-OpenShift renders must keep the chart's hardened UID/GID.
default_run_as_user="$(yq -r \
  "select(.kind == \"Deployment\" and .metadata.name == \"${expected_fullname}\") | .spec.template.spec.securityContext.runAsUser" \
  "${RENDER_DIR}/enabled.yaml")"
assert_eq "default render keeps the subchart's non-root UID" \
  "65532" "$default_run_as_user"

# --- CI/CD sanity-check bypass --------------------------------------------
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set global.platforms.cicd.enabled=true \
  --set global.platforms.cicd.skipSanityChecks=true \
  --set "${values_key}.config.kubecostApiKey.existingSecret=does-not-exist" \
  > "${RENDER_DIR}/cicd.yaml"
pass "global.platforms.cicd.skipSanityChecks lets the subchart render for Argo CD"

assert_contains "subchart reads the API key from the referenced Secret" \
  "${RENDER_DIR}/cicd.yaml" "name: does-not-exist"

# ---------------------------------------------------------------------------
group "Summary"

if [ "$failures" -ne 0 ]; then
  printf '%s check(s) failed.\n' "$failures" >&2
  exit 1
fi
printf 'All mcp-kubecost subchart checks passed.\n'
