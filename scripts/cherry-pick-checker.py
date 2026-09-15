#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "pygithub>=2.10.0",
# ]
# ///

"""
cherry-pick-checker.py

Used by the PR Backport Status workflow to check the status of PRs labeled with each detected release version.
@ .github/workflows/pr-backport-status.yaml

Lists merged PRs labeled with each detected release version in kubecost/kubecost
and checks whether each PR's merge commit is present in the corresponding
release branch. Also detects cherry-pick PRs and PRs whose diff is already
on the branch (superseded / empty cherry-pick). Open and closed-unmerged PRs
are ignored.

Versions are auto-detected: the two highest semver branches matching v\\d+\\.\\d+
in the target repo are used — highest = RC, second-highest = GA.

Requirements: PyGithub, git
Environment: GITHUB_TOKEN must be set.

Usage:
    uv run ./scripts/cherry-pick-checker.py [options]

    --repo REPO            GitHub repo slug (default: kubecost/kubecost)
    --limit N              Max PRs to fetch per label (default: 200)
    --output-file PATH     Write Markdown report to this file
    --summary-json PATH    Write per-branch JSON summary to this file
    --only-missing         Print only PRs whose cherry-pick is missing
    --branch BRANCH        Check only this branch (skip GA/RC detection)

Suppressing the MISSING alert:
    Label a PR with `ignore-cherry-pick-checker` to mark it as intentionally
    not cherry-picked. The script will report it as SKIPPED (⏭️) rather than
    MISSING (❌) and exclude it from needs-attention counts.

Run locally:
uv run ./scripts/cherry-pick-checker.py                              # GA + RC, all labeled PRs
uv run ./scripts/cherry-pick-checker.py --only-missing               # GA + RC, missing cherry-picks
uv run ./scripts/cherry-pick-checker.py --branch v3.3 --only-missing # one branch only, missing cherry-picks only
"""

import argparse
import dataclasses
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import UTC, datetime

# pygithub is automatically installed when running with uv
# if needed, install with:
# uv add pygithub
from github import Auth, Github, GithubException

# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------


class Status:
    IN_BRANCH = "IN_BRANCH"
    CHERRY_PICKED = "CHERRY_PICKED"
    ALREADY_ON_BRANCH = "ALREADY_ON_BRANCH"
    MISSING = "MISSING"
    SKIPPED = "SKIPPED"


SKIP_LABEL = "ignore-cherry-pick-checker"


@dataclasses.dataclass
class PRResult:
    number: int
    title: str
    merged_at: str | None  # ISO date string YYYY-MM-DD or None
    status: str
    cherry_pick_pr: int | None = None


# ---------------------------------------------------------------------------
# Version detection
# ---------------------------------------------------------------------------


def detect_versions(repo) -> tuple[str, str]:
    """Return (ga_version, rc_version) by inspecting branch names."""
    pattern = re.compile(r"^v(\d+)\.(\d+)$")
    versions = []
    try:
        branches = repo.get_branches()
        for branch in branches:
            m = pattern.match(branch.name)
            if m:
                versions.append((int(m.group(1)), int(m.group(2)), branch.name))
    except GithubException as e:
        raise RuntimeError(f"Could not detect release branches: {e}") from e

    if len(versions) < 2:
        raise RuntimeError(
            f"Expected at least 2 release branches matching v\\d+\\.\\d+, "
            f"found {len(versions)}: {[v[2] for v in versions]}"
        )

    versions.sort(key=lambda t: (t[0], t[1]), reverse=True)
    rc_version = versions[0][2]
    ga_version = versions[1][2]
    return ga_version, rc_version


# ---------------------------------------------------------------------------
# PR fetching
# ---------------------------------------------------------------------------


def fetch_prs(repo, label: str, limit: int) -> list[dict]:
    """Fetch merged PRs carrying the given label. Open and closed-unmerged PRs are skipped."""
    results = []
    label_obj = repo.get_label(label)
    issues = repo.get_issues(labels=[label_obj], state="closed")
    for issue in issues:
        if not issue.pull_request:
            continue
        pr = issue.as_pull_request()
        if not pr.merged:
            continue
        merge_sha = pr.merge_commit_sha or ""
        merged_at = pr.merged_at.strftime("%Y-%m-%d") if pr.merged_at else None
        results.append(
            {
                "number": pr.number,
                "title": pr.title,
                "state": pr.state,
                "merge_sha": merge_sha,
                "merged_at": merged_at,
                "head_ref": pr.head.ref,
                "body": pr.body or "",
                "labels": [lbl.name for lbl in issue.labels],
            }
        )
        if len(results) >= limit:
            break
    return results


# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------


