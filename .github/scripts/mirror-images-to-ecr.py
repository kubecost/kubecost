#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "rich>=13.9",
# ]
# ///

"""
mirror-images-to-ecr.py

Used by the Chart build and test 3.x workflow (.github/workflows/test-chart-3.0.yml) so the
`public.ecr.aws` images the EKS values file renders exist before check-images.sh verifies them.
Image bump PRs are often opened before the release pipeline has pushed to ECR Public.

Reads a helm-rendered YAML file, picks every `public.ecr.aws/kubecost/*` image, and copies
the matching image from icr.io (the source of truth) when the tag is not on ECR Public yet.

Why this is cheap:
  * `crane digest` is a single HEAD request, so images already mirrored cost nothing.
  * `crane copy` streams registry to registry (nothing lands on the runner's disk), keeps the
    digest, copies the whole manifest list (amd64 + arm64), and skips blobs the destination
    already has.
  * `--no-clobber` means a published tag is never overwritten.
  * Missing images are copied concurrently.

Auth is expected to be set up by the calling workflow: `crane auth login` for public.ecr.aws,
and a prior `docker login icr.io` (crane reads ~/.docker/config.json).

Usage:
    ./.github/scripts/mirror-images-to-ecr.py full.yaml
    ./.github/scripts/mirror-images-to-ecr.py full.yaml --dry-run
"""

import argparse
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from rich.console import Console
from rich.table import Table

ECR_PREFIX = "public.ecr.aws/kubecost/"
# Only these source namespaces are ever copied from, so a PR cannot make the job
# publish an arbitrary image to the public registry.
ICR_DEFAULT = "icr.io/kubecost/"
# ECR name -> icr.io repository, for images that live outside icr.io/kubecost.
ICR_OVERRIDES = {"agent": "icr.io/ibm-finops/agent"}

IMAGE_RE = re.compile(r"""^\s*(?:-\s+)?image:\s*["']?([^"'\s#]+)""", re.MULTILINE)

console = Console()


def source_for(dst: str) -> str:
    """public.ecr.aws/kubecost/<name>:<tag> -> the icr.io image it is mirrored from."""
    rest = dst.removeprefix(ECR_PREFIX)
    name = re.split(r"[:@]", rest, maxsplit=1)[0]
    return ICR_OVERRIDES.get(name, ICR_DEFAULT + name) + rest[len(name) :]


def crane(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["crane", *args], capture_output=True, text=True, check=False)


def mirror(dst: str, dry_run: bool) -> tuple[str, str, str]:
    """Returns (dst, status, detail). status is one of exists, would-copy, copied, failed."""
    src = source_for(dst)
    if crane("digest", dst).returncode == 0:
        return dst, "exists", ""
    if dry_run:
        return dst, "would-copy", src
    result = crane("copy", "--no-clobber", src, dst)
    if result.returncode != 0:
        return dst, "failed", f"{src}: {result.stderr.strip()}"
    return dst, "copied", src


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "yaml_file", type=Path, help="helm-rendered YAML to scan for images"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="report what would be copied"
    )
    args = parser.parse_args()

    images = sorted(
        {
            i
            for i in IMAGE_RE.findall(args.yaml_file.read_text())
            if i.startswith(ECR_PREFIX)
        }
    )
    if not images:
        console.print(f"No {ECR_PREFIX}* images found in {args.yaml_file}")
        return 0

    with ThreadPoolExecutor(max_workers=len(images)) as pool:
        results = list(pool.map(lambda image: mirror(image, args.dry_run), images))

    table = Table(title="ECR Public mirror")
    table.add_column("Image")
    table.add_column("Status")
    table.add_column("Detail", overflow="fold")
    styles = {
        "exists": "green",
        "copied": "cyan",
        "would-copy": "yellow",
        "failed": "red",
    }
    for dst, status, detail in results:
        table.add_row(dst, f"[{styles[status]}]{status}[/]", detail)
    console.print(table)

    failed = [r for r in results if r[1] == "failed"]
    for dst, _, detail in failed:
        print(f"::error::Could not mirror {dst}: {detail}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
