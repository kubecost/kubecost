# Kubecost Helm Chart Development Guide<!-- omit in toc -->

- [YAML Style Guidelines](#yaml-style-guidelines)
- [Sub-chart Dependencies](#sub-chart-dependencies)
- [Local Testing](#local-testing)
  - [How We Test](#how-we-test)
  - [How You Can Test Locally](#how-you-can-test-locally)
  - [MCP Subchart Validation](#mcp-subchart-validation)
  - [Link Checking](#link-checking)
- [CI Testing](#ci-testing)
  - [Linting](#linting)
  - [Templating](#templating)
  - [Conformance](#conformance)
  - [Cluster Tests](#cluster-tests)

This guide contains tips on setting up a development environment for the Kubecost Helm chart.

## YAML Style Guidelines

For the `values.yaml` file, these are the design decisions we make:

- Explicitly define all configurations. Preferably, don't add the configuration as a commented out value.
- All configurations should have a default value, or an empty value defined.
- Comments
  - Only provide comments that provide context beyond the configuration name
  - Use the following headers for regions of configuration:

    ```yaml
    ## Title.
    ## Optional description. Leave line below blank.
    ##
    ```

  - Use `##` for comments that describe a single line of configuration.
  - Use `#` for commented out example values.

For Helm chart templates, these are the design decisions we make:

- Avoid using the [`default`](https://helm.sh/docs/chart_template_guide/functions_and_pipelines/#using-the-default-function) function in templates. Instead, explicitly define the configuration and its default value in the `values.yaml` file.

## Sub-chart Dependencies

This chart depends on two sub-charts declared in [`kubecost/Chart.yaml`](kubecost/Chart.yaml):

| Name           | Alias         | Enabled by default           |
| -------------- | ------------- | ---------------------------- |
| `finops-agent` | `finopsagent` | `false`                      |
| `mcp-kubecost` | `mcp`         | follows `aggregator.enabled` |

Install or update all sub-chart dependencies before running `helm template` or `helm install`:

```sh
helm repo add finops-agent-chart https://kubecost.github.io/finops-agent-chart
helm repo add mcp-kubecost https://kubecost.github.io/mcp-kubecost
helm repo update
helm dependency build ./kubecost
```

> **Note:** `helm dependency update` also works but will regenerate `Chart.lock`. Use `helm dependency build` to reproduce the exact pinned versions from `Chart.lock`.

## Local Testing

### How We Test

This project uses GitHub Actions for automated testing. Each push and pull request triggers our continuous integration (CI) workflows to ensure code quality and correctness before merging.

**CI Workflows run the following checks automatically:**

- **Link Checking:** Uses [Lychee](https://github.com/lycheeverse/lychee) to validate documentation and configuration file links.
- **Helm Chart Validation:** Runs `helm template` to verify that the chart renders as valid Kubernetes manifests without errors.
- **Linting:** Runs YAML linter and shell scripts to enforce code style and detect errors, if present in repository workflows.

### How You Can Test Locally

Before submitting a pull request, you are encouraged to run the same core tests locally to catch issues early:

1. Helm Chart Rendering

    Remove any existing subcharts and ensure both subchart repos are present.

    ```sh
    rm -rf ./kubecost/charts
    helm repo add finops-agent-chart https://kubecost.github.io/finops-agent-chart
    helm repo add mcp-kubecost https://kubecost.github.io/mcp-kubecost
    helm repo update
    helm dependency build ./kubecost
    ```

    Render Kubernetes manifests to check for errors

    ```sh
    helm template kubecost ./kubecost
    ```

2. Link Checking\*\*

    Follow the Lychee instructions above for validating links locally

    ```sh
    lychee --verbose --include-fragments --no-progress --exclude-path '.github-actions' .
    ```

3. Linting & Other Checks

    ```sh
    ct lint-and-install --target-branch develop \
    --chart-dirs=./kubecost \
    --validate-maintainers=false \
    --namespace=kubecost-chart-testing \
    --helm-extra-set-args "--set networkCosts.enabled=false --create-namespace"
    ```

### MCP Subchart Validation

A separate workflow (`validate-mcp-subchart.yml`) validates the `mcp-kubecost` subchart integration. It runs on pull requests that touch `Chart.yaml`, `Chart.lock`, `values.yaml`, or the frontend templates, and checks that:

- The subchart dependency is pinned and `Chart.lock` is in sync.
- The subchart follows `aggregator.enabled` unless `mcp.enabled` is set (`mcp.enabled,aggregator.enabled`).
- The expected Kubernetes resources (Deployment, Service, ConfigMap) render correctly.
- The MCP server's `KUBECOST_BASE_URL` targets the correct in-cluster frontend Service.
- The frontend nginx ConfigMap proxies `/mcp` and OAuth paths when the subchart is enabled and omits them when disabled.
- `global.*` values (imageRegistry, imagePullSecrets, additionalLabels, annotations, podAnnotations) are propagated into the subchart.

To run the validation script locally (requires `helm ≥ 3.8` and `yq ≥ 4`):

```sh
helm repo add finops-agent-chart https://kubecost.github.io/finops-agent-chart
helm repo add mcp-kubecost https://kubecost.github.io/mcp-kubecost
helm repo update
helm dependency build ./kubecost
MCP_SUBCHART_SKIP_DEP_BUILD=1 .github/scripts/validate_mcp_subchart.sh kubecost
```

### Link Checking

This repository uses [Lychee](https://github.com/lycheeverse/lychee) to validate links in documentation and configuration files. Link checking runs automatically in CI on pull requests.

```sh
# Install macOS
brew install lychee

# Install Linux
cargo install lychee

# Or, install from release: https://github.com/lycheeverse/lychee/releases

# CI-matching command
lychee --verbose --include-fragments --no-progress --exclude-path '.github-actions' -E './**/*.md' './**/*.yaml' './**/*.yml'

# Single file
lychee --verbose --include-fragments --no-progress kubecost/values-openshift.yaml
```

Notes:

- Excluded links are listed in `.lycheeignore` (example URLs, internal services, etc.)
- Lychee follows redirects automatically and reports the final destination

## CI Testing

This repository employs CI checks designed to catch many common issues with Helm charts. These checks must all pass for a PR to be merged as they are designed to prevent regressions and other errors that may impact successful deployment and operation. The workflow `test-chart-3.0.yml` is responsible for these checks and a graph of what is checked and the order is shown below.

```mermaid
flowchart LR
    A(Lint) --> B(Template)
    B --> C(Conformance)
    C --> D{Test}
    D ---> E[Version 1]
    D ---> F[Version 2]
    D ---> G[Version N]
```

In addition to the default `values.yaml` file required by every chart, this repository also allows testing of additional values files for other configurations of Kubecost. Any values files placed at `kubecost/ci/` will be automatically picked up by this testing process. Values files placed here must conform to the pattern `*-values.yaml` in order to be linted. Changes to any templates will allow testing by all combined values files.

### Linting

Charts and chart values will be linted for YAML syntax and Helm best practices.

### Templating

The chart will be fully templated with each available values file to ensure, given the input values, the templates render correctly.

### Conformance

Once templating is successful, the combined results of the chart templated across all values will be examined for correctness against Kubernetes OpenAPI schemas to ensure the resources are compliant with the latest version.

### Cluster Tests

If all previous tests pass, the chart with each of the eligible values files will be deployed across a matrix of Kubernetes cluster versions to ensure all expected resources are available, and finally that a basic end-to-end test of the Kubecost deployment is successful. In order for some deployment configurations to succeed, there may be some dependent resources which are required. For example, in some configurations Kubecost requires Kubernetes Secrets to already exist so they may be consumed by Pods in the form of a volume mount. Any such prerequisite resources should be stored in `.github/ci-files` as they will be automatically deployed as part of the test suite. Files in this directory must not clash and all will be deployed at the outset of testing.
