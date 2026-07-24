#!/usr/bin/env python3
"""Validate canonical behavior-contract service route ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tech-priests_src/scripts/core/behavior_contracts_0479.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def main() -> int:
    errors: list[str] = []
    text = SOURCE.read_text(encoding="utf-8", errors="replace")
    if DIRECT_RE.search(text):
        errors.append("behavior contracts retains a direct script.on_* route")

    required = (
        'pcall(require, "scripts.core.runtime_event_registry")',
        'owner = "behavior_contracts_0479"',
        'route = "behavior-contract-service"',
        'local cadence = registry.on_nth_tick',
        'if not cadence then',
        'M.wrap_scan_line()',
        'M.wrap_laser()',
        'M.wrap_diagnostics()',
        '_G.TECH_PRIESTS_BEHAVIOR_CONTRACTS_0479 = M',
        'M.register_commands()',
        'M._installed = true',
        'return false',
    )
    for fragment in required:
        if fragment not in text:
            errors.append(f"behavior contracts missing contract: {fragment}")

    cadence = text.find('local cadence = registry.on_nth_tick')
    for later in (
        'root()',
        'M.wrap_scan_line()',
        'M.wrap_laser()',
        'M.wrap_diagnostics()',
        '_G.TECH_PRIESTS_BEHAVIOR_CONTRACTS_0479 = M',
        'M.register_commands()',
        'M._installed = true',
    ):
        if cadence < 0 or text.rfind(later) < cadence:
            errors.append(f"behavior contracts publishes {later} before canonical route registration")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    history = HISTORY.read_text(encoding="utf-8", errors="replace")
    if "### Behavior contracts route ownership — 2026-07-24" not in testing:
        errors.append("testing goals missing 0799 behavior contracts route evidence")
    if "## Behavior Contracts Route Ownership — 2026-07-24" not in authority:
        errors.append("authority map missing 0799 behavior contracts route section")
    if "## 2026-07-24 — Milestone 0799: Behavior Contracts Route Ownership" not in history:
        errors.append("development history missing Milestone 0799")

    if errors:
        print("Behavior contracts route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Behavior contracts route ownership audit passed: one registry cadence, zero direct routes, fail-closed installation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
