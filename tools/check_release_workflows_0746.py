#!/usr/bin/env python3
"""Verify historical publishers remain archived and canonical packaging is fail closed."""
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
WORKFLOW_FORBIDDEN = (
    "\n  push:",
    "contents: write",
    "gh release create",
    "gh release upload",
    "tools/package_local.py --overwrite",
)
PACKAGE_PATH = pathlib.Path("tools/package_local.py")
PACKAGE_REQUIRED = (
    'RELEASE_AUTHORIZATION_CHECKER = "check_release_authorization_0745.py"',
    'RECOVERY_CHECKER = "check_recovery_architecture_0744.py"',
    'INVENTORY_CHECKER = "check_inventory_insert_safety_0638.py"',
    'PROTECTED_VERSION = "0.1.672"',
    "run_release_authorization_checker(project_root)",
    "run_recovery_checker(project_root)",
    "run_inventory_checker(project_root)",
    "protected {PROTECTED_VERSION} recovery source may not be packaged",
    "MIGRATION_TEST_ONLY.json",
    "deterministic_zip",
    "write_digest",
)
PACKAGE_FORBIDDEN = (
    "--skip-locale-check",
    "--skip-inventory-check",
    "--strict-inventory-safety",
    "packaging anyway",
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
        for fragment in WORKFLOW_FORBIDDEN:
            if fragment in text:
                errors.append(f"{relative}: unsafe publication surface remains: {fragment}")

    package = root / PACKAGE_PATH
    if not package.is_file():
        errors.append(f"canonical packager is missing: {PACKAGE_PATH}")
    else:
        text = package.read_text(encoding="utf-8", errors="replace")
        for fragment in PACKAGE_REQUIRED:
            if fragment not in text:
                errors.append(f"{PACKAGE_PATH}: missing fail-closed contract: {fragment}")
        for fragment in PACKAGE_FORBIDDEN:
            if fragment in text:
                errors.append(f"{PACKAGE_PATH}: unsafe bypass remains: {fragment}")

    if errors:
        print("Release workflow and packaging audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print(
        "Release workflow and packaging audit passed; historical publishers are "
        "archived and canonical packaging is authorization-gated."
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    args = parser.parse_args(argv)
    return check(pathlib.Path(args.project_root).resolve())


if __name__ == "__main__":
    raise SystemExit(main())
