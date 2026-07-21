#!/usr/bin/env python3
"""Inventory remaining runtime command registrations after milestone 0789."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
patterns = (
    re.compile(r'TechPriestsDebugCommandRegistry\.add\(\s*["\']([^"\']+)["\']'),
    re.compile(r'commands\.add_command\(\s*["\']([^"\']+)["\']'),
)
rows = []
for path in sorted((root / "tech-priests_src").rglob("*.lua")):
    if path.name == "runtime_command_cleanup_0720.lua":
        continue
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    for index, line in enumerate(lines):
        for pattern in patterns:
            match = pattern.search(line)
            if match:
                rows.append((match.group(1), path.relative_to(root), index + 1, line.strip()))
for name, path, line_no, source in sorted(rows):
    print(f"{name}\t{path}:{line_no}\t{source}")
print(f"TOTAL={len(rows)}")
raise SystemExit("0790 command inventory complete; source intentionally unchanged")
