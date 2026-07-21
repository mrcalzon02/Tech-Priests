#!/usr/bin/env python3
"""Print every generated beam, scan-line, and direct-extraction definition with context."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
needle_set = (
    "function draw_emergency_craft_scan_line(pair, target_entity)",
    "function tech_priests_0312_fire_laser(priest, target, damage, reason, color)",
    "function tech_priests_0312_service_direct_current(pair, task)",
    "function tech_priests_0315_service_direct_current(pair, task)",
    "function handle_emergency_desperation_craft(pair)",
)
for path in sorted((root / "tech-priests_src").rglob("*.lua")):
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    for needle in needle_set:
        for index, line in enumerate(lines):
            if needle in line:
                start = max(0, index - 20)
                end = min(len(lines), index + 70)
                print(f"=== {path.relative_to(root)}:{index + 1} :: {needle} ===")
                for offset in range(start, end):
                    print(f"{offset + 1:06d}: {lines[offset]}")
                print()
raise SystemExit("0784 extraction inspection complete; transformation intentionally not applied")