def _git_env() -> dict[str, str]:
    env = os.environ.copy()
    env["GIT_ASKPASS"] = "sh -c 'case \"$1\" in *Username*) echo x-access-token;; *) echo \"$GIT_PASSWORD\";; esac' --"
    env["GIT_PASSWORD"] = env["GITHUB_TOKEN"]
    env["GIT_TERMINAL_PROMPT"] = "0"
    return env


def _git(tmpdir: str, *args, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", tmpdir, *args],
        capture_output=True,
        check=check,
        env=_git_env(),
    )


def clone_branch(remote: str, branch: str, tmpdir: str) -> None:
    """Blobless no-checkout clone of a single branch into tmpdir."""
    env = _git_env()
    result = subprocess.run(
        [
            "git",
            "clone",
            "--quiet",
            "--filter=blob:none",
            "--no-checkout",
            "--branch",
            branch,
            remote,
            tmpdir,
        ],
        capture_output=True,
        check=False,
        env=env,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Could not clone branch '{branch}' from {remote}:\n"
            f"{result.stderr.decode()}"
        )


def ensure_commit(tmpdir: str, sha: str) -> bool:
    """Ensure sha is available locally; fetch it if needed. Returns False if unavailable."""
    if not sha or sha == "null":
        return False
    r = _git(tmpdir, "cat-file", "-e", f"{sha}^{{commit}}", check=False)
    if r.returncode == 0:
        return True
    r = _git(
        tmpdir, "fetch", "--quiet", "--filter=blob:none", "origin", sha, check=False
    )
    return r.returncode == 0


def is_in_branch(tmpdir: str, sha: str) -> bool:
    """Return True if sha is an ancestor of the cloned branch HEAD."""
    r = _git(tmpdir, "merge-base", "--is-ancestor", sha, "HEAD", check=False)
    return r.returncode == 0


def is_already_on_branch(tmpdir: str, sha: str) -> bool:
    """
    Return True when the PR's diff is already fully absorbed into the branch
    (i.e., applying the merge commit produces no new tree changes).

    Uses merge-tree without -X ours: if a conflict occurs the merge is non-trivial
    and we conservatively return False to avoid hiding real missing cherry-picks.
    """
    if not ensure_commit(tmpdir, sha):
        return False

    # Resolve the first parent of the merge commit
    r = _git(tmpdir, "rev-parse", f"{sha}^1", check=False)
    if r.returncode != 0:
        return False
    parent = r.stdout.decode().strip()
    if not ensure_commit(tmpdir, parent):
        return False

    r = _git(
        tmpdir,
        "merge-tree",
        "--write-tree",
        f"--merge-base={parent}",
        "HEAD",
        sha,
        check=False,
    )
    # Non-zero exit means conflicts — not cleanly already on branch
    if r.returncode != 0:
        return False

    result_ref = r.stdout.decode().strip()

    head_tree = _git(tmpdir, "rev-parse", "HEAD^{tree}").stdout.decode().strip()
    r2 = _git(tmpdir, "rev-parse", f"{result_ref}^{{tree}}", check=False)
    result_tree = r2.stdout.decode().strip() if r2.returncode == 0 else result_ref

    return head_tree == result_tree


# ---------------------------------------------------------------------------
# Cherry-pick detection
# ---------------------------------------------------------------------------


def normalize_title(title: str) -> str:
    """Strip cherry-pick decorations so titles can be compared."""
    t = title.lower().strip()
    t = re.sub(r"^\[cherry-pick\]\s*", "", t)
    t = re.sub(r"^:cherries:\s*", "", t)
    t = re.sub(r"\s+to\s+v\d+\.\d+\s*$", "", t)
    return re.sub(r"\s+", " ", t).strip()


