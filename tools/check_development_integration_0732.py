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
HARDENER_RE = re.compile(r'\{\s*module\s*=\s*"(?P<module>scripts\.core\.[^"]+)"\s*,\s*label\s*=\s*"(?P<label>[^"]+)"\s*\}')
RETIRED_RE = re.compile(r'\["(?P<module>scripts\.core\.[^"]+)"\]\s*=\s*"(?P<reason>[^"]+)"')
SERVICE_RE = re.compile(r'register_service\s*\(?\s*\{.{0,3000}?\bname\s*=\s*["\']([^"\']+)["\']', re.S)
INSTALL_RE = re.compile(r"\bfunction\s+M\.install\s*\(")
EXPLICIT_RETURN_RE = re.compile(r"\breturn\s+[^\s]")

EXPECTED_ACTIVE_COUNT = 26
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
    "scripts.core.movement_cadence_contract_0518",
    "scripts.core.combat_magos_movement_authority_0472",
    "scripts.core.movement_bounds_contract_0511",
    "scripts.core.movement_enforcement_0566",
    "scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577",
    "scripts.core.direct_acquisition_recall_guard_0632", "scripts.core.ground_route_authority_0633",
    "scripts.core.priest_vanish_guard_0502",
    "scripts.core.pair_link_hardening_0495",
    "scripts.core.priest_lifecycle_seal_0500",
    "scripts.core.priest_vanish_guard_0501",
    "scripts.core.mobility_recovery_contract_0506",
    "scripts.core.movement_recovery_authority_0508",
    "scripts.core.task_pair_audit_0498",
    "scripts.core.behavior_execution_doctrine_0505",
    "scripts.core.pair_death_and_respawn",
    "scripts.core.station_pair_recovery",
    "scripts.core.fluid_output_sink_doctrine_0694",
    "scripts.core.reservation_position_scope_0697",
    "scripts.core.fluid_connection_execution_guard_0692",
    "scripts.core.fluid_output_connection_planner_0696",
    "scripts.core.fluid_port_collision_validator_0699",
    "scripts.core.fluid_port_context_guard_0700",
    "scripts.core.item_family_integrity_0703",
    "scripts.core.fusion_reactor_readiness_guard_0727",
    "scripts.core.energy_readiness_diagnostics_0711",
    "scripts.core.energy_item_automation_guard_0722",
    "scripts.core.energy_automation_guard_install_assertion_0726",
    "scripts.core.rocket_silo_live_ownership_guard_0728",
    "scripts.core.artillery_train_validity_guard_0724",
    "scripts.core.fluid_turret_internal_buffer_guard_0731",
    "scripts.core.fluid_turret_proposal_integrity_0718",
    "scripts.core.fluid_turret_planner_integrity_0730",
}
REQUIRED_ACTIVE = {
    "scripts.core.direct_acquisition_physical_guard_0649",
    "scripts.core.proxy_ammo_hardener_0649",
    "scripts.core.visual_intent_line_authority_0657",
    "scripts.core.storage_role_authority_0686",
    "scripts.core.inventory_transfer_integrity_0687",
    "scripts.core.fluid_network_doctrine_0689",
    "scripts.core.fluid_connection_planner_0691",
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
    "scripts.core.fluid_turret_connection_proposals_0717",
    "scripts.core.fluid_turret_connection_planner_0719",
    "scripts.core.development_integration_audit_0721",
    "scripts.core.runtime_command_cleanup_0720",
    "scripts.core.migration_pair_integrity_0734",
    "scripts.core.development_lifecycle_checkpoint_0733",
    "scripts.core.broker_registry_integrity_0725",
    "scripts.core.migration_lifecycle_assertion_0735",
    "scripts.core.hardener_installation_audit_0723",
}
ORDER_GROUPS = {
    "standard-fluid": ["scripts.core.fluid_network_doctrine_0689", "scripts.core.fluid_connection_planner_0691"],
    "energy": ["scripts.core.energy_family_readiness_0705", "scripts.core.energy_family_logistics_0707"],
    "silo": ["scripts.core.rocket_silo_readiness_0709", "scripts.core.rocket_silo_logistics_0710"],
    "artillery": ["scripts.core.artillery_readiness_0712", "scripts.core.artillery_logistics_0713"],
    "roboport": ["scripts.core.roboport_readiness_0714", "scripts.core.roboport_repair_pack_logistics_0715"],
    "fluid-turret": ["scripts.core.fluid_turret_readiness_0716", "scripts.core.fluid_turret_connection_proposals_0717", "scripts.core.fluid_turret_connection_planner_0719"],
    "final-audit": ["scripts.core.development_integration_audit_0721", "scripts.core.runtime_command_cleanup_0720", "scripts.core.migration_pair_integrity_0734", "scripts.core.development_lifecycle_checkpoint_0733", "scripts.core.broker_registry_integrity_0725", "scripts.core.migration_lifecycle_assertion_0735", "scripts.core.hardener_installation_audit_0723"],
}
CRITICAL_SERVICES = {
    "single_dispatcher_0510", "construction_discovery_0338", "machine_logistics_discovery_0528",
    "item_family_discovery_0702", "energy_family_readiness_0705", "energy_family_discovery_0707",
    "rocket_silo_readiness_0709", "rocket_silo_discovery_0710", "storage_role_authority_0686_sweep",
    "artillery_readiness_0712", "artillery_discovery_0713", "roboport_readiness_0714",
    "roboport_repair_pack_discovery_0715", "fluid_network_doctrine_0689",
    "standard_fluid_route_discovery_0691", "fluid_turret_readiness_0716",
    "fluid_turret_connection_proposals_0717", "fluid_turret_route_discovery_0719",
    "runtime_command_cleanup_0720", "development_integration_audit_0721",
    "hardener_installation_audit_0723", "broker_registry_integrity_0725",
    "development_lifecycle_checkpoint_0733", "combat_proxy_sustain_0472",
    "proxy_turret_alignment_0555", "command_hierarchy_rebuild_0480",
    "movement_controller_enforcement_0566", "void_movement_authority_0630",
    "behavior_stack_cleanup_0509", "priest_lifecycle_observation_0499", "priest_missing_recovery_0503",
}
WORKFLOW_CHECKERS = {
    "check_development_integration_0732.py", "check_energy_family_boundary_0754.py",
    "check_rocket_silo_boundary_0755.py", "check_artillery_boundary_0756.py",
    "check_roboport_boundary_0757.py", "check_construction_boundary_0758.py",
    "check_fluid_turret_boundary_0759.py", "check_standard_fluid_boundary_0760.py",
    "check_movement_cadence_boundary_0761.py", "check_combat_proxy_boundary_0762.py",
    "check_combat_command_boundary_0763.py", "check_direct_acquisition_bounds_boundary_0764.py",
    "check_movement_enforcement_void_boundary_0765.py", "check_corridor_route_planner_boundary_0766.py", "check_movement_economy_boundary_0767.py", "check_ground_route_loader_boundary_0768.py", "check_priest_vanish_0502_boundary_0769.py", "check_pair_link_0495_boundary_0770.py", "check_lifecycle_seal_0500_boundary_0771.py", "check_vanish_guard_0501_boundary_0772.py", "check_mobility_recovery_0506_0508_boundary_0773.py", "check_priest_recovery_0503_boundary_0774.py", "check_task_pair_0498_boundary_0775.py", "check_behavior_execution_0505_boundary_0776.py",
"check_pair_death_reimprint_0426_boundary_0777.py",
"check_station_pair_recovery_0363_boundary_0778.py",
"check_generated_equipment_lifecycle_hooks_0779.py",
"check_generated_glow_research_commands_0780.py",
"check_generated_glow_ownership_0781.py",
"check_generated_gui_damage_commands_0782.py",
"check_generated_gui_ownership_0783.py",
"check_generated_mining_beam_ownership_0784.py",
"check_combat_safety_predicate_ownership_0785.py",
"check_cached_target_ownership_0786.py",
"check_idle_availability_ownership_0787.py",
"check_priority_command_retirement_0788.py",
"check_0250_command_retirement_0789.py",
"check_legacy_observability_commands_0790.py",
}
RETIRED_FORBIDDEN = (
    "function M.install", "register_service", "script.on_nth_tick", "build.service_pair",
    "build.install", "previous_build_service_pair", "previous_build_install",
    "tech_priests_request_movement_0418", "surface.create_entity", "inventory.remove", "inventory.insert",
)


