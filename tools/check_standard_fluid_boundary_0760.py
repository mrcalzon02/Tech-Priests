#!/usr/bin/env python3
"""Validate consolidated standard-fluid doctrine and route ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "reservations": ROOT / "tech-priests_src/scripts/core/work_reservations.lua",
    "doctrine": ROOT / "tech-priests_src/scripts/core/fluid_network_doctrine_0689.lua",
    "route": ROOT / "tech-priests_src/scripts/core/fluid_connection_planner_0691.lua",
    "construction": ROOT / "tech-priests_src/scripts/core/construction_planner.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "reservations": (
        "shared reservation authority",
        "position_scope_integrated=true",
        "function M.target_key",
        '"surface:"..surface..":"',
        "surface_index_of(target,meta)",
        'name="work_reservations_0601_cleanup"',
        "acted=0",
    ),
    "doctrine": (
        "canonical standard-fluid doctrine",
        "read_only=true",
        "input_output_proposals_integrated=true",
        "port_collision_integrated=true",
        "context_guard_integrated=true",
        "fluid_item_policy_integrated=true",
        "structured_scan_truth=true",
        "function M.inspect_machine",
        "function M.validate_endpoint",
        "function M.validate_proposal",
        "function M.scan_pair",
        "pair.fluid_connection_proposals_0689=inputs",
        "pair.fluid_output_sink_proposals_0694=outputs",
        'name="fluid_network_doctrine_0689"',
        "acted=0",
    ),
    "route": (
        "standard-fluid route coordinator",
        "construction_planner alone moves",
        "wrapper_free=true",
        "input_output_integrated=true",
        "construction_handoff=true",
        "structured_scan_truth=true",
        'r.claim("standard-fluid-pipe-route"',
        "pair.standard_fluid_route_plan_0691=plan",
        "pair.fluid_pipe_plan_0691=plan",
        "pair.fluid_output_pipe_plan_0696=plan",
        'source="standard-fluid-route-0691"',
        "pair.construction_last_task_0338",
        'name="standard_fluid_route_discovery_0691"',
        "acted=0",
    ),
    "construction": (
        "Sole physical construction owner",
        "construction_request",
        "construction_last_task_0338",
        "exact_item_custody=true",
    ),
    "planning": (
        "active_hardener_count=26",
        "retired_authority_count=29",
        '{module="scripts.core.fluid_network_doctrine_0689"',
        '{module="scripts.core.fluid_connection_planner_0691"',
        '["scripts.core.fluid_connection_execution_guard_0692"]',
        '["scripts.core.fluid_output_sink_doctrine_0694"]',
        '["scripts.core.fluid_output_connection_planner_0696"]',
        '["scripts.core.reservation_position_scope_0697"]',
        '["scripts.core.fluid_port_collision_validator_0699"]',
        '["scripts.core.fluid_port_context_guard_0700"]',
    ),
    "workflow": (
        "Audit consolidated standard fluid boundary",
        "check_standard_fluid_boundary_0760.py",
    ),
}
FORBIDDEN = {
    "reservations": (
        "reservation_position_scope_0697",
        "previous_target_key",
        "TechPriestsRuntimeEventRegistry",
        "script.on_nth_tick",
    ),
    "doctrine": (
        "previous_final_activate",
        "previous_machine_service",
        "machine.service_pair =",
        "final.activate =",
        "active_supply_request = nil",
        "logistic_requested_item = nil",
        "machine_logistics_0528 = nil",
        "machine_logistics_candidate_0528 = nil",
        "tech_priests_request_movement_0418",
        "inventory.remove",
        "inventory.insert",
        "create_entity",
        "script.on_nth_tick",
    ),
    "route": (
        "fluid_connection_execution_guard_0692",
        "fluid_output_connection_planner_0696",
        "reservation_position_scope_0697",
        "fluid_port_collision_validator_0699",
        "fluid_port_context_guard_0700",
        "previous_build_service_pair",
        "previous_build_install",
        "build.service_pair =",
        "build.install =",
        "tech_priests_request_movement_0418",
        "inventory.remove",
        "inventory.insert",
        "surface.create_entity",
        "pair.construction_task_0338 = nil",
        "script.on_nth_tick",
    ),
    "planning": (
        '{module="scripts.core.fluid_connection_execution_guard_0692"',
        '{module="scripts.core.fluid_output_sink_doctrine_0694"',
        '{module="scripts.core.fluid_output_connection_planner_0696"',
        '{module="scripts.core.reservation_position_scope_0697"',
        '{module="scripts.core.fluid_port_collision_validator_0699"',
        '{module="scripts.core.fluid_port_context_guard_0700"',
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
    if len(active) != 26:
        errors.append(f"expected 26 active hardeners, found {len(active)}")
    if len(retired) != 29:
        errors.append(f"expected 29 retired authorities, found {len(retired)}")

    if errors:
        print("Standard fluid boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print(
        "Standard fluid boundary audit passed: reservations are natively surface scoped; "
        "0689 owns read-only machine context and exact input/output proposals; 0691 owns "
        "wrapper-free routes and identified construction requests; construction alone moves, "
        "carries pipe items, and places entities; six wrapper authorities remain retired."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