def find_cherrypick_pr(
    repo,
    g: "Github",
    pr_number: int,
    title: str,
    all_prs: list[dict],
    tmpdir: str,
    target_branch: str,
) -> int | None:
    """
    Search for a cherry-pick PR that brought pr_number into target_branch.
    Returns the cherry-pick PR number, or None.
    """
    expected_branch = f"cherry-pick/{pr_number}-to-{target_branch}"
    orig_norm = normalize_title(title)

    # --- Pass 1: scan the already-fetched PR list ---
    for candidate in all_prs:
        if candidate["number"] == pr_number:
            continue
        head = candidate["head_ref"]
        ctitle = candidate["title"]
        cbody = candidate["body"]
        ctitle_lower = ctitle.lower()

        title_match = False
        if orig_norm:
            cand_norm = normalize_title(ctitle)
            title_match = cand_norm == orig_norm and (
                re.search(r"cherry-pick|:cherries:", ctitle, re.IGNORECASE)
                or head.startswith("cherry-pick/")
            )

        if (
            head == expected_branch
            or f"cherry-pick #{pr_number}" in ctitle_lower
            or re.search(
                rf"(?i)cherrypick of #{pr_number}|cherry-pick[^\n]*#{pr_number}",
                cbody,
            )
            or title_match
        ):
            cp_sha = candidate["merge_sha"]
            if cp_sha:
                ensure_commit(tmpdir, cp_sha)
                if is_in_branch(tmpdir, cp_sha):
                    return candidate["number"]

    # --- Pass 2: GitHub search ---
    def _search_merged(query: str) -> list:
        try:
            found = []
            items = g.search_issues(
                f"{query} is:pr is:merged repo:{repo.full_name}",
            )
            for item in items:
                if not item.pull_request:
                    continue
                pr = item.as_pull_request()
                found.append(
                    {
                        "number": pr.number,
                        "merge_sha": pr.merge_commit_sha or "",
                    }
                )
                if len(found) >= 10:
                    break
            return found
        except GithubException:
            return []

    for query in [
        f"{pr_number}-to-{target_branch}",
        f"Cherrypick of #{pr_number}",
    ]:
        for candidate in _search_merged(query):
            cp_sha = candidate["merge_sha"]
            if cp_sha:
                ensure_commit(tmpdir, cp_sha)
                if is_in_branch(tmpdir, cp_sha):
                    return candidate["number"]

    return None


# ---------------------------------------------------------------------------
# Branch checking
# ---------------------------------------------------------------------------


def check_branch(
    repo,
    g: "Github",
    version: str,
    all_prs: list[dict],
    tmpdir: str,
) -> list[PRResult]:
    """Check every PR in all_prs against the given version branch."""
    results = []
    for pr in all_prs:
        num = pr["number"]
        title = pr["title"]
        merged_at = pr["merged_at"]
        merge_sha = pr["merge_sha"]

        if not merge_sha:
            continue

        if SKIP_LABEL in pr.get("labels", []):
            results.append(PRResult(num, title, merged_at, Status.SKIPPED))
            continue

        if not ensure_commit(tmpdir, merge_sha):
            # Commit unavailable; is_in_branch will return False and the PR
            # will fall through to cherry-pick detection or be flagged MISSING.
            pass

        if is_in_branch(tmpdir, merge_sha):
            results.append(PRResult(num, title, merged_at, Status.IN_BRANCH))
            continue

        cp_num = find_cherrypick_pr(repo, g, num, title, all_prs, tmpdir, version)
        if cp_num is not None:
            results.append(
                PRResult(num, title, merged_at, Status.CHERRY_PICKED, cp_num)
            )
            continue

        if is_already_on_branch(tmpdir, merge_sha):
            results.append(PRResult(num, title, merged_at, Status.ALREADY_ON_BRANCH))
            continue

        results.append(PRResult(num, title, merged_at, Status.MISSING))

    return results


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

STATUS_EMOJI = {
    Status.IN_BRANCH: "✅",
    Status.CHERRY_PICKED: "🍒",
    Status.ALREADY_ON_BRANCH: "🔵",
    Status.MISSING: "❌",
    Status.SKIPPED: "⏭️",
}

STATUS_LABEL = {
    Status.IN_BRANCH: "IN BRANCH",
    Status.CHERRY_PICKED: "CHERRY-PICKED",
    Status.ALREADY_ON_BRANCH: "ALREADY ON BRANCH",
    Status.MISSING: "MISSING",
    Status.SKIPPED: "SKIPPED",
}


def render_markdown(
    version: str,
    results: list[PRResult],
    *,
    only_missing: bool = False,
    repo: str = "kubecost/kubecost",
) -> str:
    counts = {s: 0 for s in STATUS_LABEL}
    for r in results:
        counts[r.status] += 1

    display = (
        [r for r in results if r.status == Status.MISSING] if only_missing else results
    )

    lines = [
        f"## Branch: `{version}`",
        "",
        "| PR | Title | Merged At | Status |",
        "|----|-------|-----------|--------|",
    ]
    if only_missing and not display:
        lines.append("| — | No missing cherry-picks | — | — |")
    for r in display:
        emoji = STATUS_EMOJI[r.status]
        label = STATUS_LABEL[r.status]
        if r.status == Status.CHERRY_PICKED and r.cherry_pick_pr:
            label = f"CHERRY-PICKED via #{r.cherry_pick_pr}"
        title = r.title.replace("|", "\\|")
        if len(title) > 60:
            title = title[:57] + "..."
        lines.append(
            f"| [#{r.number}](https://github.com/{repo}/pull/{r.number}) "
            f"| {title} | {r.merged_at or '—'} | {emoji} {label} |"
        )

    if only_missing:
        n_missing = counts[Status.MISSING]
        summary = (
            f"**Summary:** {n_missing} missing cherry-pick"
            f"{'' if n_missing == 1 else 's'} "
            f"({len(results)} labeled PRs checked)."
        )
    else:
        summary = (
            f"**Summary:** "
            f"{counts[Status.IN_BRANCH]} in branch directly, "
            f"{counts[Status.CHERRY_PICKED]} via cherry-pick, "
            f"{counts[Status.ALREADY_ON_BRANCH]} already on branch, "
            f"{counts[Status.MISSING]} missing, "
            f"{counts[Status.SKIPPED]} skipped."
        )

    lines += ["", summary, ""]
    return "\n".join(lines)


