#!/bin/bash
# Test script for in-place pod resize Helm templates
# This script validates that the templates render correctly with various configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(dirname "$SCRIPT_DIR")"
TEMP_DIR=$(mktemp -d)

echo "Testing in-place pod resize Helm templates..."
echo "Chart directory: $CHART_DIR"
echo "Temp directory: $TEMP_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name=$1
    local values_file=$2
    local expected_resource=$3
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "\n${YELLOW}Test $TESTS_RUN: $test_name${NC}"
    
    # Render the template
    if helm template test-release "$CHART_DIR" -f "$values_file" > "$TEMP_DIR/output.yaml" 2>&1; then
        # Check if expected resource exists
        if grep -q "$expected_resource" "$TEMP_DIR/output.yaml"; then
            echo -e "${GREEN}✓ PASSED${NC}: $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC}: Expected resource '$expected_resource' not found"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAILED${NC}: Template rendering failed"
        cat "$TEMP_DIR/output.yaml"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to validate RBAC permissions
validate_rbac() {
    local test_name=$1
    local values_file=$2
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "\n${YELLOW}Test $TESTS_RUN: $test_name${NC}"
    
    if helm template test-release "$CHART_DIR" -f "$values_file" > "$TEMP_DIR/output.yaml" 2>&1; then
        # Check for required RBAC permissions
        if grep -q "resources: \['pods', 'pods/status'\]" "$TEMP_DIR/output.yaml" && \
           grep -q "verbs: \['get', 'list', 'watch', 'patch'\]" "$TEMP_DIR/output.yaml"; then
            echo -e "${GREEN}✓ PASSED${NC}: $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC}: Required RBAC permissions not found"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAILED${NC}: Template rendering failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to validate ConfigMap structure
validate_configmap() {
    local test_name=$1
    local values_file=$2
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "\n${YELLOW}Test $TESTS_RUN: $test_name${NC}"
    
    if helm template test-release "$CHART_DIR" -f "$values_file" > "$TEMP_DIR/output.yaml" 2>&1; then
        # Check for ConfigMap with correct structure
        if grep -q "kind: ConfigMap" "$TEMP_DIR/output.yaml" && \
           grep -q "cluster-controller-inplace-resize-config" "$TEMP_DIR/output.yaml" && \
           grep -q "binaryData:" "$TEMP_DIR/output.yaml"; then
            echo -e "${GREEN}✓ PASSED${NC}: $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC}: ConfigMap structure invalid"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAILED${NC}: Template rendering failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: CPU-only resize configuration
run_test \
    "CPU-only resize renders correctly" \
    "$CHART_DIR/ci/inplace-resize-cpu-values.yaml" \
    "cluster-controller"

# Test 2: Memory resize configuration
run_test \
    "Memory resize renders correctly" \
    "$CHART_DIR/ci/inplace-resize-memory-values.yaml" \
    "cluster-controller"

# Test 3: Combined CPU and memory resize
run_test \
    "Combined resize renders correctly" \
    "$CHART_DIR/ci/inplace-resize-combined-values.yaml" \
    "cluster-controller"

# Test 4: RBAC permissions for CPU resize
validate_rbac \
    "RBAC permissions for CPU resize" \
    "$CHART_DIR/ci/inplace-resize-cpu-values.yaml"

# Test 5: RBAC permissions for memory resize
validate_rbac \
    "RBAC permissions for memory resize" \
    "$CHART_DIR/ci/inplace-resize-memory-values.yaml"

# Test 6: ConfigMap structure for CPU resize
validate_configmap \
    "ConfigMap structure for CPU resize" \
    "$CHART_DIR/ci/inplace-resize-cpu-values.yaml"

# Test 7: ConfigMap structure for memory resize
validate_configmap \
    "ConfigMap structure for memory resize" \
    "$CHART_DIR/ci/inplace-resize-memory-values.yaml"

# Test 8: Validate default values don't break
TESTS_RUN=$((TESTS_RUN + 1))
echo -e "\n${YELLOW}Test $TESTS_RUN: Default values render without errors${NC}"
if helm template test-release "$CHART_DIR" > "$TEMP_DIR/default-output.yaml" 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}: Default values render correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}: Default values failed to render"
    cat "$TEMP_DIR/default-output.yaml"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 9: Validate labels are applied correctly
TESTS_RUN=$((TESTS_RUN + 1))
echo -e "\n${YELLOW}Test $TESTS_RUN: Labels applied correctly${NC}"
if helm template test-release "$CHART_DIR" -f "$CHART_DIR/ci/inplace-resize-cpu-values.yaml" > "$TEMP_DIR/output.yaml" 2>&1; then
    if grep -q "app.kubernetes.io/component: cluster-controller" "$TEMP_DIR/output.yaml" && \
       grep -q "kubecost.com/action-type: inplace-pod-resize" "$TEMP_DIR/output.yaml"; then
        echo -e "${GREEN}✓ PASSED${NC}: Labels applied correctly"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAILED${NC}: Expected labels not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}✗ FAILED${NC}: Template rendering failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 10: Validate YAML syntax
TESTS_RUN=$((TESTS_RUN + 1))
echo -e "\n${YELLOW}Test $TESTS_RUN: YAML syntax validation${NC}"
if helm template test-release "$CHART_DIR" -f "$CHART_DIR/ci/inplace-resize-combined-values.yaml" > "$TEMP_DIR/output.yaml" 2>&1; then
    if command -v yamllint &> /dev/null; then
        if yamllint -d relaxed "$TEMP_DIR/output.yaml" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASSED${NC}: YAML syntax valid"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAILED${NC}: YAML syntax errors found"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${YELLOW}⊘ SKIPPED${NC}: yamllint not installed"
    fi
else
    echo -e "${RED}✗ FAILED${NC}: Template rendering failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Cleanup
rm -rf "$TEMP_DIR"

# Summary
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi

# Made with Bob
