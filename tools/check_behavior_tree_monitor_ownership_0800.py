#!/usr/bin/env python3
"""Validate broker-first behavior-tree monitor ownership and registry fallback."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tech-priests_src/scripts/core/behavior_tree_monitor_0642.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def main() -> int:
    errors: list[str] = []
    text = SOURCE.read_text(encoding="utf-8", errors="replace")
    if DIRECT_RE.search(text):
        errors.append("behavior-tree monitor retains a direct script.on_* route")

    required = (
        'pcall(require, "scripts.core.runtime_tick_broker")',
        'pcall(broker.register_service',
        'name = "behavior_tree_monitor_0642"',
        'pcall(require, "scripts.core.runtime_event_registry")',
        'owner = "behavior_tree_monitor_0642"',
        'route = "behavior-tree-monitor-fallback"',
        'if not owner then',
        'M.route_owner = owner',
        'M.installed = true',
        'return false',
    )
    for fragment in required:
        if fragment not in text:
            errors.append(f"behavior-tree monitor missing contract: {fragment}")

    broker = text.find('pcall(broker.register_service')
    registry = text.find('route = "behavior-tree-monitor-fallback"')
    if broker < 0 or registry < 0 or broker > registry:
        errors.append("behavior-tree monitor does not preserve broker-first ownership")
    for later in (
        'root()',
        '_G.TechPriestsBehaviorTreeMonitor0642 = M',
        '_G.tech_priests_behavior_tree_0642_mark = M.mark',
        'M.route_owner = owner',
        'M.installed = true',
    ):
        if registry < 0 or text.rfind(later) < registry:
            errors.append(f"behavior-tree monitor publishes {later} before canonical ownership resolution")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    history = HISTORY.read_text(encoding="utf-8", errors="replace")
    if "### Behavior-tree monitor route ownership — 2026-07-24" not in testing:
        errors.append("testing goals missing 0800 behavior-tree monitor evidence")
    if "## Behavior-Tree Monitor Route Ownership — 2026-07-24" not in authority:
        errors.append("authority map missing 0800 behavior-tree monitor section")
    if "## 2026-07-24 — Milestone 0800: Behavior-Tree Monitor Route Ownership" not in history:
        errors.append("development history missing Milestone 0800")

    if errors:
        print("Behavior-tree monitor ownership audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Behavior-tree monitor ownership audit passed: broker primary, one registry fallback, zero direct routes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
