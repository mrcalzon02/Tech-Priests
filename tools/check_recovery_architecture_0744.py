#!/usr/bin/env python3
"""Audit the protected recovery graph and canonical runtime authority boundaries."""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CORE = ROOT / "tech-priests_src/scripts/core"
HARDENER_RE = re.compile(r'\{\s*module\s*=\s*"(scripts\.core\.[^"]+)"\s*,\s*label\s*=\s*"([^"]+)"\s*\}')
RETIRED_RE = re.compile(r'\["(scripts\.core\.[^"]+)"\]\s*=\s*"([^"]+)"')
EXPECTED_RETIRED = {
    "scripts.core.direct_acquisition_movement_lock_0650", "scripts.core.movement_vector_enforcer_0651",
    "scripts.core.movement_target_reconciler_0652", "scripts.core.movement_intent_authority_0654",
    "scripts.core.active_leaf_task_truth_0655", "scripts.core.construction_placement_authority_0656",
    "scripts.core.logistics_mineable_source_bridge_0657", "scripts.core.repair_executor_integrity_0673",
    "scripts.core.combat_repair_integrity_0676", "scripts.core.combat_repair_terminal_cleanup_0677",
    "scripts.core.machine_logistics_integrity_0682", "scripts.core.machine_logistics_candidate_recovery_0683",
    "scripts.core.machine_logistics_final_authority_0684", "scripts.core.movement_cadence_contract_0518", "scripts.core.combat_magos_movement_authority_0472", "scripts.core.movement_bounds_contract_0511", "scripts.core.movement_enforcement_0566", "scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577", "scripts.core.direct_acquisition_recall_guard_0632", "scripts.core.ground_route_authority_0633", "scripts.core.priest_vanish_guard_0502", "scripts.core.pair_link_hardening_0495", "scripts.core.priest_lifecycle_seal_0500", "scripts.core.priest_vanish_guard_0501", "scripts.core.mobility_recovery_contract_0506", "scripts.core.movement_recovery_authority_0508", "scripts.core.task_pair_audit_0498", "scripts.core.behavior_execution_doctrine_0505", "scripts.core.fluid_output_sink_doctrine_0694",
    "scripts.core.reservation_position_scope_0697", "scripts.core.fluid_connection_execution_guard_0692",
    "scripts.core.fluid_output_connection_planner_0696", "scripts.core.fluid_port_collision_validator_0699",
    "scripts.core.fluid_port_context_guard_0700", "scripts.core.item_family_integrity_0703",
    "scripts.core.fusion_reactor_readiness_guard_0727", "scripts.core.energy_readiness_diagnostics_0711",
    "scripts.core.energy_item_automation_guard_0722", "scripts.core.energy_automation_guard_install_assertion_0726",
    "scripts.core.rocket_silo_live_ownership_guard_0728", "scripts.core.artillery_train_validity_guard_0724",
    "scripts.core.fluid_turret_internal_buffer_guard_0731", "scripts.core.fluid_turret_proposal_integrity_0718",
    "scripts.core.fluid_turret_planner_integrity_0730",
    "scripts.core.pair_death_and_respawn",
    "scripts.core.station_pair_recovery",
}
FILES = {
    "planning": CORE / "planning_constraints_0646.lua",
    "registry": CORE / "runtime_event_registry.lua",
    "broker": CORE / "runtime_tick_broker.lua",
    "arbiter": CORE / "action_state_arbiter_0488.lua",
    "dispatcher": CORE / "single_dispatcher_0510.lua",
    "construction_site": CORE / "construction_site_planner.lua",
    "construction": CORE / "construction_planner.lua",
    "reservations": CORE / "work_reservations.lua",
    "fluid_doctrine": CORE / "fluid_network_doctrine_0689.lua",
    "fluid_route": CORE / "fluid_connection_planner_0691.lua",
    "machine": CORE / "logistics_machine_fulfillment_0528.lua",
    "item": CORE / "item_family_logistics_0702.lua",
    "energy_readiness": CORE / "energy_family_readiness_0705.lua",
    "energy_logistics": CORE / "energy_family_logistics_0707.lua",
    "silo_readiness": CORE / "rocket_silo_readiness_0709.lua",
    "silo_logistics": CORE / "rocket_silo_logistics_0710.lua",
    "artillery_readiness": CORE / "artillery_readiness_0712.lua",
    "artillery_logistics": CORE / "artillery_logistics_0713.lua",
    "roboport_readiness": CORE / "roboport_readiness_0714.lua",
    "roboport_logistics": CORE / "roboport_repair_pack_logistics_0715.lua",
    "fluid_turret_readiness": CORE / "fluid_turret_readiness_0716.lua",
    "fluid_turret_proposals": CORE / "fluid_turret_connection_proposals_0717.lua",
    "fluid_turret_route": CORE / "fluid_turret_connection_planner_0719.lua",
    "storage": CORE / "storage_role_authority_0686.lua",
    "transfer": CORE / "inventory_transfer_integrity_0687.lua",
    "repair": CORE / "repair_executor_0516.lua",
    "combat": CORE / "combat_repair_doctrine_0517.lua",
    "proxy": CORE / "proxy_ammo_hardener_0649.lua",
    "visual": CORE / "visual_intent_line_authority_0657.lua",
    "map": ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md",
    "continuity": ROOT / "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md",
    "history": ROOT / "docs/DEVELOPMENT_HISTORY.md",
    "testing": ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
    "manifest": ROOT / "dist/release-manifest-0.1.674-rc.3.json",
}


