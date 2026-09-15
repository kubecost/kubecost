# CI Workflow Security Split Plan

## Overview

The current [`test-chart-3.0.yml`](.github/workflows/test-chart-3.0.yml) workflow uses `pull_request_target` with an explicit checkout of the PR head SHA. This pattern is a known security risk for public repos — `pull_request_target` runs with full repo secrets access, and checking out untrusted fork code under that trigger means a malicious PR could exfiltrate secrets.

The fix is to switch the trigger to plain `pull_request`. Under `pull_request`, GitHub **never passes repository secrets** to workflows triggered by forks. This eliminates the risk without requiring any allow-unsafe-pr-checkout exemption.

To preserve the full test pipeline for internal contributors (same-repo branches), the three secret-dependent jobs (`deploy-chart`, `deploy-ocp`, `deploy-eks`) get an `if:` guard that skips them when the PR is from a fork. The static validation job (`test-chart`) always runs for all contributors.

---

## Sub-Tasks

---

### Sub-Task 1 — Git hygiene: pull develop and create a feature branch

**Intent**
Before making any changes, ensure the local `develop` branch is up to date and all work lands on a dedicated branch so it can be submitted as a PR.

**Expected Outcomes**
- Local `develop` is current with origin
- A new branch (`fix/ci-pr-target-security`) is checked out and ready for commits

**Todo List**
1. `git checkout develop && git pull origin develop`
2. `git checkout -b fix/ci-pr-target-security`

**Relevant Context**
No file changes — pure git operations.

**Status** — `[ ] pending`

---

### Sub-Task 2 — Switch trigger from `pull_request_target` to `pull_request`

**Intent**
Remove the unsafe `pull_request_target` trigger (which grants secret access to fork code) and replace it with `pull_request`. This eliminates the attack surface entirely. The explicit `ref: ${{ github.event.pull_request.head.sha }}` checkout override in the `test-chart` job becomes unnecessary and should also be removed — `pull_request` already checks out the merge commit of the PR head by default.

**Expected Outcomes**
- Workflow trigger is `pull_request` only (plus `workflow_dispatch`)
- The `ref:` override is removed from the `test-chart` job's `Checkout` step
- The commented-out `pull_request` block and its associated explanatory comment are removed

**Todo List**
1. In [`.github/workflows/test-chart-3.0.yml`](.github/workflows/test-chart-3.0.yml), replace the `pull_request_target` trigger block (lines 5–14) with a plain `pull_request` trigger
2. Remove the `ref: ${{ github.event.pull_request.head.sha }}` override from the `test-chart` job's `Checkout` step (line 29)

**Relevant Context**
- [`test-chart-3.0.yml`](.github/workflows/test-chart-3.0.yml:7) — `pull_request_target` trigger at line 7
- [`test-chart-3.0.yml`](.github/workflows/test-chart-3.0.yml:29) — `ref:` override in `test-chart` checkout at line 29

**Status** — `[ ] pending`

---

### Sub-Task 3 — Add `if:` guard to `deploy-chart`, `deploy-ocp`, and `deploy-eks` jobs

**Intent**
Secret-dependent jobs must not run for fork PRs (where secrets are unavailable anyway). Add a job-level `if:` condition to each of the three deploy jobs so they are skipped when the PR originates from a fork. Internal branches and `workflow_dispatch` runs continue unaffected.

The condition to use:
```yaml
if: github.event.pull_request.head.repo.full_name == github.repository || github.event_name == 'workflow_dispatch'
```

**Expected Outcomes**
- `deploy-chart`, `deploy-ocp`, and `deploy-eks` each have the `if:` guard at the job level
- Fork PRs see `test-chart` pass and the three deploy jobs skipped (not failed)
- Internal PRs and manual dispatches run the full pipeline unchanged

**Todo List**
1. Add the `if:` guard to `deploy-chart` job (after `needs: test-chart`)
2. Add the `if:` guard to `deploy-ocp` job (after `needs: test-chart`)
3. Add the `if:` guard to `deploy-eks` job (after `needs: test-chart`)
4. Remove the `ref: ${{ github.event.pull_request.head.sha }}` checkout overrides from the first checkout step in each of `deploy-chart`, `deploy-ocp`, and `deploy-eks`. The `Checkout Target Branch` step in `deploy-chart` (line 188) checks out the *base* branch for the upgrade test — keep it as-is.

**Relevant Context**
- [`test-chart-3.0.yml`](.github/workflows/test-chart-3.0.yml:71) — `deploy-chart` job starts at line 71
- [`test-chart-3.0.yml`](.github/workflows/test-chart-3.0.yml:211) — `deploy-ocp` job starts at line 211
- [`test-chart-3.0.yml`](.github/workflows/test-chart-3.0.yml:273) — `deploy-eks` job starts at line 273

**Status** — `[ ] pending`

---

## Notes

- No new workflow files are needed — everything is a targeted edit to the single existing file
- `validate-mcp-subchart.yml` and the other workflows are unrelated and should not be touched
- After implementation, open a PR from `fix/ci-pr-target-security` → `develop` and verify `test-chart` runs on the PR while the three deploy jobs show as skipped
