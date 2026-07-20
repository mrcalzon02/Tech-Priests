#!/usr/bin/env python3
"""Validate the active/retired hardener graph and critical runtime contracts."""
from __future__ import annotations

import argparse
import pathlib
import re
import sys
from collections import Counter

SOURCE_DIR = "tech-priests_src"
PLANNING = pathlib.Path("scripts/core/planning_constraints_0646.lua")
LIFECYCLE = pathlib.Path("scripts/core/development_lifecycle_checkpoint_0733.lua")
HARDENER_RE = re.compile(
    r'\{\s*module\s*=\s*"(?P<module>scripts\.core\.[^"]+)"\s*,\s*'
    r'label\s*=\s*"(?P<label>[^"]+)"\s*\}'
)
RETIRED_RE = re.compile(
    r'\["(?P<module>scripts\.core\.[^"]+)"\]\s*=\s*"(?P<reason>[^"]+)"'
)
SERVICE_RE = re.compile(
    r'register_service\s*\(?\s*\{.{0,2600}?\bname\s*=\s*["\']([^"\']+)["\']',
    re.S,
)
INSTALL_RE = re.compile(r"\bfunction\s+M\.install\s*\(")
EXPLICIT_RETURN_RE = re.compile(r"\breturn\s+[^\s]")

