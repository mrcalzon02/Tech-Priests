#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(".")
PARTS = tuple(
    ROOT / f"tech-priests_src/scripts/generated/control_legacy_part_{number:03d}.lua"
    for number in range(15, 21)
)
MARKER = r"-- 0\.1\.674-dev / 0792: retired manual generated command [^\n]+\."
BLOCK_RE = re.compile(
    rf"(?ms)^(?P<indent>[ \t]*)if commands(?: and commands\.add_command)? then\s*\n"
    rf"(?P<body>(?:[ \t]*{MARKER}[ \t]*\n)+)"
    rf"(?P=indent)end[ \t]*\n"
)
REGISTRY_RE = re.compile(r"TechPriestsRuntimeEventRegistry\.(?:on_event|on_nth_tick)\s*\(")
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")

before = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in PARTS)
registry_before = len(REGISTRY_RE.findall(before))
if registry_before != 31:
    raise SystemExit(f"0792 marker cleanup expected 31 registry routes, found {registry_before}")
if DIRECT_RE.search(before):
    raise SystemExit("0792 marker cleanup found an unexpected direct script.on_* route")

collapsed = 0
for path in PARTS:
    text = path.read_text(encoding="utf-8")

    def replace(match: re.Match[str]) -> str:
        nonlocal_collapsed[0] += 1
        indent = match.group("indent")
        markers = [line.strip() for line in match.group("body").splitlines() if line.strip()]
        return "".join(indent + line + "\n" for line in markers)

    nonlocal_collapsed = [0]
    while True:
        text, count = BLOCK_RE.subn(replace, text)
        if count == 0:
            break
    collapsed += nonlocal_collapsed[0]
    path.write_text(text.rstrip() + "\n", encoding="utf-8")

post = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in PARTS)
if BLOCK_RE.search(post):
    raise SystemExit("0792 marker-only command shell remains")
if len(REGISTRY_RE.findall(post)) != registry_before:
    raise SystemExit("0792 marker cleanup changed registry route ownership")
if DIRECT_RE.search(post):
    raise SystemExit("0792 marker cleanup introduced a direct script.on_* route")
marker_count = len(re.findall(MARKER, post))
if marker_count != 31:
    raise SystemExit(f"0792 expected 31 retirement markers after cleanup, found {marker_count}")

print(f"0792 marker shell cleanup complete: collapsed {collapsed} empty command blocks")
