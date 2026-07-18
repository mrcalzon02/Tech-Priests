#!/usr/bin/env python3
"""Verify historical Tech Priests publication workflows remain archived.

The current main branch contains recovery source with protected 0.1.672 metadata.
No historical baseline or experimental RC workflow may publish from this tree.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

WORKFLOWS = {
    ".github/workflows/publish-baseline-0.1.672.yml": (
        "Archived protected baseline publisher",
        "VERIFIED_RELEASE_AUTHORIZATION.json",
    ),
    ".github/workflows/publish-repair-candidate-0.1.674.yml": (
        "Archived experimental prerelease RC1",
        "VERIFIED_RELEASE_AUTHORIZATION.json",
    ),
    ".github/workflows/publish-hotfix-0.1.674-rc.2.yml": (
        "Archived experimental prerelease RC2",
        "VERIFIED_RELEASE_AUTHORIZATION.json",
    ),
    ".github/workflows/publish-repair-candidate-0.1.674-rc.3.yml": (
        "Archived experimental prerelease RC3",
        "VERIFIED_RELEASE_AUTHORIZATION.json",
    ),
}
FORBIDDEN = (
    "\n  push:",
    "contents: write",
    "gh release create",
    "gh release upload",
    "tools/package_local.py --overwrite",
)


def check(root: pathlib.Path) -> int:
    errors: list[str] = []
    for relative, required in WORKFLOWS.items():
        path = root / relative
        if not path.is_file():
            errors.append(f"missing historical workflow guard: {relative}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for fragment in ("workflow_dispatch:", "contents: read", "exit 1", *required):
            if fragment not in text:
                errors.append(f"{relative}: missing archive guard: {fragment}")
        for fragment in FORBIDDEN:
            if fragment in text:
                errors.append(f"{relative}: unsafe publication surface remains: {fragment}")
    if errors:
        print("Release workflow archive audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("Release workflow archive audit passed; baseline and RC1-RC3 publishers are blocked.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    args = parser.parse_args(argv)
    return check(pathlib.Path(args.project_root).resolve())


if __name__ == "__main__":
    raise SystemExit(main())
