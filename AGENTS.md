# Agents.md

## GitHub Actions

- Never downgrade (or change) a GitHub Actions version without first verifying the version exists. Use `execute_command` to look it up: `curl -s https://api.github.com/repos/<owner>/<repo>/git/refs/tags | grep '"ref"' | grep '@v<N>'` or check the GitHub Marketplace page. Do not assume a version does not exist based on training knowledge alone.
- when a GitHub Action is modified, verify that all actions in the workflow are current and use online lookups, do not depend on stale training data. If a new version is available, always suggest updating it.

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

# Get the updated subchart
helm repo add finops-agent https://kubecost.github.io/finops-agent-chart/
helm repo update finops-agent
helm dependency build ./kubecost

# Templating
helm template kubecost ./kubecost
```
