#!/usr/bin/env python3
"""Validate canonical combat/acquisition behavior mutex route ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tech-priests_src/scripts/core/behavior_mutex_0466.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def main() -> int:
    errors: list[str] = []
    text = SOURCE.read_text(encoding="utf-8", errors="replace")
    if DIRECT_RE.search(text):
        errors.append("behavior mutex retains a direct script.on_* route")

    required = (
        'pcall(require, "scripts.core.runtime_event_registry")',
        'owner = "behavior_mutex_0466"',
        'route = "combat-acquisition-mutex-service"',
        'local cadence = registry.on_nth_tick',
        'if not cadence then',
        'M.wrap_globals()',
        'M.wrap_modules()',
        'M.install_commands()',
        '_G.TECH_PRIESTS_BEHAVIOR_MUTEX_0466 = M',
        '_G.tech_priests_pair_combat_active_0466 = M.combat_active',
        'M._installed = true',
        'return false',
    )
    for fragment in required:
        if fragment not in text:
            errors.append(f"behavior mutex missing contract: {fragment}")

    cadence = text.find('local cadence = registry.on_nth_tick')
    for later in (
        'ensure_root()',
        'M.wrap_globals()',
        'M.wrap_modules()',
        'M.install_commands()',
        '_G.TECH_PRIESTS_BEHAVIOR_MUTEX_0466 = M',
        '_G.tech_priests_pair_combat_active_0466 = M.combat_active',
        'M._installed = true',
    ):
        if cadence < 0 or text.rfind(later) < cadence:
            errors.append(f"behavior mutex publishes {later} before canonical route registration")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    history = HISTORY.read_text(encoding="utf-8", errors="replace")
    if "### Behavior mutex route ownership — 2026-07-24" not in testing:
        errors.append("testing goals missing 0798 behavior mutex route evidence")
    if "## Behavior Mutex Route Ownership — 2026-07-24" not in authority:
        errors.append("authority map missing 0798 behavior mutex route section")
    if "## 2026-07-24 — Milestone 0798: Behavior Mutex Route Ownership" not in history:
        errors.append("development history missing Milestone 0798")

    if errors:
        print("Behavior mutex route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Behavior mutex route ownership audit passed: one registry cadence, zero direct routes, fail-closed installation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
