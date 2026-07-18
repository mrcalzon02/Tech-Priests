#!/usr/bin/env python3
"""Validate Tech Priests governance and packaging prerequisites.

This source-only checker enforces the authoritative standards document, the
single canonical development history, the temporary base-state recovery
authority, truthful milestone state, connected developer guidance, and
fail-closed packaging integration. It does not claim that runtime or release
gates passed.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

README_PATH = pathlib.Path("README.md")
RECOVERY_PATH = pathlib.Path("RECOVERY_REPAIR_SEQUENCE.md")
STANDARDS_PATH = pathlib.Path("docs/STANDARDS_AND_PRACTICES.md")
HISTORY_PATH = pathlib.Path("docs/DEVELOPMENT_HISTORY.md")
PLAN_PATH = pathlib.Path("docs/state-of-mod-master-plan.md")
SOURCE_STANDARDS_PATH = pathlib.Path("tech-priests_src/docs/STANDARDS_AND_PRACTICES.md")
CURRENT_TESTING_PATH = pathlib.Path("tech-priests_src/docs/CURRENT_TESTING_GOALS.md")
CONTINUITY_PATH = pathlib.Path("tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md")
PACKAGE_PATH = pathlib.Path("tools/package_local.py")
WORKFLOW_PATH = pathlib.Path(".github/workflows/source-validation.yml")
INFO_PATH = pathlib.Path("tech-priests_src/info.json")
CHECKER_NAME = "check_governance_prerequisites_0738.py"

README_REQUIRED = [
    "RECOVERY_REPAIR_SEQUENCE.md",
    "docs/STANDARDS_AND_PRACTICES.md",
    "docs/DEVELOPMENT_HISTORY.md",
    "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
    "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md",
]

RECOVERY_REQUIRED = [
    "**Status:** Temporary top-level recovery authority",
    "## Purpose and Explicit Exception",
    "## Recovery Freeze",
    "## Documentation Authority Graph",
    "## Evidence Vocabulary",
    "## Stage 0 — Establish Repository and Architecture Truth",
    "## Stage 1 — Protect Physical State and Scheduler Truth",
    "## Stage 2 — Repair the Shared Runtime Spine",
    "## Stage 3 — Consolidate Behavioral Authority",
    "## Stage 4 — Reduce Runtime Pressure and Diagnostic Self-Cost",
    "## Stage 5 — Execute Runtime, Migration, Save/Load, and Behavioral Evidence",
    "## Stage 6 — Establish One Artifact and Release Doctrine",
    "# Required Documentation Update Contract for Every Repair Slice",
    "docs/DEVELOPMENT_HISTORY.md",
    "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
]

STANDARDS_REQUIRED = [
    "**Status:** Authoritative project governance document",
    "**Authoritative branch:** `main`",
    "**Packaged baseline:** `0.1.672`",
    "**Active development lane:** `0.1.674-dev`",
    "## Base-State Recovery Exception",
    "`RECOVERY_REPAIR_SEQUENCE.md`",
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
    "## Base-State Recovery and Unification Directive",
    "RECOVERY_REPAIR_SEQUENCE.md",
    "### Gate 4: Factorio load and migration validation",
    "### Gate 6: release-candidate packaging",
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

SOURCE_STANDARDS_REQUIRED = [
    "## Base-state recovery sequence rule",
    "../../RECOVERY_REPAIR_SEQUENCE.md",
    "AUTHORITY_REFACTOR_CONTINUITY.md",
    "../../docs/DEVELOPMENT_HISTORY.md",
]

CURRENT_TESTING_REQUIRED = [
    "**Top-level work order:** `../../RECOVERY_REPAIR_SEQUENCE.md`",
    "## Recovery Directive",
    "### Active Stage 0 target",
    "### Gate 4 — Stage 1 physical-state and scheduler scenarios",
    "### Gate 6 — Performance consolidation",
]

CONTINUITY_REQUIRED = [
    "../../RECOVERY_REPAIR_SEQUENCE.md",
    "## Recovery ownership target",
    "## Recovery migration order",
    "Action classification must become and remain read-only.",
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
            "base-state recovery must not advance the protected source version; "
            f"expected 0.1.672, found {version!r}"
        )


def check(project_root: pathlib.Path) -> int:
    root = project_root.resolve()
    errors: list[str] = []

    readme_path = root / README_PATH
    recovery_path = root / RECOVERY_PATH
    standards_path = root / STANDARDS_PATH
    history_path = root / HISTORY_PATH
    plan_path = root / PLAN_PATH
    source_standards_path = root / SOURCE_STANDARDS_PATH
    current_testing_path = root / CURRENT_TESTING_PATH
    continuity_path = root / CONTINUITY_PATH
    package_path = root / PACKAGE_PATH
    workflow_path = root / WORKFLOW_PATH

    readme = read_required(readme_path, errors)
    recovery = read_required(recovery_path, errors)
    standards = read_required(standards_path, errors)
    history = read_required(history_path, errors)
    plan = read_required(plan_path, errors)
    source_standards = read_required(source_standards_path, errors)
    current_testing = read_required(current_testing_path, errors)
    continuity = read_required(continuity_path, errors)
    package = read_required(package_path, errors)
    workflow = read_required(workflow_path, errors)

    require_fragments(readme_path, readme, README_REQUIRED, [], errors)
    require_fragments(recovery_path, recovery, RECOVERY_REQUIRED, [], errors)
    require_fragments(standards_path, standards, STANDARDS_REQUIRED, [], errors)
    require_fragments(history_path, history, HISTORY_REQUIRED, [], errors)
    require_fragments(plan_path, plan, PLAN_REQUIRED, PLAN_FORBIDDEN, errors)
    require_fragments(
        source_standards_path,
        source_standards,
        SOURCE_STANDARDS_REQUIRED,
        [],
        errors,
    )
    require_fragments(
        current_testing_path,
        current_testing,
        CURRENT_TESTING_REQUIRED,
        [],
        errors,
    )
    require_fragments(continuity_path, continuity, CONTINUITY_REQUIRED, [], errors)
    require_fragments(package_path, package, PACKAGE_REQUIRED, [], errors)
    require_fragments(workflow_path, workflow, WORKFLOW_REQUIRED, [], errors)

    if standards.count("Authoritative project governance document") != 1:
        errors.append(
            f"{STANDARDS_PATH}: governance authority marker must appear exactly once"
        )
    if history.count("Canonical narrative development history") != 1:
        errors.append(
            f"{HISTORY_PATH}: canonical history marker must appear exactly once"
        )
    if recovery.count("Temporary top-level recovery authority") != 1:
        errors.append(
            f"{RECOVERY_PATH}: recovery authority marker must appear exactly once"
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
