#!/usr/bin/env python3
"""Validate Tech Priests governance and packaging prerequisites.

This source-only checker enforces the authoritative standards document, the
single canonical development history, truthful milestone state, and fail-closed
packaging integration. It does not claim that runtime or release gates passed.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

STANDARDS_PATH = pathlib.Path("docs/STANDARDS_AND_PRACTICES.md")
HISTORY_PATH = pathlib.Path("docs/DEVELOPMENT_HISTORY.md")
PLAN_PATH = pathlib.Path("docs/state-of-mod-master-plan.md")
PACKAGE_PATH = pathlib.Path("tools/package_local.py")
WORKFLOW_PATH = pathlib.Path(".github/workflows/source-validation.yml")
INFO_PATH = pathlib.Path("tech-priests_src/info.json")
CHECKER_NAME = "check_governance_prerequisites_0738.py"

STANDARDS_REQUIRED = [
    "**Status:** Authoritative project governance document",
    "**Authoritative branch:** `main`",
    "**Packaged baseline:** `0.1.672`",
    "**Active development lane:** `0.1.674-dev`",
    "## Development Branch Policy",
    "## Physical Honesty",
    "## Runtime Event and Timing Ownership",
    "## Persistent State and Serialization",
    "## Validation Gates",
    "## Packaging Rules",
    "`docs/DEVELOPMENT_HISTORY.md` is the single canonical narrative development history.",
]

HISTORY_REQUIRED = [
    "**Status:** Canonical narrative development history",
    "**Authoritative branch:** `main`",
    "**Packaged baseline:** `0.1.672`",
    "**Active development lane:** `0.1.674-dev`",
    "This file is the single canonical narrative record",
    "No accepted Factorio runtime logs have yet been recorded",
    "### Gate 4: Factorio load and migration validation",
    "### Gate 6: release-candidate packaging",
    "`info.json` must remain at `0.1.672`",
]

PLAN_REQUIRED = [
    "`docs/STANDARDS_AND_PRACTICES.md`",
    "`docs/DEVELOPMENT_HISTORY.md`",
    "**Authoritative branch:** `main`",
    "### Gate 1: governance and build prerequisites",
    "No accepted Factorio runtime evidence has yet been recorded.",
]

PLAN_FORBIDDEN = [
    "`docs/STANDARDS_AND_PRACTICES.md` is absent",
    "standards prerequisite therefore remains unresolved",
    "except the energy automation guard noted above",
]

PACKAGE_REQUIRED = [
    CHECKER_NAME,
    "def run_governance_checker(",
    "run_governance_checker(project_root)",
    "Governance prerequisite checker passed.",
]

WORKFLOW_REQUIRED = [
    CHECKER_NAME,
    "Audit governance prerequisites",
]


def read_required(path: pathlib.Path, errors: list[str]) -> str:
    if not path.is_file():
        errors.append(f"required governance file is missing: {path}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def require_fragments(
    path: pathlib.Path,
    text: str,
    required: list[str],
    forbidden: list[str],
    errors: list[str],
) -> None:
    for fragment in required:
        if fragment not in text:
            errors.append(f"{path}: missing required governance contract: {fragment}")
    for fragment in forbidden:
        if fragment in text:
            errors.append(f"{path}: stale or forbidden governance statement remains: {fragment}")


def validate_metadata(project_root: pathlib.Path, errors: list[str]) -> None:
    path = project_root / INFO_PATH
    if not path.is_file():
        errors.append(f"mod metadata is missing: {path}")
        return
    try:
        metadata = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"mod metadata is invalid JSON: {path}: {exc}")
        return
    version = metadata.get("version")
    if version != "0.1.672":
        errors.append(
            "governance reconstruction must not advance the packaged version; "
            f"expected 0.1.672, found {version!r}"
        )


def check(project_root: pathlib.Path) -> int:
    root = project_root.resolve()
    errors: list[str] = []

    standards_path = root / STANDARDS_PATH
    history_path = root / HISTORY_PATH
    plan_path = root / PLAN_PATH
    package_path = root / PACKAGE_PATH
    workflow_path = root / WORKFLOW_PATH

    standards = read_required(standards_path, errors)
    history = read_required(history_path, errors)
    plan = read_required(plan_path, errors)
    package = read_required(package_path, errors)
    workflow = read_required(workflow_path, errors)

    require_fragments(
        standards_path,
        standards,
        STANDARDS_REQUIRED,
        [],
        errors,
    )
    require_fragments(
        history_path,
        history,
        HISTORY_REQUIRED,
        [],
        errors,
    )
    require_fragments(
        plan_path,
        plan,
        PLAN_REQUIRED,
        PLAN_FORBIDDEN,
        errors,
    )
    require_fragments(
        package_path,
        package,
        PACKAGE_REQUIRED,
        [],
        errors,
    )
    require_fragments(
        workflow_path,
        workflow,
        WORKFLOW_REQUIRED,
        [],
        errors,
    )

    if standards.count("Authoritative project governance document") != 1:
        errors.append(
            f"{STANDARDS_PATH}: governance authority marker must appear exactly once"
        )
    if history.count("Canonical narrative development history") != 1:
        errors.append(
            f"{HISTORY_PATH}: canonical history marker must appear exactly once"
        )

    validate_metadata(root, errors)
    return report(errors)


def report(errors: list[str]) -> int:
    if not errors:
        print("Governance prerequisite audit passed.")
        return 0
    print("Governance prerequisite audit failed:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        return check(pathlib.Path(args.project_root))
    except OSError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
