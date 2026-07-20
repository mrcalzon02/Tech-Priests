#!/usr/bin/env python3
"""Validate consolidated fluid-turret readiness, proposal, and route ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "readiness": ROOT / "tech-priests_src/scripts/core/fluid_turret_readiness_0716.lua",
    "proposals": ROOT / "tech-priests_src/scripts/core/fluid_turret_connection_proposals_0717.lua",
    "route": ROOT / "tech-priests_src/scripts/core/fluid_turret_connection_planner_0719.lua",
    "construction": ROOT / "tech-priests_src/scripts/core/construction_planner.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "readiness": (
        "Canonical read-only inspection",
        "read_only=true",
        "internal_buffer_correction_integrated=true",
        "structured_scan_truth=true",
        "entity-total-minus-local-fluidboxes",
        "function M.inspect_entity",
        "function M.scan_pair",
        'name="fluid_turret_readiness_0716"',
        "acted=0",
    ),
    "proposals": (
        "Canonical source selection and exact endpoint validation",
        "read_only=true",
        "proposal_integrity_integrated=true",
        "structured_scan_truth=true",
        "function M.refresh_pair",
        "local function validate_proposal",
        'copy.integrity_0718="safe"',
        "pair.fluid_turret_safe_proposals_0718=safe_proposals",
        'name="fluid_turret_connection_proposals_0717"',
        "acted=0",
    ),
    "route": (
        "construction_planner remains the sole movement, item-custody, and placement owner",
        "read_only_route_planner=true",
        "construction_handoff=true",
        "wrapper_free=true",
        "structured_scan_truth=true",
        'r.claim("fluid-turret-pipe-route"',
        'pair.construction_request={item_name=M.pipe_item',
        'source="fluid-turret-route-0719"',
        "local function observe_construction_result",
        "pair.construction_last_task_0338",
        'name="fluid_turret_route_discovery_0719"',
        "acted=0",
    ),
    "construction": (
        "Sole physical construction owner",
        "construction_request",
        "construction_last_task_0338",
        "exact_item_custody=true",
    ),
    "planning": (
        "active_hardener_count=32",
        "retired_authority_count=23",
        '{module="scripts.core.fluid_turret_readiness_0716"',
        '{module="scripts.core.fluid_turret_connection_proposals_0717"',
        '{module="scripts.core.fluid_turret_connection_planner_0719"',
        '["scripts.core.fluid_turret_internal_buffer_guard_0731"]',
        '["scripts.core.fluid_turret_proposal_integrity_0718"]',
        '["scripts.core.fluid_turret_planner_integrity_0730"]',
    ),
    "workflow": (
        "Audit consolidated fluid turret boundary",
        "check_fluid_turret_boundary_0759.py",
    ),
}
FORBIDDEN = {
    "readiness": (
        "fluid_turret_internal_buffer_guard_0731",
        "tech_priests_request_movement_0418",
        "script.on_nth_tick",
        "insert_fluid",
        "remove_fluid",
    ),
    "proposals": (
        "fluid_turret_proposal_integrity_0718",
        "tech_priests_request_movement_0418",
        "script.on_nth_tick",
        "create_entity",
        "inventory.remove",
        "inventory.insert",
    ),
    "route": (
        "fluid_turret_planner_integrity_0730",
        "previous_build_service_pair",
        "previous_build_install",
        "build.service_pair =",
        "build.install =",
        "tech_priests_request_movement_0418",
        "script.on_nth_tick",
        "inventory.remove",
        "inventory.insert",
        "surface.create_entity",
        "pair.construction_task_0338 = nil",
    ),
    "planning": (
        '{module="scripts.core.fluid_turret_internal_buffer_guard_0731"',
        '{module="scripts.core.fluid_turret_proposal_integrity_0718"',
        '{module="scripts.core.fluid_turret_planner_integrity_0730"',
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

    active = re.findall(r'\{\s*module\s*=\s*"(scripts\.core\.[^"]+)"', texts["planning"])
    retired = re.findall(r'\["(scripts\.core\.[^"]+)"\]\s*=', texts["planning"])
    if len(active) != 32:
        errors.append(f"expected 32 active hardeners, found {len(active)}")
    if len(retired) != 23:
        errors.append(f"expected 23 retired authorities, found {len(retired)}")

    if errors:
        print("Fluid turret boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print(
        "Fluid turret boundary audit passed: corrected readiness and exact proposals are read-only; "
        "route planning publishes identified construction requests; construction alone moves, "
        "carries items, and places pipes; wrapper authorities remain retired."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
