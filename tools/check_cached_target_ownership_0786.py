#!/usr/bin/env python3
"""Validate canonical cache-aware repair and consecration target ownership."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "part3": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_003.lua",
    "part14": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_014.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "source_workflow": ROOT / ".github/workflows/source-validation.yml",
    "workflow": ROOT / ".github/workflows/cached-target-ownership-validation.yml",
}

REQUIRED = {
    "part3": (
        "function can_fully_use_repair_pack(target)",
        "TECH_PRIESTS_BASE_FIND_DAMAGED_TARGET_0248_MERGED = true",
        "function get_station_consecration_radius(station)",
        "TECH_PRIESTS_BASE_FIND_CONSECRATION_TARGET_0248_MERGED = true",
        "sanctify_target_with_priest = function(pair, target)",
        "function repair_target(pair, target)",
    ),
    "part14": (
        "TECH_PRIESTS_FIND_DAMAGED_TARGET_PREDECESSOR_RETIRED = true",
        "TECH_PRIESTS_FIND_CONSECRATION_TARGET_PREDECESSOR_RETIRED = true",
        "function tech_priests_0248_target_inside_radius_0786(station, entity, radius)",
        "function tech_priests_0248_repair_score_0786(station, priest, entity)",
        "function find_damaged_target(station, radius, priest)",
        'tech_priests_0248_first_valid_from_cache(pair, "repair_targets"',
        "tech_priests_0248_is_repair_target(station, entity)",
        "tech_priests_0248_target_inside_radius_0786(station, entity, radius)",
        "station.surface.find_entities_filtered({ area = area, force = station.force })",
        "tech_priests_0248_repair_score_0786(station, priest, entity)",
        "function tech_priests_0248_consecration_candidate_0786(station, priest, entity, radius)",
        "tech_priests_0248_is_sanctification_target(entity)",
        "get_consecration_record and get_consecration_record(entity)",
        "get_available_station_consecration_item and get_available_station_consecration_item(station, missing)",
        "find_consecration_target_for_station = function(station, radius, priest)",
        "station_has_consecration_item and station_has_consecration_item(station)",
        'tech_priests_0248_first_valid_from_cache(pair, "sanctify_targets"',
        "tech_priests_0248_consecration_candidate_0786(station, priest, entity, radius)",
        "name = CONSECRATION_TARGET_NAME_LIST",
        "candidate.ratio < best_ratio",
    ),
    "integration": ("check_cached_target_ownership_0786.py",),
    "source_workflow": (
        "Audit canonical cached repair and consecration target ownership",
        "check_cached_target_ownership_0786.py",
    ),
    "workflow": (
        "Audit canonical cached repair and consecration target ownership",
        "check_cached_target_ownership_0786.py",
    ),
}

FORBIDDEN = {
    "part3": (
        "function find_damaged_target(station, radius, priest)",
        "find_consecration_target_for_station = function(station, radius, priest)",
    ),
    "part14": (
        "TECH_PRIESTS_FIND_DAMAGED_TARGET_BEFORE_0248",
        "TECH_PRIESTS_FIND_CONSECRATION_TARGET_BEFORE_0248",
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
                errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden predecessor ownership: {fragment}")

    ownership = texts["part3"] + "\n" + texts["part14"]
    count_contract(ownership, "function find_damaged_target(station, radius, priest)", 1, "canonical repair selector", errors)
    count_contract(ownership, "find_consecration_target_for_station = function(station, radius, priest)", 1, "canonical consecration selector", errors)
    count_contract(ownership, "function tech_priests_0248_target_inside_radius_0786(station, entity, radius)", 1, "shared current-radius validator", errors)
    count_contract(ownership, "function tech_priests_0248_repair_score_0786(station, priest, entity)", 1, "repair scoring helper", errors)
    count_contract(ownership, "function tech_priests_0248_consecration_candidate_0786(station, priest, entity, radius)", 1, "consecration eligibility helper", errors)

    if errors:
        print("Cached target ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Cached target ownership audit passed: one cache-aware repair selector and one cache-aware consecration selector "
        "own current-radius validation, live fallback scanning, useful-supply eligibility, and original scoring rules."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
