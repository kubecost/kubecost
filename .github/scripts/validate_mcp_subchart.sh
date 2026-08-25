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

# The frontend ConfigMap must proxy MCP HTTP + OAuth paths to the subchart
# Service when enabled, and report MCP settings from /model/productConfigs.
nginx_enabled="$(yq -r \
  'select(.kind == "ConfigMap" and (.metadata.name | test("^nginx-conf-"))) | .data["nginx.conf"]' \
  "${RENDER_DIR}/enabled.yaml")"
printf '%s\n' "$nginx_enabled" > "${RENDER_DIR}/nginx-enabled.conf"

assert_contains "frontend nginx defines the mcpKubecost upstream when enabled" \
  "${RENDER_DIR}/nginx-enabled.conf" "upstream mcpKubecost"
assert_contains "frontend nginx targets the subchart Service" \
  "${RENDER_DIR}/nginx-enabled.conf" "server ${expected_fullname}."
assert_contains "frontend nginx proxies /mcp" \
  "${RENDER_DIR}/nginx-enabled.conf" "location /mcp"
assert_contains "frontend nginx proxies the MCP OIDC callback" \
  "${RENDER_DIR}/nginx-enabled.conf" "location /auth-mcp"
assert_contains "frontend nginx proxies FastMCP OAuth routes" \
  "${RENDER_DIR}/nginx-enabled.conf" "location ~ ^/(register|authorize|token|consent)(/|$)"
assert_contains "productConfigs reports mcpEnabled=true" \
  "${RENDER_DIR}/nginx-enabled.conf" '"mcpEnabled": "true"'
assert_contains "productConfigs reports default mcpAuthMode" \
  "${RENDER_DIR}/nginx-enabled.conf" '"mcpAuthMode": "none"'
assert_contains "productConfigs reports mcpRedirectPath" \
  "${RENDER_DIR}/nginx-enabled.conf" '"mcpRedirectPath": "/auth-mcp"'

helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=false" \
  > "${RENDER_DIR}/disabled.yaml"
pass "helm template (${values_key}.enabled=false) rendered without errors"

nginx_disabled="$(yq -r \
  'select(.kind == "ConfigMap" and (.metadata.name | test("^nginx-conf-"))) | .data["nginx.conf"]' \
  "${RENDER_DIR}/disabled.yaml")"
printf '%s\n' "$nginx_disabled" > "${RENDER_DIR}/nginx-disabled.conf"

assert_absent "frontend nginx omits the mcpKubecost upstream when disabled" \
  "${RENDER_DIR}/nginx-disabled.conf" "upstream mcpKubecost"
assert_absent "frontend nginx omits /mcp proxy when disabled" \
  "${RENDER_DIR}/nginx-disabled.conf" "location /mcp"
assert_contains "productConfigs reports mcpEnabled=false" \
  "${RENDER_DIR}/nginx-disabled.conf" '"mcpEnabled": "false"'

# ---------------------------------------------------------------------------
group "authMode routing guard"

# 1) httpRoute.enabled=true + authMode=none must FAIL (hard fail expected).
set +e
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.httpRoute.enabled=true \
  --set mcp.config.authMode=none \
  > /dev/null 2>&1
_exit_code=$?
set -e
if [[ "$_exit_code" -eq 0 ]]; then
  fail "helm template should have failed when httpRoute.enabled=true and authMode=none"
else
  pass "helm template fails when httpRoute.enabled=true and authMode=none (exit code ${_exit_code})"
fi

# 2) httpRoute.enabled=true + authMode=open must SUCCEED and produce a ConfigMap.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.httpRoute.enabled=true \
  --set mcp.config.authMode=open \
  > "${RENDER_DIR}/httproute-open.yaml"
pass "helm template succeeds when httpRoute.enabled=true and authMode=open"

assert_contains "authMode=open render includes a ConfigMap" \
  "${RENDER_DIR}/httproute-open.yaml" "kind: ConfigMap"

# 3) skipSanityChecks=true must SUCCEED (warning path) even with authMode=none.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.httpRoute.enabled=true \
  --set mcp.config.authMode=none \
  --set global.platforms.cicd.enabled=true \
  --set global.platforms.cicd.skipSanityChecks=true \
  > "${RENDER_DIR}/httproute-none-skip.yaml"
pass "helm template succeeds with skipSanityChecks=true when httpRoute.enabled=true and authMode=none"

assert_contains "skipSanityChecks render includes a ConfigMap" \
  "${RENDER_DIR}/httproute-none-skip.yaml" "kind: ConfigMap"

# 4) kubecostApiPort=9008 + authMode=none must FAIL (aggregator SSO bypass).
set +e
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.kubecostApiPort=9008 \
  --set mcp.config.authMode=none \
  > /dev/null 2>&1
_exit_code=$?
set -e
if [[ "$_exit_code" -eq 0 ]]; then
  fail "helm template should have failed when kubecostApiPort=9008 and authMode=none"
else
  pass "helm template fails when kubecostApiPort=9008 and authMode=none (exit code ${_exit_code})"
fi

# 5) kubecostApiPort=9008 + authMode=oidc must SUCCEED.
helm template "$RELEASE_NAME" "$CHART_DIR" \
  "${skip_schema[@]}" \
  --set "${values_key}.enabled=true" \
  --set mcp.config.kubecostApiPort=9008 \
  --set mcp.config.authMode=oidc \
  > "${RENDER_DIR}/apiport-9008-oidc.yaml"
pass "helm template succeeds when kubecostApiPort=9008 and authMode=oidc"

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
