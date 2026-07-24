#!/usr/bin/env python3
"""Validate disabled-by-default bootstrap resource governor route ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tech-priests_src/scripts/core/bootstrap_resource_governor_0637.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def main() -> int:
    errors: list[str] = []
    text = SOURCE.read_text(encoding="utf-8", errors="replace")
    if DIRECT_RE.search(text):
        errors.append("bootstrap governor retains a direct script.on_* route")

    required = (
        'enabled=false',
        'pcall(require, "scripts.core.runtime_event_registry")',
        'owner = "bootstrap_resource_governor_0637"',
        'route = "bootstrap-reserve-service"',
        'local cadence = registry.on_nth_tick',
        'if not cadence then return false end',
        'install_command()',
        '_G.TechPriestsBootstrapResourceGovernor0637 = M',
        'M.installed = true',
    )
    for fragment in required:
        if fragment not in text:
            errors.append(f"bootstrap governor missing contract: {fragment}")

    cadence = text.find('local cadence = registry.on_nth_tick')
    for later in ('M.root()', 'install_command()', '_G.TechPriestsBootstrapResourceGovernor0637 = M', 'M.installed = true'):
        if cadence < 0 or text.rfind(later) < cadence:
            errors.append(f"bootstrap governor publishes {later} before route registration")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    history = HISTORY.read_text(encoding="utf-8", errors="replace")
    if "### Bootstrap resource governor route ownership — 2026-07-24" not in testing:
        errors.append("testing goals missing 0801 bootstrap governor evidence")
    if "## Bootstrap Resource Governor Route Ownership — 2026-07-24" not in authority:
        errors.append("authority map missing 0801 bootstrap governor section")
    if "## 2026-07-24 — Milestone 0801: Bootstrap Resource Governor Route Ownership" not in history:
        errors.append("development history missing Milestone 0801")

    if errors:
        print("Bootstrap governor route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Bootstrap governor route ownership audit passed: disabled by default, one registry cadence, zero direct routes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
