#!/usr/bin/env python3
"""Print repair and consecration target selector owners for milestone 0786."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
needles = (
    "function find_damaged_target(station, radius, priest)",
    "find_damaged_target = function(station, radius, priest)",
    "function find_consecration_target_for_station(station, radius, priest)",
    "find_consecration_target_for_station = function(station, radius, priest)",
)
for path in sorted((root / "tech-priests_src").rglob("*.lua")):
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    emitted: set[tuple[int, str]] = set()
    for needle in needles:
        for index, line in enumerate(lines):
            if needle in line and (index, line) not in emitted:
                emitted.add((index, line))
                start = max(0, index - 24)
                end = min(len(lines), index + 130)
                print(f"=== {path.relative_to(root)}:{index + 1} :: {line.strip()} ===")
                for offset in range(start, end):
                    print(f"{offset + 1:06d}: {lines[offset]}")
                print()
raise SystemExit("0786 cached target ownership inspection complete; transformation intentionally not applied")
