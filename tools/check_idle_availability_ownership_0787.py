#!/usr/bin/env python3
"""Validate canonical idle scan and conversation availability ownership."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "part4": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_004.lua",
    "part7": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_007.lua",
    "part13": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_013.lua",
    "part14": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_014.lua",
    "conversation": ROOT / "tech-priests_src/scripts/idle_priest_conversations.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "source_workflow": ROOT / ".github/workflows/source-validation.yml",
    "workflow": ROOT / ".github/workflows/idle-availability-validation.yml",
}

REQUIRED = {
    "part4": ("TECH_PRIESTS_BASE_IDLE_SCAN_AVAILABILITY_0248_MERGED = true",),
    "part7": ("TECH_PRIESTS_BASE_IDLE_CONVERSATION_AVAILABILITY_0249_MERGED = true",),
    "part13": (
        "TECH_PRIESTS_0246_IDLE_SCAN_AVAILABILITY_WRAPPER_RETIRED = true",
        "TECH_PRIESTS_0246_IDLE_CONVERSATION_AVAILABILITY_WRAPPER_RETIRED = true",
        "TECH_PRIESTS_FINAL_TICK_PAIR_BEFORE_DIAGNOSTICS_0246 = tick_pair",
    ),
    "part14": (
        "TECH_PRIESTS_IDLE_SCAN_AVAILABLE_PREDECESSORS_RETIRED = true",
        "function is_pair_available_for_idle_scan(pair)",
        "tech_priests_0248_higher_priority_probe and tech_priests_0248_higher_priority_probe(pair)",
        "tech_priests_0248_cancel_idle_layers(pair, probe.priority)",
        "tech_priests_0246_priority_blocks_idle and tech_priests_0246_priority_blocks_idle(pair)",
        "pair.idle_scan_quarantined_0246 = game and game.tick or 0",
        'read_global_bool_setting("tech-priests-enable-idle-scan-behavior", true)',
        "if pair.target and pair.target.valid then return false end",
        "if pair.idle_conversation or pair.idle_conversation_listener_until then return false end",
        "if pair.inventory_scan or pair.scavenge or pair.cram then return false end",
        "TECH_PRIESTS_0248_IDLE_CONVERSATION_AVAILABILITY_WRAPPER_RETIRED = true",
        "TECH_PRIESTS_TICK_PAIR_BEFORE_0248 = tick_pair",
    ),
    "conversation": (
        "TECH_PRIESTS_IDLE_CONVERSATION_AVAILABILITY_PREDECESSORS_RETIRED = true",
        "function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)",
        "tech_priests_idle_priest_conversations_higher_priority_visible_0249(pair)",
        "tech_priests_idle_priest_conversations_cancel_0249(pair, \"higher-priority-work\")",
        "tech_priests_0248_higher_priority_probe and tech_priests_0248_higher_priority_probe(pair)",
        "tech_priests_0248_cancel_idle_layers(pair, probe.priority)",
        "tech_priests_0246_priority_blocks_idle and tech_priests_0246_priority_blocks_idle(pair)",
        "pair.idle_conversation_quarantined_0246 = game and game.tick or 0",
        'read_global_bool_setting("tech-priests-enable-idle-conversations", true)',
        "if pair.inventory_scan or pair.scavenge or pair.cram or pair.emergency_craft then return false end",
        "if game.tick < (pair.next_idle_conversation_tick or 0) then return false end",
        "tech_priests_original_start_idle_conversation_0249",
        "tech_priests_original_update_idle_conversation_behavior_0249",
    ),
    "integration": ("check_idle_availability_ownership_0787.py",),
    "source_workflow": (
        "Audit canonical idle availability predicate ownership",
        "check_idle_availability_ownership_0787.py",
    ),
    "workflow": (
        "Audit canonical idle availability predicate ownership",
        "check_idle_availability_ownership_0787.py",
    ),
}

FORBIDDEN = {
    "part4": ("function is_pair_available_for_idle_scan(pair)",),
    "part7": ("function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)",),
    "part13": (
        "TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_SCAN_0246",
        "TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_CONVERSATION_0246",
        "function is_pair_available_for_idle_scan(pair)",
        "function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)",
    ),
    "part14": (
        "TECH_PRIESTS_IDLE_SCAN_AVAILABLE_BEFORE_0248",
        "TECH_PRIESTS_IDLE_CONVERSATION_AVAILABLE_BEFORE_0248",
        "function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)",
    ),
    "conversation": ("tech_priests_original_is_pair_available_for_idle_conversation_0249",),
}


def count_contract(text: str, needle: str, expected: int, label: str, errors: list[str]) -> None:
    actual = text.count(needle)
    if actual != expected:
        errors.append(f"{label} expected {expected} occurrence(s) of {needle!r}, found {actual}")


def main() -> int:
    errors: list[str] = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]:
                errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden availability predecessor: {fragment}")

    ownership = "\n".join(texts[name] for name in ("part4", "part7", "part13", "part14", "conversation"))
    count_contract(ownership, "function is_pair_available_for_idle_scan(pair)", 1, "canonical idle-scan predicate", errors)
    count_contract(ownership, "function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)", 1, "canonical conversation predicate", errors)

    if errors:
        print("Idle availability ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print(
        "Idle availability ownership audit passed: one idle-scan predicate and one conversation predicate "
        "directly own 0249 visibility, 0248 probing, 0246 quarantine, settings, state, mode, and cooldown checks."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
