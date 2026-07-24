#!/usr/bin/env python3
"""Validate canonical stable Cogitator overlay and Alt-writ route ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tech-priests_src/scripts/core/alt_writ_visual_stability_0474.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def main() -> int:
    errors: list[str] = []
    text = SOURCE.read_text(encoding="utf-8", errors="replace")
    if DIRECT_RE.search(text):
        errors.append("stable visual authority retains a direct script.on_* route")

    required = (
        'pcall(require, "scripts.core.runtime_event_registry")',
        'owner = "alt_writ_visual_stability_0474"',
        'route = "periodic-stable-overlay-refresh"',
        'route = "cursor-stack-refresh"',
        'route = "runtime-setting-refresh"',
        'route = "selected-entity-refresh"',
        'local cadence = registry.on_nth_tick',
        'local cursor = registry.on_event',
        'local settings = registry.on_event',
        'local selected = registry.on_event',
        'if not (cadence and cursor and settings and selected) then',
        'M.register_commands()',
        'M._installed = true',
        'return false',
    )
    for fragment in required:
        if fragment not in text:
            errors.append(f"stable visual authority missing contract: {fragment}")

    route_anchor = text.find('local cadence = registry.on_nth_tick')
    for later in (
        'ensure_root()',
        'patch_legacy_visual_modules()',
        '_G.TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474 = M',
        '_G.tech_priests_0474_refresh_stable_visuals = M.refresh_all',
        'M.register_commands()',
        'M._installed = true',
    ):
        position = text.rfind(later)
        if route_anchor < 0 or position < route_anchor:
            errors.append(f"stable visual authority publishes {later} before canonical route registration")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    history = HISTORY.read_text(encoding="utf-8", errors="replace")
    if "### Stable visual route ownership — 2026-07-24" not in testing:
        errors.append("testing goals missing 0797 stable visual route ownership evidence")
    if "## Stable Visual Route Ownership — 2026-07-24" not in authority:
        errors.append("authority map missing 0797 stable visual route ownership section")
    if "## 2026-07-24 — Milestone 0797: Stable Visual Route Ownership" not in history:
        errors.append("development history missing Milestone 0797")

    if errors:
        print("Stable visual route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Stable visual route ownership audit passed: four registry routes, zero direct routes, fail-closed installation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
