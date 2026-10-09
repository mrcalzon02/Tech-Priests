#!/usr/bin/env python3
"""Validate Milestone 0811 economy-housekeeping route ownership."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CORE = ROOT / "tech-priests_src/scripts/core"
ROUTES = {
    "efficiency_economy_0568.lua": "cache-prune",
    "efficiency_economy_0569.lua": "dirty-region-prune",
    "efficiency_economy_0570.lua": "negative-cache-prune",
    "efficiency_economy_0571.lua": "maintenance-cache-prune",
    "efficiency_economy_0575.lua": "corridor-cache-service",
    "efficiency_economy_0576.lua": "machine-claim-cleanup",
    "efficiency_economy_0578.lua": "prototype-cache-housekeeping",
    "efficiency_economy_0579.lua": "catalog-index-cleanup",
    "efficiency_economy_0582.lua": "behavior-cache-cleanup",
    "efficiency_economy_0585.lua": "coalesced-dirty-flush",
    "efficiency_economy_0593.lua": "performance-cache-prune",
    "efficiency_economy_0594.lua": "adaptive-route-rescan",
}
EXTRA = {
    "efficiency_economy_0576.lua": ("diagnostic-settings", "on_runtime_mod_setting_changed"),
}
CONTROL = ROOT / "tech-priests_src/control.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
SEQUENCE = ROOT / "RECOVERY_REPAIR_SEQUENCE.md"


def main() -> int:
    errors: list[str] = []
    for filename, route in ROUTES.items():
        path = CORE / filename
        if not path.is_file():
            errors.append(f"missing economy authority file: {path.relative_to(ROOT)}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        owner = filename.removesuffix(".lua")
        if "TechPriestsRuntimeEventRegistry" not in text or "runtime_event_registry" not in text:
            errors.append(f"{filename} does not require/discover canonical runtime_event_registry")
        if f'owner="{owner}"' not in text or f'route="{route}"' not in text:
            errors.append(f"{filename} missing stable owner/route identity {owner}:{route}")
        if "script.on_nth_tick(" in text:
            errors.append(f"{filename} retains raw script.on_nth_tick fallback")
        if "script.on_event(" in text:
            errors.append(f"{filename} retains raw script.on_event fallback")
    for filename, fragments in EXTRA.items():
        text = (CORE / filename).read_text(encoding="utf-8", errors="replace")
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{filename} missing route contract: {fragment}")

    control = CONTROL.read_text(encoding="utf-8", errors="replace")
    for filename in ROUTES:
        tag = filename.removeprefix("efficiency_economy_").removesuffix(".lua")
        varname = "Economy" + tag
        if f'{varname}.install() ~= true' not in control:
            errors.append(f"control.lua does not fail closed on {filename} install result")

    docs = {
        TESTING: "## Milestone 0811 — Economy housekeeping route ownership",
        HISTORY: "## Milestone 0811 — Economy Housekeeping Route Ownership",
        MAP: "## Milestone 0811 — Economy Housekeeping Route Ownership",
        SEQUENCE: "Source implementation now consolidates the remaining economy-housekeeping cadences",
    }
    for path, marker in docs.items():
        if not path.is_file() or marker not in path.read_text(encoding="utf-8", errors="replace"):
            errors.append(f"{path.relative_to(ROOT)} missing Milestone 0811 marker")

    early = (CORE / "efficiency_economy_0596.lua").read_text(encoding="utf-8", errors="replace")
    if "script.on_nth_tick = function" not in early:
        errors.append("0596 early raw-nth hook unexpectedly disappeared before the remaining direct-route audit is complete")

    if errors:
        print("Economy-housekeeping route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Economy-housekeeping route ownership audit passed: 12 housekeeping cadences are registry-owned, control observes literal install success, and 0596 remains explicitly temporary.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
