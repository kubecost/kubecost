split our ci workflow into two: one for internal contributors and one for external contributors.


test-chart (lint, helm template, Kubeconform, the frontend config test) never touches secrets — it's pure static validation of the fork's chart.
deploy-chart / deploy-ocp / deploy-eks genuinely need secrets to spin up real clusters and install the chart.

So: switch the trigger to plain pull_request instead of pull_request_target. GitHub does not pass repository secrets to pull_request workflows when the head is a fork — only same-repo branches get secrets. That removes the checkout block entirely (it only applies to pull_request_target + fork-head checkout) and gives you exactly the split you want without extra workflow files:

yaml
on:
  workflow_dispatch: {}
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
yaml
  deploy-chart:
    needs: test-chart
    # Skip the secret-dependent jobs for external fork PRs; they still get lint+template+kubeconform above.
    if: github.event.pull_request.head.repo.full_name == github.repository || github.event_name == 'workflow_dispatch'
    ...

Add the same if: guard to deploy-ocp and deploy-eks.

Result:

Internal contributors (branches in kubecost/kubecost, not forks) — full pipeline runs exactly as today, secrets included.
External/fork PRs — test-chart (lint/template/kubeconform) still runs safely against their code with no secrets in scope; the cluster-deploy jobs are skipped rather than silently failing or exposing tokens.
No need for allow-unsafe-pr-checkout anywhere.