def source_root(path: pathlib.Path) -> pathlib.Path:
    resolved = path.resolve()
    return resolved / SOURCE_DIR if (resolved / SOURCE_DIR).is_dir() else resolved


def module_path(mod_root: pathlib.Path, name: str) -> pathlib.Path:
    return mod_root / pathlib.Path(*name.split(".")).with_suffix(".lua")


def install_has_explicit_return(text: str) -> bool:
    start = INSTALL_RE.search(text)
    end = text.rfind("return M")
    return bool(start and end > start.end() and EXPLICIT_RETURN_RE.search(text[start.end():end]))


def require(text: str, fragments: tuple[str, ...], where: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{where} missing contract: {fragment}")


def forbid(text: str, fragments: tuple[str, ...], where: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment in text:
            errors.append(f"{where} contains forbidden regression: {fragment}")


def check(project: pathlib.Path) -> int:
    errors: list[str] = []
    mod_root = source_root(project)
    planning_path = mod_root / PLANNING
    planning = planning_path.read_text(encoding="utf-8", errors="replace")
    entries = [match.groupdict() for match in HARDENER_RE.finditer(planning)]
    retired = {match.group("module"): match.group("reason") for match in RETIRED_RE.finditer(planning)}
    active = [entry["module"] for entry in entries]
    labels = [entry["label"] for entry in entries]
    active_set = set(active)

    if len(active) != EXPECTED_ACTIVE_COUNT:
        errors.append(f"expected {EXPECTED_ACTIVE_COUNT} active hardeners, found {len(active)}")
    if set(retired) != EXPECTED_RETIRED:
        errors.append(f"retired set mismatch missing={sorted(EXPECTED_RETIRED-set(retired))} unexpected={sorted(set(retired)-EXPECTED_RETIRED)}")
    if Counter(active).most_common(1) and Counter(active).most_common(1)[0][1] > 1:
        errors.append("duplicate active hardener module")
    if Counter(labels).most_common(1) and Counter(labels).most_common(1)[0][1] > 1:
        errors.append("duplicate active hardener label")
    for name in sorted(REQUIRED_ACTIVE - active_set):
        errors.append(f"required active hardener missing: {name}")
    for name in sorted(active_set & set(retired)):
        errors.append(f"authority both active and retired: {name}")
    require(planning, ("active_hardener_count=26", "retired_authority_count=47", 'fluid={"scripts.core.fluid_network_doctrine_0689","scripts.core.fluid_connection_planner_0691"}', "runtime_tick_broker_0600:central-pulse", "install must return literal true"), str(planning_path.relative_to(mod_root)), errors)

    positions = {name: index for index, name in enumerate(active)}
    for name in active:
        path = module_path(mod_root, name)
        if not path.is_file():
            errors.append(f"active hardener file missing: {name}")
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        if not INSTALL_RE.search(source):
            errors.append(f"active hardener lacks M.install(): {name}")
        elif not install_has_explicit_return(source):
            errors.append(f"active hardener install lacks explicit return: {name}")
        if not re.search(r"\breturn\s+M\s*$", source.rstrip()):
            errors.append(f"active hardener does not end with return M: {name}")

    for name in sorted(retired):
        path = module_path(mod_root, name)
        if not path.is_file():
            errors.append(f"retired authority file missing: {name}")
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        for fragment in RETIRED_FORBIDDEN:
            if fragment in source:
                errors.append(f"retired authority retains runtime ownership: {name}: {fragment}")

    for group, names in ORDER_GROUPS.items():
        missing = [name for name in names if name not in positions]
        if missing:
            errors.append(f"{group} order missing: {', '.join(missing)}")
        elif [positions[name] for name in names] != sorted(positions[name] for name in names):
            errors.append(f"{group} install order incorrect")

    construction_path = mod_root / "scripts/core/construction_planner.lua"
    construction = construction_path.read_text(encoding="utf-8", errors="replace")
    require(construction, ("Sole physical construction owner", "dispatcher_owned=true", "discovery_only_broker=true", "construction_last_task_0338", "construction_discovery_0338"), str(construction_path.relative_to(mod_root)), errors)
    forbid(construction, ("script.on_nth_tick", "TechPriestsRuntimeEventRegistry", "spill_item_stack"), str(construction_path.relative_to(mod_root)), errors)

    doctrine_path = mod_root / "scripts/core/fluid_network_doctrine_0689.lua"
    doctrine = doctrine_path.read_text(encoding="utf-8", errors="replace")
    require(doctrine, ("canonical standard-fluid doctrine", "read_only=true", "input_output_proposals_integrated=true", "port_collision_integrated=true", "context_guard_integrated=true", "function M.validate_proposal", "function M.scan_pair", 'name="fluid_network_doctrine_0689"', "acted=0"), str(doctrine_path.relative_to(mod_root)), errors)
    forbid(doctrine, ("previous_machine_service", "previous_inspect_machine", "machine.service_pair", "build.service_pair", "tech_priests_request_movement_0418", "surface.create_entity"), str(doctrine_path.relative_to(mod_root)), errors)

    route_path = mod_root / "scripts/core/fluid_connection_planner_0691.lua"
    route = route_path.read_text(encoding="utf-8", errors="replace")
    require(route, ("standard-fluid route coordinator", "wrapper_free=true", "input_output_integrated=true", "construction_handoff=true", 'source="standard-fluid-route-0691"', "pair.construction_last_task_0338", 'name="standard_fluid_route_discovery_0691"', "acted=0"), str(route_path.relative_to(mod_root)), errors)
    forbid(route, ("previous_build_service_pair", "previous_build_install", "build.service_pair", "build.install", "tech_priests_request_movement_0418", "surface.create_entity", "inventory.remove", "inventory.insert", "pair.construction_task_0338=nil"), str(route_path.relative_to(mod_root)), errors)

    turret_path = mod_root / "scripts/core/fluid_turret_connection_planner_0719.lua"
    turret = turret_path.read_text(encoding="utf-8", errors="replace")
    require(turret, ("wrapper_free=true", "construction_handoff=true", 'source="fluid-turret-route-0719"', "pair.construction_last_task_0338", "fluid_turret_route_discovery_0719"), str(turret_path.relative_to(mod_root)), errors)
    forbid(turret, ("previous_build_service_pair", "build.service_pair =", "build.install =", "tech_priests_request_movement_0418", "surface.create_entity"), str(turret_path.relative_to(mod_root)), errors)

    lifecycle_path = mod_root / LIFECYCLE
    lifecycle = lifecycle_path.read_text(encoding="utf-8", errors="replace")
    require(lifecycle, ("scripts.core.runtime_event_registry", "registry.on_init", "registry.on_configuration_changed", 'name = "development_lifecycle_checkpoint_0733"', "source_revision"), str(LIFECYCLE), errors)
    forbid(lifecycle, ("script.on_init(", "script.on_configuration_changed(", "script.on_load("), str(LIFECYCLE), errors)

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
            errors.append(f"source-validation workflow missing checker: {checker}")

    print(f"Development integration observations: active={len(active)} retired={len(retired)} explicit_installs={len(active)}")
    if errors:
        print("Development integration audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Development integration audit passed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", nargs="?", default=".")
    args = parser.parse_args()
    return check(pathlib.Path(args.project))


if __name__ == "__main__":
    raise SystemExit(main())
