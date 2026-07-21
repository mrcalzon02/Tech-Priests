#!/usr/bin/env python3
"""Validate canonical generated mining-beam and direct-extraction ownership."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "part5": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_005.lua",
    "part8": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_008.lua",
    "part21": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_021.lua",
    "part22": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_022.lua",
    "safety": ROOT / "tech-priests_src/scripts/core/combat_safety.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "source_workflow": ROOT / ".github/workflows/source-validation.yml",
    "workflow": ROOT / ".github/workflows/generated-mining-beam-validation.yml",
}

REQUIRED = {
    "part5": (
        "function draw_emergency_craft_scan_line(pair, target_entity)",
        "local current_0784 = task_0784 and task_0784.current or nil",
        'current_0784.kind == "direct-mine-0273"',
        'target_entity.type == "item-entity"',
        "task_0784.sound_current_key_0177",
        "tech_priests_play_task_sound_0177(pair, sound_key_0784",
    ),
    "part8": ("TECH_PRIESTS_0177_SCAN_LINE_SOUND_WRAPPER_RETIRED = true",),
    "part21": (
        "function tech_priests_0312_beam_origin(priest)",
        "function tech_priests_0312_beam_target_position(target)",
        "function tech_priests_0312_effective_beam_profile(force)",
        "function tech_priests_0312_fire_laser(priest, target, damage, reason, color)",
        "tech_priests_0322_is_laser_target_allowed(priest, target, reason)",
        'if target.type == "item-entity" then return false end',
        "function tech_priests_0312_insert_loose_item(pair, item_entity)",
        "function tech_priests_0312_stop_for_mining(pair)",
        "function tech_priests_0312_is_hostile_nearby(pair, radius)",
        "function tech_priests_0312_service_direct_current(pair, task)",
        "tech_priests_0322_validate_direct_mining_current(pair, task)",
        'cur.entity.type == "item-entity"',
        "tech_priests_0312_insert_loose_item(pair, cur.entity)",
        "task.direct_due_tick_0315",
        "task.next_direct_laser_tick_0315",
        "task.gathered_units = (task.gathered_units or 0) + 1",
        "TECH_PRIESTS_0313_BEAM_PREDECESSOR_CAPTURE_RETIRED = true",
        "TECH_PRIESTS_0315_VALID_PAIR_HELPER_RETIRED = true",
        "TECH_PRIESTS_0315_BEAM_ORIGIN_HELPER_RETIRED = true",
        "TECH_PRIESTS_0315_BEAM_TARGET_HELPER_RETIRED = true",
        "TECH_PRIESTS_0315_HOSTILE_NEARBY_HELPER_RETIRED = true",
        "TECH_PRIESTS_0315_BEAM_PROFILE_HELPER_RETIRED = true",
        "TECH_PRIESTS_0315_SCAN_LINE_OVERRIDE_RETIRED = true",
        "TECH_PRIESTS_0315_BEAM_OVERRIDE_RETIRED = true",
    ),
    "part22": (
        "TECH_PRIESTS_0315_LOOSE_ITEM_HELPER_RETIRED = true",
        "TECH_PRIESTS_0315_STOP_HELPER_RETIRED = true",
        "TECH_PRIESTS_0315_DIRECT_SERVICE_OVERRIDE_RETIRED = true",
        "TECH_PRIESTS_0315_HANDLE_WRAPPER_RETIRED = true",
        "TECH_PRIESTS_0315_DEBUG_COMMAND_RETIRED = true",
        "TECH_PRIESTS_0316_DEBUG_COMMAND_RETIRED = true",
        'TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = require("scripts.core.bootstrap_runtime")',
    ),
    "safety": (
        "tech_priests_0322_is_laser_target_allowed = function(priest, target, reason)",
        "tech_priests_0322_validate_direct_mining_current = function(pair, task)",
        'if cur.entity.type == "item-entity" then return true end',
        "M.is_safe_direct_mining_target",
        "M.is_valid_hostile_target",
        "TECH_PRIESTS_0322_BEAM_SERVICE_WRAPPERS_RETIRED = true",
        "TECH_PRIESTS_0322_DEBUG_COMMAND_RETIRED = true",
    ),
    "cleanup": (
        '["tp-mining-0315"] = true',
        '["tp-mining-0316"] = true',
        '["tp-combat-safety-0322"] = true',
    ),
    "integration": ("check_generated_mining_beam_ownership_0784.py",),
    "source_workflow": (
        "Audit canonical generated mining beam and extraction ownership",
        "check_generated_mining_beam_ownership_0784.py",
    ),
    "workflow": (
        "Audit canonical generated mining beam and extraction ownership",
        "check_generated_mining_beam_ownership_0784.py",
    ),
}

FORBIDDEN = {
    "part8": (
        "tech_priests_original_draw_emergency_craft_scan_line_0177",
        "function draw_emergency_craft_scan_line(pair, target_entity)",
    ),
    "part21": (
        "TECH_PRIESTS_0313_PRE_FIRE_LASER",
        "TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE",
        "function tech_priests_0315_valid_pair(pair)",
        "function tech_priests_0315_origin(priest)",
        "function tech_priests_0315_target_position(target)",
        "function tech_priests_0315_is_hostile_nearby(pair, radius)",
        "function tech_priests_0315_effective_profile(force)",
    ),
    "part22": (
        "function tech_priests_0315_insert_loose_item",
        "function tech_priests_0315_stop_for_mining",
        "function tech_priests_0315_service_direct_current",
        "TECH_PRIESTS_0315_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT",
        'TechPriestsDebugCommandRegistry.add("tp-mining-0315"',
        'TechPriestsDebugCommandRegistry.add("tp-mining-0316"',
    ),
    "safety": (
        "TECH_PRIESTS_0322_PRE_0312_FIRE_LASER",
        "TECH_PRIESTS_0322_PRE_0315_SERVICE_DIRECT_CURRENT",
        "function tech_priests_0312_fire_laser(priest, target, damage, reason, color)",
        "function tech_priests_0315_service_direct_current(pair, task)",
        'commands.add_command("tp-combat-safety-0322"',
    ),
}


def count_contract(text: str, needle: str, expected: int, label: str, errors: list[str]) -> None:
    actual = text.count(needle)
    if actual != expected:
        errors.append(f"{label} expected {expected} occurrence(s) of {needle!r}, found {actual}")


def main() -> int:
    errors: list[str] = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}

    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden ownership: {fragment}")

    generated_and_safety = "\n".join(texts[name] for name in ("part5", "part8", "part21", "part22", "safety"))
    count_contract(generated_and_safety, "function draw_emergency_craft_scan_line(pair, target_entity)", 1, "canonical scan-line owner", errors)
    count_contract(generated_and_safety, "function tech_priests_0312_fire_laser(priest, target, damage, reason, color)", 1, "canonical beam owner", errors)
    count_contract(generated_and_safety, "function tech_priests_0312_service_direct_current(pair, task)", 1, "canonical direct-extraction owner", errors)
    count_contract(generated_and_safety, "function tech_priests_0315_service_direct_current(pair, task)", 0, "retired 0315 direct service", errors)
    count_contract(generated_and_safety, "tech_priests_0322_is_laser_target_allowed = function", 1, "named beam safety predicate", errors)
    count_contract(generated_and_safety, "tech_priests_0322_validate_direct_mining_current = function", 1, "named direct-service safety predicate", errors)

    if errors:
        print("Canonical generated mining beam ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Canonical generated mining beam ownership audit passed: one scan-line owner, one 0312 beam, "
        "one 0312 direct-extraction service, named 0322 safety predicates, loose-item pickup, and retired "
        "0177/0315/0322 wrapper and debug-command surfaces."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