EXPECTED_ACTIVE_COUNT = 35
EXPECTED_RETIRED = {
    "scripts.core.direct_acquisition_movement_lock_0650",
    "scripts.core.movement_vector_enforcer_0651",
    "scripts.core.movement_target_reconciler_0652",
    "scripts.core.movement_intent_authority_0654",
    "scripts.core.active_leaf_task_truth_0655",
    "scripts.core.construction_placement_authority_0656",
    "scripts.core.logistics_mineable_source_bridge_0657",
    "scripts.core.repair_executor_integrity_0673",
    "scripts.core.combat_repair_integrity_0676",
    "scripts.core.combat_repair_terminal_cleanup_0677",
    "scripts.core.machine_logistics_integrity_0682",
    "scripts.core.machine_logistics_candidate_recovery_0683",
    "scripts.core.machine_logistics_final_authority_0684",
    "scripts.core.item_family_integrity_0703",
    "scripts.core.fusion_reactor_readiness_guard_0727",
    "scripts.core.energy_readiness_diagnostics_0711",
    "scripts.core.energy_item_automation_guard_0722",
    "scripts.core.energy_automation_guard_install_assertion_0726",
    "scripts.core.rocket_silo_live_ownership_guard_0728",
    "scripts.core.artillery_train_validity_guard_0724",
}
REQUIRED_ACTIVE = {
    "scripts.core.direct_acquisition_physical_guard_0649",
    "scripts.core.proxy_ammo_hardener_0649",
    "scripts.core.visual_intent_line_authority_0657",
    "scripts.core.storage_role_authority_0686",
    "scripts.core.inventory_transfer_integrity_0687",
    "scripts.core.item_family_logistics_0702",
    "scripts.core.energy_family_readiness_0705",
    "scripts.core.energy_family_logistics_0707",
    "scripts.core.rocket_silo_readiness_0709",
    "scripts.core.rocket_silo_logistics_0710",
    "scripts.core.artillery_readiness_0712",
    "scripts.core.artillery_logistics_0713",
    "scripts.core.roboport_readiness_0714",
    "scripts.core.roboport_repair_pack_logistics_0715",
    "scripts.core.fluid_turret_readiness_0716",
    "scripts.core.fluid_turret_connection_planner_0719",
    "scripts.core.development_integration_audit_0721",
    "scripts.core.runtime_command_cleanup_0720",
    "scripts.core.broker_registry_integrity_0725",
    "scripts.core.development_lifecycle_checkpoint_0733",
    "scripts.core.hardener_installation_audit_0723",
}
ORDER_GROUPS = {
    "energy": [
        "scripts.core.energy_family_readiness_0705",
        "scripts.core.energy_family_logistics_0707",
    ],
    "silo": [
        "scripts.core.rocket_silo_readiness_0709",
        "scripts.core.rocket_silo_logistics_0710",
    ],
    "artillery": [
        "scripts.core.artillery_readiness_0712",
        "scripts.core.artillery_logistics_0713",
    ],
    "roboport": [
        "scripts.core.roboport_readiness_0714",
        "scripts.core.roboport_repair_pack_logistics_0715",
    ],
    "fluid-turret": [
        "scripts.core.fluid_turret_readiness_0716",
        "scripts.core.fluid_turret_internal_buffer_guard_0731",
        "scripts.core.fluid_turret_connection_proposals_0717",
        "scripts.core.fluid_turret_proposal_integrity_0718",
        "scripts.core.fluid_turret_connection_planner_0719",
        "scripts.core.fluid_turret_planner_integrity_0730",
    ],
    "final-audit": [
        "scripts.core.development_integration_audit_0721",
        "scripts.core.runtime_command_cleanup_0720",
        "scripts.core.migration_pair_integrity_0734",
        "scripts.core.development_lifecycle_checkpoint_0733",
        "scripts.core.broker_registry_integrity_0725",
        "scripts.core.migration_lifecycle_assertion_0735",
        "scripts.core.hardener_installation_audit_0723",
    ],
}
CRITICAL_SERVICES = {
    "single_dispatcher_0510",
    "construction_discovery_0338",
    "machine_logistics_discovery_0528",
    "item_family_discovery_0702",
    "energy_family_readiness_0705",
    "energy_family_discovery_0707",
    "rocket_silo_readiness_0709",
    "rocket_silo_discovery_0710",
    "storage_role_authority_0686_sweep",
    "artillery_readiness_0712",
    "artillery_discovery_0713",
    "roboport_readiness_0714",
    "roboport_repair_pack_discovery_0715",
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
WORKFLOW_CHECKERS = {
    "check_development_integration_0732.py",
    "check_energy_family_boundary_0754.py",
    "check_rocket_silo_boundary_0755.py",
    "check_artillery_boundary_0756.py",
    "check_roboport_boundary_0757.py",
    "check_construction_boundary_0758.py",
}


def source_root(path: pathlib.Path) -> pathlib.Path:
    resolved = path.resolve()
    return resolved / SOURCE_DIR if (resolved / SOURCE_DIR).is_dir() else resolved


def module_path(mod_root: pathlib.Path, name: str) -> pathlib.Path:
    return mod_root / pathlib.Path(*name.split(".")).with_suffix(".lua")


def install_has_explicit_return(text: str) -> bool:
    start = INSTALL_RE.search(text)
    end = text.rfind("return M")
    return bool(start and end > start.end() and EXPLICIT_RETURN_RE.search(text[start.end() : end]))


def require(text: str, parts: tuple[str, ...], where: str, errors: list[str]) -> None:
    for part in parts:
        if part not in text:
            errors.append(f"{where} missing contract: {part}")


def forbid(text: str, parts: tuple[str, ...], where: str, errors: list[str]) -> None:
    for part in parts:
        if part in text:
            errors.append(f"{where} contains forbidden regression: {part}")


def check(project: pathlib.Path) -> int:
    errors: list[str] = []
    mod_root = source_root(project)
    planning_path = mod_root / PLANNING
    text = planning_path.read_text(encoding="utf-8", errors="replace")
    entries = [match.groupdict() for match in HARDENER_RE.finditer(text)]
    retired = {match.group("module"): match.group("reason") for match in RETIRED_RE.finditer(text)}
    active = [entry["module"] for entry in entries]
    labels = [entry["label"] for entry in entries]
    active_set = set(active)

    if len(active) != EXPECTED_ACTIVE_COUNT:
        errors.append(f"expected {EXPECTED_ACTIVE_COUNT} active hardeners, found {len(active)}")
    if set(retired) != EXPECTED_RETIRED:
        errors.append(
            "retired set mismatch "
            f"missing={sorted(EXPECTED_RETIRED - set(retired))} "
            f"unexpected={sorted(set(retired) - EXPECTED_RETIRED)}"
        )
    if Counter(active).most_common(1) and Counter(active).most_common(1)[0][1] > 1:
        errors.append("duplicate active hardener module")
    if Counter(labels).most_common(1) and Counter(labels).most_common(1)[0][1] > 1:
        errors.append("duplicate active hardener label")
    for name in sorted(REQUIRED_ACTIVE - active_set):
        errors.append(f"required active hardener missing: {name}")
    for name in sorted(active_set & set(retired)):
        errors.append(f"authority both active and retired: {name}")
    for name, reason in retired.items():
        if not reason.strip():
            errors.append(f"retired authority lacks reason: {name}")

    positions = {name: index for index, name in enumerate(active)}
    explicit = 0
    for name in active:
        path = module_path(mod_root, name)
        if not path.is_file():
            errors.append(f"active hardener file missing: {name}")
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        if not INSTALL_RE.search(source):
            errors.append(f"active hardener lacks M.install(): {name}")
        if install_has_explicit_return(source):
            explicit += 1
        else:
            errors.append(f"active hardener install lacks explicit return: {name}")
        if not re.search(r"\breturn\s+M\s*$", source.rstrip()):
            errors.append(f"active hardener does not end with return M: {name}")

    for group, names in ORDER_GROUPS.items():
        missing = [name for name in names if name not in positions]
        if missing:
            errors.append(f"{group} order missing: {', '.join(missing)}")
        elif [positions[name] for name in names] != sorted(positions[name] for name in names):
            errors.append(f"{group} install order incorrect")

    construction_path = mod_root / "scripts/core/construction_planner.lua"
    construction = construction_path.read_text(encoding="utf-8", errors="replace")
    require(
        construction,
        (
            "Sole physical construction owner",
            "dispatcher_owned=true",
            "discovery_only_broker=true",
            "function M.install()",
            "construction_discovery_0338",
            "return true end",
        ),
        str(construction_path.relative_to(mod_root)),
        errors,
    )
    forbid(
        construction,
        ("script.on_nth_tick", "TechPriestsRuntimeEventRegistry", "spill_item_stack"),
        str(construction_path.relative_to(mod_root)),
        errors,
    )

    arbiter_path = mod_root / "scripts/core/action_state_arbiter_0488.lua"
    arbiter = arbiter_path.read_text(encoding="utf-8", errors="replace")
    require(
        arbiter,
        ("local function construction_recommendation", "active_construction", "active-construction-custody"),
        str(arbiter_path.relative_to(mod_root)),
        errors,
    )
    dispatcher_path = mod_root / "scripts/core/single_dispatcher_0510.lua"
    dispatcher = dispatcher_path.read_text(encoding="utf-8", errors="replace")
    require(
        dispatcher,
        ("dispatcher_owns_construction", "TechPriestsConstructionPlanner0338", "canonical_action_0744"),
        str(dispatcher_path.relative_to(mod_root)),
        errors,
    )

    lifecycle_path = mod_root / LIFECYCLE
    lifecycle = lifecycle_path.read_text(encoding="utf-8", errors="replace")
    require(
        lifecycle,
        (
            "scripts.core.runtime_event_registry",
            "registry.on_init",
            "registry.on_configuration_changed",
            'name = "development_lifecycle_checkpoint_0733"',
            "source_revision",
        ),
        str(LIFECYCLE),
        errors,
    )
    forbid(
        lifecycle,
        ("script.on_init(", "script.on_configuration_changed(", "script.on_load("),
        str(LIFECYCLE),
        errors,
    )

    service_locations: dict[str, list[pathlib.Path]] = {}
    for path in sorted((mod_root / "scripts/core").glob("*.lua")):
        source = path.read_text(encoding="utf-8", errors="replace")
        for name in SERVICE_RE.findall(source):
            service_locations.setdefault(name, []).append(path)
    for name in sorted(CRITICAL_SERVICES):
        paths = service_locations.get(name, [])
        if len(paths) != 1:
            errors.append(f"critical service {name} has {len(paths)} literal registrations")

    workflow = project.resolve() / ".github/workflows/source-validation.yml"
    workflow_text = workflow.read_text(encoding="utf-8", errors="replace") if workflow.is_file() else ""
    for checker in sorted(WORKFLOW_CHECKERS):
        if checker not in workflow_text:
            errors.append(f"source-validation workflow does not run {checker}")

    print(
        "Development integration audit found "
        f"active={len(active)} retired={len(retired)} "
        f"explicit_returns={explicit} critical_services={len(CRITICAL_SERVICES)} "
        "base_authorities=construction"
    )
    if errors:
        print("Development integration source audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Development integration source audit passed.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    args = parser.parse_args(argv)
    try:
        return check(pathlib.Path(args.project_root))
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
