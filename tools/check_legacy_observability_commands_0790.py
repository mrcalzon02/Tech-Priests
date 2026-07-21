#!/usr/bin/env python3
"""Validate retirement of report-only legacy observability commands."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "part1": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_001.lua",
    "part2": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_002.lua",
    "part3": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_003.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "source_workflow": ROOT / ".github/workflows/source-validation.yml",
    "workflow": ROOT / ".github/workflows/legacy-observability-validation.yml",
}

COMMANDS = (
    "tp-priest-diag",
    "tp-radii",
    "tp-spawn-dump",
    "tp-last-dump",
    "tp-list-pairs",
    "tp-list-names",
    "tp-legacy-snapshot",
    "tp-cog-summary",
)

REQUIRED = {
    "part1": (
        "function tech_priests_find_priest_for_player_0120(player)",
        "TECH_PRIESTS_0120_DEBUG_COMMAND_RETIRED = true",
        "function rank_scan_radius(pair)",
        "TECH_PRIESTS_0121_RADII_COMMAND_RETIRED = true",
        "function refresh_pair_radius(pair)",
        "TECH_PRIESTS_RANK_SCAN_RADII_0121",
    ),
    "part2": (
        "TECH_PRIESTS_0124_SPAWN_DUMP_COMMAND_RETIRED = true",
        "TECH_PRIESTS_0124_LAST_DUMP_COMMAND_RETIRED = true",
        "TECH_PRIESTS_ACTIVE_PAIRS_0127",
        "TECH_PRIESTS_ACTIVE_NAMES_0127",
        "TECH_PRIESTS_0127_LIST_PAIRS_COMMAND_RETIRED = true",
        "TECH_PRIESTS_0127_LIST_NAMES_COMMAND_RETIRED = true",
        "function tech_priests_0127_register_pair(pair)",
        "function tech_priests_0127_sync_names(pair)",
    ),
    "part3": (
        "TECH_PRIESTS_0137_LEGACY_SNAPSHOT_COMMAND_RETIRED = true",
        "TECH_PRIESTS_0150_COG_SUMMARY_COMMAND_RETIRED = true",
        "function tech_priests_inventory_summary_0150(inv)",
        "function tech_priests_cogitator_inventory_summary_0150(pair)",
        'tech_priests_log_0150("Cogitator inventory summary helper active")',
    ),
    "integration": ("check_legacy_observability_commands_0790.py",),
    "source_workflow": (
        "Audit retired legacy observability commands",
        "check_legacy_observability_commands_0790.py",
    ),
    "workflow": (
        "Audit retired legacy observability commands",
        "check_legacy_observability_commands_0790.py",
    ),
}


def main() -> int:
    errors: list[str] = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}

    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")

    generated = "\n".join(texts[name] for name in ("part1", "part2", "part3"))
    for command in COMMANDS:
        registrations = (
            f'TechPriestsDebugCommandRegistry.add("{command}"',
            f"TechPriestsDebugCommandRegistry.add('{command}'",
            f'commands.add_command("{command}"',
            f"commands.add_command('{command}'",
        )
        for registration in registrations:
            if registration in generated:
                errors.append(f"generated legacy source retains command registration: {registration}")
        cleanup_entry = f'["{command}"] = true'
        if cleanup_entry not in texts["cleanup"]:
            errors.append(f"{FILES['cleanup'].relative_to(ROOT)} missing cleanup entry: {cleanup_entry}")

    if errors:
        print("Legacy observability command audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Legacy observability command audit passed: eight report-only commands are retired and cleaned up; "
        "priest lookup, rank radii, active pair/name registries, legacy state, and inventory summary helpers remain."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
