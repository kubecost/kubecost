#!/bin/bash

set -eo pipefail

# Check if branch parameter is provided
if [ -z "$1" ]; then
  echo "Error: Branch name is required as first parameter"
  echo "Usage: $0 <branch-name>"
  echo "Example: $0 main"
  exit 1
fi

BRANCH="$1"
REPO_URL="https://github.com/kubecost/finops-agent-chart"
CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHARTS_DIR="${CHART_DIR}/charts"
FINOPS_CHART_DIR="${CHARTS_DIR}/finops-agent"
CHART_YAML="${CHART_DIR}/Chart.yaml"

echo "Building finops-agent chart from branch: ${BRANCH}"

# Create charts directory if it doesn't exist
mkdir -p "${CHARTS_DIR}"

# Remove existing finops-agent chart if it exists
if [ -d "${FINOPS_CHART_DIR}" ]; then
  echo "Removing existing finops-agent chart..."
  rm -rf "${FINOPS_CHART_DIR}"
fi

# Clone the repository to a temporary location
TEMP_CLONE_DIR="${CHARTS_DIR}/finops-agent-chart-temp"
echo "Cloning finops-agent-chart repository (branch: ${BRANCH})..."
git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${TEMP_CLONE_DIR}"

# Extract the chart directory from the cloned repo
# The repo structure has the chart at charts/finops-agent
if [ -d "${TEMP_CLONE_DIR}/charts/finops-agent" ]; then
  echo "Found chart at charts/finops-agent, moving to correct location..."
  mv "${TEMP_CLONE_DIR}/charts/finops-agent" "${FINOPS_CHART_DIR}"
  rm -rf "${TEMP_CLONE_DIR}"
elif [ -f "${TEMP_CLONE_DIR}/Chart.yaml" ]; then
  echo "Found chart at repository root, moving to correct location..."
  mv "${TEMP_CLONE_DIR}" "${FINOPS_CHART_DIR}"
else
  echo "Error: Could not find chart in expected locations"
  rm -rf "${TEMP_CLONE_DIR}"
  exit 1
fi

# Update Chart.yaml to reference the local chart
echo "Updating Chart.yaml to reference local chart..."

# Check if Chart.yaml exists
if [ ! -f "${CHART_YAML}" ]; then
  echo "Error: Chart.yaml not found at ${CHART_YAML}"
  exit 1
fi

# Create a backup
cp "${CHART_YAML}" "${CHART_YAML}.bak"

# Update the finops-agent dependency to use local file path
# Replace the repository line with file:// path and set version to "*" for local charts
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS uses BSD sed
  # Update repository URL
  sed -i '' 's|repository: https://kubecost.github.io/finops-agent-chart|repository: file://../charts/finops-agent|g' "${CHART_YAML}"
  # Update version within the finops-agent dependency block
  sed -i '' '/- name: finops-agent$/,/condition: finopsagent.enabled$/s|version: ".*"|version: "*"|' "${CHART_YAML}"
else
  # Linux uses GNU sed
  sed -i 's|repository: https://kubecost.github.io/finops-agent-chart|repository: file://../charts/finops-agent|g' "${CHART_YAML}"
  sed -i '/- name: finops-agent$/,/condition: finopsagent.enabled$/s|version: ".*"|version: "*"|' "${CHART_YAML}"
fi
helm dependency build ./kubecost/charts/finops-agent/

echo "Successfully updated Chart.yaml"
echo "Chart cloned to: ${FINOPS_CHART_DIR}"
echo "Backup of Chart.yaml saved to: ${CHART_YAML}.bak"
