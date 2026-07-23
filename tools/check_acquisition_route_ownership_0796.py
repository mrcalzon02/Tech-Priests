#!/usr/bin/env python3
"""Validate registry-owned acquisition executor, repair, and unstick cadences."""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
EXECUTOR = ROOT / "tech-priests_src/scripts/core/acquisition_executor.lua"
REPAIR = ROOT / "tech-priests_src/scripts/core/acquisition_repair.lua"
UNSTICK = ROOT / "tech-priests_src/scripts/core/acquisition_unstick.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
INTEGRATION = ROOT / "tools/check_development_integration_0732.py"
SOURCE_WORKFLOW = ROOT / ".github/workflows/source-validation.yml"
WORKFLOW = ROOT / ".github/workflows/acquisition-route-ownership-validation.yml"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def main() -> int:
    errors: list[str] = []
    modules = (
        (EXECUTOR, "acquisition_executor", "direct-acquisition-executor-pulse", "Exec.installed_0507 = true", "Exec.commands()", 30),
        (REPAIR, "acquisition_repair", "assigned-idle-repair-watchdog", "Repair.installed_0507 = true", "Repair.commands()", 90),
        (UNSTICK, "acquisition_unstick", "acquisition-unstick-watchdog", "Unstick.installed_0507 = true", "Unstick.commands()", 120),
    )

    for path, owner, route, installed, commands, period in modules:
        text = path.read_text(encoding="utf-8", errors="replace")
        if DIRECT_RE.search(text):
            errors.append(f"{path.name} retains a direct script.on_* route")
        if text.count("registry.on_nth_tick(") != 1:
            errors.append(f"{path.name} must own exactly one registry cadence")
        for fragment in (
            'pcall(require, "scripts.core.runtime_event_registry")',
            f'owner = "{owner}"',
            f'route = "{route}"',
            installed,
            commands,
            "return false",
            "return true",
        ):
            if fragment not in text:
                errors.append(f"{path.name} missing contract: {fragment}")
        if f"registry.on_nth_tick({period}" not in text:
            errors.append(f"{path.name} does not preserve its {period}-tick cadence")
        cadence = text.find("local cadence = registry.on_nth_tick")
        if cadence >= 0:
            if text.rfind(installed) < cadence:
                errors.append(f"{path.name} publishes installed state before cadence registration")
            if text.rfind(commands) < cadence:
                errors.append(f"{path.name} installs commands before cadence registration")

    repair = REPAIR.read_text(encoding="utf-8", errors="replace")
    cadence = repair.find("local cadence = registry.on_nth_tick")
    if cadence >= 0 and repair.rfind("Repair.wrap_emergency_acquire()") < cadence:
        errors.append("acquisition_repair.lua wraps emergency acquisition before cadence registration")

    executor = EXECUTOR.read_text(encoding="utf-8", errors="replace")
    unstick = UNSTICK.read_text(encoding="utf-8", errors="replace")
    if 'Exec.pulse("nth-tick-30-acquisition-executor-owned-0507")' not in executor:
        errors.append("acquisition_executor.lua changed its canonical pulse reason")
    if 'Unstick.pulse("nth-tick-120-acquisition-unstick-owned-0507")' not in unstick:
        errors.append("acquisition_unstick.lua changed its canonical pulse reason")
    if "Repair.watch_assigned_idle" not in repair:
        errors.append("acquisition_repair.lua lost assigned-idle repair behavior")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    if "### Acquisition route ownership — 2026-07-23" not in testing:
        errors.append("CURRENT_TESTING_GOALS.md does not record 0796")
    if "## Acquisition Route Ownership — 2026-07-23" not in authority:
        errors.append("RECOVERY_AUTHORITY_MAP_CURRENT.md does not record 0796")

    checker = "check_acquisition_route_ownership_0796.py"
    integration = INTEGRATION.read_text(encoding="utf-8", errors="replace")
    source_workflow = SOURCE_WORKFLOW.read_text(encoding="utf-8", errors="replace")
    workflow = WORKFLOW.read_text(encoding="utf-8", errors="replace")
    if checker not in integration:
        errors.append("development integration graph does not register 0796")
    if checker not in source_workflow or "Audit canonical acquisition route ownership" not in source_workflow:
        errors.append("Source validation does not run 0796")
    if checker not in workflow or "Audit canonical acquisition route ownership" not in workflow:
        errors.append("dedicated 0796 workflow is incomplete")

    if errors:
        print("Acquisition route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Acquisition route ownership audit passed: executor, repair, and unstick own one registry cadence each; "
        "direct fallbacks are absent; wrappers, commands, pulse semantics, and installed-state ordering remain valid."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
