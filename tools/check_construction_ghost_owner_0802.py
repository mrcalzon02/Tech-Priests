#!/usr/bin/env python3
"""Validate broker-first construction bootstrap ghost planner ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tech-priests_src/scripts/core/construction_bootstrap_ghost_planner_0645.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def main() -> int:
    errors: list[str] = []
    text = SOURCE.read_text(encoding="utf-8", errors="replace")
    if DIRECT_RE.search(text):
        errors.append("construction ghost planner retains a direct script.on_* route")
    required = (
        'pcall(require, "scripts.core.runtime_tick_broker")',
        'pcall(broker.register_service',
        'name = "construction_bootstrap_ghost_planner_0645"',
        'pcall(require, "scripts.core.runtime_event_registry")',
        'route = "construction-bootstrap-ghost-fallback"',
        'M.route_owner = owner',
        'M.installed = true',
        'return false',
    )
    for fragment in required:
        if fragment not in text:
            errors.append(f"construction ghost planner missing contract: {fragment}")
    broker = text.find('pcall(broker.register_service')
    registry = text.find('route = "construction-bootstrap-ghost-fallback"')
    if broker < 0 or registry < 0 or broker > registry:
        errors.append("construction ghost planner does not preserve broker-first ownership")
    for later in ('root()', '_G.TechPriestsConstructionBootstrapGhostPlanner0645 = M', 'M.route_owner = owner', 'M.installed = true'):
        if registry < 0 or text.rfind(later) < registry:
            errors.append(f"construction ghost planner publishes {later} before ownership resolution")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    history = HISTORY.read_text(encoding="utf-8", errors="replace")
    if "### Construction ghost planner ownership — 2026-07-24" not in testing:
        errors.append("testing goals missing 0802 construction ghost evidence")
    if "## Construction Ghost Planner Ownership — 2026-07-24" not in authority:
        errors.append("authority map missing 0802 construction ghost section")
    if "## 2026-07-24 — Milestone 0802: Construction Ghost Planner Ownership" not in history:
        errors.append("development history missing Milestone 0802")

    if errors:
        print("Construction ghost planner ownership audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("Construction ghost planner ownership audit passed: broker primary, one registry fallback, zero direct routes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
