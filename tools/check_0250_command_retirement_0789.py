#!/usr/bin/env python3
"""Validate retirement of 0250-0255 diagnostic commands without removing runtime behavior."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "part14": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_014.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "source_workflow": ROOT / ".github/workflows/source-validation.yml",
    "workflow": ROOT / ".github/workflows/command-retirement-0250-validation.yml",
}

COMMANDS = (
    "tp-emergency-miner-debug",
    "tp-assignment-debug",
    "tp-power-chain-debug",
    "tp-fuel-bootstrap-debug",
    "tp-magos-planner-debug",
)

REQUIRED = {
    "part14": (
        "TECH_PRIESTS_0250_DEBUG_COMMAND_RETIRED = true",
        "function tech_priests_0252_service_assignment(pair)",
        "TECH_PRIESTS_TICK_PAIR_BEFORE_ASSIGNMENTS_0252 = tick_pair",
        "function tick_pair(pair)",
        "TECH_PRIESTS_0252_DEBUG_COMMAND_RETIRED = true",
        "function tech_priests_ensure_power_chain_before_laboratorium_0253",
        "TECH_PRIESTS_0253_DEBUG_COMMAND_RETIRED = true",
        "TECH_PRIESTS_0254_DEBUG_COMMAND_RETIRED = true",
        "function tech_priests_0255_service_magos_standard_planner(pair, op)",
        "TECH_PRIESTS_0255_DEBUG_COMMAND_RETIRED = true",
        'tech_priests_0252_diag("ranked emergency assignment delegation loaded")',
        'tech_priests_0255_diag("Planetary Magos standard-industry degradation planner loaded")',
    ),
    "integration": ("check_0250_command_retirement_0789.py",),
    "source_workflow": (
        "Audit retired 0250 through 0255 diagnostic commands",
        "check_0250_command_retirement_0789.py",
    ),
    "workflow": (
        "Audit retired 0250 through 0255 diagnostic commands",
        "check_0250_command_retirement_0789.py",
    ),
}

GLOBAL_RUNTIME_REQUIRED = (
    "function tech_priests_debug_emergency_miner_0250",
    "TECH_PRIESTS_EMERGENCY_FUELLED_ENTITIES_0254",
    "function tech_priests_get_fuel_inventory_0254",
)


def main() -> int:
    errors: list[str] = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}
    all_lua = "\n".join(
        path.read_text(encoding="utf-8", errors="replace")
        for path in (ROOT / "tech-priests_src").rglob("*.lua")
    )

    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")

    for fragment in GLOBAL_RUNTIME_REQUIRED:
        if fragment not in all_lua:
            errors.append(f"tech-priests_src missing preserved runtime contract: {fragment}")

    for command in COMMANDS:
        for prefix in ('TechPriestsDebugCommandRegistry.add("', 'commands.add_command("'):
            registration = prefix + command + '"'
            if registration in all_lua:
                errors.append(f"tech-priests_src retains command registration: {registration}")
        cleanup_entry = f'["{command}"] = true'
        if cleanup_entry not in texts["cleanup"]:
            errors.append(f"{FILES['cleanup'].relative_to(ROOT)} missing cleanup entry: {cleanup_entry}")

    if texts["part14"].count("TECH_PRIESTS_TICK_PAIR_BEFORE_ASSIGNMENTS_0252 = tick_pair") != 1:
        errors.append("0252 assignment tick wrapper is not preserved exactly once")

    if errors:
        print("0250-0255 command retirement audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "0250-0255 command retirement audit passed: five manual diagnostics are retired and cleaned up; "
        "emergency miner reporting, assignment service, power-chain, fuel, and Magos planner behavior remain."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
