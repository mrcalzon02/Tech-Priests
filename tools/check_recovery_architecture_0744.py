#!/usr/bin/env python3
"""Audit the protected recovery graph and its canonical authority boundaries."""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CORE = ROOT / "tech-priests_src/scripts/core"
HARDENER_RE = re.compile(r'\{module="(scripts\.core\.[^"]+)",label="([^"]+)"\}')
RETIRED_RE = re.compile(r'\["(scripts\.core\.[^"]+)"\]="([^"]+)"')
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
}
FILES = {
    "planning": CORE / "planning_constraints_0646.lua",
    "registry": CORE / "runtime_event_registry.lua",
    "broker": CORE / "runtime_tick_broker.lua",
    "arbiter": CORE / "action_state_arbiter_0488.lua",
    "dispatcher": CORE / "single_dispatcher_0510.lua",
    "machine": CORE / "logistics_machine_fulfillment_0528.lua",
    "item": CORE / "item_family_logistics_0702.lua",
    "storage": CORE / "storage_role_authority_0686.lua",
    "transfer": CORE / "inventory_transfer_integrity_0687.lua",
    "repair": CORE / "repair_executor_0516.lua",
    "combat": CORE / "combat_repair_doctrine_0517.lua",
    "proxy": CORE / "proxy_ammo_hardener_0649.lua",
    "visual": CORE / "visual_intent_line_authority_0657.lua",
    "map": ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md",
    "continuity": ROOT / "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md",
    "history": ROOT / "docs/DEVELOPMENT_HISTORY.md",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
    "manifest": ROOT / "dist/release-manifest-0.1.674-rc.3.json",
}


def read(name: str, errors: list[str]) -> str:
    path = FILES[name]
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def need(name: str, text: str, parts: tuple[str, ...], errors: list[str]) -> None:
    for part in parts:
        if part not in text:
            errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {part}")


def ban(name: str, text: str, parts: tuple[str, ...], errors: list[str]) -> None:
    for part in parts:
        if part in text:
            errors.append(
                f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}"
            )


def graph(text: str, errors: list[str]) -> None:
    active = [match.group(1) for match in HARDENER_RE.finditer(text)]
    retired = {
        match.group(1): match.group(2)
        for match in RETIRED_RE.finditer(text)
    }
    if len(active) != 41:
        errors.append(f"expected 41 active hardeners, found {len(active)}")
    if set(retired) != EXPECTED_RETIRED:
        errors.append(
            f"retired mismatch missing={sorted(EXPECTED_RETIRED-set(retired))} "
            f"unexpected={sorted(set(retired)-EXPECTED_RETIRED)}"
        )
    if len(active) != len(set(active)):
        errors.append("duplicate active hardener")
    if set(active) & set(retired):
        errors.append("authority is both active and retired")
    for required in (
        "scripts.core.storage_role_authority_0686",
        "scripts.core.inventory_transfer_integrity_0687",
        "scripts.core.item_family_logistics_0702",
        "scripts.core.energy_family_readiness_0705",
        "scripts.core.energy_family_logistics_0707",
    ):
        if required not in active:
            errors.append(f"required active authority missing: {required}")


