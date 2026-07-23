#!/usr/bin/env python3
"""Validate canonical consecration GUI, lifecycle, and cadence ownership."""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
HISTORY_GUI = ROOT / "tech-priests_src/scripts/core/consecration/history_gui.lua"
RUNTIME_BRIDGE = ROOT / "tech-priests_src/scripts/core/consecration/runtime_bridge.lua"
MINING_SENSOR = ROOT / "tech-priests_src/scripts/core/consecration/mining_sensor_0495.lua"
GUI_ROUTER = ROOT / "tech-priests_src/scripts/gui/gui_router.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
INTEGRATION = ROOT / "tools/check_development_integration_0732.py"
SOURCE_WORKFLOW = ROOT / ".github/workflows/source-validation.yml"
WORKFLOW = ROOT / ".github/workflows/consecration-route-ownership-validation.yml"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def require(text: str, fragment: str, label: str, errors: list[str]) -> None:
    if fragment not in text:
        errors.append(f"{label} missing contract: {fragment}")


def main() -> int:
    errors: list[str] = []
    history = HISTORY_GUI.read_text(encoding="utf-8", errors="replace")
    bridge = RUNTIME_BRIDGE.read_text(encoding="utf-8", errors="replace")
    sensor = MINING_SENSOR.read_text(encoding="utf-8", errors="replace")
    router = GUI_ROUTER.read_text(encoding="utf-8", errors="replace")
    combined = "\n".join((history, bridge, sensor))

    if DIRECT_RE.search(combined):
        errors.append("consecration route owners retain a direct script.on_* route")

    for fragment in (
        'pcall(require, "scripts.gui.gui_router")',
        'router.register("opened", M.handle_gui_opened, "consecration-history-opened-0422")',
        'router.register("closed", M.handle_gui_closed, "consecration-history-closed-0422")',
        'router.register("click", M.handle_gui_click, "consecration-history-click-0422")',
        'registry.on_nth_tick(121, function() M.refresh_all_open() end',
        'owner = "consecration-history-gui"',
        'route = "refresh-open-history"',
        'return false',
    ):
        require(history, fragment, "history_gui.lua", errors)
    if "gui_bus" in history:
        errors.append("history_gui.lua still routes through the compatibility GUI bus")
    if "TechPriestsRuntimeEventRegistry.on_event" in history:
        errors.append("history_gui.lua still duplicates GUI handlers through the event registry")
    for label in (
        "consecration-history-opened-0422",
        "consecration-history-closed-0422",
        "consecration-history-click-0422",
    ):
        if history.count(label) != 1:
            errors.append(f"history_gui.lua requires exactly one labeled route: {label}")

    for fragment in (
        'pcall(require, "scripts.core.runtime_event_registry")',
        'route = "register-built-entity"',
        'route = "remove-destroyed-entity"',
        'registry.on_nth_tick(89, service_scan',
        'route = "periodic-target-scan"',
        'return false',
    ):
        require(bridge, fragment, "runtime_bridge.lua", errors)
    if bridge.count("registry.on_event({") != 2:
        errors.append("runtime_bridge.lua must own exactly two grouped registry event routes")
    if bridge.count("registry.on_nth_tick(89, service_scan") != 1:
        errors.append("runtime_bridge.lua must own exactly one 89-tick registry route")
    if "Fallback only" in bridge or "elseif script" in bridge:
        errors.append("runtime_bridge.lua retains fallback ownership text or branch")

    for fragment in (
        'pcall(require, "scripts.core.runtime_event_registry")',
        'local cadence = registry.on_nth_tick(M.tick_interval',
        'owner = "consecration_mining_sensor_0495"',
        'route = "periodic-mining-operation-scan"',
        'M.installed = true',
        'M.register_commands()',
        'return false',
    ):
        require(sensor, fragment, "mining_sensor_0495.lua", errors)
    if sensor.count("registry.on_nth_tick(M.tick_interval") != 1:
        errors.append("mining_sensor_0495.lua must own exactly one registry cadence")
    if sensor.index("M.installed = true") < sensor.index("local cadence = registry.on_nth_tick"):
        errors.append("mining_sensor_0495.lua publishes installed state before cadence registration")
    if sensor.index("_G.TechPriestsConsecrationMiningSensor0495 = M") < sensor.index("local cadence = registry.on_nth_tick"):
        errors.append("mining_sensor_0495.lua publishes its global before cadence registration")

    for fragment in (
        'This module is the runtime owner for GUI opened/closed/click dispatch.',
        'registry.on_event(defines.events.on_gui_opened, Router.dispatch_opened',
        'registry.on_event(defines.events.on_gui_closed, Router.dispatch_closed',
        'registry.on_event(defines.events.on_gui_click, Router.dispatch_click',
    ):
        require(router, fragment, "gui_router.lua", errors)

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    if "### Consecration route ownership — 2026-07-23" not in testing:
        errors.append("CURRENT_TESTING_GOALS.md does not record 0794")
    if "## Consecration Route Ownership — 2026-07-23" not in authority:
        errors.append("RECOVERY_AUTHORITY_MAP_CURRENT.md does not record 0794")

    checker = "check_consecration_route_ownership_0794.py"
    integration = INTEGRATION.read_text(encoding="utf-8", errors="replace")
    source_workflow = SOURCE_WORKFLOW.read_text(encoding="utf-8", errors="replace")
    workflow = WORKFLOW.read_text(encoding="utf-8", errors="replace")
    if checker not in integration:
        errors.append("development integration graph does not register 0794")
    if checker not in source_workflow or "Audit canonical consecration route ownership" not in source_workflow:
        errors.append("Source validation does not run 0794")
    if checker not in workflow or "Audit canonical consecration route ownership" not in workflow:
        errors.append("dedicated 0794 workflow is incomplete")

    if errors:
        print("Consecration route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Consecration route ownership audit passed: GUI handlers are router-owned; three consecration cadences/event groups "
        "are registry-owned; six direct routes and duplicate GUI bindings are absent; installers fail closed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
