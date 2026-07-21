#!/usr/bin/env python3
"""Print 0250-era generated manual command registrations for milestone 0789."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
commands = (
    "tp-emergency-miner-debug",
    "tp-assignment-debug",
    "tp-power-chain-debug",
    "tp-fuel-bootstrap-debug",
    "tp-magos-planner-debug",
)
for path in sorted((root / "tech-priests_src").rglob("*.lua")):
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    for index, line in enumerate(lines):
        if any((f'"{name}"' in line) for name in commands):
            start = max(0, index - 16)
            end = min(len(lines), index + 90)
            print(f"=== {path.relative_to(root)}:{index + 1} :: {line.strip()} ===")
            for offset in range(start, end):
                print(f"{offset + 1:06d}: {lines[offset]}")
            print()
raise SystemExit("0789 0250-era command inspection complete; source intentionally unchanged")
