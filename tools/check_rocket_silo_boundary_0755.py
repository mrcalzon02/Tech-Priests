#!/usr/bin/env python3
"""Validate consolidated rocket-silo readiness and physical logistics ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "readiness": ROOT / "tech-priests_src/scripts/core/rocket_silo_readiness_0709.lua",
    "logistics": ROOT / "tech-priests_src/scripts/core/rocket_silo_logistics_0710.lua",
    "arbiter": ROOT / "tech-priests_src/scripts/core/action_state_arbiter_0488.lua",
    "dispatcher": ROOT / "tech-priests_src/scripts/core/single_dispatcher_0510.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
}
REQUIRED = {
    "readiness": (
        'version = "0.1.674-dev"',
        "read_only = true",
        "live_ownership_integrated = true",
        "structured_scan_truth = true",
        "function M.connected_item_automation",
        "function M.inspect_silo",
        "function M.scan_pair",
        "launch_sequence_active",
        "automation_owned",
        'name="rocket_silo_readiness_0709"',
        "acted=0",
    ),
    "logistics": (
        'version = "0.1.674-dev"',
        "dispatcher_owned=true",
        "discovery_only_broker=true",
        "live_ownership_integrated=true",
        "rocket_silo_candidate_0710",
        "rocket_silo_custody_0710",
        "function M.recommend_action",
        "function M.service_pair",
        "function M.abort_pair",
        'name="rocket_silo_discovery_0710"',
        'reservations.claim("rocket-silo-logistics"',
        "return ok and accepted==true",
        "return_custody",
        "deposit_exact",
        "launch-sequence-active",
        "external-logistics-owned",
    ),
    "arbiter": (
        "local function rocket_silo_recommendation",
        "TechPriestsRocketSiloLogistics0710",
        "active_silo",
        'kind,reason="rocket-silo-logistics"',
    ),
    "dispatcher": (
        "dispatcher_owns_rocket_silo_logistics",
        '["rocket-silo-logistics"]',
        '"scripts.core.rocket_silo_logistics_0710"',
        '"TechPriestsRocketSiloLogistics0710"',
    ),
    "planning": (
        '{module="scripts.core.rocket_silo_readiness_0709"',
        '{module="scripts.core.rocket_silo_logistics_0710"',
        '["scripts.core.rocket_silo_live_ownership_guard_0728"]',
    ),
}
FORBIDDEN = {
    "readiness": (
        "tech_priests_request_movement_0418",
        "script.on_nth_tick",
        "TechPriestsRuntimeEventRegistry",
        "rocket_silo_live_ownership_guard_0728",
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
        'name="rocket_silo_logistics_0710"',
        "rocket_silo_live_ownership_guard_0728",
        'reservations.claim("machine-logistics"',
    ),
    "arbiter": (
        'pcall(require,"scripts.core.rocket_silo_logistics_0710")',
        'pcall(require, "scripts.core.rocket_silo_logistics_0710")',
        "pair.rocket_silo_candidate_0710=",
        "pair.rocket_silo_logistics_0710=",
        "pair.rocket_silo_custody_0710=",
    ),
    "dispatcher": (
        "rocket_silo_discovery_0710",
        "TechPriestsRuntimeEventRegistry",
        "script.on_nth_tick",
    ),
    "planning": (
        '{module="scripts.core.rocket_silo_live_ownership_guard_0728"',
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

    planning = texts["planning"]
    active = re.findall(r'\{module="(scripts\.core\.[^"]+)"', planning)
    retired = re.findall(r'\["(scripts\.core\.[^"]+)"\]="', planning)
    if len(active) != 36:
        errors.append(f"expected 36 active hardeners, found {len(active)}")
    if len(retired) != 19:
        errors.append(f"expected 19 retired authorities, found {len(retired)}")

    if errors:
        print("Rocket-silo boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print(
        "Rocket-silo boundary audit passed: readiness is read-only; launch and "
        "external-logistics ownership are canonical; discovery is broker-owned; "
        "execution is dispatcher-owned; and removed items retain exact custody."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
