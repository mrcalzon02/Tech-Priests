#!/usr/bin/env python3
"""Validate migration audit and lifecycle assertion integration for 0.1.674-dev.

This checker is source-only. It proves that the migration pair audit, lifecycle
checkpoint, broker audit, lifecycle assertion, and final installation audit are
installed exactly once and in dependency order. It also protects the assertion
layer from quietly becoming a second timer or event authority.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from collections import Counter

SOURCE_DIR = "tech-priests_src"
CORE_DIR = pathlib.Path("scripts/core")
PLANNING_PATH = CORE_DIR / "planning_constraints_0646.lua"
MIGRATION_AUDIT_PATH = CORE_DIR / "migration_pair_integrity_0734.lua"
ASSERTION_PATH = CORE_DIR / "migration_lifecycle_assertion_0735.lua"
INFO_PATH = pathlib.Path("info.json")
WORKFLOW_PATH = pathlib.Path(".github/workflows/source-validation.yml")
CHECKER_NAME = "check_migration_lifecycle_integration_0736.py"

INSTALL_RE = re.compile(
    r'install\(\s*["\'](?P<module>scripts\.core\.[^"\']+)["\']\s*,\s*'
    r'["\'](?P<label>[^"\']+)["\']\s*\)'
)
SERVICE_START_RE = re.compile(r"register_service\s*\(\s*\{", re.MULTILINE)
SERVICE_NAME_RE = re.compile(r'\bname\s*=\s*["\']([^"\']+)["\']')

ORDERED_MODULES = [
    "scripts.core.migration_pair_integrity_0734",
    "scripts.core.development_lifecycle_checkpoint_0733",
    "scripts.core.broker_registry_integrity_0725",
    "scripts.core.migration_lifecycle_assertion_0735",
    "scripts.core.hardener_installation_audit_0723",
]

AUDIT_REQUIRED = [
    "function M.audit()",
    "read_only = true",
    'name = "migration_pair_integrity_0734"',
    "_G.TechPriestsMigrationPairIntegrity0734 = M",
    "mutations=0",
]

ASSERTION_REQUIRED = [
    'require, "scripts.core.migration_pair_integrity_0734"',
    'require, "scripts.core.development_lifecycle_checkpoint_0733"',
    'require, "scripts.core.broker_registry_integrity_0725"',
    "migration_lifecycle_assertion_0735_active",
    "migration_pair_service_count_0735",
    "last.complete = complete == true and migration.complete == true",
    "_G.TechPriestsMigrationLifecycleAssertion0735 = M",
    "timing_authorities=0",
]

ASSERTION_FORBIDDEN = [
    "script.on_init(",
    "script.on_load(",
    "script.on_configuration_changed(",
    "script.on_event(",
    "script.on_nth_tick(",
    "register_service(",
]


def resolve_roots(project_root: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path]:
    project = project_root.resolve()
    mod = project / SOURCE_DIR
    if mod.is_dir():
        return project, mod
    if (project / INFO_PATH).is_file():
        return project.parent, project
    raise FileNotFoundError(f"could not locate {SOURCE_DIR} below {project}")


def module_entries(planning_text: str) -> list[tuple[str, str]]:
    return [
        (match.group("module"), match.group("label"))
        for match in INSTALL_RE.finditer(planning_text)
    ]


def literal_service_names(text: str) -> list[str]:
    names: list[str] = []
    for start in SERVICE_START_RE.finditer(text):
        window = text[start.end() : start.end() + 1600]
        match = SERVICE_NAME_RE.search(window)
        if match:
            names.append(match.group(1))
    return names


def require_fragments(
    path: pathlib.Path,
    required: list[str],
    forbidden: list[str],
    errors: list[str],
) -> None:
    if not path.is_file():
        errors.append(f"required file is missing: {path}")
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    for fragment in required:
        if fragment not in text:
            errors.append(f"{path}: missing required contract: {fragment}")
    for fragment in forbidden:
        if fragment in text:
            errors.append(f"{path}: forbidden authority surface present: {fragment}")


def check(project_root: pathlib.Path) -> int:
    project, mod = resolve_roots(project_root)
    errors: list[str] = []

    planning = mod / PLANNING_PATH
    if not planning.is_file():
        errors.append(f"planning constraints are missing: {planning}")
        return report(errors, 0, 0)

    entries = module_entries(planning.read_text(encoding="utf-8"))
    modules = [module for module, _ in entries]
    labels = [label for _, label in entries]
    module_counts = Counter(modules)
    label_counts = Counter(labels)

    for module in ORDERED_MODULES:
        if module_counts[module] != 1:
            errors.append(
                f"required migration hardener appears {module_counts[module]} times: {module}"
            )
        label = module.rsplit(".", 1)[-1]
        if label_counts[label] != 1:
            errors.append(
                f"required migration hardener label appears {label_counts[label]} times: {label}"
            )

    if all(module in modules for module in ORDERED_MODULES):
        positions = [modules.index(module) for module in ORDERED_MODULES]
        if positions != sorted(positions):
            errors.append(
                "migration lifecycle install order is incorrect: "
                + " -> ".join(ORDERED_MODULES)
            )

    require_fragments(
        mod / MIGRATION_AUDIT_PATH,
        AUDIT_REQUIRED,
        [
            "script.on_init(",
            "script.on_load(",
            "script.on_configuration_changed(",
            "script.on_event(",
            "script.on_nth_tick(",
        ],
        errors,
    )
    require_fragments(
        mod / ASSERTION_PATH,
        ASSERTION_REQUIRED,
        ASSERTION_FORBIDDEN,
        errors,
    )

    service_locations: list[pathlib.Path] = []
    for path in sorted((mod / CORE_DIR).rglob("*.lua")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if "migration_pair_integrity_0734" in literal_service_names(text):
            service_locations.append(path)
    if len(service_locations) != 1:
        joined = ", ".join(str(path.relative_to(mod)) for path in service_locations)
        errors.append(
            "migration_pair_integrity_0734 must have exactly one broker registration; "
            f"found {len(service_locations)}"
            + (f": {joined}" if joined else "")
        )
    elif service_locations[0] != mod / MIGRATION_AUDIT_PATH:
        errors.append(
            "migration_pair_integrity_0734 broker registration is owned by the wrong file: "
            f"{service_locations[0].relative_to(mod)}"
        )

    info = mod / INFO_PATH
    if not info.is_file():
        errors.append(f"mod metadata is missing: {info}")
    else:
        metadata = json.loads(info.read_text(encoding="utf-8"))
        if metadata.get("version") != "0.1.672":
            errors.append(
                "migration integration must not bump the packaged version before runtime gates pass; "
                f"found {metadata.get('version')!r}"
            )

    workflow = project / WORKFLOW_PATH
    if not workflow.is_file():
        errors.append(f"source-validation workflow is missing: {workflow}")
    elif CHECKER_NAME not in workflow.read_text(encoding="utf-8", errors="replace"):
        errors.append(f"source-validation workflow does not run {CHECKER_NAME}")

    return report(errors, len(entries), len(service_locations))


def report(errors: list[str], hardeners: int, migration_services: int) -> int:
    print(
        "Migration lifecycle integration audit found "
        f"{hardeners} hardeners and {migration_services} migration broker registrations."
    )
    if not errors:
        print("Migration lifecycle integration source audit passed.")
        return 0
    print("Migration lifecycle integration source audit failed:", file=sys.stderr)
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
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
