# AGENTS Instructions

This repository hosts examples and configuration for deploying Kubecost to Kubernetes clusters such as AWS EKS.

## General Guidelines
- Use `rg` for searching the codebase instead of `grep -R` or `ls -R`.
- Keep line lengths under 120 characters.

## Kubernetes Manifests
- Validate any changed `.yaml` files with:
  ```bash
  python - <<'PY'
import sys, yaml; yaml.safe_load(open(sys.argv[1]))
PY kubecost.yaml
  ```
  Replace `kubecost.yaml` with the manifest being tested.
- Prefer explicit `apiVersion` and `kind` declarations.

## Commit Messages
- Follow [Conventional Commits](https://www.conventionalcommits.org/) style (e.g., `feat:`, `fix:`, `docs:`).

## Testing
- Run the YAML validation command above for each modified Kubernetes manifest.
- If Go code is changed, run `go fmt ./...` and `go test ./...`.

