#!/usr/bin/env python3
"""Validate registry-owned startup provisioning routes and fail-closed installation."""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
STARTUP = ROOT / "tech-priests_src/scripts/core/startup_provisioning.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
INTEGRATION = ROOT / "tools/check_development_integration_0732.py"
SOURCE_WORKFLOW = ROOT / ".github/workflows/source-validation.yml"
WORKFLOW = ROOT / ".github/workflows/startup-route-ownership-validation.yml"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def main() -> int:
    errors: list[str] = []
    text = STARTUP.read_text(encoding="utf-8", errors="replace")

    if DIRECT_RE.search(text):
        errors.append("startup_provisioning.lua retains a direct script.on_* route")
    if text.count("registry.on_event(") != 2:
        errors.append(f"startup provisioning must own exactly two registry event routes, found {text.count('registry.on_event(')}")
    if text.count("registry.on_nth_tick(") != 1:
        errors.append(f"startup provisioning must own exactly one registry cadence, found {text.count('registry.on_nth_tick(')}")
    if text.count('owner = "startup-provisioning-0324"') != 3:
        errors.append("startup provisioning must declare one stable owner on all three routes")

    for fragment in (
        'pcall(require, "scripts.core.runtime_event_registry")',
        'registry.on_event(defines.events.on_player_created, M.handle_player_created',
        'route = "player-created"',
        'registry.on_event(defines.events.on_player_joined_game, M.handle_player_joined',
        'route = "player-joined"',
        'registry.on_nth_tick(M.service_period',
        'route = "pending-station-kit-service"',
        '_G.grant_tech_priest_first_spawn_bonus = function(player)',
        'M.schedule(player.index, M.initial_delay_ticks)',
        'commands.add_command("tp-startup-0324"',
        'commands.add_command("tp-startup-0326"',
        'M.installed = true',
        'return false',
        'return true',
    ):
        if fragment not in text:
            errors.append(f"startup_provisioning.lua missing contract: {fragment}")

    if "local pending = registry.on_nth_tick" in text and "M.installed = true" in text:
        if text.index("M.installed = true") < text.index("local pending = registry.on_nth_tick"):
            errors.append("startup provisioning publishes installed state before cadence registration")
    if "local created = registry.on_event" in text and "_G.grant_tech_priest_first_spawn_bonus = function" in text:
        if text.index("_G.grant_tech_priest_first_spawn_bonus = function") < text.index("local created = registry.on_event"):
            errors.append("startup provisioning mutates compatibility authority before route registration")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    if "### Startup provisioning route ownership — 2026-07-23" not in testing:
        errors.append("CURRENT_TESTING_GOALS.md does not record 0795")
    if "## Startup Provisioning Route Ownership — 2026-07-23" not in authority:
        errors.append("RECOVERY_AUTHORITY_MAP_CURRENT.md does not record 0795")

    checker = "check_startup_route_ownership_0795.py"
    integration = INTEGRATION.read_text(encoding="utf-8", errors="replace")
    source_workflow = SOURCE_WORKFLOW.read_text(encoding="utf-8", errors="replace")
    workflow = WORKFLOW.read_text(encoding="utf-8", errors="replace")
    if checker not in integration:
        errors.append("development integration graph does not register 0795")
    if checker not in source_workflow or "Audit canonical startup provisioning route ownership" not in source_workflow:
        errors.append("Source validation does not run 0795")
    if checker not in workflow or "Audit canonical startup provisioning route ownership" not in workflow:
        errors.append("dedicated 0795 workflow is incomplete")

    if errors:
        print("Startup provisioning route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1

    print(
        "Startup provisioning route ownership audit passed: player creation, join, and pending-kit service are "
        "registry-owned; direct routes are absent; installation is fail-closed and behavior surfaces remain."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
