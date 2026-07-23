#!/usr/bin/env python3
"""Validate commandless generated fragments 015-020 and preserved registry ownership."""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PART_COMMANDS = {
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_015.lua": (
        "tp-force-emergency", "tp-emergency-status", "tp-write-emergency-log",
        "tp-survival-status", "tp-bootstrap-now", "tp-fast-debug-status",
        "tp-raw-fallback-debug", "tp-refresh-orders",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_016.lua": (
        "tp-no-resources-debug", "tp-subordinates-debug", "tp-direct-gather-debug",
        "tp-replan-gather", "tp-scheduler-0277",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_017.lua": (
        "tp-radar-0278", "tp-radar-0281", "tp-radar-0282", "tp-radar-0283",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_018.lua": (
        "tp-fanout-0284", "tp-scheduler-0285", "tp-scheduler-0286",
        "tp-acquire-0287", "tp-craft-0290", "tp-ground-0291", "tp-combat-0292",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_019.lua": (
        "tp-combat-0293", "tp-retreat-0294", "tp-swarm-0295",
        "tp-supply-0296", "tp-armor-0297",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_020.lua": (
        "tp-reimprint-0298", "tp-preserve-0301",
    ),
}
CLEANUP = ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
INTEGRATION = ROOT / "tools/check_development_integration_0732.py"
SOURCE_WORKFLOW = ROOT / ".github/workflows/source-validation.yml"
WORKFLOW = ROOT / ".github/workflows/generated-command-retirement-validation.yml"
COMMANDS = tuple(command for commands in PART_COMMANDS.values() for command in commands)
COMMAND_RE = re.compile(
    r"(?:TechPriestsDebugCommandRegistry\.add|commands\.add_command)\(\s*([\"'])([^\"']+)\1"
)
DIRECT_ROUTE_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")
REGISTRY_ROUTE_RE = re.compile(r"TechPriestsRuntimeEventRegistry\.(?:on_event|on_nth_tick)\s*\(")
MARKER_SHELL_RE = re.compile(
    r"(?ms)^\s*if commands(?: and commands\.add_command)? then\s*\n"
    r"(?:\s*-- 0\.1\.674-dev / 0792: retired manual generated command [^\n]+\.\s*\n)+"
    r"\s*end\s*$"
)


def main() -> int:
    errors: list[str] = []
    part_texts = {path: path.read_text(encoding="utf-8", errors="replace") for path in PART_COMMANDS}
    combined = "\n".join(part_texts.values())
    cleanup = CLEANUP.read_text(encoding="utf-8", errors="replace")

    registrations = [match.group(2) for match in COMMAND_RE.finditer(combined)]
    for command in COMMANDS:
        if command in registrations:
            errors.append(f"generated fragments retain retired command registration: {command}")
        marker = f"-- 0.1.674-dev / 0792: retired manual generated command {command}."
        owning_text = next(text for path, text in part_texts.items() if command in PART_COMMANDS[path])
        if owning_text.count(marker) != 1:
            errors.append(f"generated fragments require exactly one retirement marker for {command}")
        cleanup_entry = f'["{command}"] = true'
        if cleanup_entry not in cleanup:
            errors.append(f"runtime command cleanup missing {command}")

    registry_routes = len(REGISTRY_ROUTE_RE.findall(combined))
    if registry_routes != 31:
        errors.append(f"fragments 015-020 must retain exactly 31 registry routes, found {registry_routes}")
    if DIRECT_ROUTE_RE.search(combined):
        errors.append("fragments 015-020 contain a direct script.on_* route")
    if MARKER_SHELL_RE.search(combined):
        errors.append("fragments 015-020 retain an empty command compatibility shell around 0792 markers")

    integration = INTEGRATION.read_text(encoding="utf-8", errors="replace")
    source_workflow = SOURCE_WORKFLOW.read_text(encoding="utf-8", errors="replace")
    workflow = WORKFLOW.read_text(encoding="utf-8", errors="replace")
    checker_name = "check_generated_command_retirement_0792.py"
    if checker_name not in integration:
        errors.append("development integration graph does not register 0792")
    if checker_name not in source_workflow or "Audit retired generated command surfaces" not in source_workflow:
        errors.append("Source validation does not run 0792")
    if checker_name not in workflow or "Audit retired generated command surfaces" not in workflow:
        errors.append("dedicated 0792 workflow is incomplete")

    if errors:
        print("Generated command retirement audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Generated command retirement audit passed: 31 manual registrations are retired and cleaned up; "
        "31 registry-owned automatic routes remain; direct script routes and empty command shells are absent."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
