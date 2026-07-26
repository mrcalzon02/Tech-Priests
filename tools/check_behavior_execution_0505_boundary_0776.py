#!/usr/bin/env python3
"""Validate retired 0505 and canonical facility-first production ownership in 0514."""
from __future__ import annotations
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "retired": ROOT / "tech-priests_src/scripts/core/behavior_execution_doctrine_0505.lua",
    "production": ROOT / "tech-priests_src/scripts/core/emergency_production_executor_0514.lua",
    "control": ROOT / "tech-priests_src/control.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "architecture": ROOT / "tools/check_recovery_architecture_0744.py",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
    "recovery": ROOT / "RECOVERY_REPAIR_SEQUENCE.md",
    "history": ROOT / "docs/DEVELOPMENT_HISTORY.md",
    "testing": ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
    "continuity": ROOT / "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md",
    "map": ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md",
}
REQUIRED = {
    "retired": ('retired = true', 'authority = "behavior_execution_doctrine_0505"', 'emergency_production_executor_0514 + direct_acquisition_executor_0513 + movement_controller + priest_lifecycle_authority_0499 + priest_recovery_safety_0503'),
    "production": ('behavior_doctrine_0505_integrated = true', 'facility_first_integrated = true', 'visible_station_craft_integrated = true', 'retired_0505_state_cleanup = true', 'local function clear_retired_0505_state', 'prefer_emergency_facilities=true', 'allow_timed_station_fallback=true', 'require_strict_fallback_recipe=true', 'tech_priests_request_movement_0418', 'craft_due_tick_0514', 'consume_transaction', 'service_custody'),
    "control": ('Historical 0505 behavior-execution wrapper is retired',),
    "cleanup": ('["tp-behavior-0505"] = true',),
    "planning": ('retired_authority_count=48', '["scripts.core.behavior_execution_doctrine_0505"]'),
    "architecture": ('scripts.core.behavior_execution_doctrine_0505', 'retired_authority_count=48'),
    "integration": ('scripts.core.behavior_execution_doctrine_0505', 'check_behavior_execution_0505_boundary_0776.py'),
    "workflow": ('Audit retired 0505 behavior execution wrapper', 'check_behavior_execution_0505_boundary_0776.py'),
    "recovery": ('26-active / 47-retired graph', 'behavior-execution wrapper'),
    "history": ('26 active hardeners and 47 explicitly retired source-only authorities', 'Retired `0505` behavior-execution wrapper'),
    "testing": ('26 active hardeners and 47 retired source-only authorities', '`0505` is inert'),
    "continuity": ('47 source-preserved authorities', '`behavior_execution_doctrine_0505.lua`'),
    "map": ('47 retired source-only authorities', '`0505` is retired'),
}
FORBIDDEN = {
    "retired": ('function M.install', 'register_service', 'on_nth_tick', 'commands.add_command', 'ensure_pair_priest', 'handle_emergency_desperation_craft', 'tech_priests_request_movement_0418', 'pair.mode', 'pair.target', 'set_command'),
    "control": ('require("scripts.core.behavior_execution_doctrine_0505")',),
    "production": ('TECH_PRIESTS_0505_PRE_', 'remote_direct_blocked_0505 = {'),
}
def main() -> int:
    errors = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}")
    if errors:
        print("0505 behavior boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("0505 behavior boundary audit passed: 0505 is inert and 0514 owns facility-first, visible timed emergency production.")
    return 0
if __name__ == "__main__": raise SystemExit(main())
