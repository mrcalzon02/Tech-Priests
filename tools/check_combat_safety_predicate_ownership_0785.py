#!/usr/bin/env python3
"""Validate canonical combat target selection and predicate ownership."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "part3": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_003.lua",
    "part13": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_013.lua",
    "part14": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_014.lua",
    "safety": ROOT / "tech-priests_src/scripts/core/combat_safety.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "source_workflow": ROOT / ".github/workflows/source-validation.yml",
    "workflow": ROOT / ".github/workflows/combat-safety-predicate-validation.yml",
}

REQUIRED = {
    "part3": (
        "TECH_PRIESTS_BASE_FIND_ENEMY_TARGET_0248_MERGED = true",
        "function enemy_inside_station_radius(station, enemy, radius)",
        "tech_priests_0322_is_valid_hostile_target(station, enemy)",
        "function handle_combat(pair)",
        'tech_priests_0322_clear_invalid_combat_state(pair, "before-handle-combat")',
        'tech_priests_0322_clear_invalid_combat_state(pair, "after-handle-combat")',
        "local function finish_0785(result)",
        "return finish_0785(false)",
        "return finish_0785(true)",
    ),
    "part13": (
        "function tech_priests_0248_is_enemy_of_station(station, entity)",
        "tech_priests_0322_is_valid_hostile_target(station, entity)",
        "is_asteroid_threat_entity(entity)",
    ),
    "part14": (
        "TECH_PRIESTS_FIND_ENEMY_TARGET_PREDECESSOR_RETIRED = true",
        "function find_enemy_target(station, radius, priest)",
        'tech_priests_0248_first_valid_from_cache(pair, "hostiles"',
        "find_space_asteroid_targets(surface, area)",
        "tech_priests_0248_is_enemy_of_station(station, entity)",
        "score_threat_to_station_and_priest(entity, position, priest)",
    ),
    "safety": (
        "tech_priests_0322_is_valid_hostile_target = M.is_valid_hostile_target",
        "tech_priests_0322_clear_invalid_combat_state = M.clear_invalid_combat_state",
        "TECH_PRIESTS_0322_TARGET_COMBAT_WRAPPERS_RETIRED = true",
        "tech_priests_0322_is_laser_target_allowed = function(priest, target, reason)",
        "tech_priests_0322_validate_direct_mining_current = function(pair, task)",
        "TECH_PRIESTS_0322_BEAM_SERVICE_WRAPPERS_RETIRED = true",
    ),
    "integration": ("check_combat_safety_predicate_ownership_0785.py",),
    "source_workflow": (
        "Audit canonical combat safety predicate ownership",
        "check_combat_safety_predicate_ownership_0785.py",
    ),
    "workflow": (
        "Audit canonical combat safety predicate ownership",
        "check_combat_safety_predicate_ownership_0785.py",
    ),
}

FORBIDDEN = {
    "part3": ("function find_enemy_target(station, radius, priest)",),
    "part14": ("TECH_PRIESTS_FIND_ENEMY_TARGET_BEFORE_0248",),
    "safety": (
        "TECH_PRIESTS_0322_PRE_FIND_ENEMY_TARGET",
        "TECH_PRIESTS_0322_PRE_ENEMY_INSIDE_STATION_RADIUS",
        "TECH_PRIESTS_0322_PRE_0248_IS_ENEMY_OF_STATION",
        "TECH_PRIESTS_0322_PRE_HANDLE_COMBAT",
        "function find_enemy_target(station, radius, priest)",
        "function enemy_inside_station_radius(station, enemy, radius)",
        "function tech_priests_0248_is_enemy_of_station(station, entity)",
        "function handle_combat(pair)",
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
                errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden wrapper ownership: {fragment}")

    ownership = "\n".join(texts[name] for name in ("part3", "part13", "part14", "safety"))
    count_contract(ownership, "function find_enemy_target(station, radius, priest)", 1, "canonical enemy query", errors)
    count_contract(ownership, "function enemy_inside_station_radius(station, enemy, radius)", 1, "canonical station-radius predicate", errors)
    count_contract(ownership, "function tech_priests_0248_is_enemy_of_station(station, entity)", 1, "canonical station-enemy predicate", errors)
    count_contract(ownership, "function handle_combat(pair)", 1, "canonical combat service", errors)
    count_contract(ownership, "tech_priests_0322_is_valid_hostile_target = M.is_valid_hostile_target", 1, "hostile-target predicate export", errors)
    count_contract(ownership, "tech_priests_0322_clear_invalid_combat_state = M.clear_invalid_combat_state", 1, "invalid-state cleanup export", errors)

    if errors:
        print("Combat safety predicate ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Combat safety predicate ownership audit passed: one cache-aware enemy query, one radius predicate, "
        "one station-enemy predicate, one combat service, and named 0322 safety exports with no target/combat wrappers."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
