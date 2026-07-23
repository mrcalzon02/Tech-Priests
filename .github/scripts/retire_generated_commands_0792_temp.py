#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(".")
PART_COMMANDS = {
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_015.lua": (
        "tp-force-emergency",
        "tp-emergency-status",
        "tp-write-emergency-log",
        "tp-survival-status",
        "tp-bootstrap-now",
        "tp-fast-debug-status",
        "tp-raw-fallback-debug",
        "tp-refresh-orders",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_016.lua": (
        "tp-no-resources-debug",
        "tp-subordinates-debug",
        "tp-direct-gather-debug",
        "tp-replan-gather",
        "tp-scheduler-0277",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_017.lua": (
        "tp-radar-0278",
        "tp-radar-0281",
        "tp-radar-0282",
        "tp-radar-0283",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_018.lua": (
        "tp-fanout-0284",
        "tp-scheduler-0285",
        "tp-scheduler-0286",
        "tp-acquire-0287",
        "tp-craft-0290",
        "tp-ground-0291",
        "tp-combat-0292",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_019.lua": (
        "tp-combat-0293",
        "tp-retreat-0294",
        "tp-swarm-0295",
        "tp-supply-0296",
        "tp-armor-0297",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_020.lua": (
        "tp-reimprint-0298",
        "tp-preserve-0301",
    ),
}
CLEANUP = ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
ALL_COMMANDS = tuple(command for commands in PART_COMMANDS.values() for command in commands)
COMMAND_RE = re.compile(
    r"(?:TechPriestsDebugCommandRegistry\.add|commands\.add_command)\(\s*([\"'])([^\"']+)\1"
)
DIRECT_ROUTE_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")
REGISTRY_ROUTE_RE = re.compile(r"TechPriestsRuntimeEventRegistry\.(?:on_event|on_nth_tick)\s*\(")


def matching_paren(text: str, open_index: int) -> int:
    depth = 0
    quote: str | None = None
    i = open_index
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in ("\"", "'"):
            quote = ch
            i += 1
            continue
        if ch == "-" and nxt == "-":
            newline = text.find("\n", i + 2)
            if newline < 0:
                return len(text) - 1
            i = newline + 1
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise SystemExit("unbalanced Lua parentheses while retiring generated command")


def line_bounds(text: str, start: int, end: int) -> tuple[int, int]:
    line_start = text.rfind("\n", 0, start) + 1
    line_end = end
    while line_end < len(text) and text[line_end] in " \t;":
        line_end += 1
    if line_end < len(text) and text[line_end] == "\n":
        line_end += 1
    return line_start, line_end


def command_span(text: str, command: str) -> tuple[int, int]:
    matches = [match for match in COMMAND_RE.finditer(text) if match.group(2) == command]
    if len(matches) != 1:
        raise SystemExit(f"{command}: expected exactly one registration in owning fragment, found {len(matches)}")
    match = matches[0]
    open_index = text.find("(", match.start())
    close_index = matching_paren(text, open_index)
    statement_start, statement_end = line_bounds(text, match.start(), close_index + 1)

    # Most generated commands are isolated inside pcall(function() ... end). Retire
    # that wrapper with the command so no empty compatibility shell remains.
    pcall_start = text.rfind("pcall(function()", 0, statement_start)
    if pcall_start >= 0:
        outer_open = text.find("(", pcall_start)
        outer_close = matching_paren(text, outer_open)
        if statement_end <= outer_close + 1:
            prefix = text[pcall_start + len("pcall(function()"):statement_start].strip()
            suffix = text[statement_end:outer_close + 1].strip()
            if not prefix and suffix in {"end)", "end);"}:
                return line_bounds(text, pcall_start, outer_close + 1)
    return statement_start, statement_end


def marker(command: str) -> str:
    return f"-- 0.1.674-dev / 0792: retired manual generated command {command}.\n"