def need(name: str, text: str, fragments: tuple[str, ...], errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")


def ban(name: str, text: str, fragments: tuple[str, ...], errors: list[str]) -> None:
    for fragment in fragments:
        if fragment in text:
            errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}")


def main() -> int:
    errors: list[str] = []
    texts: dict[str, str] = {}
    for name, path in FILES.items():
        if not path.is_file():
            errors.append(f"missing required file: {path.relative_to(ROOT)}")
            texts[name] = ""
        else:
            texts[name] = path.read_text(encoding="utf-8", errors="replace")

    active = [match.group(1) for match in HARDENER_RE.finditer(texts["planning"])]
    retired = {match.group(1): match.group(2) for match in RETIRED_RE.finditer(texts["planning"])}
    if len(active) != 26:
        errors.append(f"expected 26 active hardeners, found {len(active)}")
    if len(active) != len(set(active)):
        errors.append("duplicate active hardener")
    if set(retired) != EXPECTED_RETIRED:
        errors.append(f"retired mismatch missing={sorted(EXPECTED_RETIRED-set(retired))} unexpected={sorted(set(retired)-EXPECTED_RETIRED)}")
    if set(active) & set(retired):
        errors.append("authority is both active and retired")

    need("planning", texts["planning"], (
        "active_hardener_count=26", "retired_authority_count=47",
        "runtime_tick_broker_0600:central-pulse", "install must return literal true",
        "function M.defense_position_allowed", 'construction={"scripts.core.construction_planner"}',
        'fluid={"scripts.core.fluid_network_doctrine_0689","scripts.core.fluid_connection_planner_0691"}',
    ), errors)
    for module in EXPECTED_RETIRED:
        ban("planning", texts["planning"], (f'{{module="{module}"',), errors)

    need("registry", texts["registry"], ("Registry.on_event", "Registry.on_nth_tick", "Registry.on_init", "Registry.on_configuration_changed", "isolated handler failure"), errors)
    need("broker", texts["broker"], ("function M.normalize_result", "function M.installation_summary", "runtime_tick_broker_0600:central-pulse", "isolated service failure"), errors)
    ban("broker", texts["broker"], ("script.on_nth_tick", "direct-fallback"), errors)

    need("arbiter", texts["arbiter"], (
        "Pure action classifier", "local function construction_recommendation",
        "local function machine_logistics_recommendation", "local function item_family_recommendation",
        "local function energy_family_recommendation", "local function rocket_silo_recommendation",
        "local function artillery_recommendation", "local function roboport_recommendation",
        "active_construction", "active_artillery", "active_roboport", "function M.tick_all() return 0 end",
    ), errors)
    ban("arbiter", texts["arbiter"], ("tech_priests_request_movement_0418", "register_service", "pair.mode =", "pair.target ="), errors)

    need("dispatcher", texts["dispatcher"], (
        "canonical_action_0744", "dispatcher_owns_construction", "dispatcher_owns_machine_logistics",
        "dispatcher_owns_item_family_logistics", "dispatcher_owns_energy_family_logistics",
        "dispatcher_owns_rocket_silo_logistics", "dispatcher_owns_artillery_logistics",
        "dispatcher_owns_roboport_repair_pack_logistics", "TechPriestsConstructionPlanner0338",
        "TechPriestsArtilleryLogistics0713", "TechPriestsRoboportRepairPackLogistics0715", "function M.service_all",
    ), errors)
    ban("dispatcher", texts["dispatcher"], ("construction_discovery_0338", "standard_fluid_route_discovery_0691", "fluid_turret_route_discovery_0719", "TechPriestsRuntimeEventRegistry", "script.on_nth_tick"), errors)

    need("construction_site", texts["construction_site"], ("Canonical read-only placement authority", "placement_authority = true", "read_only = true", "effectiveness_scoring = true", "function Planner.plan_defense_site", "function Planner.placement_effectiveness_report", "defense-roboport"), errors)
    ban("construction_site", texts["construction_site"], ("tech_priests_request_movement_0418", "register_service", "inventory.remove", "inventory.insert", "create_entity"), errors)
    need("construction", texts["construction"], ("Sole physical construction owner", "dispatcher_owned=true", "discovery_only_broker=true", "construction_candidate_0338", "construction_custody_0338", "construction_last_task_0338", "function M.service_pair", "function M.abort_pair", 'name="construction_discovery_0338"'), errors)
    ban("construction", texts["construction"], ("active_leaf_task_0655", "pair.target=", "pair.mode=", "script.on_nth_tick", "TechPriestsRuntimeEventRegistry", "spill_item_stack", "result ~= false", "accepted ~= false"), errors)

    need("reservations", texts["reservations"], ('version="0.1.674-dev"', "position_scope_integrated=true", "function M.target_key(target,meta)", "surface_scoped_position_claims"), errors)
    ban("reservations", texts["reservations"], ("previous_target_key", "previous_claim"), errors)

    need("fluid_doctrine", texts["fluid_doctrine"], (
        "canonical standard-fluid doctrine", "read_only=true", "input_output_proposals_integrated=true",
        "port_collision_integrated=true", "context_guard_integrated=true", "fluid_item_policy_integrated=true",
        "structured_scan_truth=true", "function M.validate_endpoint", "function M.validate_proposal",
        "function M.inspect_machine", "function M.scan_pair", 'name="fluid_network_doctrine_0689"', "acted=0",
    ), errors)
    ban("fluid_doctrine", texts["fluid_doctrine"], ("previous_machine_service", "previous_inspect_machine", "machine.service_pair", "build.service_pair", "tech_priests_request_movement_0418", "surface.create_entity", "inventory.remove", "inventory.insert", "script.on_nth_tick"), errors)

    need("fluid_route", texts["fluid_route"], (
        "standard-fluid route coordinator", "wrapper_free=true", "input_output_integrated=true",
        "construction_handoff=true", 'r.claim("standard-fluid-pipe-route"',
        'pair.construction_request={item_name=M.pipe_item', 'source="standard-fluid-route-0691"',
        "pair.construction_last_task_0338", 'name="standard_fluid_route_discovery_0691"', "acted=0",
    ), errors)
    ban("fluid_route", texts["fluid_route"], ("previous_build_service_pair", "previous_build_install", "build.service_pair", "build.install", "tech_priests_request_movement_0418", "script.on_nth_tick", "inventory.remove", "inventory.insert", "surface.create_entity", "pair.construction_task_0338=nil"), errors)

    need("machine", texts["machine"], ("machine_logistics_candidate_0528", "machine_logistics_custody_0528", "function M.recommend_action", "function M.service_pair", "machine_logistics_discovery_0528"), errors)
    need("item", texts["item"], ("dispatcher_owned = true", "discovery_only_broker = true", "proxy_ammo_excluded = true", "item_family_custody_0702"), errors)
    need("energy_readiness", texts["energy_readiness"], ("read_only = true", "fusion_heat_semantics_integrated = true", 'name="energy_family_readiness_0705"', "acted=0"), errors)
    need("energy_logistics", texts["energy_logistics"], ("dispatcher_owned=true", "discovery_only_broker=true", "energy_family_custody_0707", 'name="energy_family_discovery_0707"'), errors)
    need("silo_readiness", texts["silo_readiness"], ("read_only = true", "live_ownership_integrated = true", 'name="rocket_silo_readiness_0709"', "acted=0"), errors)
    need("silo_logistics", texts["silo_logistics"], ("dispatcher_owned=true", "discovery_only_broker=true", "rocket_silo_custody_0710", 'name="rocket_silo_discovery_0710"'), errors)
    need("artillery_readiness", texts["artillery_readiness"], ("read_only = true", "train_validity_integrated = true", 'name="artillery_readiness_0712"', "acted=0"), errors)
    need("artillery_logistics", texts["artillery_logistics"], ("dispatcher_owned=true", "discovery_only_broker=true", "artillery_custody_0713", 'name="artillery_discovery_0713"'), errors)
    need("roboport_readiness", texts["roboport_readiness"], ("read_only=true", "placement_authority=false", "robot_population_monitor_only=true", 'name="roboport_readiness_0714"', "acted=0"), errors)
    need("roboport_logistics", texts["roboport_logistics"], ("dispatcher_owned=true", "discovery_only_broker=true", "robot_inventory_excluded=true", "roboport_repair_custody_0715", 'name="roboport_repair_pack_discovery_0715"'), errors)

    need("fluid_turret_readiness", texts["fluid_turret_readiness"], ("Canonical read-only inspection", "read_only=true", "internal_buffer_correction_integrated=true", 'name="fluid_turret_readiness_0716"', "acted=0"), errors)
    need("fluid_turret_proposals", texts["fluid_turret_proposals"], ("Canonical source selection and exact endpoint validation", "read_only=true", "proposal_integrity_integrated=true", 'name="fluid_turret_connection_proposals_0717"', "acted=0"), errors)
    need("fluid_turret_route", texts["fluid_turret_route"], ("construction_planner remains the sole movement, item-custody, and placement owner", "construction_handoff=true", "wrapper_free=true", 'source="fluid-turret-route-0719"', "pair.construction_last_task_0338", 'name="fluid_turret_route_discovery_0719"', "acted=0"), errors)
    ban("fluid_turret_route", texts["fluid_turret_route"], ("previous_build_service_pair", "build.service_pair =", "build.install =", "tech_priests_request_movement_0418", "surface.create_entity"), errors)

    need("storage", texts["storage"], ("generic_container_only = true", "function M.deposit_exact", "function M.remove_generic_item"), errors)
    ban("storage", texts["storage"], ("assembling_machine_input", "assembling_machine_output", "furnace_source", "furnace_result", "lab_input", "spill_item_stack"), errors)
    need("transfer", texts["transfer"], ("inventory_transfer_custody_0687", "function M.service_custody"), errors)
    need("repair", texts["repair"], ("repair_pack_custody_0516", "function M.abort_pair"), errors)
    ban("repair", texts["repair"], ("script.on_nth_tick", "register_service", "spill_item_stack", "q.current=nil"), errors)
    need("combat", texts["combat"], ("Dispatcher-owned tactical selector", "function M.recommend_action"), errors)
    need("proxy", texts["proxy"], ("proxy_ammo_refund_custody_0649", "atomic_return"), errors)
    need("visual", texts["visual"], ("canonical_action_0744", "canonical-intent-line-0657"), errors)

    need("map", texts["map"], ("26 declarative active hardeners", "Forty-seven files remain", "standard_fluid_route_discovery_0691", "fluid_turret_route_discovery_0719", "## Stage 5 — Evidence and Release Boundary"), errors)
    need("continuity", texts["continuity"], ("26 retained hardeners", "47 source-preserved authorities", "## Standard-fluid authority", "## Fluid-turret authority"), errors)
    need("history", texts["history"], ("26 active hardeners and 47 explicitly retired", "Consolidated standard-fluid authority", "No accepted Factorio runtime logs have yet been recorded"), errors)
    need("testing", texts["testing"], ("standard fluid route", "### Fluid turret route", "Stage 5 objective validation"), errors)

    for title, checker in (
        ("Audit generic storage boundary", "check_generic_storage_boundary_0750.py"),
        ("Audit machine logistics boundary", "check_machine_logistics_boundary_0751.py"),
        ("Audit priest cargo transfer boundary", "check_inventory_transfer_boundary_0752.py"),
        ("Audit item family logistics boundary", "check_item_family_logistics_boundary_0753.py"),
        ("Audit energy family boundary", "check_energy_family_boundary_0754.py"),
        ("Audit rocket silo boundary", "check_rocket_silo_boundary_0755.py"),
        ("Audit artillery boundary", "check_artillery_boundary_0756.py"),
        ("Audit roboport boundary", "check_roboport_boundary_0757.py"),
        ("Audit construction placement and execution boundary", "check_construction_boundary_0758.py"),
        ("Audit consolidated fluid turret boundary", "check_fluid_turret_boundary_0759.py"),
        ("Audit consolidated standard fluid boundary", "check_standard_fluid_boundary_0760.py"),
        ("Audit consolidated movement cadence boundary", "check_movement_cadence_boundary_0761.py"),
        ("Audit consolidated combat proxy ownership", "check_combat_proxy_boundary_0762.py"),
        ("Audit canonical combat command safety boundary", "check_combat_command_boundary_0763.py"),
        ("Audit canonical direct acquisition bounds", "check_direct_acquisition_bounds_boundary_0764.py"),
        ("Audit canonical movement enforcement and void backend", "check_movement_enforcement_void_boundary_0765.py"),
        ("Audit observer-only corridor route planner", "check_corridor_route_planner_boundary_0766.py"),
        ("Audit retired movement economy wrappers", "check_movement_economy_boundary_0767.py"),
        ("Audit retired ground route and explicit child loaders", "check_ground_route_loader_boundary_0768.py"),
        ("Audit retired 0502 vanish quarantine", "check_priest_vanish_0502_boundary_0769.py"),
        ("Audit retired 0426 reimprint lifecycle wrapper", "check_pair_death_reimprint_0426_boundary_0777.py"),
        ("Audit development integration graph", "check_development_integration_0732.py"),
    ):
        if title not in texts["workflow"] or checker not in texts["workflow"]:
            errors.append(f"workflow missing {title}: {checker}")

    try:
        manifest = json.loads(texts["manifest"] or "{}")
    except json.JSONDecodeError as exc:
        errors.append(f"experimental manifest invalid JSON: {exc}")
        manifest = {}
    if manifest.get("runtime_validation_complete") is not False:
        errors.append("experimental manifest must remain runtime_validation_complete=false")
    if manifest.get("prerelease") is not True:
        errors.append("experimental manifest must remain prerelease=true")

    print("Recovery architecture observations: active=26 retired=46 construction=canonical standard_fluid=consolidated fluid_turret=consolidated")
    if errors:
        print("Recovery architecture audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Recovery architecture source audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
