#!/usr/bin/env python3
"""Validate consolidated machine-logistics ownership and custody boundaries."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "machine": ROOT / "tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua",
    "arbiter": ROOT / "tech-priests_src/scripts/core/action_state_arbiter_0488.lua",
    "dispatcher": ROOT / "tech-priests_src/scripts/core/single_dispatcher_0510.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
}
REQUIRED = {
    "machine": (
        'version = "0.1.674-dev"',
        "dispatcher_owned = true",
        "function M.recommend_action",
        "function M.abort_pair",
        "function M.service_pair",
        "machine_logistics_custody_0528",
        "machine_logistics_discovery_0528",
        "generic_item_count",
        "remove_generic_item",
        "deposit_exact",
        "machine_input",
        "machine_output",
        "machine_fuel",
        "return ok and accepted == true",
        "fn = function(_, budget) return discover_pairs(budget) end",
        "return discovery_ok == true",
        "station_machine_inventory_access=0",
    ),
    "arbiter": (
        "local function recommendation",
        "a.kind==kind",
        "local function machine_logistics_recommendation",
        'recommendation("TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528","scripts.core.logistics_machine_fulfillment_0528",p,"machine-logistics")',
        'order_kind=="machine-logistics"',
        'kind,reason="machine-logistics","machine-recommendation"',
    ),
    "dispatcher": (
        "dispatcher_owns_machine_logistics",
        'family=="machine-logistics"',
        "scripts.core.logistics_machine_fulfillment_0528",
        "TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528",
        "service~=nil",
    ),
    "planning": (
        '["scripts.core.machine_logistics_integrity_0682"]',
        '["scripts.core.machine_logistics_candidate_recovery_0683"]',
        '["scripts.core.machine_logistics_final_authority_0684"]',
    ),
}
FORBIDDEN = {
    "machine": (
        "get_station_inventory",
        "station_inventory",
        "station_inventories",
        "inventory(pair.station, ids.assembling_machine_input)",
        "inventory(pair.station, ids.assembling_machine_output)",
        "inventory(pair.station, ids.furnace_source)",
        "inventory(pair.station, ids.furnace_result)",
        "TECH_PRIESTS_0528_MACHINE_LOGISTICS_WRAPPED",
        "machine_logistics_integrity_0682",
        "machine_logistics_candidate_recovery_0683",
        "machine_logistics_final_authority_0684",
        "active_leaf_task_0655",
        "script.on_nth_tick",
        "TechPriestsRuntimeEventRegistry",
        "commands.add_command",
        "res ~= false",
        "res~=false",
        "result ~= false",
        "result~=false",
        "spill_item_stack",
    ),
    "arbiter": (
        'pcall(require,"scripts.core.logistics_machine_fulfillment_0528")',
        "pair.machine_logistics_candidate_0528 =",
        "pair.machine_logistics_0528 =",
    ),
    "dispatcher": (
        "TechPriestsRuntimeEventRegistry",
        "script.on_nth_tick",
        "dispatcher-0510:fallback",
        'return true, "registry-fallback"',
    ),
    "planning": (
        '{module="scripts.core.machine_logistics_integrity_0682"',
        '{module="scripts.core.machine_logistics_candidate_recovery_0683"',
        '{module="scripts.core.machine_logistics_final_authority_0684"',
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
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}")
    if errors:
        print("Machine logistics boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print(
        "Machine logistics boundary audit passed: broker discovery, pure generic "
        "classification, dispatcher execution, and persistent custody are consolidated."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
