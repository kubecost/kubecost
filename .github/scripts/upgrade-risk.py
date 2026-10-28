#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "pyyaml>=6.0",
#     "typesafe-sdk>=0.7.2",
# ]
# ///

"""
upgrade-risk.py

Used by the Upgrade Risk workflow to flag chart changes that can break `helm upgrade`
for users with existing values. @ .github/workflows/upgrade-risk.yaml

Diffs values.yaml keys, `.Values.*` template references, and immutable fields in the
rendered manifests between the merge base of BASE and HEAD, then asks Jev (TypeSafe)
to rate the risk. Prints a Markdown comment to stdout, or nothing if the chart is
unchanged. Jev is skipped if TYPESAFE_API_KEY is unset.

Requirements: uv, git, helm (with the chart's dependency repos added)
Environment: TYPESAFE_API_KEY (optional). Create one at https://console.typesafe.ai/

Usage:
    uv run --script ./.github/scripts/upgrade-risk.py BASE HEAD [--pr-body-file PATH]

Example:
    export TYPESAFE_API_KEY=

    # Current Branch
    uv run --script ./.github/scripts/upgrade-risk.py origin/develop HEAD

    # An Open PR
    git fetch origin pull/4736/head:pr-4736
    gh pr view 4736 --json body -q .body > /tmp/pr-body.md
    uv run --script ./.github/scripts/upgrade-risk.py origin/develop pr-4736 --pr-body-file /tmp/pr-body.md
"""

import argparse
import os
import subprocess
import tempfile
from pathlib import Path

import yaml

CHART = "kubecost"
MARKER = "<!-- upgrade-risk -->"  # Lets the workflow find and update its own comment.
MAX_DIFF = 20000  # Keeps the Jev request small on large PRs.
MAX_LIST = 30


def git(*args):
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=True
    ).stdout


def flatten(d, prefix=""):
    """{"a": {"b": 1}} -> {"a.b": 1}"""
    out = {}
    for k, v in d.items():
        path = f"{prefix}{k}"
        if isinstance(v, dict) and v:
            out.update(flatten(v, f"{path}."))
        else:
            out[path] = v
    return out


def values_defaults(ref):
    """Every key in values.yaml with its default, e.g. {"aggregator.retention10m": 36}."""
    return flatten(yaml.safe_load(git("show", f"{ref}:{CHART}/values.yaml")) or {})


def values_used_by_templates(ref):
    """Every `.Values.x.y` path the templates read, e.g. {"aggregator.retention10m"}.

    Many supported keys are commented out in values.yaml, so removing one only shows
    up here, as a value the templates stop reading.
    """
    out = git(
        "grep",
        "--only-matching",
        "-h",  # no filenames
        "--extended-regexp",
        r"\.Values\.[A-Za-z0-9_.]+",
        ref,
        "--",
        f"{CHART}/templates",
    )
    return {match.removeprefix(".Values.") for match in out.splitlines()}


# Fields Kubernetes rejects changes to, so `helm upgrade` fails if the chart changes them.
IMMUTABLE_FIELDS = {
    "Deployment": ["spec.selector"],
    "DaemonSet": ["spec.selector"],
    "StatefulSet": [
        "spec.selector",
        "spec.serviceName",
        "spec.podManagementPolicy",
        "spec.volumeClaimTemplates",
    ],
    "PersistentVolumeClaim": ["spec.accessModes", "spec.storageClassName"],
    "RoleBinding": ["roleRef"],
    "ClusterRoleBinding": ["roleRef"],
}


def immutable_fields(ref):
    """Immutable fields of the chart rendered at ref, e.g.
    {"StatefulSet/kubecost-aggregator spec.selector": {...}}."""
    with tempfile.TemporaryDirectory() as tmp:
        chart = f"{tmp}/{CHART}"
        subprocess.run(
            f"git archive {ref} {CHART} | tar -x -C {tmp}", shell=True, check=True
        )
        subprocess.run(
            ["helm", "dependency", "build", chart], capture_output=True, check=True
        )
        manifests = subprocess.run(
            ["helm", "template", "kubecost", chart],
            capture_output=True,
            text=True,
            check=True,
        ).stdout

    out = {}
    for doc in filter(None, yaml.safe_load_all(manifests)):
        for path in IMMUTABLE_FIELDS.get(doc["kind"], []):
            value = doc
            for key in path.split("."):
                value = (value or {}).get(key)
            out[f"{doc['kind']}/{doc['metadata']['name']} {path}"] = value
    return out


