#!/usr/bin/env python3
"""Validate effective placement and dispatcher-owned physical construction."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "site": ROOT / "tech-priests_src/scripts/core/construction_site_planner.lua",
    "executor": ROOT / "tech-priests_src/scripts/core/construction_planner.lua",
    "arbiter": ROOT / "tech-priests_src/scripts/core/action_state_arbiter_0488.lua",
    "dispatcher": ROOT / "tech-priests_src/scripts/core/single_dispatcher_0510.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "site": (
        "Canonical read-only placement authority",
        "placement_authority = true",
        "read_only = true",
        "effectiveness_scoring = true",
        "function Planner.evaluate_defense_candidate",
        "function Planner.plan_defense_site",
        "function Planner.plan_site",
        "function Planner.placement_effectiveness_report",
        "defense-roboport",
        "threat_alignment_score",
        "support_penalty",
        "spacing_penalty",
        "function M.defense_position_allowed",
    ),
    "executor": (
        "Sole physical construction owner",
        "dispatcher_owned=true",
        "discovery_only_broker=true",
        "positional_reservation=true",
        "exact_item_custody=true",
        "construction_candidate_0338",
        "construction_custody_0338",
        "function M.recommend_action",
        "function M.service_pair",
        "function M.abort_pair",
        'r.claim("construction-placement"',
        "return ok and accepted==true",
        "direction=request.placeable.direction",
        "direction=c.direction",
        "effectiveness-revalidated",
        "construction-custody-station-return-0338",
        'name="construction_discovery_0338"',
        "local function canonical_broker()",
    ),
    "arbiter": (
        "local function construction_recommendation",
        "active_construction",
        "construction-recommendation",
        "active-construction-custody",
        "p and p.construction_task_0338",
        "p and p.construction_custody_0338",
        "p and p.construction_candidate_0338",
    ),
    "dispatcher": (
        "dispatcher_owns_construction",
        '["construction"]={"scripts.core.construction_planner","TechPriestsConstructionPlanner0338"}',
        'kind=="construction"or kind=="construction-placement"',
        "canonical_action_0744",
    ),
    "planning": (
        'construction={"scripts.core.construction_planner"}',
        'label:find("construction",1,true)then return"construction"',
        '"scripts.core.repair_executor_0516","scripts.core.construction_planner"',
        '["scripts.core.construction_placement_authority_0656"]',
    ),
    "workflow": (
        "Audit construction placement and execution boundary",
        "check_construction_boundary_0758.py",
    ),
}
FORBIDDEN = {
    "site": (
        "tech_priests_request_movement_0418",
        "register_service",
        "script.on_nth_tick",
        "inventory.remove",
        "inventory.insert",
        "create_entity",
    ),
    "executor": (
        "active_leaf_task_0655",
        "pair.target=",
        "pair.target =",
        "pair.mode=",
        "pair.mode =",
        "script.on_nth_tick",
        "TechPriestsRuntimeEventRegistry",
        "spill_item_stack",
        "result ~= false",
        "accepted ~= false",
        'name="construction_planner_0338"',
    ),
    "arbiter": (
        'pcall(require,"scripts.core.construction_planner")',
        'pcall(require, "scripts.core.construction_planner")',
        "tech_priests_request_movement_0418",
        "register_service",
        "pair.target =",
        "pair.mode =",
    ),
    "dispatcher": (
        "construction_discovery_0338",
        "TechPriestsRuntimeEventRegistry",
        "script.on_nth_tick",
    ),
    "planning": (
        '{module="scripts.core.construction_placement_authority_0656"',
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
        print("Construction boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print(
        "Construction boundary audit passed: placement is read-only and effectiveness-scored; "
        "discovery is broker-owned; selection is pure; execution is dispatcher-owned; "
        "and removed placeable items retain exact physical custody."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
