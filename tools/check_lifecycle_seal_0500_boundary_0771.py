#!/usr/bin/env python3
"""Validate inert 0500 and fail-closed canonical lifecycle destruction/replacement."""
from __future__ import annotations
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "retired": ROOT / "tech-priests_src/scripts/core/priest_lifecycle_seal_0500.lua",
    "lifecycle": ROOT / "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
    "control": ROOT / "tech-priests_src/control.lua",
    "part1": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_001.lua",
    "part2": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_002.lua",
    "part3": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_003.lua",
    "part6": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_006.lua",
    "part11": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_011.lua",
    "part12": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_012.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "retired": ('retired = true', 'authority = "priest_lifecycle_seal_0500"', 'priest_lifecycle_authority_0499 + authoritative lifecycle functions'),
    "lifecycle": ('destruction_authority_integrated = true', 'replacement_authority_integrated = true', 'controlled_missing_recovery = true', 'function M.authorize_missing_recovery', 'function M.consume_replacement_lease', 'function M.note_recovered_priest', 'function M.replacement_authorized', 'function M.destruction_authorized', 'function M.destroy_priest_authorized', 'tech_priests_priest_replacement_authorized_0499', 'tech_priests_destroy_priest_authorized_0499', 'allow_station_cleanup == true', 'station-cleanup-remove_pair_for_entity'),
    "control": ('Historical 0500 lifecycle seal is retired into canonical 0499',),
    "part1": ('tech_priests_destroy_priest_authorized_0499', 'allow_station_cleanup = is_station and is_station(entity)', 'priest cleanup denied: canonical lifecycle authority unavailable'),
    "part2": ('priest.destructible = false', 'storage.tech_priests.pairs_by_priest[priest.unit_number] = pair', 'tech_priests_consume_replacement_lease_0499', 'tech_priests_note_recovered_priest_0499', 'tech_priests_canonical_respawn_pair_priest_0503'),
    "part3": ('tech_priests_priest_replacement_authorized_0499', 'tech_priests_destroy_priest_authorized_0499', 'new_priest.destroy'),
    "part6": ('tech_priests_destroy_priest_authorized_0499', 'if not destroyed then return false end'),
    "part11": ('tech_priests_priest_replacement_authorized_0499', 'allow_unbound_replacement_cleanup = true', 'allow_replacement = true'),
    "cleanup": ('["tp-priest-lifecycle-0500"] = true',),
    "planning": ('retired_authority_count=48', '["scripts.core.priest_lifecycle_seal_0500"]'),
    "workflow": ('Audit retired 0500 lifecycle seal', 'check_lifecycle_seal_0500_boundary_0771.py'),
}
FORBIDDEN = {
    "retired": ('function M.install', 'register_service', 'on_nth_tick', 'commands.add_command', 'tech_priests_destroy_priest_0500'),
    "lifecycle": ('tech_priests_destroy_priest_0500', 'tech_priests_allow_priest_station_cleanup_0500', 'lifecycle_0500'),
    "control": ('require("scripts.core.priest_lifecycle_seal_0500")',),
    "part1": ('tech_priests_destroy_priest_0500', 'priest.destroy({ raise_destroy = false })'),
    "part2": ('tech_priests_destroy_priest_0500',),
    "part3": ('tech_priests_destroy_priest_0500',),
    "part6": ('tech_priests_destroy_priest_0500', 'priest.destroy({ raise_destroy = false })'),
    "part11": ('tech_priests_destroy_priest_0500', 'tech_priests_is_priest_0500'),
    "part12": ('tech_priests_destroy_priest_0500', 'tech_priests_is_priest_0500'),
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
        print("0500 lifecycle boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("0500 lifecycle boundary audit passed: destruction and replacement are fail-closed in canonical source; 0500 is inert.")
    return 0
if __name__ == "__main__": raise SystemExit(main())
