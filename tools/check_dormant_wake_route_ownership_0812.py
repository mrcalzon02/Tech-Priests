#!/usr/bin/env python3
"""Validate Milestone 0812 dormant wake-event route ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tech-priests_src/scripts/core/efficiency_economy_0595.lua"
CONTROL = ROOT / "tech-priests_src/control.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
SEQUENCE = ROOT / "RECOVERY_REPAIR_SEQUENCE.md"


def main() -> int:
    errors: list[str] = []
    text = SOURCE.read_text(encoding="utf-8", errors="replace")
    required = (
        'owner = "efficiency_economy_0595"',
        'route = route',
        '"wake-build"',
        '"wake-remove"',
        '"wake-research"',
        'return true, unregister_all',
        'local routes_ok, rollback = M.register_events()',
    )
    for fragment in required:
        if fragment not in text:
            errors.append(f"0595 missing route contract: {fragment}")
    if "script.on_event(" in text:
        errors.append("0595 retains raw script.on_event fallback")
    # Optional Factorio events must not create holes in an ipairs ID list.
    for group, handler in (("build_events", "on_any_build"), ("remove_events", "on_any_remove")):
        start = text.find(f"  local {group} = {{")
        end = text.find("\n  }", start) if start >= 0 else -1
        if end < 0:
            errors.append(f"0595 missing {group} event list")
            continue
        entries = [line.strip().rstrip(",") for line in text[start:end].splitlines()[1:] if line.strip()]
        if len(entries) != 5 or any(not re.fullmatch(r'"[a-z_]+"', entry) for entry in entries):
            errors.append(f"0595 {group} must contain five event names, not potentially nil IDs")
        if f"for _, name in ipairs({group}) do" not in text or f"register_event(ev[name], {handler}" not in text:
            errors.append(f"0595 {group} must resolve event names during registration")

    install_start = text.find("function M.install()")
    install_end = text.find("\nend", install_start)
    if install_start < 0 or install_end < 0:
        errors.append("0595 installer boundary missing")
    else:
        install = text[install_start:install_end]
        route_accept = install.find("local routes_ok, rollback = M.register_events()")
        route_check = install.find("if routes_ok ~= true then return false end")
        protected_call = install.find("local ok, err = pcall(function()")
        command = install.find("M.commands()")
        publication = install.find("_G.tech_priests_runtime_active_0595 = M.runtime_active")
        nth_publication = install.find("_G.tech_priests_should_run_nth_tick_0595 = M.should_run_nth_tick")
        failure_check = install.find("if not ok then")
        rollback = install.find("if rollback then rollback() end")
        if not (0 <= route_accept < route_check < protected_call < command
                < publication < nth_publication < failure_check < rollback):
            errors.append("0595 must accept routes, register diagnostics, publish globals, then roll back on failure")

    control = CONTROL.read_text(encoding="utf-8", errors="replace")
    if "Economy0595.install() ~= true" not in control:
        errors.append("control.lua does not fail on rejected 0595 route ownership")

    docs = {
        TESTING: "## Milestone 0812 — Dormant wake-event route ownership",
        HISTORY: "## Milestone 0812 — Dormant Wake-Event Route Ownership",
        MAP: "## Milestone 0812 — Dormant Wake-Event Route Ownership",
        SEQUENCE: "Source implementation now consolidates dormant-runtime wake events in 0595",
    }
    for path, marker in docs.items():
        if marker not in path.read_text(encoding="utf-8", errors="replace"):
            errors.append(f"{path.relative_to(ROOT)} missing Milestone 0812 marker")

    if errors:
        print("Dormant wake-event route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Dormant wake-event route ownership audit passed: 0595 wake events are registry-owned, rollback-capable, and publish only after route acceptance.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
