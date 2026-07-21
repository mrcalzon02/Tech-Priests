#!/usr/bin/env python3
"""Print all combat target-selection and combat-service owners for milestone 0785."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
needles = (
    "function find_enemy_target(station, radius, priest)",
    "function enemy_inside_station_radius(station, enemy, radius)",
    "function tech_priests_0248_is_enemy_of_station(station, entity)",
    "function handle_combat(pair)",
)
for path in sorted((root / "tech-priests_src").rglob("*.lua")):
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    for needle in needles:
        for index, line in enumerate(lines):
            if needle in line:
                start = max(0, index - 24)
                end = min(len(lines), index + 100)
                print(f"=== {path.relative_to(root)}:{index + 1} :: {needle} ===")
                for offset in range(start, end):
                    print(f"{offset + 1:06d}: {lines[offset]}")
                print()
raise SystemExit("0785 combat ownership inspection complete; transformation intentionally not applied")
