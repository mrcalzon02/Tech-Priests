#!/usr/bin/env python3
"""Validate consolidated visible item-family logistics ownership and custody."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "family": ROOT / "tech-priests_src/scripts/core/item_family_logistics_0702.lua",
    "arbiter": ROOT / "tech-priests_src/scripts/core/action_state_arbiter_0488.lua",
    "dispatcher": ROOT / "tech-priests_src/scripts/core/single_dispatcher_0510.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "proxy": ROOT / "tech-priests_src/scripts/core/proxy_ammo_hardener_0649.lua",
}
REQUIRED = {
    "family": (
        'version = "0.1.674-dev"',
        "dispatcher_owned = true",
        "discovery_only_broker = true",
        "proxy_ammo_excluded = true",
        "item_family_candidate_0702",
        "item_family_custody_0702",
        "function M.recommend_action",
        "function M.service_pair",
        "function M.abort_pair",
        'name = "item_family_discovery_0702"',
        "return ok and accepted == true",
        "deposit_exact",
        'task.family == "turret-ammo"',
        'task.family == "lab-science"',
        '"item-family-logistics"',
        "return discover_pairs(budget)",
    ),
    "arbiter": (
        "local function item_family_recommendation",
        "family.recommend_action",
        'action.kind == "item-family-logistics"',
        'rawget(_G, "TechPriestsItemFamilyLogistics0702")',
        'package.loaded["scripts.core.item_family_logistics_0702"]',
        "active_item_recommendation",
        'kind, reason = "item-family-logistics"',
    ),
    "dispatcher": (
        "dispatcher_owns_item_family_logistics",
        'family=="item-family-logistics"',
        '"scripts.core.item_family_logistics_0702"',
        '"TechPriestsItemFamilyLogistics0702"',
        '"service_pair",pair,reason',
    ),
    "planning": (
        '{module="scripts.core.item_family_logistics_0702"',
        '["scripts.core.item_family_integrity_0703"]',
        "consolidated into item_family_logistics_0702",
    ),
    "proxy": (
        'version="0.1.674-dev"',
        "proxy_ammo_refund_custody_0649",
        'name="proxy_ammo_hardener_0649"',
    ),
}
FORBIDDEN = {
    "family": (
        "proxy_candidate",
        "patch_proxy_hardener",
        "previous_proxy_load",
        "active_leaf_task_0655",
        "pair.mode=",
        "pair.mode =",
        "pair.target=",
        "pair.target =",
        "script.on_nth_tick",
        "TechPriestsRuntimeEventRegistry",
        "result ~= false",
        "result~=false",
        "accepted ~= false",
        "accepted~=false",
        'name = "item_family_logistics_0702"',
        'name="item_family_logistics_0702"',
        "item_family_integrity_0703",
        'family == "proxy-ammo"',
        'family=="proxy-ammo"',
    ),
    "arbiter": (
        'pcall(require, "scripts.core.item_family_logistics_0702")',
        'pcall(require,"scripts.core.item_family_logistics_0702")',
        "pair.item_family_candidate_0702 =",
        "pair.item_family_logistics_0702 =",
        "pair.item_family_custody_0702 =",
    ),
    "dispatcher": (
        "item_family_discovery_0702",
        "register_service({name=\"item_family_logistics_0702\"",
        "TechPriestsRuntimeEventRegistry",
        "script.on_nth_tick",
    ),
    "planning": (
        '{module="scripts.core.item_family_integrity_0703"',
    ),
    "proxy": (
        "item_family_logistics_0702_wrapped",
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
                errors.append(
                    f"{FILES[name].relative_to(ROOT)} missing contract: {part}"
                )
    for name, parts in FORBIDDEN.items():
        for part in parts:
            if part in texts[name]:
                errors.append(
                    f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}"
                )

    if errors:
        print("Item-family logistics boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print(
        "Item-family logistics boundary audit passed: proxy ammo remains with 0649; "
        "visible turret/lab discovery is broker-owned, classification is pure, "
        "execution is dispatcher-owned, and custody is persistent."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
