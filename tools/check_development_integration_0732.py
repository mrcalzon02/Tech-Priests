#!/usr/bin/env python3
"""Validate the 0.1.674-dev hardener, retirement, lifecycle, and broker graph.

This checker is source-only. It proves that every module in the declarative
HARDENERS table exists, exposes an install entry point with an explicit return,
appears once, and is ordered after its dependencies. It also proves that the six
retired movement/salvage authorities cannot appear in the active table and that
each critical broker service has one literal registration.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys
from collections import Counter
from dataclasses import dataclass

SOURCE_DIR = "tech-priests_src"
PLANNING_PATH = pathlib.Path("scripts/core/planning_constraints_0646.lua")
LIFECYCLE_PATH = pathlib.Path("scripts/core/development_lifecycle_checkpoint_0733.lua")

HARDENER_RE = re.compile(
    r'\{module="(?P<module>scripts\.core\.[^"]+)",label="(?P<label>[^"]+)"\}'
)
RETIRED_RE = re.compile(
    r'\["(?P<module>scripts\.core\.[^"]+)"\]="(?P<reason>[^"]+)"'
)
SERVICE_START_RE = re.compile(r"register_service\s*\(\s*\{", re.MULTILINE)
SERVICE_NAME_RE = re.compile(r'\bname\s*=\s*["\']([^"\']+)["\']')
INSTALL_START_RE = re.compile(r"\bfunction\s+M\.install\s*\(")
EXPLICIT_RETURN_RE = re.compile(r"\breturn\s+[^\s]", re.MULTILINE)

RETIRED_REQUIRED = {
    "scripts.core.direct_acquisition_movement_lock_0650",
    "scripts.core.movement_vector_enforcer_0651",
    "scripts.core.movement_target_reconciler_0652",
    "scripts.core.movement_intent_authority_0654",
    "scripts.core.active_leaf_task_truth_0655",
    "scripts.core.logistics_mineable_source_bridge_0657",
}
REQUIRED_MODULES = {
    "scripts.core.proxy_ammo_hardener_0649",
    "scripts.core.visual_intent_line_authority_0657",
    "scripts.core.energy_family_readiness_0705",
    "scripts.core.fusion_reactor_readiness_guard_0727",
    "scripts.core.energy_family_logistics_0707",
    "scripts.core.energy_item_automation_guard_0722",
    "scripts.core.energy_automation_guard_install_assertion_0726",
    "scripts.core.rocket_silo_readiness_0709",
    "scripts.core.rocket_silo_logistics_0710",
    "scripts.core.rocket_silo_live_ownership_guard_0728",
    "scripts.core.artillery_readiness_0712",
    "scripts.core.artillery_logistics_0713",
    "scripts.core.artillery_train_validity_guard_0724",
    "scripts.core.roboport_readiness_0714",
    "scripts.core.roboport_repair_pack_logistics_0715",
    "scripts.core.fluid_turret_readiness_0716",
    "scripts.core.fluid_turret_internal_buffer_guard_0731",
    "scripts.core.fluid_turret_connection_proposals_0717",
    "scripts.core.fluid_turret_proposal_integrity_0718",
    "scripts.core.fluid_turret_connection_planner_0719",
    "scripts.core.fluid_turret_planner_integrity_0730",
    "scripts.core.development_integration_audit_0721",
    "scripts.core.runtime_command_cleanup_0720",
    "scripts.core.development_lifecycle_checkpoint_0733",
    "scripts.core.broker_registry_integrity_0725",
    "scripts.core.hardener_installation_audit_0723",
}
ORDER_GROUPS = [
    (
        "energy authority order",
        [
            "scripts.core.energy_family_readiness_0705",
            "scripts.core.fusion_reactor_readiness_guard_0727",
            "scripts.core.energy_readiness_diagnostics_0711",
            "scripts.core.energy_family_logistics_0707",
            "scripts.core.energy_item_automation_guard_0722",
            "scripts.core.energy_automation_guard_install_assertion_0726",
        ],
    ),
    (
        "rocket silo authority order",
        [
            "scripts.core.rocket_silo_readiness_0709",
            "scripts.core.rocket_silo_logistics_0710",
            "scripts.core.rocket_silo_live_ownership_guard_0728",
        ],
    ),
    (
        "artillery authority order",
        [
            "scripts.core.artillery_readiness_0712",
            "scripts.core.artillery_logistics_0713",
            "scripts.core.artillery_train_validity_guard_0724",
        ],
    ),
    (
        "fluid turret authority order",
        [
            "scripts.core.fluid_turret_readiness_0716",
            "scripts.core.fluid_turret_internal_buffer_guard_0731",
            "scripts.core.fluid_turret_connection_proposals_0717",
            "scripts.core.fluid_turret_proposal_integrity_0718",
            "scripts.core.fluid_turret_connection_planner_0719",
            "scripts.core.fluid_turret_planner_integrity_0730",
        ],
    ),
    (
        "final development audit order",
        [
            "scripts.core.development_integration_audit_0721",
            "scripts.core.runtime_command_cleanup_0720",
            "scripts.core.development_lifecycle_checkpoint_0733",
            "scripts.core.broker_registry_integrity_0725",
            "scripts.core.migration_lifecycle_assertion_0735",
            "scripts.core.hardener_installation_audit_0723",
        ],
    ),
]
CRITICAL_SERVICES = {
    "energy_family_readiness_0705",
    "energy_family_logistics_0707",
    "rocket_silo_readiness_0709",
    "rocket_silo_logistics_0710",
    "artillery_readiness_0712",
    "artillery_logistics_0713",
    "roboport_readiness_0714",
    "roboport_repair_pack_logistics_0715",
    "fluid_turret_readiness_0716",
    "fluid_turret_connection_proposals_0717",
    "fluid_turret_proposal_integrity_0718",
    "runtime_command_cleanup_0720",
    "development_integration_audit_0721",
    "hardener_installation_audit_0723",
    "broker_registry_integrity_0725",
    "fluid_turret_planner_integrity_0730",
    "development_lifecycle_checkpoint_0733",
}


@dataclass(frozen=True)
class InstallEntry:
    module: str
    label: str
    index: int


def resolve_root(project_root: pathlib.Path) -> pathlib.Path:
    root = project_root.resolve()
    candidate = root / SOURCE_DIR
    if candidate.is_dir():
        return candidate
    if (root / "info.json").is_file():
        return root
    raise FileNotFoundError(f"could not locate {SOURCE_DIR} below {root}")


def module_path(mod_root: pathlib.Path, module: str) -> pathlib.Path:
    return mod_root / pathlib.Path(*module.split(".")).with_suffix(".lua")


def install_entries(planning_text: str) -> list[InstallEntry]:
    return [
        InstallEntry(match.group("module"), match.group("label"), index)
        for index, match in enumerate(HARDENER_RE.finditer(planning_text))
    ]


def retired_entries(planning_text: str) -> dict[str, str]:
    return {
        match.group("module"): match.group("reason")
        for match in RETIRED_RE.finditer(planning_text)
    }


def literal_service_names(text: str) -> list[str]:
    names: list[str] = []
    for start in SERVICE_START_RE.finditer(text):
        window = text[start.end() : start.end() + 1600]
        name_match = SERVICE_NAME_RE.search(window)
        if name_match:
            names.append(name_match.group(1))
    return names


def install_has_explicit_return(text: str) -> bool:
    start = INSTALL_START_RE.search(text)
    if not start:
        return False
    module_return = text.rfind("return M")
    body = text[start.end() : module_return if module_return > start.end() else None]
    return EXPLICIT_RETURN_RE.search(body) is not None


def check_lifecycle_module(mod_root: pathlib.Path, errors: list[str]) -> None:
    path = mod_root / LIFECYCLE_PATH
    if not path.is_file():
        errors.append(f"development lifecycle checkpoint is missing: {path}")
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    for fragment in (
        "scripts.core.runtime_event_registry",
        "registry.on_init",
        "registry.on_configuration_changed",
        'name = "development_lifecycle_checkpoint_0733"',
        "source_revision",
    ):
        if fragment not in text:
            errors.append(f"lifecycle checkpoint is missing required contract: {fragment}")
    for fragment in (
        "script.on_init(",
        "script.on_configuration_changed(",
        "script.on_load(",
    ):
        if fragment in text:
            errors.append(f"lifecycle checkpoint bypasses canonical registry: {fragment}")


def check(project_root: pathlib.Path) -> int:
    mod_root = resolve_root(project_root)
    planning_file = mod_root / PLANNING_PATH
    planning_text = planning_file.read_text(encoding="utf-8")
    entries = install_entries(planning_text)
    retired = retired_entries(planning_text)
    errors: list[str] = []

    if not entries:
        errors.append(f"{planning_file}: no declarative hardener entries found")
        return report(errors, 0, 0, 0, len(retired))

    module_counts = Counter(entry.module for entry in entries)
    label_counts = Counter(entry.label for entry in entries)
    for module, count in sorted(module_counts.items()):
        if count != 1:
            errors.append(f"hardener module appears {count} times: {module}")
    for label, count in sorted(label_counts.items()):
        if count != 1:
            errors.append(f"hardener label appears {count} times: {label}")

    installed_modules = set(module_counts)
    for module in sorted(REQUIRED_MODULES - installed_modules):
        errors.append(f"required development module is not installed: {module}")
    for module in sorted(RETIRED_REQUIRED - set(retired)):
        errors.append(f"required retired authority is not documented: {module}")
    for module in sorted(RETIRED_REQUIRED & installed_modules):
        errors.append(f"retired authority remains in active HARDENERS table: {module}")
    for module, reason in sorted(retired.items()):
        if not reason.strip():
            errors.append(f"retired authority has no reason: {module}")

    explicit_returns = 0
    for entry in entries:
        path = module_path(mod_root, entry.module)
        if not path.is_file():
            errors.append(f"installed module file is missing: {entry.module} -> {path}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if not INSTALL_START_RE.search(text):
            errors.append(f"installed module has no function M.install(): {entry.module}")
        if install_has_explicit_return(text):
            explicit_returns += 1
        else:
            errors.append(
                f"installed module M.install() has no explicit return under the "
                f"literal-true hardener contract: {entry.module}"
            )
        if not re.search(r"\breturn\s+M\s*$", text.rstrip()):
            errors.append(f"installed module does not end with return M: {entry.module}")

    positions = {entry.module: entry.index for entry in entries}
    for group_name, group in ORDER_GROUPS:
        missing = [module for module in group if module not in positions]
        if missing:
            errors.append(f"{group_name}: missing {', '.join(missing)}")
            continue
        observed = [positions[module] for module in group]
        if observed != sorted(observed):
            errors.append(f"{group_name}: incorrect install order: {' -> '.join(group)}")

    check_lifecycle_module(mod_root, errors)

    service_locations: dict[str, list[pathlib.Path]] = {}
    for path in sorted((mod_root / "scripts/core").rglob("*.lua")):
        text = path.read_text(encoding="utf-8", errors="replace")
        for name in literal_service_names(text):
            service_locations.setdefault(name, []).append(path)

    for name in sorted(CRITICAL_SERVICES):
        paths = service_locations.get(name, [])
        if len(paths) == 0:
            errors.append(f"critical broker service has no literal registration: {name}")
        elif len(paths) > 1:
            joined = ", ".join(str(path.relative_to(mod_root)) for path in paths)
            errors.append(f"critical broker service registered {len(paths)} times: {name}: {joined}")

    workflow = project_root.resolve() / ".github/workflows/source-validation.yml"
    if workflow.is_file():
        workflow_text = workflow.read_text(encoding="utf-8", errors="replace")
        if "check_development_integration_0732.py" not in workflow_text:
            errors.append("source-validation workflow does not run check_development_integration_0732.py")
    else:
        errors.append("source-validation workflow is missing")

    return report(
        errors,
        len(entries),
        len(service_locations),
        explicit_returns,
        len(retired),
    )


def report(
    errors: list[str],
    hardeners: int,
    services: int,
    explicit_returns: int,
    retired: int,
) -> int:
    print(
        f"Development integration audit found {hardeners} active hardeners, "
        f"{retired} retired authorities, {services} literal broker service names, "
        f"and {explicit_returns} explicit install returns."
    )
    if not errors:
        print("Development integration source audit passed.")
        return 0
    print("Development integration source audit failed:", file=sys.stderr)
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
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
