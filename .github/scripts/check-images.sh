#!/usr/bin/env bash
# check-images.sh <rendered-yaml-file>
#
# Local usage:
#   helm template kubecost/ -f .github/ci-helmValues/helmValues-federated-store.yaml > /tmp/full.yaml && \
#   helm template kubecost/ -f kubecost/values-eks-cost-monitoring.yaml >> /tmp/full.yaml && \
#   .github/scripts/check-images.sh /tmp/full.yaml
#
# Extracts every container image reference from a helm-rendered YAML file,
# then verifies that each image:
#   1. Exists in its registry (docker manifest inspect succeeds)
#   2. Is a multi-arch manifest list with both linux/amd64 and linux/arm64
#
# ECR Public images (*.ecr.aws/*) are handled with an anonymous login before
# the check loop runs.
#
# All images are checked regardless of earlier failures. A summary of every
# failed image is printed at the end, then the script exits non-zero if any
# failure was recorded.
#
# Requires: yq >= 4, docker (with manifest support), jq, aws CLI (for ECR)
set -euo pipefail

YAML_FILE="${1:?Usage: check-images.sh <rendered-yaml-file>}"

# ── Extract images ──────────────────────────────────────────────────────────
mapfile -t IMAGES < <(
  yq e '.. | select(has("image")) | .image' "$YAML_FILE" \
    | grep -v '^null$' \
    | grep -v '^---$' \
    | grep -v '^\s*$' \
    | sort -u
)

if [ ${#IMAGES[@]} -eq 0 ]; then
  echo "No images found in $YAML_FILE"
  exit 0
fi

echo "Found ${#IMAGES[@]} unique image(s) to check:"
printf '  %s\n' "${IMAGES[@]}"
echo ""

# ── ECR Public login (anonymous, one-time) ──────────────────────────────────
HAS_ECR=false
for img in "${IMAGES[@]}"; do
  if [[ "$img" == *".ecr.aws/"* ]]; then
    HAS_ECR=true
    break
  fi
done

if [ "$HAS_ECR" = true ]; then
  echo "ECR Public images detected — logging in anonymously..."
  aws ecr-public get-login-password --region us-east-1 \
    | docker login --username AWS --password-stdin public.ecr.aws
  echo ""
fi

# ── Check each image ─────────────────────────────────────────────────────────
failures=()
total=${#IMAGES[@]}
idx=0

for image in "${IMAGES[@]}"; do
  idx=$((idx + 1))
  printf "[%d/%d] %-70s " "$idx" "$total" "$image"

  # Step 1: existence
  if ! manifest_json=$(docker manifest inspect --verbose "$image" 2>/dev/null); then
    echo "✗ not found"
    failures+=("$image: not found in registry")
    continue
  fi

  # Step 2: multi-arch — expect a manifest list/index with amd64 + arm64
  has_amd64=$(echo "$manifest_json" | jq -r '
    if type == "array" then
      [.[] | select(.Descriptor.platform.architecture == "amd64")] | length
    else
      [.manifests[]? | select(.platform.architecture == "amd64")] | length
    end' 2>/dev/null || echo "0")

  has_arm64=$(echo "$manifest_json" | jq -r '
    if type == "array" then
      [.[] | select(.Descriptor.platform.architecture == "arm64")] | length
    else
      [.manifests[]? | select(.platform.architecture == "arm64")] | length
    end' 2>/dev/null || echo "0")

  if [ "$has_amd64" -eq 0 ] && [ "$has_arm64" -eq 0 ]; then
    echo "✗ single-arch only (no manifest list)"
    failures+=("$image: single-arch only (no manifest list)")
  elif [ "$has_amd64" -eq 0 ]; then
    echo "✗ missing linux/amd64"
    failures+=("$image: missing linux/amd64")
  elif [ "$has_arm64" -eq 0 ]; then
    echo "✗ missing linux/arm64"
    failures+=("$image: missing linux/arm64")
  else
    echo "✓ amd64 + arm64"
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ ${#failures[@]} -gt 0 ]; then
  echo "::error::Image check failed — ${#failures[@]} image(s) did not pass:"
  for f in "${failures[@]}"; do
    echo "  ✗ $f"
    echo "::error::  ✗ $f"
  done
  exit 1
fi

echo "All ${#IMAGES[@]} image(s) passed existence and multi-arch checks."
