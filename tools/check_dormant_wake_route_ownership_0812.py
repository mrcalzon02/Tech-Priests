#!/usr/bin/env python3
"""Validate Milestone 0812 dormant wake-event route ownership."""
from __future__ import annotations

import pathlib
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
    if text.find("M.register_events()") > text.find("_G.tech_priests_runtime_active_0595"):
        errors.append("0595 publishes globals before route acceptance")

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
