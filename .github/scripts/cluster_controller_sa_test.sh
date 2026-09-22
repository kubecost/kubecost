#!/bin/bash
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

# grep -q closes stdin early on first match, causing echo to receive SIGPIPE.
# With pipefail that non-zero pipe exit is treated as failure.
# contains() avoids the SIGPIPE problem by using grep without -q and
# discarding output, which lets the writer fully drain.
contains() {
    echo "$1" | grep -F "$2" > /dev/null
}

not_contains() {
    ! echo "$1" | grep -F "$2" > /dev/null
}

# Render all cluster-controller templates for a given set of --set flags.
render_cc() {
    helm template kubecost "${CHART_DIR}" \
        --set clusterController.enabled=true \
        "$@" 2>/dev/null
}

# --- Test 1: default service account name ---
# When clusterController.serviceAccount.name is empty (default), every reference
# to the SA should use <release>-cluster-controller.
DEFAULT_SA="kubecost-cluster-controller"

rendered=$(render_cc) || fail "helm template failed (default SA)"

# ServiceAccount resource
contains "$rendered" "name: ${DEFAULT_SA}" \
    || fail "ServiceAccount resource should have name '${DEFAULT_SA}'"

# Deployment spec.serviceAccountName
contains "$rendered" "serviceAccountName: ${DEFAULT_SA}" \
    || fail "Deployment should reference serviceAccountName '${DEFAULT_SA}'"

# ClusterRoleBinding subject
contains "$rendered" "name: ${DEFAULT_SA}" \
    || fail "ClusterRoleBinding subject should reference SA '${DEFAULT_SA}'"

pass "default: all resources use '${DEFAULT_SA}'"

# --- Test 2: custom service account name ---
# When clusterController.serviceAccount.name is set, all three resources must
# use that custom name instead of the generated one.
CUSTOM_SA="my-custom-sa"

rendered=$(render_cc --set "clusterController.serviceAccount.name=${CUSTOM_SA}") \
    || fail "helm template failed (custom SA)"

# ServiceAccount resource
contains "$rendered" "name: ${CUSTOM_SA}" \
    || fail "ServiceAccount resource should have name '${CUSTOM_SA}'"

# Deployment spec.serviceAccountName
contains "$rendered" "serviceAccountName: ${CUSTOM_SA}" \
    || fail "Deployment should reference serviceAccountName '${CUSTOM_SA}'"

# ClusterRoleBinding subject
contains "$rendered" "name: ${CUSTOM_SA}" \
    || fail "ClusterRoleBinding subject should reference SA '${CUSTOM_SA}'"

# The default generated name must NOT appear anywhere in the SA-related resources.
not_contains "$rendered" "serviceAccountName: ${DEFAULT_SA}" \
    || fail "Default SA name should not appear in serviceAccountName when custom name is set"

pass "custom: all resources use '${CUSTOM_SA}' and serviceAccountName '${DEFAULT_SA}' is absent"
