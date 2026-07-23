#!/usr/bin/env python3
"""Validate complete generated-command closure and automatic route preservation."""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "tech-priests_src/scripts/generated"
CLEANUP = ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
INTEGRATION = ROOT / "tools/check_development_integration_0732.py"
SOURCE_WORKFLOW = ROOT / ".github/workflows/source-validation.yml"
WORKFLOW = ROOT / ".github/workflows/generated-command-closure-validation.yml"
COMMANDS = (
    "tp-event-registry-0425",
    "tp-special-movement-0430",
    "tp-consecration-0347",
    "tech-priests-emergency-operation",
    "tech-priests-debug-priests",
    "tech-priests-lifecycle-log",
    "tp-scan-nearby",
)
COMMAND_RE = re.compile(
    r"(?:TechPriestsDebugCommandRegistry\.add|commands\.add_command)\(\s*([\"'])([^\"']+)\1"
)
REGISTRY_RE = re.compile(r"TechPriestsRuntimeEventRegistry\.(?:on_event|on_nth_tick)\s*\(")
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def main() -> int:
    errors: list[str] = []
    parts = sorted(GENERATED.glob("control_legacy_part_*.lua"))
    generated = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in parts)
    cleanup = CLEANUP.read_text(encoding="utf-8", errors="replace")

    registrations = [match.group(2) for match in COMMAND_RE.finditer(generated)]
    if registrations:
        errors.append(f"generated fragments retain command registrations: {registrations}")
    registry_routes = len(REGISTRY_RE.findall(generated))
    if registry_routes != 69:
        errors.append(f"generated fragments must retain exactly 69 registry routes, found {registry_routes}")
    if DIRECT_RE.search(generated):
        errors.append("generated fragments contain a direct script.on_* route")

    for command in COMMANDS:
        marker = f"-- 0.1.674-dev / 0793: retired manual generated command {command}."
        if generated.count(marker) != 1:
            errors.append(f"generated source requires exactly one 0793 marker for {command}")
        cleanup_entry = f'["{command}"] = true'
        if cleanup_entry not in cleanup:
            errors.append(f"runtime command cleanup missing {command}")

    known_check = "if initial_cleanup and KNOWN_COMMANDS[name] then return true end"
    prefix_check = "if string.sub(name, 1, #M.prefix) ~= M.prefix then return false end"
    if known_check not in cleanup or prefix_check not in cleanup:
        errors.append("runtime command cleanup is missing exact-known or prefix ownership checks")
    elif cleanup.index(known_check) > cleanup.index(prefix_check):
        errors.append("runtime command cleanup rejects historical exact-known names before ownership lookup")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    if "### Generated command closure — 2026-07-23" not in testing:
        errors.append("CURRENT_TESTING_GOALS.md does not record generated command closure")
    if "Generated fragments now contain zero command registrations" not in testing:
        errors.append("CURRENT_TESTING_GOALS.md does not record zero generated commands")
    if "## Generated Command Closure — 2026-07-23" not in authority:
        errors.append("RECOVERY_AUTHORITY_MAP_CURRENT.md does not record generated command closure")

    checker = "check_generated_command_closure_0793.py"
    integration = INTEGRATION.read_text(encoding="utf-8", errors="replace")
    source_workflow = SOURCE_WORKFLOW.read_text(encoding="utf-8", errors="replace")
    workflow = WORKFLOW.read_text(encoding="utf-8", errors="replace")
    if checker not in integration:
        errors.append("development integration graph does not register 0793")
    if checker not in source_workflow or "Audit complete generated command closure" not in source_workflow:
        errors.append("Source validation does not run 0793")
    if checker not in workflow or "Audit complete generated command closure" not in workflow:
        errors.append("dedicated 0793 workflow is incomplete")

    if errors:
        print("Generated command closure audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Generated command closure audit passed: zero generated commands remain; 69 registry routes and zero "
        "direct routes remain; exact historical command cleanup and governance records are complete."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
