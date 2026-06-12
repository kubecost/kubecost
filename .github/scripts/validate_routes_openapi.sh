#!/bin/bash
# shellcheck disable=SC2016,SC2329
set -euo pipefail

# Validate nginx-native routes from the frontend configmap against OpenAPI.
#
# Extracts location blocks that return JSON directly (return 200/204) and are
# NOT proxied to aggregator, cloudCost, or forecasting upstreams.
#
# Examples: /model/productConfigs, /model/installInfo, /model/isSaaSDeployment
#
# Proxied routes (/model/ -> aggregator, /forecasting/, cloudCost, auth) are ignored.
# Cerberus is skipped (on-prem).
#
# Usage:
#   ./validate_routes_openapi.sh [openapi_base] [--json]

JSON_OUTPUT=false
POSITIONAL_ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--json" ]; then
        JSON_OUTPUT=true
    else
        POSITIONAL_ARGS+=("$arg")
    fi
done

if [ "$JSON_OUTPUT" = true ]; then
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
    DEBUG_MODE=false
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    DEBUG_MODE=true
fi

NGINX_CONFIGMAP="${NGINX_CONFIGMAP:-kubecost/templates/frontend/frontend-configmap.yaml}"
OPENAPI_BASE="${POSITIONAL_ARGS[0]:-kubecost-proxy/deploy/openapi}"
OPENAPI_SPEC_FILENAME="${OPENAPI_SPEC_FILENAME:-kubecost-complete-api.yaml}"
OPENAPI_PATH_PREFIX="${OPENAPI_PATH_PREFIX_OVERRIDE:-/model}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLOWLIST_PATH="${ROUTE_VALIDATION_ALLOWLIST:-${SCRIPT_DIR}/../config/route_validation_allowlist.txt}"

ROUTES_FILE=$(mktemp)
OPENAPI_ROUTES_FILE=$(mktemp)
MISSING_ROUTES_FILE=$(mktemp)
ENV_ROUTES_DEV=$(mktemp)
ENV_ROUTES_STAGING=$(mktemp)
ENV_ROUTES_PROD=$(mktemp)
ALLOWLIST_LOADED=$(mktemp)
ROUTES_TO_VALIDATE=$(mktemp)

cleanup_temp_files() {
    rm -f "$ROUTES_FILE" "$OPENAPI_ROUTES_FILE" "$MISSING_ROUTES_FILE" \
        "$ENV_ROUTES_DEV" "$ENV_ROUTES_STAGING" "$ENV_ROUTES_PROD" \
        "$ALLOWLIST_LOADED" "$ROUTES_TO_VALIDATE"
}
trap cleanup_temp_files EXIT

emit_json_error() {
    echo "{"
    echo "  \"validation_passed\": false,"
    echo "  \"error\": \"$(json_escape "$1")\""
    echo "}"
}

json_escape() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    echo -n "$value"
}

load_allowlist() {
    : > "$ALLOWLIST_LOADED"
    if [ ! -f "$ALLOWLIST_PATH" ]; then
        return 0
    fi
    grep -vE '^\s*(#|$)' "$ALLOWLIST_PATH" \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -E '^[A-Z]+ ' >> "$ALLOWLIST_LOADED" || true
}

is_route_allowlisted() {
    local route=$1
    [ -s "$ALLOWLIST_LOADED" ] && grep -qF "$route" "$ALLOWLIST_LOADED"
}

extract_nginx_direct_routes() {
    local configmap=$1

    if [ ! -f "$configmap" ]; then
        emit_json_error "Nginx configmap not found: ${configmap}"
        exit 2
    fi

    awk '
        function flush_route(    p) {
            p = path
            path = ""
            if (skip_location || p == "") return
            if (has_proxy) return
            if (!has_api_return) return
            if (p == "/") return
            if (p == "/custom_504.html") return
            print "GET " p
        }

        /^[[:space:]]*location[[:space:]]+/ {
            flush_route()
            skip_location = 0
            has_proxy = 0
            has_api_return = 0

            if ($0 ~ /location[[:space:]]+~/) {
                skip_location = 1
                next
            }

            line = $0
            sub(/^.*location[[:space:]]+(=[[:space:]]+)?/, "", line)
            sub(/[[:space:]{].*/, "", line)
            path = line
        }

        /proxy_pass[[:space:]]+http:\/\// {
            has_proxy = 1
        }

        /return[[:space:]]+200|return[[:space:]]+204/ {
            has_api_return = 1
        }

        END {
            flush_route()
        }
    ' "$configmap" | sort -u > "$ROUTES_FILE"
}

extract_openapi_routes() {
    local spec_file=$1
    local output_file=$2

    if [ ! -f "$spec_file" ]; then
        return 0
    fi

    yq eval '.paths | to_entries | .[] | .key as $path | .value | to_entries | .[] | select(.key == "get" or .key == "post" or .key == "put" or .key == "delete" or .key == "patch") | .key + " " + $path' "$spec_file" 2>/dev/null \
        | awk -v prefix="$OPENAPI_PATH_PREFIX" '{print toupper($1), prefix $2}' \
        | sort -u > "$output_file"

    cat "$output_file" >> "$OPENAPI_ROUTES_FILE"
}

build_routes_to_validate() {
    : > "$ROUTES_TO_VALIDATE"
    while read -r route; do
        if is_route_allowlisted "$route"; then
            continue
        fi
        echo "$route"
    done < "$ROUTES_FILE" > "$ROUTES_TO_VALIDATE"
}

if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${BLUE}Extracting nginx-native routes from ${NGINX_CONFIGMAP}${NC}"
    echo -e "${BLUE}OpenAPI prefix: ${OPENAPI_PATH_PREFIX}${NC}"
fi

