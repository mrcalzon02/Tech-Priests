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
    "scripts.core.fluid_turret_internal_buffer_guard_0731",
    "scripts.core.fluid_turret_proposal_integrity_0718",
    "scripts.core.fluid_turret_planner_integrity_0730",
}
FILES = {
    "planning": CORE / "planning_constraints_0646.lua",
    "registry": CORE / "runtime_event_registry.lua",
    "broker": CORE / "runtime_tick_broker.lua",
    "arbiter": CORE / "action_state_arbiter_0488.lua",
    "dispatcher": CORE / "single_dispatcher_0510.lua",
    "construction_site": CORE / "construction_site_planner.lua",
    "construction": CORE / "construction_planner.lua",
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


def need(name: str, text: str, parts: tuple[str, ...], errors: list[str]) -> None:
    for part in parts:
        if part not in text:
            errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {part}")


def ban(name: str, text: str, parts: tuple[str, ...], errors: list[str]) -> None:
    for part in parts:
        if part in text:
            errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}")


def main() -> int:
    errors: list[str] = []
    texts: dict[str, str] = {}
    for name, path in FILES.items():
        if not path.is_file():
            errors.append(f"missing required file: {path.relative_to(ROOT)}")
            texts[name] = ""
        else:
            texts[name] = path.read_text(encoding="utf-8", errors="replace")

    active = [m.group(1) for m in HARDENER_RE.finditer(texts["planning"])]
    retired = {m.group(1): m.group(2) for m in RETIRED_RE.finditer(texts["planning"])}
    if len(active) != 32:
        errors.append(f"expected 32 active hardeners, found {len(active)}")
    if len(active) != len(set(active)):
        errors.append("duplicate active hardener")
    if set(retired) != EXPECTED_RETIRED:
        errors.append(
            f"retired mismatch missing={sorted(EXPECTED_RETIRED-set(retired))} "
            f"unexpected={sorted(set(retired)-EXPECTED_RETIRED)}"
        )
    if set(active) & set(retired):
        errors.append("authority is both active and retired")

    need("planning", texts["planning"], (
        "active_hardener_count=32", "retired_authority_count=23",
        "runtime_tick_broker_0600:central-pulse", "install must return literal true",
        "function M.defense_position_allowed", 'construction={"scripts.core.construction_planner"}',
    ), errors)
    for retired_module in (
        "scripts.core.construction_placement_authority_0656",
        "scripts.core.fluid_turret_internal_buffer_guard_0731",
        "scripts.core.fluid_turret_proposal_integrity_0718",
        "scripts.core.fluid_turret_planner_integrity_0730",
    ):
        ban("planning", texts["planning"], (f'{{module="{retired_module}"',), errors)

    need("registry", texts["registry"], ("Registry.on_event", "Registry.on_nth_tick", "Registry.on_init", "Registry.on_configuration_changed", "isolated handler failure"), errors)
    need("broker", texts["broker"], ("function M.normalize_result", "function M.installation_summary", "runtime_tick_broker_0600:central-pulse", "isolated service failure"), errors)
    ban("broker", texts["broker"], ("script.on_nth_tick", "direct-fallback"), errors)

    need("arbiter", texts["arbiter"], (
        "Pure action classifier", "local function construction_recommendation",
        "local function machine_logistics_recommendation", "local function item_family_recommendation",
        "local function energy_family_recommendation", "local function rocket_silo_recommendation",
        "local function artillery_recommendation", "local function roboport_recommendation",
        "active_construction", "active_artillery", "active_roboport",
        "function M.tick_all() return 0 end",
    ), errors)
    ban("arbiter", texts["arbiter"], (
        "tech_priests_request_movement_0418", "register_service", "pair.mode =", "pair.target =",
        'pcall(require,"scripts.core.construction_planner")',
        'pcall(require,"scripts.core.artillery_logistics_0713")',
        'pcall(require,"scripts.core.roboport_repair_pack_logistics_0715")',
    ), errors)

    need("dispatcher", texts["dispatcher"], (
        "canonical_action_0744", "dispatcher_owns_construction",
        "dispatcher_owns_machine_logistics", "dispatcher_owns_item_family_logistics",
        "dispatcher_owns_energy_family_logistics", "dispatcher_owns_rocket_silo_logistics",
        "dispatcher_owns_artillery_logistics", "dispatcher_owns_roboport_repair_pack_logistics",
        "TechPriestsConstructionPlanner0338", "TechPriestsArtilleryLogistics0713",
        "TechPriestsRoboportRepairPackLogistics0715", "function M.service_all",
    ), errors)
    ban("dispatcher", texts["dispatcher"], (
        "construction_discovery_0338", "energy_family_discovery_0707",
        "item_family_discovery_0702", "rocket_silo_discovery_0710",
        "artillery_discovery_0713", "roboport_repair_pack_discovery_0715",
        "fluid_turret_route_discovery_0719", "TechPriestsRuntimeEventRegistry", "script.on_nth_tick",
    ), errors)

    need("construction_site", texts["construction_site"], (
        "Canonical read-only placement authority", "placement_authority = true",
        "read_only = true", "effectiveness_scoring = true",
        "function Planner.plan_defense_site", "function Planner.placement_effectiveness_report",
        "defense-roboport", "threat_alignment_score", "support_penalty", "spacing_penalty",
    ), errors)
    ban("construction_site", texts["construction_site"], (
        "tech_priests_request_movement_0418", "register_service", "script.on_nth_tick",
        "inventory.remove", "inventory.insert", "create_entity",
    ), errors)
    need("construction", texts["construction"], (
        "Sole physical construction owner", "dispatcher_owned=true", "discovery_only_broker=true",
        "construction_candidate_0338", "construction_custody_0338",
        "function M.recommend_action", "function M.service_pair", "function M.abort_pair",
        'r.claim("construction-placement"', "return ok and accepted==true",
        "effectiveness-revalidated", "construction-custody-station-return-0338",
        'name="construction_discovery_0338"', "local function canonical_broker()",
    ), errors)
    ban("construction", texts["construction"], (
        "active_leaf_task_0655", "pair.target=", "pair.target =", "pair.mode=", "pair.mode =",
        "script.on_nth_tick", "TechPriestsRuntimeEventRegistry", "spill_item_stack",
        "result ~= false", "accepted ~= false",
    ), errors)

    need("machine", texts["machine"], ("machine_logistics_candidate_0528", "machine_logistics_custody_0528", "function M.recommend_action", "function M.service_pair", "machine_logistics_discovery_0528"), errors)
    need("item", texts["item"], ("dispatcher_owned = true", "discovery_only_broker = true", "proxy_ammo_excluded = true", "item_family_custody_0702"), errors)
    need("energy_readiness", texts["energy_readiness"], ("read_only = true", "fusion_heat_semantics_integrated = true", 'name="energy_family_readiness_0705"', "acted=0"), errors)
    need("energy_logistics", texts["energy_logistics"], ("dispatcher_owned=true", "discovery_only_broker=true", "energy_family_custody_0707", 'name="energy_family_discovery_0707"'), errors)
    need("silo_readiness", texts["silo_readiness"], ("read_only = true", "live_ownership_integrated = true", 'name="rocket_silo_readiness_0709"', "acted=0"), errors)
    need("silo_logistics", texts["silo_logistics"], ("dispatcher_owned=true", "discovery_only_broker=true", "rocket_silo_custody_0710", 'name="rocket_silo_discovery_0710"'), errors)
    need("artillery_readiness", texts["artillery_readiness"], ("read_only = true", "train_validity_integrated = true", 'name="artillery_readiness_0712"', "acted=0"), errors)
    need("artillery_logistics", texts["artillery_logistics"], ("dispatcher_owned=true", "discovery_only_broker=true", "artillery_custody_0713", 'name="artillery_discovery_0713"'), errors)
    need("roboport_readiness", texts["roboport_readiness"], ("read_only=true", "placement_authority=false", "placement_effectiveness_observed=true", "robot_population_monitor_only=true", 'name="roboport_readiness_0714"', "acted=0"), errors)
    need("roboport_logistics", texts["roboport_logistics"], ("dispatcher_owned=true", "discovery_only_broker=true", "robot_inventory_excluded=true", "placement_authority=false", "roboport_repair_custody_0715", 'name="roboport_repair_pack_discovery_0715"', "accepted==true"), errors)
    ban("roboport_logistics", texts["roboport_logistics"], ("active_leaf_task_0655", "pair.target=", "pair.target =", "result ~= false", "accepted ~= false", 'r.claim("machine-logistics"', "defines.inventory.roboport_robot", "script.on_nth_tick"), errors)

    need("fluid_turret_readiness", texts["fluid_turret_readiness"], (
        "Canonical read-only inspection", "read_only=true", "internal_buffer_correction_integrated=true",
        "entity-total-minus-local-fluidboxes", 'name="fluid_turret_readiness_0716"', "acted=0",
    ), errors)
    ban("fluid_turret_readiness", texts["fluid_turret_readiness"], ("fluid_turret_internal_buffer_guard_0731", "tech_priests_request_movement_0418", "script.on_nth_tick"), errors)
    need("fluid_turret_proposals", texts["fluid_turret_proposals"], (
        "Canonical source selection and exact endpoint validation", "read_only=true",
        "proposal_integrity_integrated=true", 'copy.integrity_0718="safe"',
        "pair.fluid_turret_safe_proposals_0718=safe_proposals",
        'name="fluid_turret_connection_proposals_0717"', "acted=0",
    ), errors)
    ban("fluid_turret_proposals", texts["fluid_turret_proposals"], ("fluid_turret_proposal_integrity_0718", "tech_priests_request_movement_0418", "script.on_nth_tick", "create_entity"), errors)
    need("fluid_turret_route", texts["fluid_turret_route"], (
        "construction_planner remains the sole movement, item-custody, and placement owner",
        "read_only_route_planner=true", "construction_handoff=true", "wrapper_free=true",
        'r.claim("fluid-turret-pipe-route"', 'pair.construction_request={item_name=M.pipe_item',
        'source="fluid-turret-route-0719"', "pair.construction_last_task_0338",
        'name="fluid_turret_route_discovery_0719"', "acted=0",
    ), errors)
    ban("fluid_turret_route", texts["fluid_turret_route"], (
        "fluid_turret_planner_integrity_0730", "previous_build_service_pair", "build.service_pair =",
        "build.install =", "tech_priests_request_movement_0418", "script.on_nth_tick",
        "inventory.remove", "inventory.insert", "surface.create_entity", "pair.construction_task_0338 = nil",
    ), errors)

    need("storage", texts["storage"], ("generic_container_only = true", "function M.deposit_exact", "function M.remove_generic_item"), errors)
    ban("storage", texts["storage"], ("assembling_machine_input", "assembling_machine_output", "furnace_source", "furnace_result", "lab_input", "spill_item_stack"), errors)
    need("transfer", texts["transfer"], ("inventory_transfer_custody_0687", "function M.service_custody"), errors)
    need("repair", texts["repair"], ("repair_pack_custody_0516", "function M.abort_pair"), errors)
    ban("repair", texts["repair"], ("script.on_nth_tick", "register_service", "spill_item_stack", "q.current=nil"), errors)
    need("combat", texts["combat"], ("Dispatcher-owned tactical selector", "function M.recommend_action"), errors)
    need("proxy", texts["proxy"], ("proxy_ammo_refund_custody_0649", "atomic_return"), errors)
    need("visual", texts["visual"], ("canonical_action_0744", "canonical-intent-line-0657"), errors)

    need("map", texts["map"], ("32 declarative active hardeners", "Twenty-three files remain", "## Stage 5 — Evidence and Release Boundary", "fluid_turret_route_discovery_0719"), errors)
    need("continuity", texts["continuity"], ("32 retained hardeners", "23 source-preserved authorities", "placement authority", "## Fluid-turret authority"), errors)
    need("history", texts["history"], ("32 active hardeners and 23 explicitly retired", "Consolidated fluid-turret authority", "No accepted Factorio runtime logs have yet been recorded"), errors)
    need("testing", texts["testing"], ("placement effectiveness", "fluid turret route", "Stage 5 objective validation"), errors)

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

    print("Recovery architecture observations: active=32 retired=23 construction=canonical fluid_turret=consolidated")
    if errors:
        print("Recovery architecture audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Recovery architecture source audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
