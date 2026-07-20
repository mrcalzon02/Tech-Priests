#!/usr/bin/env python3
"""Validate canonical combat command routing and observer-only safety predicates."""
from __future__ import annotations
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "safety": ROOT / "tech-priests_src/scripts/core/combat_safety.lua",
    "movement": ROOT / "tech-priests_src/scripts/core/movement_controller.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "safety": ('version = "0.1.674-dev"', 'command_routing_observer_only = true', 'proxy_prime_observer_only = true', 'function M.is_valid_hostile_target', 'function M.clear_invalid_combat_state', 'return true'),
    "movement": ('local CombatSafety = nil', 'local function valid_hostile_target', 'friendly_attack_commands_blocked', 'invalid_proxy_prime_blocked', 'movement-controller-attack-rejected', '0292-prime-rejected-0419', '0293-prime-rejected-0419'),
    "workflow": ('Audit canonical combat command safety boundary', 'check_combat_command_boundary_0763.py'),
}
FORBIDDEN = {
    "safety": ('TECH_PRIESTS_0322_PRE_ISSUE_PRIEST_COMMAND', 'function issue_priest_command', 'TECH_PRIESTS_0322_PRE_0292_PRIME_PROXY_ATTACK', 'function tech_priests_0292_prime_proxy_attack', 'TECH_PRIESTS_0322_PRE_0293_PRIME_PROXY_ATTACK', 'function tech_priests_0293_prime_proxy_attack'),
}

def main() -> int:
    errors: list[str] = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden wrapper: {fragment}")
    if errors:
        print("Combat command boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("Combat command boundary audit passed: combat_safety supplies predicates; movement_controller alone routes attack and proxy-prime commands.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