extract_nginx_direct_routes "$NGINX_CONFIGMAP"
load_allowlist
build_routes_to_validate

route_count=$(wc -l < "$ROUTES_FILE" | tr -d ' ')
routes_to_validate_count=$(wc -l < "$ROUTES_TO_VALIDATE" | tr -d ' ')
excluded_route_count=0
if [ -s "$ALLOWLIST_LOADED" ]; then
    excluded_route_count=$(wc -l < "$ALLOWLIST_LOADED" | tr -d ' ')
fi

if [ "$route_count" -eq 0 ]; then
    emit_json_error "No nginx-native routes found in ${NGINX_CONFIGMAP}"
    exit 2
fi

if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${GREEN}Found ${route_count} nginx-native route(s)${NC}"
    if [ "$excluded_route_count" -gt 0 ]; then
        echo -e "${YELLOW}Validating ${routes_to_validate_count} route(s); ${excluded_route_count} excluded${NC}"
    fi
fi

if [ "$DEBUG_MODE" = true ]; then
    echo ""
    echo -e "${BLUE}Nginx-native routes (direct JSON responses):${NC}"
    cat "$ROUTES_FILE" | sed 's/^/  /'
    echo ""
fi

if ! command -v yq >/dev/null 2>&1; then
    emit_json_error "yq not found"
    exit 2
fi

: > "$OPENAPI_ROUTES_FILE"
for env in dev staging prod; do
    spec_file="${OPENAPI_BASE}/${env}/${OPENAPI_SPEC_FILENAME}"
    case $env in
        dev) extract_openapi_routes "$spec_file" "$ENV_ROUTES_DEV" ;;
        staging) extract_openapi_routes "$spec_file" "$ENV_ROUTES_STAGING" ;;
        prod) extract_openapi_routes "$spec_file" "$ENV_ROUTES_PROD" ;;
    esac
done

sort -u "$OPENAPI_ROUTES_FILE" -o "$OPENAPI_ROUTES_FILE"

validation_failed=0
missing_count=0
declare -a missing_routes_json

: > "$MISSING_ROUTES_FILE"
while read -r route; do
    if grep -qF "$route" "$OPENAPI_ROUTES_FILE"; then
        continue
    fi

    echo "$route" >> "$MISSING_ROUTES_FILE"
    missing_count=$((missing_count + 1))

    method=$(echo "$route" | awk '{print $1}')
    path=$(echo "$route" | awk '{$1=""; print $0}' | sed 's/^ //')
    missing_envs=""
    grep -qF "$route" "$ENV_ROUTES_DEV" || missing_envs="${missing_envs}dev,"
    grep -qF "$route" "$ENV_ROUTES_STAGING" || missing_envs="${missing_envs}staging,"
    grep -qF "$route" "$ENV_ROUTES_PROD" || missing_envs="${missing_envs}prod,"
    missing_envs=${missing_envs%,}
    missing_routes_json+=("{\"method\":\"${method}\",\"path\":\"${path}\",\"missing_from\":\"${missing_envs}\"}")
done < "$ROUTES_TO_VALIDATE"

if [ "$missing_count" -gt 0 ]; then
    validation_failed=1
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}Missing from OpenAPI (${missing_count}):${NC}"
        cat "$MISSING_ROUTES_FILE" | sed 's/^/  /'
    fi
elif [ "$JSON_OUTPUT" = false ]; then
    echo -e "${GREEN}All nginx-native routes present in OpenAPI specs${NC}"
fi

if [ "$JSON_OUTPUT" = true ]; then
    echo "{"
    echo "  \"validation_passed\": $([ "$validation_failed" -eq 0 ] && echo "true" || echo "false"),"
    echo "  \"nginx_configmap\": \"$(json_escape "$NGINX_CONFIGMAP")\","
    echo "  \"openapi_path_prefix\": \"$(json_escape "$OPENAPI_PATH_PREFIX")\","
    echo "  \"openapi_validation\": {"
    echo "    \"total_routes\": ${route_count},"
    echo "    \"validated_routes\": ${routes_to_validate_count},"
    echo "    \"missing_count\": ${missing_count},"
    echo "    \"missing_routes\": ["
    for i in "${!missing_routes_json[@]}"; do
        if [ "$i" -lt $((${#missing_routes_json[@]} - 1)) ]; then
            echo "      ${missing_routes_json[$i]},"
        else
            echo "      ${missing_routes_json[$i]}"
        fi
    done
    echo "    ]"
    echo "  },"
    echo "  \"cerberus_validation\": {"
    echo "    \"skipped\": true,"
    echo "    \"reason\": \"on-prem helm chart; proxied routes validated in other repos\""
    echo "  },"
    echo "  \"excluded_routes\": {"
    echo "    \"count\": ${excluded_route_count},"
    echo -n "    \"allowlist_path\": \""
    json_escape "$ALLOWLIST_PATH"
    echo "\","
    echo "    \"routes\": ["
    excluded_routes_json=()
    if [ -s "$ALLOWLIST_LOADED" ]; then
        while read -r allowlisted_route; do
            method=$(echo "$allowlisted_route" | awk '{print $1}')
            path=$(echo "$allowlisted_route" | awk '{$1=""; print $0}' | sed 's/^ //')
            excluded_routes_json+=("{\"method\":\"${method}\",\"path\":\"${path}\"}")
        done < "$ALLOWLIST_LOADED"
    fi
    for i in "${!excluded_routes_json[@]}"; do
        if [ "$i" -lt $((${#excluded_routes_json[@]} - 1)) ]; then
            echo "      ${excluded_routes_json[$i]},"
        else
            echo "      ${excluded_routes_json[$i]}"
        fi
    done
    echo "    ]"
    echo "  }"
    echo "}"
fi

exit "$validation_failed"
