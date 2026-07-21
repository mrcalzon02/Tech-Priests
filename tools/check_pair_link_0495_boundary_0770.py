#!/usr/bin/env python3
"""Validate retired 0495 and broker-owned canonical lifecycle observation in 0499."""
from __future__ import annotations
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "retired": ROOT / "tech-priests_src/scripts/core/pair_link_hardening_0495.lua",
    "lifecycle": ROOT / "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
    "control": ROOT / "tech-priests_src/control.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "retired": ('retired = true', 'authority = "pair_link_hardening_0495"', 'replacement = "priest_lifecycle_authority_0499"', 'return M'),
    "lifecycle": ('version = "0.1.674-dev"', 'broker_required = true', 'pair_link_integrated = true', 'local function repair_reverse_maps', 'local function rebind_nearby_orphan', 'lifecycle.missing_since', 'function M.register_broker_service', 'name = "priest_lifecycle_observation_0499"', 'broker.register_service', 'function M.service_all(_, budget)'),
    "control": ('Historical 0495 pair-link wrapper is retired into priest_lifecycle_authority_0499',),
    "cleanup": ('["tp-pair-link-0495"] = true',),
    "planning": ('retired_authority_count=44', '["scripts.core.pair_link_hardening_0495"]'),
    "workflow": ('Audit retired 0495 pair-link authority', 'check_pair_link_0495_boundary_0770.py'),
}
FORBIDDEN = {
    "retired": ('function M.install', 'ensure_pair_priest', 'respawn_pair_priest', 'commands.add_command', 'on_nth_tick', 'register_service', 'pair.target', 'pair.mode'),
    "lifecycle": ('TechPriestsPairLinkHardening0495', 'pair.link_0495', 'R.on_nth_tick', 'registry.on_nth_tick', 'script.on_nth_tick'),
    "control": ('require("scripts.core.pair_link_hardening_0495")',),
}
def main() -> int:
    errors = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}")
    if errors:
        print("0495 lifecycle boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("0495 lifecycle boundary audit passed: pair-link wrapper is inert; 0499 owns broker-budgeted observation without replacement.")
    return 0
if __name__ == "__main__": raise SystemExit(main())
