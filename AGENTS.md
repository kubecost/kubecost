# Agents.md

## PR Reviews

- When asked to review a PR, compare this current branch against the `develop` branch. `git diff develop`.
- Document your PR review in a new markdown file
- Point out any critical architectural or templating bugs
- Validate that the changes are coherent and concise
- Validate that the changes are consistent with the project's coding standards
- Validate that the changes are backwards compatible
- Test all configuration changes via `helm template`. Document the BEFORE and AFTER. Validate the output is valid kubernetes YAML.

Testing the changes via `helm template`:

```sh
# Remove any existing subcharts
rm -rf ./kubecost/charts

# Ensure both subchart repos are present
helm repo add finops-agent-chart https://kubecost.github.io/finops-agent-chart
helm repo add mcp-kubecost https://kubecost.github.io/mcp-kubecost
helm repo update
helm dependency build ./kubecost

# Templating
helm template kubecost ./kubecost
```
