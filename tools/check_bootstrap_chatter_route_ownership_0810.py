#!/usr/bin/env python3
"""Validate canonical bootstrap composite and chatter cadence route ownership."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "chatter": ROOT / "tech-priests_src/scripts/core/chatter.lua",
    "bootstrap": ROOT / "tech-priests_src/scripts/core/bootstrap_runtime.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "architecture": ROOT / "tools/check_recovery_architecture_0744.py",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
    "history": ROOT / "docs/DEVELOPMENT_HISTORY.md",
    "testing": ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
    "map": ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md",
    "sequence": ROOT / "RECOVERY_REPAIR_SEQUENCE.md",
}

REQUIRED = {
    "chatter": (
        'owner = "chatter_0334"',
        'route_options("background-pulse")',
        'route_options("pending-line-visibility")',
        'pcall(registry.on_nth_tick, pulse_tick',
        'pcall(registry.on_nth_tick, Chatter.visibility_check_interval',
        'unregister_tick(registry, pulse_tick, pulse_options)',
        'Chatter.route_owner = "runtime-event-registry"',
        'selection tap remains in the final bootstrap selection chain',
        'TECH_PRIESTS_0332_PRE_ON_SELECTED_ENTITY_CHANGED',
    ),
    "bootstrap": (
        'owner = "bootstrap_runtime_0810"',
        '"explicit-consecration-capsule"',
        '"consecration-build-chain"',
        '"consecration-remove-chain"',
        '"consecration-selection-chain"',
        '"consecration-watchdog"',
        'tech_priests_0810_unregister_route(TECH_PRIESTS_0810_CONSECRATION_ROUTES[index])',
        '_G.TECH_PRIESTS_BOOTSTRAP_ROUTE_OWNER_0810 = "runtime-event-registry"',
        'TECH_PRIESTS_0409_PRE_ON_SELECTED_ENTITY_CHANGED',
    ),
    "integration": ('check_bootstrap_chatter_route_ownership_0810.py',),
    "architecture": (
        'check_bootstrap_chatter_route_ownership_0810.py',
        'bootstrap_runtime_0810',
        'chatter_0334',
    ),
    "workflow": (
        'Audit bootstrap and chatter route ownership',
        'check_bootstrap_chatter_route_ownership_0810.py',
    ),
    "history": (
        '## Milestone 0810 — Bootstrap and Chatter Route Ownership',
        'No Factorio runtime proof is claimed',
    ),
    "testing": (
        '## Milestone 0810 — Bootstrap and chatter route ownership',
        'selection-chain',
        'chatter cadence',
    ),
    "map": (
        '## Milestone 0810 — Bootstrap and Chatter Route Ownership',
        'consecration-selection-chain',
        'background-pulse',
    ),
    "sequence": (
        'Source implementation now consolidates bootstrap composite events and chatter cadences',
    ),
}

FORBIDDEN = {
    "chatter": ('script.on_event(', 'script.on_nth_tick('),
    "bootstrap": ('script.on_event(', 'script.on_nth_tick('),
}


def main() -> int:
    errors: list[str] = []
    texts: dict[str, str] = {}
    for name, path in FILES.items():
        if not path.is_file():
            errors.append(f"missing file: {path.relative_to(ROOT)}")
            texts[name] = ""
        else:
            texts[name] = path.read_text(encoding="utf-8", errors="replace")

    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden raw route: {fragment}")

    chatter = texts["chatter"]
    first_route = chatter.find('pcall(registry.on_nth_tick, pulse_tick')
    root_init = chatter.find('local root_ok = pcall(ensure_root)')
    publication = chatter.find('_G.tech_priests_0334_recent_conversation_keys_for_pair')
    installed = chatter.find('Chatter._installed = true')
    if not (0 <= first_route < root_init < publication < installed):
        errors.append("chatter publication order is not route -> root -> globals -> installed")

    bootstrap = texts["bootstrap"]
    selection_route = bootstrap.find('"consecration-selection-chain"')
    owner_publication = bootstrap.find('_G.TECH_PRIESTS_BOOTSTRAP_ROUTE_OWNER_0810')
    helper_retirement = bootstrap.find('tech_priests_0810_event_registry = nil')
    if not (0 <= selection_route < owner_publication < helper_retirement):
        errors.append("bootstrap route ownership publication/cleanup order is invalid")

    if errors:
        print("Bootstrap/chatter route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Bootstrap/chatter route ownership audit passed: composite events and chatter cadences are registry-owned without raw fallback.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