def collapse_marker_only_command_blocks(text: str) -> str:
    pattern = re.compile(
        r"(?ms)^(?P<indent>[ \t]*)if commands(?: and commands\.add_command)? then\s*\n"
        r"(?P<body>(?:(?P=indent)[ \t]+-- 0\.1\.674-dev / 0792: retired manual generated command [^\n]+\.\s*\n)+)"
        r"(?P=indent)end\s*\n"
    )

    def replace(match: re.Match[str]) -> str:
        indent = match.group("indent")
        lines = [line.strip() for line in match.group("body").splitlines() if line.strip()]
        return "".join(indent + line + "\n" for line in lines)

    while True:
        updated, count = pattern.subn(replace, text)
        text = updated
        if count == 0:
            return text


before = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in PART_COMMANDS)
found_before = [match.group(2) for match in COMMAND_RE.finditer(before)]
if sorted(found_before) != sorted(ALL_COMMANDS):
    missing = sorted(set(ALL_COMMANDS) - set(found_before))
    extra = sorted(set(found_before) - set(ALL_COMMANDS))
    raise SystemExit(f"0792 precondition mismatch: missing={missing}, unexpected={extra}")
if DIRECT_ROUTE_RE.search(before):
    raise SystemExit("0792 precondition failed: fragments 015-020 contain direct script.on_* routes")
registry_count_before = len(REGISTRY_ROUTE_RE.findall(before))
if registry_count_before != 31:
    raise SystemExit(f"0792 expected 31 registry-owned routes before retirement, found {registry_count_before}")

for path, commands in PART_COMMANDS.items():
    text = path.read_text(encoding="utf-8")
    spans = []
    for command in commands:
        start, end = command_span(text, command)
        spans.append((start, end, command))
    for start, end, command in sorted(spans, reverse=True):
        text = text[:start] + marker(command) + text[end:]
    text = collapse_marker_only_command_blocks(text)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")

cleanup = CLEANUP.read_text(encoding="utf-8")
anchor = '  ["tp-cog-summary"] = true,'
entries = "\n".join(f'  ["{command}"] = true,' for command in ALL_COMMANDS)
if all(f'["{command}"] = true' in cleanup for command in ALL_COMMANDS):
    pass
elif cleanup.count(anchor) == 1:
    cleanup = cleanup.replace(anchor, anchor + "\n" + entries, 1)
    CLEANUP.write_text(cleanup, encoding="utf-8")
else:
    raise SystemExit("0792 runtime command cleanup anchor mismatch")

post = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in PART_COMMANDS)
remaining = [match.group(2) for match in COMMAND_RE.finditer(post) if match.group(2) in ALL_COMMANDS]
if remaining:
    raise SystemExit(f"0792 retired commands remain: {sorted(remaining)}")
if DIRECT_ROUTE_RE.search(post):
    raise SystemExit("0792 introduced a direct script.on_* route")
registry_count_after = len(REGISTRY_ROUTE_RE.findall(post))
if registry_count_after != registry_count_before:
    raise SystemExit(
        f"0792 changed automatic registry routes: before={registry_count_before}, after={registry_count_after}"
    )
for command in ALL_COMMANDS:
    if marker(command).strip() not in post:
        raise SystemExit(f"0792 missing retirement marker for {command}")
    if f'["{command}"] = true' not in CLEANUP.read_text(encoding="utf-8"):
        raise SystemExit(f"0792 cleanup missing {command}")

history = HISTORY.read_text(encoding="utf-8")
heading = "## 2026-07-23 — Milestone 0792: Generated Command Surface Retirement"
if heading not in history:
    history += (
        f"\n\n{heading}\n\n"
        "Retired all 31 manual command registrations in generated fragments 015–020. The removed surfaces covered emergency forcing and reporting, bootstrap forcing, fast/raw fallback diagnostics, order refresh, gather replanning, scheduler and radar reports, station craft and acquisition forcing, combat and retreat forcing, supply sanitation, armor refresh, re-imprint servicing, and cell-preservation inspection. The transformation changed no automatic event or cadence route: the fragments retain 31 TechPriestsRuntimeEventRegistry routes and zero direct script.on_* fallbacks. All underlying service and helper functions remain in their authoritative source locations, and runtime_command_cleanup_0720 removes every stale name. Static validation does not constitute Factorio runtime proof.\n"
    )
    HISTORY.write_text(history, encoding="utf-8")

print(
    "0792 generated command retirement complete: 31 registrations retired, "
    f"{registry_count_after} automatic registry routes preserved, zero direct routes."
)
