#!/usr/bin/env python3
"""Validate consolidated energy readiness and physical logistics ownership."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "readiness": ROOT / "tech-priests_src/scripts/core/energy_family_readiness_0705.lua",
    "logistics": ROOT / "tech-priests_src/scripts/core/energy_family_logistics_0707.lua",
    "arbiter": ROOT / "tech-priests_src/scripts/core/action_state_arbiter_0488.lua",
    "dispatcher": ROOT / "tech-priests_src/scripts/core/single_dispatcher_0510.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
}
REQUIRED = {
    "readiness": (
        'version = "0.1.674-dev"',
        "read_only = true",
        "fusion_heat_semantics_integrated = true",
        "item_automation_ownership_integrated = true",
        "corrected_diagnostics_integrated = true",
        "function M.connected_item_automation",
        "function M.inspect_entity",
        "function M.scan_pair",
        'entity.type ~= "reactor"',
        'readiness_state,severity="external-item-automation-owned","monitor"',
        'name="energy_family_readiness_0705"',
        "acted=0",
    ),
    "logistics": (
        'version = "0.1.674-dev"',
        "dispatcher_owned=true",
        "discovery_only_broker=true",
        "external_automation_integrated=true",
        "energy_family_candidate_0707",
        "energy_family_custody_0707",
        "function M.recommend_action",
        "function M.service_pair",
        "function M.abort_pair",
        '"energy-family-logistics"',
        'name="energy_family_discovery_0707"',
        'reservations.claim("energy-family-logistics"',
        "return ok and accepted==true",
        "deposit_exact",
        "return_custody",
    ),
    "arbiter": (
        "local function energy_family_recommendation",
        "TechPriestsEnergyFamilyLogistics0707",
        "active_energy",
        'kind,reason="energy-family-logistics"',
    ),
    "dispatcher": (
        "dispatcher_owns_energy_family_logistics",
        '["energy-family-logistics"]',
        '"scripts.core.energy_family_logistics_0707"',
        '"TechPriestsEnergyFamilyLogistics0707"',
    ),
    "planning": (
        '{module="scripts.core.energy_family_readiness_0705"',
        '{module="scripts.core.energy_family_logistics_0707"',
        '["scripts.core.fusion_reactor_readiness_guard_0727"]',
        '["scripts.core.energy_readiness_diagnostics_0711"]',
        '["scripts.core.energy_item_automation_guard_0722"]',
        '["scripts.core.energy_automation_guard_install_assertion_0726"]',
    ),
}
FORBIDDEN = {
    "readiness": (
        "tech_priests_request_movement_0418",
        "script.on_nth_tick",
        "TechPriestsRuntimeEventRegistry",
        "fusion_reactor_readiness_guard_0727",
        "energy_readiness_diagnostics_0711",
        "energy_item_automation_guard_0722",
    ),
    "logistics": (
        "active_leaf_task_0655",
        "pair.mode=",
        "pair.mode =",
        "pair.target=",
        "pair.target =",
        "TechPriestsRuntimeEventRegistry",
        "script.on_nth_tick",
        "result ~= false",
        "result~=false",
        "accepted ~= false",
        "accepted~=false",
        'name="energy_family_logistics_0707"',
        "fusion_reactor_readiness_guard_0727",
        "energy_readiness_diagnostics_0711",
        "energy_item_automation_guard_0722",
        "energy_automation_guard_install_assertion_0726",
        'reservations.claim("machine-logistics"',
    ),
    "arbiter": (
        'pcall(require,"scripts.core.energy_family_logistics_0707")',
        'pcall(require, "scripts.core.energy_family_logistics_0707")',
        "pair.energy_family_candidate_0707=",
        "pair.energy_family_logistics_0707=",
        "pair.energy_family_custody_0707=",
    ),
    "dispatcher": (
        "energy_family_discovery_0707",
        "TechPriestsRuntimeEventRegistry",
        "script.on_nth_tick",
    ),
    "planning": (
        '{module="scripts.core.fusion_reactor_readiness_guard_0727"',
        '{module="scripts.core.energy_readiness_diagnostics_0711"',
        '{module="scripts.core.energy_item_automation_guard_0722"',
        '{module="scripts.core.energy_automation_guard_install_assertion_0726"',
    ),
}


def main() -> int:
    errors: list[str] = []
    texts: dict[str, str] = {}
    for name, path in FILES.items():
        if not path.is_file():
            errors.append(f"missing required file: {path.relative_to(ROOT)}")
            texts[name] = ""
        else:
            texts[name] = path.read_text(encoding="utf-8", errors="replace")
    for name, parts in REQUIRED.items():
        for part in parts:
            if part not in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {part}")
    for name, parts in FORBIDDEN.items():
        for part in parts:
            if part in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}")

    if errors:
        print("Energy-family boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print(
        "Energy-family boundary audit passed: readiness is read-only; fusion and "
        "external automation policy are canonical; discovery is broker-owned; "
        "execution is dispatcher-owned; and removed items retain custody."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
