#!/usr/bin/env bash
#
# Validates the mcp-kubecost dependency declaration in the kubecost chart.
#
# Chart.yaml, Chart.lock, and the vendored tarball are what a shell script is
# actually needed for. Everything about the rendered output — cross-chart wiring,
# the frontend nginx proxy, global: conformance, and the exposure guards — is
# covered by the helm-unittest suites in kubecost/tests/, which this script runs.
#
# Usage (from the repository root):
#   .github/scripts/validate_mcp_subchart.sh [chart-dir]
#
# Requires: helm >= 3.8 with the unittest plugin, and yq >= 4.
set -euo pipefail

CHART_DIR="${1:-kubecost}"
SUBCHART_NAME="mcp-kubecost"

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

# dep_field <field> — read one field of the mcp-kubecost dependency from a chart file.
dep_field() {
  yq -r ".dependencies[] | select(.name == \"${SUBCHART_NAME}\") | .$1 // \"\"" "$2"
}

# ---------------------------------------------------------------------------
group "Chart metadata"

chart_yaml="${CHART_DIR}/Chart.yaml"
chart_lock="${CHART_DIR}/Chart.lock"

dep_version="$(dep_field version "$chart_yaml")"
if [ -z "$dep_version" ]; then
  fail "${chart_yaml} declares a ${SUBCHART_NAME} dependency"
  exit 1
fi
pass "${chart_yaml} declares ${SUBCHART_NAME} ${dep_version}"

# The values key is the alias when set, otherwise the chart name.
values_key="$(dep_field alias "$chart_yaml")"
values_key="${values_key:-$SUBCHART_NAME}"

assert_eq "dependency repository is the mcp-kubecost Helm repo" \
  "https://kubecost.github.io/mcp-kubecost" "$(dep_field repository "$chart_yaml")"
assert_eq "dependency condition gates the subchart" \
  "${values_key}.enabled" "$(dep_field condition "$chart_yaml")"
assert_eq "${chart_lock} pins the same version as ${chart_yaml}" \
  "${dep_version#v}" "$(dep_field version "$chart_lock" | sed 's/^v//')"
assert_eq "values.yaml defaults ${values_key}.enabled to true" \
  "true" "$(yq -r ".[\"${values_key}\"].enabled" "${CHART_DIR}/values.yaml")"

case "$dep_version" in
  \*|^*|~*) fail "dependency version must be pinned for reproducible builds, got '${dep_version}'" ;;
  *) pass "dependency version is pinned" ;;
esac

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

if [ -f "${CHART_DIR}/charts/${SUBCHART_NAME}-${dep_version#v}.tgz" ]; then
  pass "subchart tarball ${SUBCHART_NAME}-${dep_version#v}.tgz present"
else
  fail "expected ${CHART_DIR}/charts/${SUBCHART_NAME}-${dep_version#v}.tgz to be present"
fi

# ---------------------------------------------------------------------------
group "helm lint and render"

# No --skip-schema-validation: the subchart's values.schema.json is the strongest
# guard against the parent and subchart drifting apart, so CI must enforce it.
helm lint "$CHART_DIR"
pass "helm lint"

helm template mcp-schema-check "$CHART_DIR" > /dev/null
pass "helm template (defaults, schema enforced)"

# ---------------------------------------------------------------------------
group "Template behaviour (helm unittest)"

if helm unittest "$CHART_DIR"; then
  pass "helm unittest suites"
else
  fail "helm unittest suites"
fi

# ---------------------------------------------------------------------------
group "Summary"

if [ "$failures" -eq 0 ]; then
  printf '\nAll mcp-kubecost subchart checks passed.\n'
else
  printf '\n%d mcp-kubecost subchart check(s) failed.\n' "$failures" >&2
  exit 1
fi
