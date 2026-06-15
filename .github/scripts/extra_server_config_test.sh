#!/bin/bash
# shellcheck disable=SC2001
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${SCRIPT_DIR}/../../kubecost"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "PASS: $*"
}

render_configmap() {
    helm template kubecost "${CHART_DIR}" \
        --show-only templates/frontend/frontend-configmap.yaml \
        "$@" 2>/dev/null
}

DEFAULT_DIRECTIVES=(
    'proxy_busy_buffers_size 512k;'
    'proxy_buffers 4 512k;'
    'proxy_buffer_size 256k;'
    'large_client_header_buffers 8 2m;'
    'client_header_buffer_size 2m;'
)

assert_directives_present() {
    local rendered="$1"
    local label="$2"
    for directive in "${DEFAULT_DIRECTIVES[@]}"; do
        echo "$rendered" | grep -Fq "$directive" \
            || fail "${label}: expected directive not found: ${directive}"
    done
}

# Default bufferConfig enabled
rendered=$(render_configmap) || fail "helm template failed"
assert_directives_present "$rendered" "default bufferConfig"
pass "default bufferConfig directives render in nginx configmap"

# extraServerConfig merges with defaults
rendered=$(render_configmap --set 'frontend.extraServerConfig=custom_marker on;') \
    || fail "helm template with extraServerConfig failed"
assert_directives_present "$rendered" "bufferConfig + extraServerConfig"
echo "$rendered" | grep -Fq 'custom_marker on;' \
    || fail "expected extraServerConfig directive in merged output"
pass "extraServerConfig merges with bufferConfig maps"

# Disabled bufferConfig omits directives when extraServerConfig is unset
rendered=$(render_configmap --set 'frontend.bufferConfig.enabled=false') \
    || fail "helm template with bufferConfig disabled failed"
for directive in "${DEFAULT_DIRECTIVES[@]}"; do
    echo "$rendered" | grep -Fq "$directive" \
        && fail "did not expect buffer directive when bufferConfig disabled: ${directive}"
done
echo "$rendered" | grep -Fq 'large_client_header_buffers' \
    && fail "did not expect any large_client_header_buffers when bufferConfig disabled"
pass "disabled bufferConfig omits buffer directives"

# extraServerConfig overrides duplicate keys (no nginx duplicate error)
rendered=$(render_configmap --set 'frontend.extraServerConfig=large_client_header_buffers 4 64k;') \
    || fail "helm template with overlapping extraServerConfig failed"
echo "$rendered" | grep -Fq 'large_client_header_buffers 8 2m;' \
    && fail "did not expect default after extraServerConfig override"
echo "$rendered" | grep -Fq 'large_client_header_buffers 4 64k;' \
    || fail "expected reconciled large_client_header_buffers from extraServerConfig"
echo "$rendered" | grep -c 'large_client_header_buffers' | grep -q '^1$' \
    || fail "expected exactly one large_client_header_buffers directive"
pass "extraServerConfig overrides reconcile via map merge"

# extraServerConfig overrides existing keys
rendered=$(render_configmap \
    --set 'frontend.extraServerConfig=client_header_buffer_size 1m;') \
    || fail "helm template with extraServerConfig override failed"
echo "$rendered" | grep -Fq 'client_header_buffer_size 1m;' \
    || fail "expected override value for client_header_buffer_size"
echo "$rendered" | grep -Fq 'client_header_buffer_size 2m;' \
    && fail "did not expect default client_header_buffer_size after override"
pass "extraServerConfig overrides bufferConfig.directives"

# arbitrary directive keys via extraServerConfig
rendered=$(render_configmap \
    --set 'frontend.extraServerConfig=foo_bar_baz qux;') \
    || fail "helm template with arbitrary extraServerConfig failed"
echo "$rendered" | grep -Fq 'foo_bar_baz qux;' \
    || fail "expected arbitrary directive in output"
pass "arbitrary keys merge via extraServerConfig"

# multiple extraServerConfig lines merge (overrides + non-buffer directive)
FIXTURES="${SCRIPT_DIR}/testfixtures"
rendered=$(render_configmap -f "${FIXTURES}/extra-server-config-multiline.yaml") \
    || fail "helm template with multiline extraServerConfig failed"
echo "$rendered" | grep -Fq 'large_client_header_buffers 4 64k;' \
    || fail "expected multiline override for large_client_header_buffers"
echo "$rendered" | grep -Fq 'large_client_header_buffers 8 2m;' \
    && fail "did not expect default large_client_header_buffers after multiline override"
echo "$rendered" | grep -Fq 'client_header_buffer_size 1m;' \
    || fail "expected multiline override for client_header_buffer_size"
echo "$rendered" | grep -Fq 'client_header_buffer_size 2m;' \
    && fail "did not expect default client_header_buffer_size after multiline override"
echo "$rendered" | grep -Fq 'custom_marker on;' \
    || fail "expected non-buffer line from multiline extraServerConfig"
echo "$rendered" | grep -Fq 'proxy_buffers 4 512k;' \
    || fail "expected unchanged default proxy_buffers with multiline extraServerConfig"
echo "$rendered" | grep -c 'large_client_header_buffers' | grep -q '^1$' \
    || fail "expected exactly one large_client_header_buffers with multiline extraServerConfig"
pass "multiline extraServerConfig merges all lines without duplicates"