def render_summary_json(
    branch_results: list[tuple[str, list[PRResult]]],
    run_url: str = "",
) -> dict:
    def _branch_summary(version: str, results: list[PRResult]) -> dict:
        counts = {s: 0 for s in STATUS_LABEL}
        for r in results:
            counts[r.status] += 1
        needs_attention = [
            {
                "number": r.number,
                "title": r.title,
                "status": STATUS_LABEL[r.status],
                "merged_at": r.merged_at,
            }
            for r in results
            if r.status == Status.MISSING
        ]
        return {
            "version": version,
            "total": len(results),
            "in_branch": counts[Status.IN_BRANCH],
            "cherry_picked": counts[Status.CHERRY_PICKED],
            "already_on_branch": counts[Status.ALREADY_ON_BRANCH],
            "missing": counts[Status.MISSING],
            "skipped": counts[Status.SKIPPED],
            "needs_attention": needs_attention,
        }

    return {
        "generated_at": datetime.now(UTC).strftime("%Y-%m-%d %H:%M UTC"),
        "run_url": run_url,
        "branches": [
            _branch_summary(version, results) for version, results in branch_results
        ],
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default="kubecost/kubecost")
    parser.add_argument("--limit", type=int, default=200)
    parser.add_argument("--output-file", metavar="PATH")
    parser.add_argument("--summary-json", metavar="PATH")
    parser.add_argument(
        "--only-missing",
        action="store_true",
        help="Print only PRs whose cherry-pick is missing",
    )
    parser.add_argument(
        "--branch",
        metavar="BRANCH",
        help="Check only this branch (skip GA/RC detection)",
    )
    args = parser.parse_args()

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        sys.exit("ERROR: GITHUB_TOKEN environment variable is not set.")

    g = Github(auth=Auth.Token(token))
    repo = g.get_repo(args.repo)

    if args.branch:
        versions = [args.branch]
        print(f"Checking branch {args.branch} in {args.repo}...")
        branch_header = f"Branch: `{args.branch}`"
    else:
        print(f"Detecting release versions in {args.repo}...")
        ga_version, rc_version = detect_versions(repo)
        print(f"  GA  → {ga_version}")
        print(f"  RC  → {rc_version}")
        versions = [ga_version, rc_version]
        branch_header = f"GA: `{ga_version}` | RC: `{rc_version}`"

    remote = f"https://github.com/{args.repo}.git"
    report_title = (
        "# PR Backport Status Report (missing cherry-picks)"
        if args.only_missing
        else "# PR Backport Status Report"
    )
    report_sections = [
        report_title,
        "",
        f"Generated: {datetime.now(UTC).strftime('%Y-%m-%d %H:%M UTC')}  ",
        f"Repo: `{args.repo}`  ",
        branch_header,
        "",
    ]

    all_branch_results = {}

    for version in versions:
        print(f"\nChecking branch {version}...")
        tmpdir = tempfile.mkdtemp()
        try:
            clone_branch(remote, version, tmpdir)
            print(f"  Fetching PRs labeled '{version}'...")
            try:
                prs = fetch_prs(repo, version, args.limit)
            except GithubException as e:
                print(f"  WARNING: Could not fetch PRs for label '{version}': {e}")
                prs = []

            print(f"  Found {len(prs)} PRs. Checking status...")
            results = check_branch(repo, g, version, prs, tmpdir)
            all_branch_results[version] = results
            report_sections.append(
                render_markdown(
                    version, results, only_missing=args.only_missing, repo=args.repo
                )
            )
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

    full_report = "\n".join(report_sections)

    # Print to stdout always
    print("\n" + full_report)

    # Write full Markdown report
    if args.output_file:
        with open(args.output_file, "w") as f:
            f.write(full_report)
        print(f"\nFull report written to {args.output_file}")

    # Write JSON summary
    if args.summary_json:
        run_url = os.environ.get("GITHUB_RUN_URL", "")
        summary = render_summary_json(
            [(v, all_branch_results.get(v, [])) for v in versions],
            run_url=run_url,
        )
        with open(args.summary_json, "w") as f:
            json.dump(summary, f, indent=2)
        print(f"JSON summary written to {args.summary_json}")


if __name__ == "__main__":
    main()
