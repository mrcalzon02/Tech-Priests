#!/usr/bin/env python3
"""Print idle scan and conversation availability owners for milestone 0787."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
needles = (
    "function is_pair_available_for_idle_scan(pair)",
    "is_pair_available_for_idle_scan = function(pair)",
    "function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)",
    "tech_priests_is_pair_available_for_idle_conversation_0167 = function(pair, as_listener)",
)
for path in sorted((root / "tech-priests_src").rglob("*.lua")):
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    emitted: set[tuple[int, str]] = set()
    for needle in needles:
        for index, line in enumerate(lines):
            if needle in line and (index, line) not in emitted:
                emitted.add((index, line))
                start = max(0, index - 28)
                end = min(len(lines), index + 130)
                print(f"=== {path.relative_to(root)}:{index + 1} :: {line.strip()} ===")
                for offset in range(start, end):
                    print(f"{offset + 1:06d}: {lines[offset]}")
                print()
raise SystemExit("0787 idle availability inspection complete; transformation intentionally not applied")
