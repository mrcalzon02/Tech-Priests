#!/usr/bin/env python3
"""Validate the bounded 0472 movement/timer ownership consolidation."""
from __future__ import annotations
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
COMBAT = ROOT / "tech-priests_src/scripts/core/combat_magos_movement_authority_0472.lua"
MOVEMENT = ROOT / "tech-priests_src/scripts/core/movement_controller.lua"
WORKFLOW = ROOT / ".github/workflows/source-validation.yml"

REQUIRED = (
    'M.version = "0.1.674-dev"',
    'M.proxy_service_name = "combat_proxy_sustain_0472"',
    'M.broker_required = true',
    'M.movement_request_override_retired = true',
    'M.issue_command_override_retired = true',
    'function M.service(reason, budget)',
    'name = M.proxy_service_name',
    'broker.register_service',
    'return {',
)
FORBIDDEN = (
    'TECH_PRIESTS_0472_PRE_REQUEST_MOVEMENT',
    '_G.tech_priests_request_movement_0418 = function',
    'TECH_PRIESTS_0472_PRE_ISSUE_PRIEST_COMMAND',
    '_G.issue_priest_command = function',
    'TechPriestsRuntimeEventRegistry',
    'registry.on_nth_tick',
    'script.on_nth_tick',
)

def main() -> int:
    errors: list[str] = []
    combat = COMBAT.read_text(encoding="utf-8", errors="replace")
    movement = MOVEMENT.read_text(encoding="utf-8", errors="replace")
    workflow = WORKFLOW.read_text(encoding="utf-8", errors="replace")
    for fragment in REQUIRED:
        if fragment not in combat:
            errors.append(f"0472 missing contract: {fragment}")
    for fragment in FORBIDDEN:
        if fragment in combat:
            errors.append(f"0472 contains forbidden ownership regression: {fragment}")
    if 'function M.request' not in movement or 'M.broker_required = true' not in movement:
        errors.append("movement_controller is not the canonical broker-owned movement authority")
    if "Audit bounded combat proxy ownership" not in workflow or "check_combat_proxy_boundary_0762.py" not in workflow:
        errors.append("source-validation workflow is missing the 0762 boundary audit")
    if errors:
        print("Combat proxy boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Combat proxy boundary audit passed: 0472 no longer owns movement requests, visible commands, registry timers, or direct timers.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
