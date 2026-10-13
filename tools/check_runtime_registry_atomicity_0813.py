#!/usr/bin/env python3
"""Fail-closed source contract for registry callback installation (Milestone 0813)."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tech-priests_src/scripts/core/runtime_event_registry.lua"


def section(text: str, start: str, end: str) -> str:
    left = text.find(start)
    right = text.find(end, left + len(start)) if left >= 0 else -1
    return text[left:right] if left >= 0 and right > left else ""


def audit(text: str) -> list[str]:
    errors: list[str] = []
    contracts = (
        ("event", "local function install_event(id)", "local function install_tick(tick)",
         "script.on_event(id,function(event)dispatch_event(key,event)end)",
         "Registry.installed_events[key]=id", "type(script.on_event)",
         "function Registry.on_event(id,handler,filters,opts)",
         "function Registry.on_nth_tick(tick,handler,opts)",
         "if not install_event(id) then return nil end",
         "local action=upsert(Registry.event_routes[key],entry)"),
        ("nth-tick", "local function install_tick(tick)", "local function uninstall_event(key)",
         "script.on_nth_tick(tick,function(event)dispatch_tick(key,event)end)",
         "Registry.installed_nth_ticks[key]=tick", "type(script.on_nth_tick)",
         "function Registry.on_nth_tick(tick,handler,opts)",
         "local function lifecycle(list,handler,opts,name)",
         "if not install_tick(tick) then return nil end",
         "local action=upsert(Registry.nth_tick_routes[key],entry)"),
    )
    for name, begin, end, call, marker, api, register_begin, register_end, guard, upsert in contracts:
        installer = section(text, begin, end)
        registration = section(text, register_begin, register_end)
        if not installer or not registration:
            errors.append(f"{name}: missing installer or registration boundary")
            continue
        if api not in installer or "then return false end" not in installer:
            errors.append(f"{name}: missing fail-closed unavailable-API guard")
        if "then return true end" not in installer:
            errors.append(f"{name}: missing idempotent accepted-callback guard")
        if not (0 <= installer.find(call) < installer.find(marker) < installer.find("return true", installer.find(marker))):
            errors.append(f"{name}: installed marker precedes Factorio callback acceptance")
        if not (0 <= registration.find(guard) < registration.find(upsert)):
            errors.append(f"{name}: owner route inserted before callback acceptance")
    return errors


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    errors = audit(source)
    if "--self-test" in sys.argv:
        mutants = (
            source.replace("script.on_event(id,function(event)dispatch_event(key,event)end)\n Registry.installed_events[key]=id",
                           "Registry.installed_events[key]=id\n script.on_event(id,function(event)dispatch_event(key,event)end)"),
            source.replace("script.on_nth_tick(tick,function(event)dispatch_tick(key,event)end)\n Registry.installed_nth_ticks[key]=tick",
                           "Registry.installed_nth_ticks[key]=tick\n script.on_nth_tick(tick,function(event)dispatch_tick(key,event)end)"),
            source.replace("if not install_event(id) then return nil end;local action=upsert(",
                           "local action=upsert("),
            source.replace("if not install_tick(tick) then return nil end;local action=upsert(",
                           "local action=upsert("),
        )
        for index, mutant in enumerate(mutants, 1):
            if mutant == source or not audit(mutant):
                errors.append(f"self-test mutant {index} was not rejected")
    if errors:
        print("Registry installation atomicity audit FAILED:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Registry installation atomicity source audit passed (event and nth-tick).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