def main() -> int:
    errors: list[str] = []
    texts = {name: read(name, errors) for name in FILES}
    graph(texts["planning"], errors)

    need("registry", texts["registry"], (
        "Registry.on_event", "Registry.on_nth_tick", "Registry.on_init",
        "Registry.on_configuration_changed", "isolated handler failure",
    ), errors)
    need("broker", texts["broker"], (
        "function M.normalize_result", "function M.installation_summary",
        "runtime_tick_broker_0600:central-pulse", "isolated service failure",
    ), errors)
    ban("broker", texts["broker"], ("script.on_nth_tick", "direct-fallback"), errors)

    need("arbiter", texts["arbiter"], (
        "Pure action classifier", "local function machine_logistics_recommendation",
        "local function item_family_recommendation", "active_item_recommendation",
        "function M.tick_all() return 0 end",
    ), errors)
    ban("arbiter", texts["arbiter"], (
        "tech_priests_request_movement_0418", "register_service",
        "pair.mode =", "pair.target =",
        'pcall(require, "scripts.core.item_family_logistics_0702")',
    ), errors)

    need("dispatcher", texts["dispatcher"], (
        "canonical_action_0744", "dispatcher_owns_machine_logistics",
        "dispatcher_owns_item_family_logistics", "TechPriestsItemFamilyLogistics0702",
        "function M.service_all",
    ), errors)

    need("machine", texts["machine"], (
        "machine_logistics_candidate_0528", "machine_logistics_custody_0528",
        "function M.recommend_action", "function M.service_pair",
        "machine_logistics_discovery_0528", "return ok and accepted == true",
    ), errors)
    ban("machine", texts["machine"], (
        "machine_logistics_integrity_0682",
        "machine_logistics_candidate_recovery_0683",
        "machine_logistics_final_authority_0684",
        "active_leaf_task_0655", "TechPriestsRuntimeEventRegistry",
        "script.on_nth_tick", "result ~= false",
    ), errors)

    need("item", texts["item"], (
        "dispatcher_owned = true", "discovery_only_broker = true",
        "proxy_ammo_excluded = true", "item_family_candidate_0702",
        "item_family_custody_0702", "function M.recommend_action",
        "function M.service_pair", "function M.abort_pair",
        "item_family_discovery_0702", "return ok and accepted == true",
    ), errors)
    ban("item", texts["item"], (
        "item_family_integrity_0703", "proxy_candidate", "patch_proxy_hardener",
        "active_leaf_task_0655", "pair.mode =", "pair.target =",
        "TechPriestsRuntimeEventRegistry", "script.on_nth_tick",
        "result ~= false",
    ), errors)

    need("storage", texts["storage"], (
        "generic_container_only = true", "function M.generic_station_inventories",
        "function M.deposit_exact", "function M.remove_generic_item",
        "storage_role_authority_0686_sweep",
    ), errors)
    ban("storage", texts["storage"], (
        "assembling_machine_input", "assembling_machine_output",
        "furnace_source", "furnace_result", "lab_input", "spill_item_stack",
    ), errors)

    need("transfer", texts["transfer"], (
        "inventory_transfer_custody_0687", 'phase = "removed-not-credited"',
        "function M.service_custody", "function M.flush_priest_inventory_to_station",
    ), errors)
    need("repair", texts["repair"], (
        "repair_pack_custody_0516", "function M.abort_pair",
        "function M.service_repair_bucket",
    ), errors)
    ban("repair", texts["repair"], (
        "script.on_nth_tick", "register_service", "spill_item_stack", "q.current=nil",
    ), errors)
    need("combat", texts["combat"], (
        "Dispatcher-owned tactical selector", "function M.recommend_action",
        "repair.service_pair", "repair.abort_pair",
    ), errors)
    ban("combat", texts["combat"], (
        "tech_priests_request_movement_0418", "register_service", "spill_item_stack",
    ), errors)

    need("proxy", texts["proxy"], (
        "proxy_ammo_refund_custody_0649", "atomic_return",
        "proxy_ammo_hardener_0649",
    ), errors)
    ban("proxy", texts["proxy"], (
        "script.on_nth_tick", "TechPriestsRuntimeEventRegistry",
        "item_family_logistics_0702_wrapped",
    ), errors)
    need("visual", texts["visual"], (
        "canonical_action_0744", "canonical-intent-line-0657",
        "return M.refresh_pair_links()",
    ), errors)

    need("map", texts["map"], (
        "41 declarative active hardeners", "Fourteen files remain",
        "item_family_discovery_0702", "## Stage 5 — Evidence and Release Boundary",
    ), errors)
    need("continuity", texts["continuity"], (
        "41 retained hardeners", "14 source-preserved authorities",
        "item_family_integrity_0703.lua",
        "Hidden proxy ammunition must not be added back to `0702`",
    ), errors)
    need("history", texts["history"], (
        "Experimental `0.1.674` prerelease artifacts exist",
        "41 active hardeners and 14 explicitly retired",
        "Consolidated visible item-family authority",
    ), errors)

    for title, checker in (
        ("Audit generic storage boundary", "check_generic_storage_boundary_0750.py"),
        ("Audit machine logistics boundary", "check_machine_logistics_boundary_0751.py"),
        ("Audit priest cargo transfer boundary", "check_inventory_transfer_boundary_0752.py"),
        ("Audit item family logistics boundary", "check_item_family_logistics_boundary_0753.py"),
        ("Audit development integration graph", "check_development_integration_0732.py"),
    ):
        if title not in texts["workflow"] or checker not in texts["workflow"]:
            errors.append(f"workflow missing {title}: {checker}")

    manifest = json.loads(texts["manifest"] or "{}")
    if manifest.get("runtime_validation_complete") is not False:
        errors.append("experimental manifest must remain runtime_validation_complete=false")
    if manifest.get("prerelease") is not True:
        errors.append("experimental manifest must remain prerelease=true")

    print("Recovery architecture observations: active=41 retired=14")
    if errors:
        print("Recovery architecture audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Recovery architecture source audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
