#!/usr/bin/env python3
"""Print command registrations in the 0246-0249 priority and split layers."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
paths = [
    root / "tech-priests_src/scripts/generated/control_legacy_part_013.lua",
    root / "tech-priests_src/scripts/generated/control_legacy_part_014.lua",
    root / "tech-priests_src/scripts/idle_priest_conversations.lua",
    root / "tech-priests_src/scripts/idle_logistics_acquisition.lua",
]
needles = ("TechPriestsDebugCommandRegistry.add(", "commands.add_command(")
for path in paths:
    if not path.is_file():
        continue
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    for index, line in enumerate(lines):
        if any(needle in line for needle in needles):
            start = max(0, index - 8)
            end = min(len(lines), index + 70)
            print(f"=== {path.relative_to(root)}:{index + 1} :: {line.strip()} ===")
            for offset in range(start, end):
                print(f"{offset + 1:06d}: {lines[offset]}")
            print()
raise SystemExit("0788 priority command inspection complete; source intentionally unchanged")
