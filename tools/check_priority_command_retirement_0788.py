#!/usr/bin/env python3
"""Validate retirement of 0246-0249 manual priority, sweep, and logistics commands."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "part13": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_013.lua",
    "part14": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_014.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "source_workflow": ROOT / ".github/workflows/source-validation.yml",
    "workflow": ROOT / ".github/workflows/priority-command-retirement-validation.yml",
}

COMMANDS = (
    "tp-debug",
    "tp-dump-state",
    "tp-rebuild-registries",
    "tp-force-station-scan",
    "tp-sweep-debug",
    "tp-logistics-debug",
)

REQUIRED = {
    "part13": (
        "function tech_priests_0246_rebuild_station_registry(player)",
        "function tech_priests_0246_dump_state(player)",
        "function tech_priests_0246_force_station_scan(player)",
        "TECH_PRIESTS_0246_DEBUG_COMMANDS_RETIRED = true",
        "TECH_PRIESTS_0246_REGISTRY_COMMANDS_RETIRED = true",
        "TechPriestsRuntimeEventRegistry.on_nth_tick(73, function()",
        "tech_priests_0246_diagnostics_enabled()",
        "tech_priests_0246_diag_line(\"diagnostic heartbeat online; registered=\"",
    ),
    "part14": (
        "function tech_priests_0248_update_station_sweep(pair)",
        "function tech_priests_0248_higher_priority_probe(pair)",
        "TECH_PRIESTS_0248_SWEEP_DEBUG_COMMAND_RETIRED = true",
        "function tech_priests_0249_report_logistics_for_station(station, player)",
        "TECH_PRIESTS_0249_LOGISTICS_DEBUG_COMMAND_RETIRED = true",
        'require("scripts.idle_priest_conversations")',
        'require("scripts.idle_logistics_acquisition")',
    ),
    "integration": ("check_priority_command_retirement_0788.py",),
    "source_workflow": (
        "Audit retired priority sweep and logistics commands",
        "check_priority_command_retirement_0788.py",
    ),
    "workflow": (
        "Audit retired priority sweep and logistics commands",
        "check_priority_command_retirement_0788.py",
    ),
}

FORBIDDEN = {
    "part13": tuple(
        fragment
        for name in COMMANDS[:4]
        for fragment in (
            f'TechPriestsDebugCommandRegistry.add("{name}"',
            f'commands.add_command("{name}"',
        )
    ),
    "part14": tuple(
        fragment
        for name in COMMANDS[4:]
        for fragment in (
            f'TechPriestsDebugCommandRegistry.add("{name}"',
            f'commands.add_command("{name}"',
        )
    ),
}


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
                errors.append(f"{FILES[name].relative_to(ROOT)} contains retired command registration: {fragment}")

    for command in COMMANDS:
        cleanup_entry = f'["{command}"] = true'
        if cleanup_entry not in texts["cleanup"]:
            errors.append(f"{FILES['cleanup'].relative_to(ROOT)} missing stale-command cleanup: {cleanup_entry}")

    combined = texts["part13"] + "\n" + texts["part14"]
    for command in COMMANDS:
        for prefix in ('TechPriestsDebugCommandRegistry.add("', 'commands.add_command("'):
            registration = prefix + command + '"'
            actual = combined.count(registration)
            if actual != 0:
                errors.append(f"generated priority sources retain {actual} registration(s) for {command}")

    if texts["part13"].count("TechPriestsRuntimeEventRegistry.on_nth_tick(73, function()") != 1:
        errors.append("0246 automatic diagnostic heartbeat is not owned by exactly one 73-tick route")

    if errors:
        print("Priority command retirement audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Priority command retirement audit passed: six 0246-0249 manual commands are retired and cleaned up; "
        "automatic diagnostics, registry helpers, sweep updates, and logistics behavior remain available."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
