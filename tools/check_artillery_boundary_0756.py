#!/usr/bin/env python3
"""Validate consolidated artillery readiness and physical logistics ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "readiness": ROOT / "tech-priests_src/scripts/core/artillery_readiness_0712.lua",
    "logistics": ROOT / "tech-priests_src/scripts/core/artillery_logistics_0713.lua",
    "arbiter": ROOT / "tech-priests_src/scripts/core/action_state_arbiter_0488.lua",
    "dispatcher": ROOT / "tech-priests_src/scripts/core/single_dispatcher_0510.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
}
REQUIRED = {
    "readiness": (
        'version = "0.1.674-dev"',
        "read_only = true",
        "train_validity_integrated = true",
        "automation_ownership_integrated = true",
        "structured_scan_truth = true",
        "function M.connected_item_automation",
        "function M.train_status",
        "function M.inspect_entity",
        "function M.scan_pair",
        'readiness_state,severity="invalid-train-monitor","monitor"',
        'readiness_state,severity="moving-train-monitor","monitor"',
        'readiness_state,severity="automatic-train-owned","monitor"',
        'name="artillery_readiness_0712"',
        "acted=0",
    ),
    "logistics": (
        'version="0.1.674-dev"',
        "dispatcher_owned=true",
        "discovery_only_broker=true",
        "train_validity_integrated=true",
        "artillery_candidate_0713",
        "artillery_custody_0713",
        "function M.recommend_action",
        "function M.service_pair",
        "function M.abort_pair",
        'name="artillery_discovery_0713"',
        'r.claim("artillery-logistics"',
        "return ok and accepted==true",
        "return_custody",
        "deposit_exact",
        "unsafe-artillery-task-aborted",
        "unsafe-artillery-custody-return",
    ),
    "arbiter": (
        "local function artillery_recommendation",
        "TechPriestsArtilleryLogistics0713",
        "active_artillery",
        'kind,reason="artillery-logistics"',
    ),
    "dispatcher": (
        "dispatcher_owns_artillery_logistics",
        '["artillery-logistics"]',
        '"scripts.core.artillery_logistics_0713"',
        '"TechPriestsArtilleryLogistics0713"',
    ),
    "planning": (
        '{module="scripts.core.artillery_readiness_0712"',
        '{module="scripts.core.artillery_logistics_0713"',
        '["scripts.core.artillery_train_validity_guard_0724"]',
    ),
}
FORBIDDEN = {
    "readiness": (
        "tech_priests_request_movement_0418",
        "script.on_nth_tick",
        "TechPriestsRuntimeEventRegistry",
        "artillery_train_validity_guard_0724",
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
        'name="artillery_logistics_0713"',
        "artillery_train_validity_guard_0724",
        'r.claim("machine-logistics"',
    ),
    "arbiter": (
        'pcall(require,"scripts.core.artillery_logistics_0713")',
        'pcall(require, "scripts.core.artillery_logistics_0713")',
        "pair.artillery_candidate_0713=",
        "pair.artillery_logistics_0713=",
        "pair.artillery_custody_0713=",
    ),
    "dispatcher": (
        "artillery_discovery_0713",
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
    if len(active) != 35:
        errors.append(f"expected 35 active hardeners, found {len(active)}")
    if len(retired) != 20:
        errors.append(f"expected 20 retired authorities, found {len(retired)}")

    if errors:
        print("Artillery boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print(
        "Artillery boundary audit passed: readiness is read-only; train validity "
        "and automation ownership are canonical; discovery is broker-owned; "
        "execution is dispatcher-owned; and removed ammunition retains custody."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
