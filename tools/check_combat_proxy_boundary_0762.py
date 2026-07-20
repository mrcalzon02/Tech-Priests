#!/usr/bin/env python3
"""Validate complete 0472 retirement and canonical combat-proxy ownership."""
from __future__ import annotations
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "retired": ROOT / "tech-priests_src/scripts/core/combat_magos_movement_authority_0472.lua",
    "control": ROOT / "tech-priests_src/control.lua",
    "hierarchy": ROOT / "tech-priests_src/scripts/core/command_hierarchy_0480.lua",
    "radar": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_017.lua",
    "movement": ROOT / "tech-priests_src/scripts/core/movement_controller.lua",
    "mutex": ROOT / "tech-priests_src/scripts/core/behavior_mutex_0466.lua",
    "proxy": ROOT / "tech-priests_src/scripts/core/proxy_turret_alignment.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "retired": ('retired = true', 'authority = "combat_magos_movement_authority_0472"', 'return M'),
    "control": ('Historical 0472 wrapper is retired', 'require("scripts.core.proxy_turret_alignment")'),
    "hierarchy": ('M.position_authority_integrated = true', 'function M.position_in_authority', 'name = "command_hierarchy_rebuild_0480"', 'broker.register_service', '_G.tech_priests_0480_position_in_authority'),
    "radar": ('rawget(_G, "tech_priests_0480_position_in_authority")',),
    "movement": ('M.proxy_prime_throttle_integrated = true', 'local function proxy_prime_allowed', 'pair.next_proxy_prime_tick_0419', 'proxy_prime_allowed(pair, target)'),
    "mutex": ('M.force_combat_throttle_integrated = true', 'M.combat_force_cooldown_ticks = 12', 'pair.next_combat_force_tick_0466', 'force_phase(pair)'),
    "proxy": ('combat_sustain_integrated = true', 'name = "proxy_turret_alignment_0555"', 'name = "combat_proxy_sustain_0472"', 'function M.combat_sustain_service', 'broker.register_service'),
    "planning": ('retired_authority_count=32', '["scripts.core.combat_magos_movement_authority_0472"]'),
    "workflow": ('Audit consolidated combat proxy ownership', 'check_combat_proxy_boundary_0762.py'),
}
FORBIDDEN = {
    "retired": ('function M.install', 'register_service', 'on_nth_tick', 'commands.add_command', 'tech_priests_request_movement_0418', 'issue_priest_command', 'pair.target', 'pair.mode'),
    "control": ('require("scripts.core.combat_magos_movement_authority_0472")',),
    "hierarchy": ('patch_magos_authority', 'combat_magos_movement_authority_0472', 'TechPriestsRuntimeEventRegistry', 'registry.on_nth_tick', 'script.on_nth_tick'),
    "proxy": ('TechPriestsRuntimeEventRegistry', 'registry.on_nth_tick', 'script.on_nth_tick', 'pair.target =', 'pair.mode =', 'pair.task_kind ='),
}

def main() -> int:
    errors: list[str] = []
    texts = {}
    for name, path in FILES.items():
        if not path.is_file():
            errors.append(f"missing required file: {path.relative_to(ROOT)}")
            texts[name] = ""
        else:
            texts[name] = path.read_text(encoding="utf-8", errors="replace")
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}")
    if errors:
        print("Combat proxy boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("Combat proxy boundary audit passed: 0472 is inert; command territory, prime throttling, force throttling, and proxy sustain belong to canonical owners.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