def ask_jev(state):
    from typesafe_sdk import Noul, Score, TypeSafeClient

    with TypeSafeClient() as client:
        r = client.system_one(
            state=state,
            questions={
                "risk": Score(
                    instructions="How risky is this Helm chart change for a user running `helm upgrade` with their existing custom values?",
                    criteria=[
                        "No effect: comments, docs, formatting, or rendered output unchanged",
                        "Safe: new optional settings that are off by default; existing installs behave the same",
                        "Behavior change: a default or rendered resource changes, so upgraded installs behave differently",
                        "Breaking: a value users may set is removed, renamed, or ignored, or the upgrade fails on an immutable field",
                    ],
                ),
                "described": Noul(
                    instructions="Does `pr_description` tell users what changes for them on upgrade and what, if anything, they must do?",
                ),
            },
        )
    return r.scores["risk"], r.nouls["described"].noul


def changed(old, new):
    """Sorted keys in both dicts whose values differ."""
    return sorted(k for k in old.keys() & new.keys() if old[k] != new[k])


def bullets(title, items):
    if not items:
        return []
    shown = [f"- `{i}`" for i in items[:MAX_LIST]]
    if len(items) > MAX_LIST:
        shown.append(f"- ...and {len(items) - MAX_LIST} more")
    return [f"**{title}**", *shown, ""]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("base")
    p.add_argument("head")
    p.add_argument("--pr-body-file")
    args = p.parse_args()

    # git diff/grep pathspecs are relative to the cwd.
    os.chdir(git("rev-parse", "--show-toplevel").strip())
    # Diff from the branch point so newer commits on BASE aren't blamed on this PR.
    base = git("merge-base", args.base, args.head).strip()
    # Chart.yaml pins the subcharts, which render into the same release.
    paths = [f"{CHART}/Chart.yaml", f"{CHART}/values.yaml", f"{CHART}/templates"]
    diff = git("diff", base, args.head, "--", *paths)
    if not diff:
        return

    old, new = values_defaults(base), values_defaults(args.head)
    removed_keys = sorted(old.keys() - new.keys())
    changed_defaults = [f"{k}: {old[k]!r} → {new[k]!r}" for k in changed(old, new)]
    unused_values = sorted(
        values_used_by_templates(base) - values_used_by_templates(args.head)
    )
    old_fields, new_fields = immutable_fields(base), immutable_fields(args.head)
    rejected = changed(old_fields, new_fields)
    body = Path(args.pr_body_file).read_text() if args.pr_body_file else ""

    lines = [MARKER, "### Helm upgrade risk", ""]
    if os.environ.get("TYPESAFE_API_KEY"):
        risk, described = ask_jev(
            {
                "pr_description": body,
                "values_keys_removed": removed_keys,
                "values_defaults_changed": changed_defaults,
                "values_no_longer_read_by_templates": unused_values,
                "immutable_fields_changed": rejected,
                "diff": diff[:MAX_DIFF],
            }
        )
        level = round(risk.score)
        label = ["⚪ none", "🟢 low", "🟡 behavior change", "🔴 breaking"][level]
        lines += [
            f"**Risk: {label}** ({risk.score:.1f}/3, confidence {risk.confidence:.2f})",
            "",
        ]
        if level >= 2:
            if described >= 0.5:
                note = f"✅ Upgrade impact is described in the PR ({described:.2f})"
            else:
                note = f"⚠️ Upgrade impact is not described in the PR ({described:.2f}). Please add an upgrade note."
            lines += [note, ""]
    lines += bullets(
        "🔴 Kubernetes will reject this upgrade (immutable field changed)", rejected
    )
    lines += bullets("Removed values keys", removed_keys)
    lines += bullets("Changed defaults", changed_defaults)
    lines += bullets("Values no longer read by templates", unused_values)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
