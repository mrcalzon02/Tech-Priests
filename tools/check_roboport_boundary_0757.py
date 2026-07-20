#!/usr/bin/env python3
"""Validate read-only roboport doctrine and dispatcher-owned repair-pack service."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "readiness": ROOT / "tech-priests_src/scripts/core/roboport_readiness_0714.lua",
    "logistics": ROOT / "tech-priests_src/scripts/core/roboport_repair_pack_logistics_0715.lua",
    "arbiter": ROOT / "tech-priests_src/scripts/core/action_state_arbiter_0488.lua",
    "dispatcher": ROOT / "tech-priests_src/scripts/core/single_dispatcher_0510.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
}

REQUIRED = {
    "readiness": (
        'version="0.1.674-dev"',
        "read_only=true",
        "structured_scan_truth=true",
        "placement_authority=false",
        "placement_effectiveness_observed=true",
        "robot_population_monitor_only=true",
        "function M.connected_item_automation",
        "function M.inspect_entity",
        "function M.scan_pair",
        'name="roboport_readiness_0714"',
        "acted=0",
    ),
    "logistics": (
        'version="0.1.674-dev"',
        "dispatcher_owned=true",
        "discovery_only_broker=true",
        "robot_inventory_excluded=true",
        "placement_authority=false",
        "roboport_repair_candidate_0715",
        "roboport_repair_logistics_0715",
        "roboport_repair_custody_0715",
        "function M.discover_pair",
        "function M.recommend_action",
        "function M.service_pair",
        "function M.abort_pair",
        'name="roboport_repair_pack_discovery_0715"',
        'r.claim("roboport-repair-pack-logistics"',
        "accepted==true",
        "source_entity",
        "source_inv",
        "deposit_exact",
    ),
    "arbiter": (
        "local function artillery_recommendation",
        "local function roboport_recommendation",
        "active_artillery",
        "active_roboport",
        '"artillery-logistics"',
        '"roboport-repair-pack-logistics"',
    ),
    "dispatcher": (
        "dispatcher_owns_artillery_logistics",
        "dispatcher_owns_roboport_repair_pack_logistics",
        '"scripts.core.artillery_logistics_0713"',
        '"scripts.core.roboport_repair_pack_logistics_0715"',
        '"TechPriestsArtilleryLogistics0713"',
        '"TechPriestsRoboportRepairPackLogistics0715"',
    ),
    "planning": (
        '"scripts.core.roboport_repair_pack_logistics_0715",',
        '{module="scripts.core.roboport_readiness_0714"',
        '{module="scripts.core.roboport_repair_pack_logistics_0715"',
        '["scripts.core.artillery_train_validity_guard_0724"]=',
    ),
}

FORBIDDEN = {
    "readiness": (
        "tech_priests_request_movement_0418",
        "script.on_nth_tick",
        "TechPriestsRuntimeEventRegistry",
        "reservations.claim",
        "create_entity",
        "build_from_cursor",
    ),
    "logistics": (
        "active_leaf_task_0655",
        "pair.target=",
        "pair.target =",
        "pair.mode=",
        "pair.mode =",
        "result ~= false",
        "result~=false",
        "accepted ~= false",
        "accepted~=false",
        'name="roboport_repair_pack_logistics_0715"',
        'r.claim("machine-logistics"',
        "defines.inventory.roboport_robot",
        "script.on_nth_tick",
        "TechPriestsRuntimeEventRegistry",
        "create_entity",
    ),
    "arbiter": (
        'pcall(require,"scripts.core.artillery_logistics_0713")',
        'pcall(require,"scripts.core.roboport_repair_pack_logistics_0715")',
        'pcall(require, "scripts.core.artillery_logistics_0713")',
        'pcall(require, "scripts.core.roboport_repair_pack_logistics_0715")',
        "pair.artillery_candidate_0713=",
        "pair.roboport_repair_candidate_0715=",
        "pair.roboport_repair_logistics_0715=",
        "pair.roboport_repair_custody_0715=",
    ),
    "dispatcher": (
        "artillery_discovery_0713",
        "roboport_repair_pack_discovery_0715",
        "TechPriestsRuntimeEventRegistry",
        "script.on_nth_tick",
    ),
    "planning": (
        '{module="scripts.core.artillery_train_validity_guard_0724"',
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
        print("Roboport boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Roboport boundary audit passed: readiness is read-only; placement remains "
        "external; discovery is broker-owned; execution is dispatcher-owned; robot "
        "population is untouched; and removed repair packs retain source-aware custody."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
